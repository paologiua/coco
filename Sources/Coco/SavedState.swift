import Foundation

/// Everything Coco remembers between launches, as it appears on disk.
///
/// Deliberately readable JSON: this file is the only record of a gift that is meant to
/// last years, and it should be possible to open it and see what happened.
struct SavedState: Codable {
    var needs: Needs
    var lastUpdate: Date
    var sleep: SleepState

    /// The rolling hour used to cap petting.
    var pettingWindowStart: Date
    var pettingGivenInWindow: Double

    var firstLaunchDone: Bool
    /// Unused. It tracked the year the birthday speech bubble was last shown; the
    /// bubble is gone, replaced by the letter, which has no once-a-year latch. Kept so
    /// that a state file written by an older build still decodes.
    var lastBirthdayCelebrated: Int?
    /// Month and day only — a birthday recurs, it is not a date.
    var birthdayMonth: Int?
    var birthdayDay: Int?

    var launchAtLogin: Bool
    var hidden: Bool

    /// While set, Coco stays asleep regardless of how rested she is — a nap asked for
    /// from the menu. Optional, like every field added after v1.
    var forcedSleepUntil: Date?

    /// Rendering scale, 1x to 3x. Optional on purpose: every field added after v1 must
    /// be optional, or an older state file fails to decode and Coco forgets everything
    /// she has lived through. This file has to survive years of small changes.
    var scale: Int?

    var birthday: DateComponents? {
        guard let birthdayMonth, let birthdayDay else { return nil }
        return DateComponents(month: birthdayMonth, day: birthdayDay)
    }

    static func fresh(now: Date = Date()) -> SavedState {
        SavedState(needs: .full,
                   lastUpdate: now,
                   sleep: .awake,
                   pettingWindowStart: now,
                   pettingGivenInWindow: 0,
                   firstLaunchDone: false,
                   lastBirthdayCelebrated: nil,
                   birthdayMonth: nil,
                   birthdayDay: nil,
                   launchAtLogin: false,
                   hidden: false,
                   forcedSleepUntil: nil,
                   scale: nil)
    }
}

/// Reads and writes `SavedState` to Application Support.
struct Store {
    let url: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Coco", isDirectory: true)
        self.url = base.appendingPathComponent("state.json")
    }

    /// A missing or corrupt file starts Coco fresh rather than crashing. Losing her
    /// needs is a disappointment; refusing to launch on her birthday is a disaster.
    func load(now: Date = Date()) -> SavedState {
        guard let data = try? Data(contentsOf: url) else { return .fresh(now: now) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(SavedState.self, from: data) else {
            // Keep the unreadable file rather than overwrite it: if it can be salvaged
            // by hand later, it is the only copy of how long she has been alive.
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
            return .fresh(now: now)
        }
        return state
    }

    func save(_ state: SavedState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
