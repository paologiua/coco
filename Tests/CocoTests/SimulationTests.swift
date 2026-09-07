import Testing
import Foundation
@testable import Coco

/// XCTest ships with Xcode, which is not installed here; swift-testing ships with the
/// Command Line Tools, so these use `Testing`.
struct SimulationTests {
    let epoch = Date(timeIntervalSince1970: 1_757_000_000)

    func sim(_ mutate: (inout SavedState) -> Void = { _ in }) -> Simulation {
        var state = SavedState.fresh(now: epoch)
        mutate(&state)
        return Simulation(state: state)
    }

    func hours(_ n: Double) -> Date { epoch.addingTimeInterval(n * 3600) }

    // MARK: - Decay

    @Test func hungerEmptiesInFortyEightHours() {
        let s = sim()
        // Stepped, because a single 48-hour jump is charged as 12 by the catch-up cap.
        for hour in stride(from: 12.0, through: 48.0, by: 12.0) { s.advance(to: hours(hour)) }
        #expect(s.needs.hunger == 0)
    }

    @Test func affectionOutlastsHunger() {
        let s = sim()
        for hour in stride(from: 12.0, through: 48.0, by: 12.0) { s.advance(to: hours(hour)) }
        #expect(s.needs.hunger == 0)
        #expect(s.needs.affection > 0)
    }

    // MARK: - Catch-up

    @Test func threeDaysAwayCostsNoMoreThanTwelveHours() {
        let away = sim();  away.advance(to: hours(72))
        let short = sim(); short.advance(to: hours(12))
        #expect(abs(away.needs.hunger - short.needs.hunger) < 0.001)
    }

    @Test func longAbsenceIsFlaggedForAReunion() {
        let s = sim(); s.advance(to: hours(30))
        #expect(s.returnedFromLongAbsence)
    }

    @Test func shortAbsenceIsNotAReunion() {
        let s = sim(); s.advance(to: hours(2))
        #expect(!s.returnedFromLongAbsence)
    }

    @Test func backwardsClockChargesNothing() {
        let s = sim(); s.advance(to: hours(-10))
        #expect(s.needs == .full)
    }

    // MARK: - Mood

    @Test func moodIgnoresEnergySoSheIsNotSadEveryEvening() {
        let s = sim { $0.needs = Needs(hunger: 90, affection: 90, energy: 1) }
        #expect(s.mood == .happy)
    }

    @Test func moodTakesTheWorstNeedNotTheAverage() {
        let s = sim { $0.needs = Needs(hunger: 100, affection: 10, energy: 100) }
        #expect(s.mood == .sad)   // an average would have called this "happy"
    }

    // MARK: - Actions

    @Test func feedingIsRefusedWhenFull() {
        let s = sim()
        #expect(!s.canFeed)
        #expect(s.feed() == .refused(.notHungry))
    }

    @Test func hungryBirdCanStartAndCompleteFeeding() {
        let s = sim { $0.needs.hunger = 50 }
        #expect(s.canFeed)
        #expect(s.feed() == .done)
        #expect(s.needs.hunger == 95)
    }

    @Test func playingIsRefusedWhenTooTired() {
        let s = sim { $0.needs = Needs(hunger: 50, affection: 50, energy: 10) }
        #expect(s.play() == .refused(.tooTired))
    }

    @Test func pettingIsCappedPerHour() {
        let s = sim { $0.needs = Needs(hunger: 50, affection: 0, energy: 50) }
        for _ in 0..<20 { _ = s.pet(at: epoch) }
        #expect(abs(s.needs.affection - Simulation.petCapPerHour) < 0.001)
        #expect(s.pet(at: epoch) == .refused(.pettedEnough))
    }

    @Test func pettingCapResetsAfterAnHour() {
        let s = sim { $0.needs = Needs(hunger: 50, affection: 0, energy: 50) }
        for _ in 0..<20 { _ = s.pet(at: epoch) }
        #expect(s.pet(at: epoch.addingTimeInterval(3601)) == .done)
    }

    // MARK: - Sleep

    @Test func emptyEnergyPutsHerIntoDeepSleep() {
        let s = sim { $0.needs = Needs(hunger: 50, affection: 50, energy: 21) }
        // A minute at a time, as the live tick does. One flat one-hour advance means
        // the app was not running for that hour, and rests her instead of tiring her.
        for minute in 1...15 { s.advance(to: epoch.addingTimeInterval(Double(minute) * 60)) }
        #expect(s.sleep == .deep)
    }

    @Test func aClosedLaptopRestsHerRatherThanTiringHer() {
        // Left awake, lid shut for the night. This used to be charged as twelve hours
        // spent awake — minus 75 energy — so she was found flat out every morning and
        // stayed asleep until nearly lunchtime. Opening your laptop is not a fine.
        let s = sim { $0.needs = Needs(hunger: 80, affection: 80, energy: 80) }
        s.advance(to: hours(10))
        #expect(s.needs.energy == 100)
        #expect(s.sleep == .awake)
        // Hunger and Affection are right to decay across it: she really was unfed.
        #expect(s.needs.hunger < 80)
    }

    @Test func aDozeIsWorthLessThanRealSleep() {
        let dozing = sim { $0.needs.energy = 20 }
        dozing.machineWentIdle()
        let sleeping = sim { $0.sleep = .deep; $0.needs.energy = 20 }
        for minute in 1...10 {
            let at = epoch.addingTimeInterval(Double(minute) * 60)
            dozing.advance(to: at)
            sleeping.advance(to: at)
        }
        #expect(sleeping.needs.energy > dozing.needs.energy + 20)
        // The point of the slower rate: a lunch break must not refill her. If it did
        // she would never fall below the Deep Sleep threshold again, and the sleeping
        // pose, the perching and the startle would only ever happen unobserved.
        #expect(dozing.needs.energy < 26)
    }

    @Test func aHandAskedNapEndsWhenItSaysItDoes() {
        // Tired but not empty, so the nap is about three and a half minutes. On expiry
        // it used to fall through to the energy rules and hold her under until 60 —
        // hours, from a menu item that promised a doze.
        let s = sim { $0.needs = Needs(hunger: 80, affection: 80, energy: 30) }
        s.putToSleep(at: epoch)
        s.advance(to: epoch.addingTimeInterval(60))
        #expect(s.sleep == .deep)
        s.advance(to: epoch.addingTimeInterval(400))
        #expect(s.sleep == .awake)
        #expect(s.needs.energy < Simulation.wakesAbove)
    }

    @Test func aDeepSleepLastsMinutesNotAnAfternoon() {
        // The number the human actually experiences: how long she is unreachable for,
        // with Feed and Play both refused. Twenty to sixty at the deep rate.
        let s = sim { $0.sleep = .deep; $0.needs.energy = Simulation.deepSleepBelow }
        for minute in 1...12 { s.advance(to: epoch.addingTimeInterval(Double(minute) * 60)) }
        #expect(s.sleep == .awake)
    }

    @Test func activityEndsANapButNotADeepSleep() {
        let napping = sim()
        napping.machineWentIdle()
        napping.humanReturned()
        #expect(napping.sleep == .awake)

        let deep = sim { $0.sleep = .deep; $0.needs.energy = 5 }
        deep.humanReturned()
        #expect(deep.sleep == .deep)
    }

    @Test func aRestedBirdOnlyNapsBriefly() {
        // Full energy: choosing Sleep is a doze, not a night. Ten seconds, then up.
        let s = sim { $0.needs = Needs(hunger: 80, affection: 80, energy: 100) }
        s.putToSleep(at: epoch)
        s.advance(to: epoch.addingTimeInterval(5))
        #expect(s.sleep == .deep)
        s.advance(to: epoch.addingTimeInterval(20))
        #expect(s.sleep == .awake)
    }

    @Test func aTiredBirdNapsForMinutes() {
        let s = sim { $0.needs = Needs(hunger: 80, affection: 80, energy: 25) }
        s.putToSleep(at: epoch)
        s.advance(to: epoch.addingTimeInterval(60))
        #expect(s.sleep == .deep)
    }

    @Test func draggingHerEndsAHandAskedNapImmediately() {
        let s = sim { $0.needs = Needs(hunger: 80, affection: 80, energy: 25) }
        s.putToSleep(at: epoch)
        s.wakeByDragging()
        s.advance(to: epoch.addingTimeInterval(5))
        #expect(s.sleep == .awake)
    }

    @Test func deepSleepEndsOnceRested() {
        let s = sim { $0.sleep = .deep; $0.needs.energy = 10 }
        s.advance(to: hours(5))
        #expect(s.sleep == .awake)
    }

    // MARK: - Birthday

    @Test func birthdayMessageShowsOncePerYearButTheDayLastsAllDay() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 14; comps.hour = 10
        let birthday = Calendar.current.date(from: comps)!

        let s = sim { $0.birthdayMonth = 9; $0.birthdayDay = 14 }
        #expect(s.isBirthday(on: birthday))
        #expect(s.shouldShowBirthdayMessage(on: birthday))
        s.markBirthdayCelebrated(on: birthday)
        #expect(!s.shouldShowBirthdayMessage(on: birthday))
        #expect(s.isBirthday(on: birthday))
    }

    // MARK: - Persistence

    @Test func stateSurvivesARoundTrip() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coco-test-\(UUID().uuidString)")
        let store = Store(directory: dir)
        var state = SavedState.fresh(now: epoch)
        state.needs = Needs(hunger: 42, affection: 17, energy: 88)
        state.birthdayMonth = 9; state.birthdayDay = 14
        store.save(state)
        let loaded = store.load()
        #expect(loaded.needs == state.needs)
        #expect(loaded.birthdayDay == 14)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func aMissingFileStartsHerFreshRatherThanCrashing() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coco-absent-\(UUID().uuidString)")
        #expect(Store(directory: dir).load(now: epoch).needs == .full)
    }
}
