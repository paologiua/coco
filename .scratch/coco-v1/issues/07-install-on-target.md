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
3. `xattr -dr com.apple.quarantine /Applications/Coco.app`, then confirm `xattr -l` prints no
   `com.apple.quarantine`. It is **not** expected to print nothing: macOS adds
   `com.apple.provenance` to apps in `/Applications` by itself, it is unrelated to
   Gatekeeper, and it cannot be removed. Observed on the dev machine on 7 September —
   worth knowing before it looks like a failure on hers.
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

### 2026-09-08 — Carry-over build re-verified after the balancing pass; consolidated rehearsal checklist

Picked the map back up. [15 — Balancing pass: how the numbers actually feel](15-balancing-pass.md) has resolved since the last pass, so the question this session answers is narrow: **is the bundle on disk the balanced Coco, or the pre-balancing one?** It is the balanced one. Nothing was rebuilt.

Verified, not assumed:

- `bash scripts/test.sh` — **40 tests in 4 suites pass** (32 at the last pass; the balancing suite added the rest, including `flyingCostsMoreThanSittingStill` and `affectionOnlyFallsWhileSheIsOnScreen`).
- `dist/Coco.app/Contents/MacOS/Coco` was built **2026-09-08 00:42**, and **no file in `Sources/`, `Assets/` or `Package.swift` is newer than it** — the bundle post-dates `be1e442 feat: a much needier Coco, and flying that costs something`.
- `codesign -dv`: **ad-hoc, arm64, sealed resources, 26 files** (25 at the last pass — `Text/reunion.txt` is the new one).
- `Info.plist`: `LSUIElement = true`, `LSMinimumSystemVersion = 15.0`, `CFBundleIdentifier = com.paologiua.coco`.
- Bundled `Text/` now carries **`birthday.txt`, `welcome.txt` and `reunion.txt`** — the reunion line from [15](15-balancing-pass.md) is in the signed bundle, not just in the source tree. `birthday.txt` still reads `Buon compleanno! 🎂`, matching `Assets/Text/`.

**Consolidated rehearsal checklist.** The three comments above accumulated checks in the order they were discovered; this is the same set in the order to actually walk them, and supersedes them as the thing to carry to the machine.

*Install*

1. USB stick, never AirDrop. Drag `Coco.app` into `/Applications` **in the Finder**, not `cp`.
2. `xattr -dr com.apple.quarantine /Applications/Coco.app`, then `xattr -l`. `com.apple.provenance` remaining is **expected and not a failure**; only `com.apple.quarantine` matters.
3. Launch: no Dock icon, menubar icon present, welcome bubble flies in.

*The one that costs the whole gift if missed*

4. Settings → set **Birthday to 14 September**. Fresh state has none and the easter egg will not fire without it. Quit, reopen, **confirm it persisted** — the dev machine's own state carries `lastBirthdayCelebrated: 2026` and no month/day, so this has never been observed surviving a relaunch on a clean profile.

*Login*

5. Settings → **Start Coco when I log in**; expect the "Background Items Added" notification.
6. Confirm *Coco* in System Settings → General → Login Items & Extensions.
7. **Reboot and confirm she comes back.** The only real test of `SMAppService` on macOS 15. Must not be skipped.

*Visual, against macOS 15 chrome rather than macOS 26 — the only chance to see this*

8. Panel, menubar icon and open menu not visibly misaligned. Dragging steals no focus; clicks pass through where she is not drawn; she is present on all Spaces. Record **over-full-screen visibility as observed**, not assumed — it was never guaranteed.
9. Feed when hungry: she approaches, a nearby click feeds exactly once, food expires after 20 s. When full she ignores it. Hunger now rises **one bar segment per feed**, so several feeds are needed to fill her — this is the balanced behaviour, not a bug.
10. Play: hold the hoop in open space; she must fly *through* it and increment the counter. Three passes end it, 20 s timeout otherwise. Proximity alone must not score.
11. Escape, opening the menu, Hide, Settings and Sleep each remove the cursor object; ordinary clicks reach the foreground app afterwards.
12. Sleep from mid-air: she lands before closing her eyes and showing Zzz. With an eligible window below, move or close it after landing — she should startle. Check the Dock in **her** configuration; no eligible surface falls back to the screen floor.

*Before handing it over*

13. Review `Assets/Text/birthday.txt` (`Buon compleanno! 🎂`). **If changed, rebuild** — the bundle is signed after the edit, not before.
14. Show her how to turn Coco off and how to remove her.

**Still pending, unchanged:** physical USB transfer, launch on the target Mac, every visual check, and the reboot/login verification. **No target-machine result has been observed.** The ticket stays claimed and open. Six days to the deadline.

### 2026-09-08 — The menubar icon can be dropped by macOS, and then Coco is unreachable

Found while investigating a report of "no icon in the menubar" on the **dev** machine.
Not a bug in Coco, and it is a delivery risk worth carrying to her Mac.

Measured on the dev machine (14" MacBook, notched):

```
auxTopRight: (850.0, 950.0, 662.0, 32.0)
```

Status items get **662 points**, the strip right of the notch, and nothing else. When
that strip is full macOS **silently drops** the item that does not fit. Proven, not
inferred: with the app running, `statusItem.button` was non-nil, `isVisible` was
`true`, `length` was `squareLength`, all four mood icons had loaded and a valid 22x22
`NSImage` was assigned — and replacing the image with the plain text title `COCO` still
rendered nothing. The item is configured correctly and the system refuses to show it.

The single biggest consumer was the system **Now Playing** widget, which is ~130 pt and
**grows with the track title**. So a menubar that has room today loses Coco when a song
with a long name starts.

**The trap:** `Hide Coco` sets `hidden` in the saved state, and the only way to undo it
is the menu behind that icon. Hidden *and* iconless, Coco cannot be recovered from
inside the app at all — which is exactly the state the dev machine was found in.
`scripts/dev-state.py --show` was added as the way out, but that is a developer tool
and **the recipient will not have it**.

Add to the rehearsal:

1. Before declaring the install good, **check her menubar has a free slot** and that
   Coco's icon is actually visible — not merely that the app is running.
2. If it is tight, offer to turn off Now Playing (System Settings → Control Centre →
   Now Playing → Don't show in Menu Bar) while she watches, so she can undo it.
3. **Show her `Hide Coco` and how to undo it**, and consider not showing her the item
   at all: on a full menubar it is a one-way door.

Worth considering before the gift: a fallback that does not depend on the status item —
for example, refusing to persist `hidden` across a relaunch, so quitting and reopening
always brings her back. Not decided here; recorded because it is cheap insurance on the
one machine we cannot debug remotely.

### 2026-09-12 — The birthday is now a letter, and it must be configured or it never appears

The birthday speech bubble is gone. In its place: on the birthday, every time Coco is
petted, a pixel-art card appears in the middle of the screen — "Coco has something for
you!" — and clicking it before it fades plays the envelope opening and ends on a full
letter with the personal message. A close box sits in its top-left corner.

This raises the stakes on step 4 of the rehearsal rather than changing it. Before, a
missing birthday cost a speech bubble. Now it costs the whole letter, which is the gift.
Setting the birthday in Settings on her machine, and confirming it survives a relaunch,
is the single check this install cannot skip.

Also worth knowing at the machine:

- The invitation appears on EVERY pet, all day, including after she has read it. That is
  deliberate — she can reopen the letter as often as she likes.
- It only follows a pet that actually lands. Asleep, or past the hourly petting cap, she
  refuses, and no card appears. If the letter seems not to work on the day, check she is
  awake first.
- The letter is sized to the screen height, so it is readable on the 14-inch display it
  was drawn for. It has not been seen on her machine.

