import Foundation

/// The result of asking Coco to do something. A refusal is a thing she DOES —
/// she turns her head away — never a greyed-out control.
enum ActionOutcome: Equatable {
    case done
    case refused(Refusal)

    enum Refusal: String, Equatable {
        case notHungry      // already full
        case asleep
        case tooTired       // not enough energy to play
        case pettedEnough   // the hourly cap
    }
}

/// Coco's model layer. Knows nothing about windows, sprites or AppKit, and advances
/// only when handed an explicit date — which is what makes it testable.
final class Simulation {
    private(set) var state: SavedState

    /// Set when a catch-up covered more than a day. The behaviour driver consumes this
    /// to greet the human rather than sulk at them; a holiday should read as a reunion,
    /// not a fine.
    private(set) var returnedFromLongAbsence = false

    /// However long Coco was left alone, at most this much decay is charged on return.
    /// Uncapped decay is what gets tamagotchis uninstalled; freezing time while quit
    /// feels fake.
    static let catchUpCapHours = 12.0
    static let longAbsenceHours = 24.0

    /// Energy thresholds for the two sleeps.
    static let deepSleepBelow = 20.0
    static let wakesAbove = 60.0

    /// Petting is worth little each time and is capped per hour: without the cap,
    /// holding the mouse down maxes Affection in ten seconds and the toy is over.
    static let petGain = 4.0
    static let petCapPerHour = 20.0

    var needs: Needs { state.needs }
    var mood: Mood { Mood.derived(from: state.needs) }
    var sleep: SleepState { state.sleep }
    var canFeed: Bool { state.sleep == .awake && state.needs.hunger <= 85 }

    init(state: SavedState) {
        self.state = state
    }

    // MARK: - Time

    /// Charge elapsed time against the Needs and re-evaluate sleep.
    func advance(to now: Date) {
        let raw = now.timeIntervalSince(state.lastUpdate) / 3600
        // A backwards clock — a timezone change, a manual adjustment — must never
        // credit Coco with negative time.
        let elapsed = max(0, raw)
        returnedFromLongAbsence = elapsed >= Self.longAbsenceHours

        let charged = min(elapsed, Self.catchUpCapHours)
        var needs = state.needs
        needs.hunger -= 100 / Needs.Decay.hungerHours * charged
        needs.affection -= 100 / Needs.Decay.affectionHours * charged
        if state.sleep == .awake {
            needs.energy -= 100 / Needs.Decay.energyAwakeHours * charged
        } else {
            needs.energy += 100 / Needs.Decay.energyAsleepHours * charged
        }
        needs.clampAll()

        state.needs = needs
        state.lastUpdate = now
        updateSleep(now: now)
    }

    /// The machine has been idle long enough that Coco dozes off.
    func machineWentIdle() {
        if state.sleep == .awake { state.sleep = .nap }
    }

    /// The human touched the Mac. Ends a nap; a deep sleep is unmoved.
    func humanReturned() {
        if state.sleep == .nap { state.sleep = .awake }
    }

    private func updateSleep(now: Date) {
        // A hand-asked nap runs its course before the energy rules get a say.
        if let until = state.forcedSleepUntil {
            if now < until {
                state.sleep = .deep
                return
            }
            state.forcedSleepUntil = nil
        }
        switch state.sleep {
        case .awake where state.needs.energy < Self.deepSleepBelow:
            state.sleep = .deep
        case .deep where state.needs.energy >= Self.wakesAbove:
            state.sleep = .awake
        default:
            break
        }
    }

    // MARK: - Actions

    func feed() -> ActionOutcome {
        if state.sleep != .awake { return .refused(.asleep) }
        if state.needs.hunger > 85 { return .refused(.notHungry) }
        state.needs.hunger += 45
        state.needs.clampAll()
        return .done
    }

    func play() -> ActionOutcome {
        if state.sleep != .awake { return .refused(.asleep) }
        if state.needs.energy < 15 { return .refused(.tooTired) }
        state.needs.affection += 30
        state.needs.energy -= 10
        state.needs.clampAll()
        return .done
    }

    /// A nap asked for from the menu, which is a different thing from collapsing at
    /// the end of a long day.
    ///
    /// Its length scales with how much rest she actually needs: about ten seconds when
    /// she is already wide awake, up to five minutes when she is running on empty. A
    /// fixed long nap would make the menu item feel like it had ignored her state; a
    /// fixed short one would make it pointless when she is tired.
    func putToSleep(at now: Date) {
        state.sleep = .deep
        let missing = (100 - state.needs.energy) / 100
        state.forcedSleepUntil = now.addingTimeInterval(10 + missing * 290)
    }

    static let shortestNap = 10.0
    static let longestNap = 300.0

    /// Dragging her is the one thing that interrupts a deep sleep — and leaves her
    /// drowsy rather than fully awake, which is the caller's business to show.
    func wakeByDragging() {
        state.sleep = .awake
        state.forcedSleepUntil = nil
    }

    func pet(at now: Date) -> ActionOutcome {
        if state.sleep != .awake { return .refused(.asleep) }
        if now.timeIntervalSince(state.pettingWindowStart) >= 3600 {
            state.pettingWindowStart = now
            state.pettingGivenInWindow = 0
        }
        if state.pettingGivenInWindow >= Self.petCapPerHour {
            return .refused(.pettedEnough)
        }
        let gain = min(Self.petGain, Self.petCapPerHour - state.pettingGivenInWindow)
        state.pettingGivenInWindow += gain
        state.needs.affection += gain
        state.needs.clampAll()
        return .done
    }

    // MARK: - Birthday

    /// True on the configured day. Party State overrides Mood entirely: a birthday
    /// where the celebrant is sad because you forgot to feed them is a bug, not realism.
    func isBirthday(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let birthday = state.birthday else { return false }
        let today = calendar.dateComponents([.month, .day], from: date)
        return today.month == birthday.month && today.day == birthday.day
    }

    /// The personal message shows once a year. Tracked BY YEAR rather than by a flag,
    /// so it still fires if the app was already running when midnight passed.
    func shouldShowBirthdayMessage(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isBirthday(on: date, calendar: calendar) else { return false }
        return state.lastBirthdayCelebrated != calendar.component(.year, from: date)
    }

    func markBirthdayCelebrated(on date: Date, calendar: Calendar = .current) {
        state.lastBirthdayCelebrated = calendar.component(.year, from: date)
    }

    func markFirstLaunchDone() {
        state.firstLaunchDone = true
    }

    // MARK: - Settings

    func setBirthday(month: Int?, day: Int?) {
        state.birthdayMonth = month
        state.birthdayDay = day
    }

    func setLaunchAtLogin(_ on: Bool) { state.launchAtLogin = on }
    func setScale(_ scale: Int) { state.scale = scale }
    func setHidden(_ hidden: Bool) { state.hidden = hidden }
}
