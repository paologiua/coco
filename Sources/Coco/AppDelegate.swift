import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Overridden by the saved setting. 2 is Medium: the 64x64 canvas drawn at 128
    /// points. This is the size the recipient meets Coco at, so it is the moderate one.
    /// One size. She is stored at the size she is drawn, so there is nothing to
    /// multiply — and nothing to choose between.
    private static let defaultScale = 1
    private static let awakeHz = 10.0
    /// Asleep she has nowhere to be, but the Zzz still have to rise smoothly, so the
    /// loop slows rather than stopping. Hidden, there is genuinely nothing to draw.
    private static let asleepHz = 4.0
    private static let hiddenHz = 1.0
    /// How long the Mac must sit untouched before Coco takes a nap.
    private static let idleNapSeconds = 15.0 * 60

    private var panel: CocoPanel!
    private var view: SpriteView!
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private let store = Store()
    private var sim: Simulation!
    private var driver: BehaviourDriver!
    private var sprites: BehaviourDriver.SpriteSet!
    private var moodIcons: [String: NSImage] = [:]

    private var lastShownMood: Mood?
    private var statusBlock: StatusView!
    private let settings = SettingsWindow()
    private var hideItem: NSMenuItem!
    private let particles = ParticleField()
    private let bubble = BubbleWindow()
    private let birthdayLetter = BirthdayLetter()
    private let interaction = InteractionWindow()
    private var interactionKind: InteractionWindow.Kind?
    private var hoopGame = HoopGame()
    private var lastPerchRefresh = Date.distantPast
    /// A line waiting to be said once Coco has actually landed. Showing it while she is
    /// still flying in would put the bubble beside an empty patch of screen.
    private var pendingLine: String?
    /// Latched from the advance that noticed the absence, because the next tick's
    /// advance immediately clears the flag on the simulation.
    private var sawLongAbsence = false
    private var isDragging = false
    private var ticks = 0
    private var runningHz = AppDelegate.awakeHz
    private var scale = AppDelegate.defaultScale
    /// Points per pixel for the things that are NOT Coco. They are drawn at a coarser
    /// grain than she is on purpose: at one point per pixel they would be specks.
    static let propScale = 3
    /// The hoop gets its own, because it is the one prop she has to fit THROUGH.
    /// At this scale the ring stands 180 points tall with an opening 150 points high,
    /// against a bird 119 tall at full wingspan — room to pass and not much more, which
    /// is the point. One step down again and the opening is shorter than she is.
    ///
    /// A whole number, and it has to be: the asset is stored at the grain the ring was
    /// actually drawn at, so showing it is a plain pixel-doubling. Storing it at some
    /// other grain means resampling by a fraction, and then some drawn blocks land on
    /// one point and their neighbours on two — which is what made it look ragged.
    static let hoopScale = 3
    /// Half the height of the hole through the ring, in points.
    ///
    /// Measured from `hoop.png`: the opening is 50 of the asset's 60 rows. This is what
    /// the game scores against, and it has to be the HOLE rather than the image — most
    /// of the first asset was padding, and sizing the game by the image is what let her
    /// score for passing outside the ring. Re-measure it whenever the ring is redrawn:
    /// a thinner band means a bigger hole, and the number does not follow on its own.
    static var hoopOpening: Double { 50.0 / 2 * Double(hoopScale) }

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let set = loadSprites() else {
            fatalError("sprites missing from Contents/Resources/Sprites — check build-app.sh")
        }
        sprites = set

        sim = Simulation(state: store.load())
        sim.advance(to: Date())            // charge the time she was not running
        sawLongAbsence = sim.returnedFromLongAbsence
        store.save(sim.state)

        scale = Self.defaultScale
        buildPanel()
        buildStatusItem()
        showMood()
        // macOS can quietly bind a window to one desktop when it is ordered out and
        // back in, and she is ordered out every time she is hidden. Re-stating it on
        // every switch costs nothing and means a desktop she is missing from fixes
        // itself the moment you arrive on it.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.sim.state.hidden else { return }
                self.panel.showEverywhere()
            }
        }

        startWelcomeIfNeeded()
        queueReunionIfNeeded()
        retime(to: Self.awakeHz)
    }

    private func loadSprites() -> BehaviourDriver.SpriteSet? {
        func load(_ name: String) -> Sprite? { Sprite(named: name) }
        func sequence(_ stem: String, _ count: Int) -> [Sprite]? {
            let frames = (0..<count).compactMap { load("\(stem)_\($0)") }
            return frames.count == count ? frames : nil
        }
        guard let idle = load("idle"), let sad = load("sad"),
              let blink = sequence("blink", 4), let petted = sequence("petted", 4),
              let walk = sequence("walk", 4),
              let fly = sequence("fly", 4), let peck = sequence("peck", 8)
        else { return nil }

        // The hat is drawn into the art, so every frame has a hatted twin under the
        // same name. They stay optional: a frame whose twin is missing goes bare-headed
        // on the day rather than stopping the app from starting.
        var hatted: [String: Sprite] = [:]
        for frame in [idle, sad] + blink + petted + walk + fly + peck {
            if let worn = load("\(frame.name)_hat") { hatted[frame.name] = worn }
        }
        return .init(idle: idle, sad: sad, blink: blink, petted: petted,
                     walk: walk, fly: fly, peck: peck, hatted: hatted)
    }

    private var keepPosition: CGPoint?

    private func buildPanel() {
        panel = CocoPanel(scale: scale)
        view = SpriteView(frame: panel.contentLayoutRect)
        view.autoresizingMask = [.width, .height]
        view.scale = CGFloat(scale)
        view.onPress = { [weak self] in self?.beginDrag() }
        view.onDragTo = { [weak self] location in self?.dragTo(location) }
        view.onRelease = { [weak self] wasClick in self?.endDrag(wasClick: wasClick) }
        panel.contentView = view

        let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let start = keepPosition ?? CGPoint(x: screen.maxX - panel.frame.width - 60,
                                            y: screen.minY + 10)
        driver = BehaviourDriver(sim: sim, sprites: sprites,
                                 canvasSize: panel.frame.size, scale: scale, start: start)
        panel.setFrameOrigin(driver.displayPosition)
        if !sim.state.hidden { panel.showEverywhere() }
    }

    /// The very first launch: she arrives from off screen rather than simply being
    /// there. It is the moment the recipient works out what this is.
    private func startWelcomeIfNeeded() {
        guard !sim.state.firstLaunchDone else { return }
        let screen = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let landing = CGPoint(x: screen.maxX - panel.frame.width - 120, y: screen.minY + 10)
        driver.flyIn(from: CGPoint(x: screen.maxX + panel.frame.width, y: screen.midY),
                     to: landing)
        pendingLine = text(named: "welcome")
        sim.markFirstLaunchDone()
        store.save(sim.state)
    }

    /// Coming back after days away should be a welcome, not a reckoning. The
    /// simulation has counted the absence since the model was written; nothing ever
    /// read the flag, so until now returning looked exactly like never having left.
    ///
    /// Reuses the bubble the welcome and the birthday already use, so the whole
    /// feature is a text file and a queued line. The welcome wins if both are due:
    /// a first launch is not a return.
    private func queueReunionIfNeeded() {
        guard sawLongAbsence, pendingLine == nil, sim.state.firstLaunchDone else { return }
        sawLongAbsence = false
        pendingLine = text(named: "reunion") ?? "You came back!"
        NSLog("Coco: reunion line queued")
    }

    /// Plain text from the bundle, so the birthday line can be rewritten in later years
    /// without a toolchain. A missing file is not worth crashing over.
    private func text(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt",
                                        subdirectory: "Text"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Our own PNGs, never SF Symbols: a symbol name newer than macOS 15 returns nil
        // on the target machine and the icon silently disappears.
        //
        // Colour, not template: macOS must NOT recolour these. They ship at 44x44 and
        // are declared as 22x22 points, so a Retina bar draws each source pixel as a
        // crisp 2x2 block instead of smoothing the upscale.
        for mood in Mood.allCases {
            guard let url = Bundle.main.url(forResource: "mood_\(mood.rawValue)",
                                            withExtension: "png", subdirectory: "Menubar"),
                  let image = NSImage(contentsOf: url) else { continue }
            image.isTemplate = false
            image.size = NSSize(width: 22, height: 22)
            moodIcons[mood.rawValue] = image
        }

        var needIcons: [String: NSImage] = [:]
        for need in ["hunger", "affection", "energy"] {
            if let url = Bundle.main.url(forResource: "need_\(need)", withExtension: "png",
                                         subdirectory: "UI"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                needIcons[need] = image
            }
        }
        statusBlock = StatusView(icons: needIcons)

        let menu = NSMenu()
        menu.delegate = self
        let blockItem = NSMenuItem()
        blockItem.view = statusBlock
        menu.addItem(blockItem)
        menu.addItem(.separator())
        menu.addItem(action("Feed", #selector(feed)))
        menu.addItem(action("Play", #selector(playWith)))
        menu.addItem(action("Sleep", #selector(sleepNow)))
        menu.addItem(.separator())
        hideItem = action("Hide Coco", #selector(toggleHidden))
        menu.addItem(hideItem)
        menu.addItem(action("Settings…", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(action("Quit Coco", #selector(quit), key: "q"))
        statusItem.menu = menu

        settings.onChange = { [weak self] month, day, launchAtLogin, scale in
            self?.applySettings(month: month, day: day, launchAtLogin: launchAtLogin, scale: scale)
        }
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        interaction.finish()
        statusBlock.moodImage = moodIcons[sim.mood.rawValue]
        statusBlock.needs = sim.needs
        statusBlock.moodLabel = describe(sim.mood)
        statusBlock.needsDisplay = true
        hideItem.title = sim.state.hidden ? "Show Coco" : "Hide Coco"
    }

    private func describe(_ mood: Mood) -> String {
        switch mood {
        case .happy:   return "Coco is happy"
        case .content: return "Coco is content"
        case .meh:     return "Coco could use some attention"
        case .sad:     return "Coco is sad"
        }
    }

    @objc private func feed() { startInteraction(.food) }
    @objc private func playWith() { startInteraction(.hoop) }

    private func startInteraction(_ kind: InteractionWindow.Kind) {
        interaction.finish()
        guard !sim.state.hidden, sim.sleep == .awake else { return }
        if kind == .food, !sim.canFeed {
            driver.refuse()
            return
        }
        if kind == .hoop, sim.needs.energy < 15 { driver.refuse(); return }
        bubble.hide()
        interactionKind = kind
        hoopGame = HoopGame()
        interaction.onClick = { [weak self] in
            guard let self, self.interactionKind == .food,
                  hypot(self.driver.bodyCentre.x - NSEvent.mouseLocation.x,
                        self.driver.bodyCentre.y - NSEvent.mouseLocation.y)
                        < BehaviourDriver.personalSpace,
                  self.sim.needs.hunger <= 85 else { return }
            self.interaction.finish()
            let outcome = self.sim.feed()
            self.perform(outcome, celebrateWith: .seed, count: 4,
                         reacting: { self.driver.eat() })
            if outcome == .done {
                self.driver.welcomeCursor()
            }
            self.store.save(self.sim.state)
        }
        interaction.onEnd = { [weak self] completed in
            guard let self else { return }
            let earned = completed && self.interactionKind == .hoop && self.hoopGame.passes > 0
            self.interactionKind = nil
            let screen = (self.panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            self.driver.settle(screen: screen)
            if earned {
                self.perform(self.sim.play(), celebrateWith: .note, count: 4,
                             reacting: { self.driver.celebrate() })
                self.store.save(self.sim.state)
            }
        }
        interaction.show(kind, seconds: 20,
                         scale: kind == .hoop ? Self.hoopScale : Self.propScale)
    }

    private func updateInteraction(dt: Double, screen: NSRect) {
        guard let kind = interactionKind else { return }
        guard sim.sleep == .awake, screen.contains(NSEvent.mouseLocation) else {
            interaction.finish()
            return
        }
        let mouse = NSEvent.mouseLocation
        if kind == .hoop {
            // The hoop is a moving target: she keeps chasing it for as long as it is up.
            driver.interactionStyle = .chase
            // The hoop is drawn at prop scale, so the game has to measure in the same
            // units. Handing it Coco's scale — now 1 — made the opening it looked for
            // half the size of the one on screen, and she kept missing a ring she was
            // visibly flying through.
            // Aim her drawn body at the ring rather than the point `bodyCentre` reports,
            // which in flight sits a little below it. A constant, so arriving does not
            // move the target — making it depend on whether she is flying was tried,
            // and it shifted the target out from under her at the moment she landed.
            let aim = CGPoint(x: mouse.x, y: mouse.y - driver.flightAimOffset)
            driver.interactionTarget = hoopGame.target(bird: driver.bodyCentre, hoop: aim,
                                                       opening: Self.hoopOpening,
                                                       reach: driver.reachableCentreX(in: screen))
            interaction.passes = hoopGame.passes
            if hoopGame.passes >= 3 { interaction.finish(completed: true) }
            return
        }
        // Fly over, stop beside the food rather than directly below the pointer, and
        // then wait: the hand is supposed to come to her from here.
        driver.interactionStyle = .waitBeside
        let side = driver.bodyCentre.x < mouse.x ? -1.0 : 1.0
        driver.interactionTarget = CGPoint(x: mouse.x + side * 65, y: mouse.y)
    }

    @objc private func sleepNow() {
        interaction.finish()
        sim.putToSleep(at: Date())
        particles.clear()
        showMood()
    }

    /// A refusal is shown on Coco herself, not by grey text in a menu.
    ///
    /// `reacting` is what she DOES when it worked. It used to be `faceTheHuman` for
    /// every action, which is right for finishing a game and wrong for eating: taking
    /// food and then looking up at you is a bird that has been handed something, not
    /// one that has eaten it.
    private func perform(_ outcome: ActionOutcome,
                         celebrateWith kind: ParticleField.Kind, count: Int,
                         reacting: () -> Void) {
        switch outcome {
        case .done:
            reacting()
            particles.stagger(kind, count: count, at: emissionPoint)
            showMood()
        case .refused:
            driver.refuse()
        }
    }

    @objc private func toggleHidden() {
        interaction.finish()
        birthdayLetter.dismissInvitation()
        birthdayLetter.close()
        bubble.hide()
        sim.setHidden(!sim.state.hidden)
        if sim.state.hidden { panel.orderOut(nil) } else { panel.showEverywhere() }
        store.save(sim.state)
    }

    @objc private func openSettings() {
        interaction.finish()
        settings.show(month: sim.state.birthdayMonth, day: sim.state.birthdayDay,
                      launchAtLogin: sim.state.launchAtLogin, scale: scale)
    }

    private func applySettings(month: Int?, day: Int?, launchAtLogin: Bool, scale newScale: Int) {
        sim.setBirthday(month: month, day: day)
        sim.setLaunchAtLogin(launchAtLogin)
        if newScale != scale {
            sim.setScale(newScale)
            scale = newScale
            keepPosition = panel.frame.origin
            panel.orderOut(nil)
            buildPanel()
            keepPosition = nil
        }
        store.save(sim.state)
    }

    // MARK: - Loop

    /// Swap the timer rather than checking a flag inside it: a sleeping bird should not
    /// wake the CPU ten times a second to decide it has nothing to do.
    private func retime(to hz: Double) {
        guard hz != runningHz || timer == nil else { return }
        runningHz = hz
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / hz, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        ticks += 1
        let now = Date()
        let dt = 1 / runningHz

        if ticks % Int(runningHz) == 0 {
            sim.advance(to: now)
            // Also catches the lid being reopened while she was already running.
            if sim.returnedFromLongAbsence { sawLongAbsence = true }
            queueReunionIfNeeded()
            updateNapFromMachineIdle()
            showMood()
        }
        if ticks % Int(runningHz * 60) == 0 {
            // A force-quit or a crash should cost a minute of Coco's life, not all of it.
            store.save(sim.state)
        }

        guard !sim.state.hidden else {
            retime(to: Self.hiddenHz)
            return
        }
        let screen = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        if sim.sleep == .awake {
            lastPerchRefresh = .distantPast
        } else if now.timeIntervalSince(lastPerchRefresh) >= 1 {
            driver.availablePerches = Perches.visible()
            lastPerchRefresh = now
        }
        updateInteraction(dt: dt, screen: screen)
        driver.tick(dt: dt, now: now, cursor: NSEvent.mouseLocation, screen: screen)
        if driver.behaviour == .flying { sim.spendFlightEnergy(seconds: dt) }

        if driver.behaviour == .sleeping {
            particles.breatheZzz(dt: dt, at: emissionPoint)
        } else {
            particles.stopZzz()
        }
        let hadParticles = !view.particles.isEmpty
        particles.advance(dt: dt)
        if hadParticles || !particles.particles.isEmpty {
            view.particles = particles.particles
            view.needsDisplay = true
        }

        if view.sprite?.name != driver.frame.name { view.sprite = driver.frame }
        view.facingRight = driver.facingRight

        let origin = driver.displayPosition
        if origin != panel.frame.origin { panel.setFrameOrigin(origin) }

        updateClickThrough()
        deliverPendingLine()
        retime(to: driver.behaviour == .sleeping ? Self.asleepHz : Self.awakeHz)
    }

    private func deliverPendingLine() {
        guard let line = pendingLine, interactionKind == nil, driver.hasLanded, !sim.state.hidden else { return }
        pendingLine = nil
        let screen = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let seconds = 6.0
        bubble.show(line, above: panel.frame, on: screen, seconds: seconds)
        driver.stay(for: seconds)

    }

    /// Just above and beside her head, on whichever side she is facing, in stage
    /// pixels. Particles rise from here into the headroom.
    private var emissionPoint: CGPoint { driver.emissionPoint }

    /// No permissions needed for this — unlike anything that inspects other apps.
    private func updateNapFromMachineIdle() {
        let anyEvent = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
        if idle >= Self.idleNapSeconds {
            sim.machineWentIdle()
        } else {
            sim.humanReturned()
        }
    }

    /// hitTest cannot pass a click to another application — only ignoresMouseEvents can.
    /// So the window is transparent to the mouse except on Coco's drawn pixels.
    private func updateClickThrough() {
        guard !isDragging else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        guard frame.contains(mouse) else {
            panel.ignoresMouseEvents = true
            return
        }
        let s = CGFloat(scale)
        var x = Int((mouse.x - frame.minX) / s)
        // Stage rows run top-down, and the sprite starts below the particle headroom.
        let y = Int((frame.maxY - mouse.y) / s) - Canvas.particleHeadroom
        // The mask is stored facing right, so mirror the lookup when she faces left.
        if !driver.facingRight { x = Canvas.width - 1 - x }
        // One mask now, not two: the hat is drawn into the frame, so it is part of
        // Coco's own alpha and the pixels under it are hers to click.
        // A little slack around her outline. Hitting the exact pixel of a thin tail or
        // a foot is a game of its own, and the window is invisible either way.
        panel.ignoresMouseEvents = !(view.sprite?.isOpaque(x: x, y: y, slack: 3) ?? false)
    }

    private func showMood() {
        let mood = sim.mood
        guard mood != lastShownMood else { return }
        lastShownMood = mood
        statusItem.button?.image = moodIcons[mood.rawValue]
    }

    // MARK: - Interaction

    private func beginDrag() {
        interaction.finish()
        isDragging = true
        let mouse = NSEvent.mouseLocation
        grabOffset = CGSize(width: mouse.x - panel.frame.minX, height: mouse.y - panel.frame.minY)
        driver.beginDrag()
    }

    private var grabOffset: CGSize?

    /// Absolute positioning: the point of Coco you grabbed stays under the pointer,
    /// however many events the system drops along the way.
    private func dragTo(_ mouse: NSPoint) {
        guard let offset = grabOffset else { return }
        let origin = NSPoint(x: mouse.x - offset.width, y: mouse.y - offset.height)
        // The driver thinks in feet, the window in frames, and they differ by the
        // margin kept below her for wingtips.
        driver.moveTo(CGPoint(x: origin.x, y: origin.y + Double(Canvas.floorMargin)))
        panel.setFrameOrigin(origin)
    }

    /// Every path out of here must leave the dragged state. An early version only left
    /// it when the pet succeeded, so a refused pet froze Coco mid-air permanently.
    private func endDrag(wasClick: Bool) {
        isDragging = false
        grabOffset = nil
        let screen = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame

        guard wasClick else {
            driver.endDrag(screen: screen)
            return
        }
        let outcome = sim.pet(at: Date())

        // The letter is offered on any stroke she is awake for, landed or not.
        //
        // It used to need a pet that counted, and that quietly gated the gift: petting
        // is capped at sixty an hour and each stroke is worth eight, so eight clicks on
        // the birthday put the letter out of reach for the rest of the hour — and the
        // birthday is exactly the day someone sits there stroking her. The cap is a
        // brake on a held-down mouse button farming affection; it has no business
        // deciding whether she can be given her present.
        if sim.isBirthday(on: Date()), outcome != .refused(.asleep) {
            birthdayLetter.offer(on: screen)
        }

        if outcome == .done {
            driver.acceptPetting()
            if sim.isBirthday(on: Date()) {
                particles.burst(.confetti, count: 14, at: CGPoint(x: 32, y: 4))
            } else {
                particles.stagger(.heart, count: 3, at: emissionPoint)
            }
            showMood()
        } else {
            // Refused too: ticket 10 turns that into her looking away.
            driver.endDrag(screen: screen)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        interaction.finish()
        sim.advance(to: Date())
        store.save(sim.state)
    }
}
