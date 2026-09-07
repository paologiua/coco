# 07 — Install and verify on the recipient's Mac

Type: task
Status: claimed
Blocked by: 06
Parent: [map](../map.md)

## Question

Get Coco onto the recipient's macOS 15 Mac and prove she works there — the destination of the whole map.

Graduated from the map's fog once [02](02-shipping-adhoc-app.md) established the delivery path. The checklist is in that ticket's answer, section B; the essentials:

1. Transfer by **USB stick, never AirDrop** — AirDrop sets the quarantine flag and forces a Gatekeeper prompt that USB avoids entirely.
2. Drag `Coco.app` into `/Applications` **in the Finder**, not by `cp` in Terminal.
3. `xattr -dr com.apple.quarantine /Applications/Coco.app`, then confirm `xattr -l` prints nothing.
4. Launch. No Dock icon; menubar icon present.
5. Enable **Launch at login** from Coco's menu; expect the "Background Items Added" notification.
6. Confirm *Coco* appears in System Settings → General → Login Items & Extensions.
7. **Reboot and confirm she comes back.** This is the only real test of `SMAppService` on the actual target OS and must not be skipped.
8. Show the recipient how to turn her off and how to remove her.

**Run this as a rehearsal well before 14 September**, not on the day. It is also the first and only chance to see the app against macOS 15's chrome rather than macOS 26's — check that the panel, the menubar icon and the menu are not visibly misaligned.

## Comments

### 2026-09-07 — Resumed in Codex; rehearsal build prepared

Claimed the first open, unblocked ticket under the existing local tracker convention. The last recorded resolution is [Birthday easter egg and first-launch welcome](11-birthday-and-welcome.md). Git history contains only the initial setup commit; the app, assets, tests and Wayfinder state are untracked working files, preserved during this resumption.

- `bash scripts/test.sh`: all 21 tests passed. Swift required access to compiler caches outside the workspace sandbox.
- `bash scripts/build-app.sh`: succeeded with the pinned macOS 15.4 SDK; rebuilt `dist/Coco.app`, confirmed minimum macOS 15.0, and verified the ad-hoc signature.
- Feed and Play remain immediate menu actions in the code, consistent with [Interactive Feed and Play](12-interactive-actions.md) still being open. [Sleeping somewhere, and startling awake](14-sleep-perching.md) also remains open. This build is for the compatibility rehearsal, not evidence that all v1 work is complete.

Additional rehearsal checks from inspecting the actual app:

1. In Settings, set **Birthday to 14 September**. Fresh state deliberately has no birthday; the easter egg will not fire until this is configured. Quit and reopen to verify the date persists.
2. Enable **Start Coco when I log in** in Settings (the actual control location), then perform the reboot check above.
3. Verify the welcome bubble, dragging without focus theft, transparent click-through, Spaces, menu layout, Hide/Show, and Feed/Play responses on macOS 15. Record over-full-screen visibility as observed rather than assumed.
4. Review the bundled message before final delivery: `Assets/Text/birthday.txt` currently contains `Buon compleanno! 🎂`. If changed, edit the source asset and rebuild so the delivered bundle is signed after the edit.

**Pending:** physical USB transfer, target-machine launch, visual checks and reboot/login verification. No target-machine results have been observed; keep this ticket claimed and unresolved until they are reported. The existing map remains unchanged.

### 2026-09-07 — Updated rehearsal build after interaction and perching work

The earlier build notes above describe the previous snapshot. `dist/Coco.app` has now been rebuilt and signed with [Interactive Feed and Play](12-interactive-actions.md) and [Sleeping somewhere, and startling awake](14-sleep-perching.md). All 24 tests passed; the release build succeeded with SDK 15.4 and minimum OS 15.0. The pre-existing actor-isolation warning in `BubbleWindow.swift` remains.

Add these visual checks to the rehearsal:

- Feed when hungry: Coco approaches; clicking nearby feeds exactly once. When full she ignores it. Food expires after 20 seconds.
- Play: hold the hoop in an open area; Coco must fly through it and increment the counter. Three passes end the game, otherwise timeout is 20 seconds. Proximity alone must not earn a reward.
- Escape while another app is foreground, opening the menu, Hide, Settings and Sleep must remove the cursor object. Confirm ordinary clicks reach the foreground app afterwards.
- Sleep from mid-air: Coco lands before closing her eyes and showing Zzz. With an eligible window below her, move or close it after landing: she should startle. Check the Dock with its actual target-machine configuration; a missing eligible surface falls back to the visible screen floor.

No target-machine or manual UI results have been recorded yet.

### 2026-09-07 — Resumed again; build re-verified, still awaiting the target machine

Picked this map back up. This ticket was already claimed and is still the only open item on the frontier apart from the newly graduated [15 — Balancing pass: how the numbers actually feel](15-balancing-pass.md). Nothing was rebuilt: the point of this pass was to check that what the previous session left behind is still the thing we would carry over on a USB stick.

Verified, not assumed:

- `bash scripts/test.sh` — **32 tests in 4 suites pass** (the note above says 24; the interaction and perching suites have grown since).
- `dist/Coco.app/Contents/MacOS/Coco` is **newer than every file in `Sources/`, `Assets/` and `Package.swift`** — the bundle on disk is the current code, not a stale one.
- `Info.plist`: `LSUIElement = true`, `LSMinimumSystemVersion = 15.0`, `CFBundleIdentifier = com.paologiua.coco`, icon present.
- `codesign -dv`: **ad-hoc, arm64, sealed resources, 25 files**.
- Bundled resources present: `Sprites/`, `Menubar/`, `UI/` (including `food.png` and `hoop.png`), `Coco.icns`, and **`Text/birthday.txt` + `Text/welcome.txt`**.

One thing worth catching before delivery: the dev machine's `~/Library/Application Support/Coco/state.json` currently holds `"lastBirthdayCelebrated": 2026` and **no birthday month/day** — dev testing marked this year celebrated. That state lives outside the bundle and is not carried by the USB copy, so her Mac starts fresh; the risk is only that the birthday **must be set in Settings on her machine after install**, or the easter egg never fires on 14 September. Step 1 of the rehearsal checks below already covers it, but it is the single failure that would cost the whole point of the gift, so it should be confirmed twice: once at install, and once by reopening Settings after a relaunch.

**Still pending, unchanged:** physical USB transfer, launch on the target Mac, all visual checks against macOS 15 chrome, and the reboot/login verification. No target-machine result has been observed. The ticket stays claimed and open.
