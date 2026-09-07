import AppKit

struct Perch: Equatable {
    let id: UInt32
    let frame: CGRect
}

/// Window geometry only. No titles, images or accessibility access.
enum Perches {
    static func visible() -> [Perch] {
        guard let desktopTop = NSScreen.screens.first?.frame.maxY,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return [] }
        return windows.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int,
                  pid != ProcessInfo.processInfo.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  layer == 0 || owner == "Dock",
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 100, rect.height >= 30,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            return Perch(id: id, frame: CGRect(x: rect.minX, y: desktopTop - rect.maxY,
                                              width: rect.width, height: rect.height))
        }
    }
}
