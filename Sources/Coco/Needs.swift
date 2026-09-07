import Foundation

/// What Coco lacks attention in. Each falls on its own with the passage of real time
/// and is raised by an Action. Never a measure of what she deserves.
struct Needs: Codable, Equatable {
    var hunger: Double
    var affection: Double
    var energy: Double

    static let full = Needs(hunger: 100, affection: 100, energy: 100)

    /// Hours from full to empty. Hunger falls fastest because feeding is the action
    /// with the most immediate payoff; affection is slowest because it is what rewards
    /// showing up every day.
    enum Decay {
        static let hungerHours = 48.0
        static let affectionHours = 72.0
        /// Energy is spent by being AWAKE, not by the clock.
        static let energyAwakeHours = 16.0
        /// Restored only by sleeping, and at two different rates on purpose.
        ///
        /// Real sleep — the collapse from exhaustion, and the nap asked for from the
        /// menu — fills her in half an hour, which makes a Deep Sleep last about
        /// twelve minutes rather than three hours. What the human actually experiences
        /// is the LENGTH OF A SLEEP, not the time from empty to full, and hours of it
        /// is a lock-out: Feed and Play are both refused while she is asleep.
        static let energyDeepSleepHours = 0.5
        /// A doze while the Mac is left alone is worth far less. At the deep rate a
        /// lunch break would refill her completely, she would never again fall below
        /// the Deep Sleep threshold, and the sleeping pose, the perching and the
        /// startle would only ever happen overnight with nobody watching.
        static let energyNapHours = 4.0
    }

    mutating func clampAll() {
        hunger = min(100, max(0, hunger))
        affection = min(100, max(0, affection))
        energy = min(100, max(0, energy))
    }
}

/// Coco's visible emotional state — derived from Hunger and Affection only.
///
/// Energy is deliberately excluded. With it in the calculation she is sad every
/// evening purely because she is tired, and the evening is when she is most looked at.
/// Energy governs sleep, which is a state, not a sentiment.
///
/// And it is the MINIMUM of the two, not their average: an average hides which Need is
/// starving, while the minimum makes the menubar icon actionable.
enum Mood: String, CaseIterable {
    case happy, content, meh, sad

    static func derived(from needs: Needs) -> Mood {
        switch min(needs.hunger, needs.affection) {
        case 70...:   return .happy
        case 40..<70: return .content
        case 20..<40: return .meh
        default:      return .sad
        }
    }
}

/// Two sleeps, distinguished by what wakes her — the distinction exists so that Energy
/// can actually recover. A sleep any mouse movement interrupts is a sleep that never
/// happens.
enum SleepState: String, Codable {
    /// Awake.
    case awake
    /// Triggered by the machine going idle. Any human activity ends it.
    case nap
    /// Triggered by Energy running out. Human activity does not end it; she sleeps
    /// until Energy is substantially restored, and can only be dragged awake.
    case deep
}
