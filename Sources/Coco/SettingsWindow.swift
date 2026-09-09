import AppKit
import ServiceManagement

/// Coco's settings.
///
/// A window, not a panel. Her own window is a non-activating `NSPanel` that can never
/// become key, and a window that cannot become key cannot hold a text insertion point
/// or take keyboard focus — so the settings cannot live there.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let monthPopup = NSPopUpButton()
    private let dayPopup = NSPopUpButton()
    private let loginCheck = NSButton(checkboxWithTitle: "Start Coco when I log in", target: nil, action: nil)

    /// Called with the new state so the app can persist it and react.
    var onChange: ((_ month: Int?, _ day: Int?, _ launchAtLogin: Bool, _ scale: Int) -> Void)?

    func show(month: Int?, day: Int?, launchAtLogin: Bool, scale: Int) {
        if window == nil { build() }
        monthPopup.selectItem(at: month ?? 0)      // index 0 is "Not set"
        rebuildDays()
        if let day { dayPopup.selectItem(at: day - 1) }
        loginCheck.state = launchAtLogin ? .on : .off

        // The app is .accessory, so it has to ask for activation explicitly — otherwise
        // the window appears behind whatever the human was using.
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let calendar = Calendar.current
        // "Not set" leads the list so that merely opening this window cannot silently
        // choose a birthday. It did: any interaction wrote 1 January, because January
        // was the selected item of a popup nobody had touched.
        monthPopup.addItem(withTitle: "Not set")
        monthPopup.addItems(withTitles: calendar.monthSymbols)
        monthPopup.target = self
        monthPopup.action = #selector(monthChanged)
        dayPopup.target = self
        dayPopup.action = #selector(changed)

        let birthdayRow = NSStackView(views: [label("Birthday"), monthPopup, dayPopup])
        birthdayRow.spacing = 8

        loginCheck.target = self
        loginCheck.action = #selector(changed)

        content.addArrangedSubview(birthdayRow)
        content.addArrangedSubview(loginCheck)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Coco"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 70).isActive = true
        return field
    }

    /// Day counts differ by month, and a birthday set to 31 February should not be
    /// selectable at all.
    private func rebuildDays() {
        let month = monthPopup.indexOfSelectedItem
        guard month > 0 else {
            dayPopup.removeAllItems()
            dayPopup.isEnabled = false
            return
        }
        dayPopup.isEnabled = true
        let previous = dayPopup.indexOfSelectedItem
        var comps = DateComponents()
        comps.year = 2024                    // a leap year, so 29 February is offered
        comps.month = month
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month,
                                  for: calendar.date(from: comps) ?? Date())?.count ?? 31
        dayPopup.removeAllItems()
        dayPopup.addItems(withTitles: (1...days).map(String.init))
        dayPopup.selectItem(at: min(max(previous, 0), days - 1))
    }

    @objc private func monthChanged() {
        rebuildDays()
        changed()
    }

    @objc private func changed() {
        applyLaunchAtLogin(loginCheck.state == .on)
        let month = monthPopup.indexOfSelectedItem
        let isSet = month > 0 && dayPopup.indexOfSelectedItem >= 0
        onChange?(isSet ? month : nil,
                  isSet ? dayPopup.indexOfSelectedItem + 1 : nil,
                  loginCheck.state == .on,
                  // One size now: she is stored at the size she is shown at, so there
                  // is nothing to multiply and nothing to choose between.
                  1)
    }

    /// Verified to work with an ad-hoc signature — the API requires a valid signature,
    /// and ad-hoc is one; only LaunchDaemons additionally require notarization.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Never fail silently here: the whole point of the gift is that she comes
            // back after a restart, and a quiet failure is discovered months later.
            loginCheck.state = enabled ? .off : .on
            let alert = NSAlert()
            alert.messageText = "Coco could not change the login setting"
            alert.informativeText = "\(error.localizedDescription)\n\nThis usually means Coco is not in the Applications folder. Move her there and try again."
            alert.runModal()
        }
    }
}
