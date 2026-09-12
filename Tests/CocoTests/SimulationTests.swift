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

    @Test func hungerEmptiesInFiveHours() {
        let half = sim(); half.advance(to: hours(2.5))
        #expect(abs(half.needs.hunger - 50) < 0.001)
        let empty = sim(); empty.advance(to: hours(5))
        #expect(empty.needs.hunger == 0)
    }

    @Test func affectionOnlyFallsWhileSheIsOnScreen() {
        // A shut lid is not time spent ignoring her. At three hours to empty, charging
        // a night against Affection would leave it at zero every single morning
        // whatever anyone did, because twelve hours of catch-up is four whole bars.
        let closed = sim()
        closed.advance(to: hours(10))
        #expect(closed.needs.affection == 100)
        #expect(closed.needs.hunger == 0)      // Hunger is a clock and runs regardless

        // Ticking a minute at a time, it falls faster than anything else in the model.
        let watching = sim()
        for minute in 1...60 { watching.advance(to: epoch.addingTimeInterval(Double(minute) * 60)) }
        #expect(abs(watching.needs.affection - 66.67) < 0.5)
    }

    // MARK: - Catch-up

    @Test func aLongAbsenceCostsNoMoreThanAShortOne() {
        // The 12-hour cap is no longer observable on Hunger: five hours already empties
        // it, so capping the charge changes nothing. It survives as the guard that
        // keeps a long absence from being worse than a medium one.
        let away = sim();  away.advance(to: hours(72))
        let short = sim(); short.advance(to: hours(6))
        #expect(away.needs.hunger == short.needs.hunger)
    }

    @Test func longAbsenceIsFlaggedForAReunion() {
        let s = sim(); s.advance(to: hours(60))
        #expect(s.returnedFromLongAbsence)
    }

    @Test func shortAbsenceIsNotAReunion() {
        let s = sim(); s.advance(to: hours(2))
        #expect(!s.returnedFromLongAbsence)
        // A weekend of not opening the laptop must not trigger it either, or the
        // greeting fires most Mondays and stops being a greeting.
        let weekend = sim(); weekend.advance(to: hours(30))
        #expect(!weekend.returnedFromLongAbsence)
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
        // One segment of the ten-block bar: a beakful, not a meal.
        #expect(s.needs.hunger == 60)
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

    @Test func flyingCostsMoreThanSittingStill() {
        let flying = sim(); let perched = sim()
        // Ten minutes, a tenth of a second at a time, as the tick does it.
        for step in 1...6000 {
            let at = epoch.addingTimeInterval(Double(step) / 10)
            flying.advance(to: at);  flying.spendFlightEnergy(seconds: 0.1)
            perched.advance(to: at)
        }
        #expect(flying.needs.energy < perched.needs.energy)
        // Three times the resting drain, so ten minutes aloft costs about thirty.
        let restingLoss = 100 - perched.needs.energy
        let flyingLoss = 100 - flying.needs.energy
        #expect(abs(flyingLoss - restingLoss * Needs.Decay.flyingCostMultiplier) < 0.01)
    }

    @Test func sleepingCocoIsNotChargedForFlyingToHerPerch() {
        // She flies to a window edge with sleep already requested; charging that would
        // fight the recovery the flight exists to reach.
        let s = sim { $0.sleep = .deep; $0.needs.energy = 40 }
        s.spendFlightEnergy(seconds: 600)
        #expect(s.needs.energy == 40)
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

    @Test func theBirthdayLastsTheWholeDay() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 14; comps.hour = 10
        let morning = Calendar.current.date(from: comps)!
        comps.hour = 23
        let night = Calendar.current.date(from: comps)!
        comps.day = 15; comps.hour = 10
        let after = Calendar.current.date(from: comps)!

        let s = sim { $0.birthdayMonth = 9; $0.birthdayDay = 14 }
        // No once-a-year latch any more: the birthday is a property of the date, and
        // the letter can be opened as many times as she likes while it lasts.
        #expect(s.isBirthday(on: morning))
        #expect(s.isBirthday(on: night))
        #expect(!s.isBirthday(on: after))
    }

    @Test func theHourlyPettingCapRefusesWithoutSayingSheIsAsleep() {
        // The birthday letter is offered on any stroke EXCEPT one refused because she is
        // asleep, so the two refusals have to stay distinguishable: reaching the cap
        // must not report itself as sleep, or eight clicks on the birthday would put
        // the present out of reach for the rest of the hour.
        let now = Date()
        let s = sim { _ in }
        var outcome = ActionOutcome.done
        for _ in 0..<20 where outcome == .done { outcome = s.pet(at: now) }

        #expect(outcome == .refused(.pettedEnough))
        #expect(outcome != .refused(.asleep))
    }

    @Test func sheCanOnlyBeAskedWhenSheIsThereAndAwake() {
        let now = Date()

        // Awake and on screen: every action is live, including the ones she will refuse.
        // Refusing is something she DOES, and a grey menu item would say it worse.
        let ready = sim { $0.needs.hunger = 100 }
        #expect(ready.canBeAsked)
        #expect(ready.feed() == .refused(.notHungry))

        // Asleep she cannot turn her head away, so there is nothing to see.
        let sleeping = sim { $0.sleep = .deep }
        #expect(!sleeping.canBeAsked)

        // Hidden she is not on the screen at all.
        let hidden = sim { $0.hidden = true }
        #expect(!hidden.canBeAsked)

        // And hiding her mid-session takes the actions with her.
        let visible = sim { _ in }
        #expect(visible.canBeAsked)
        visible.setHidden(true)
        #expect(!visible.canBeAsked)
        _ = now
    }

    @Test func pokingASleepingBirdLeavesHerAsleep() {
        // Clicking her used to wake her before anyone knew whether the gesture was a
        // drag: by the time the click finished she was awake, the petting landed, and
        // hearts came out of a bird who was supposed to be asleep.
        let s = sim { $0.sleep = .deep }
        #expect(s.pet(at: Date()) == .refused(.asleep))
        #expect(s.sleep == .deep)

        // A drag is different, and still wakes her.
        s.wakeByDragging()
        #expect(s.sleep == .awake)
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
