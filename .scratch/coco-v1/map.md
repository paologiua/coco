# Coco v1 — wayfinder map

Labels: `wayfinder:map`
Charted: 2026-09-06

## Destination

Coco v1 installed and running on the recipient's M3 MacBook (macOS 15 Sequoia), starting at login, verified working **before 14 September 2026** — with the birthday easter egg firing on every 14 September.

## Notes

- **Domain**: a macOS desktop pet — a pixel-art budgie named Coco — with a light tamagotchi simulation. Single-context repo: `CONTEXT.md` + `docs/adr/`.
- **This effort carries execution.** The map does not stop at a spec: build tickets are in scope and the last ticket is a physical install on the recipient's machine.
- **Hard deadline: 14 September 2026**, charted on 6 September — 8 days. **Art production, not code, is the critical path.**
- **Language**: repo, code, tickets and app UI all in English.
- **Skills to consult**: `domain-modeling` when touching terminology, `grilling` for open decisions, `research` for AFK research tickets, `prototype` for art and behaviour spikes.

### Confirmed logistics

- Recipient's Mac: **macOS 15 Sequoia, M3** — confirmed, not assumed.
- **The dev has physical access before 14 September**, so the rehearsal install of [07](issues/07-install-on-target.md) will happen. This is the only test against macOS 15 chrome and it must not be skipped.
- **A USB stick is available**: delivery sets no quarantine flag and the Gatekeeper prompt never appears.
- The birthday sequence **is back in**, in minimal form: on 14 September, on the first launch of the day, Coco flies in with a speech bubble carrying a personal message read from a text file in the bundle. The party hat and click-confetti stay for the rest of the day.

### Locked constraints — decided while charting, do not reopen without cause

- Native **Swift + AppKit**. Not Electron.
- **SwiftPM only.** Xcode is not installed on the dev machine; the `.app` bundle is assembled by hand.
- **Deployment target macOS 15.0, arm64** (both machines are M3), with `SDKROOT` **pinned to the macOS 15.4 SDK** present in the CLT. The dev machine runs macOS 26 — **the target OS cannot be tested locally.**
- **Sprites load via `Bundle.main` from `Contents/Resources/Sprites/`.** SwiftPM `resources:` and `Bundle.module` are forbidden: they resolve to a hard-coded dev-machine path and crash on any other Mac (see [02](issues/02-shipping-adhoc-app.md)).
- **Menubar mood icons are our own template PNGs, never SF Symbols** — a symbol newer than macOS 15 returns `nil` and the icon silently disappears.
- **Delivery is by USB stick, never AirDrop.** AirDrop sets the quarantine flag; USB does not, and the Gatekeeper prompt never appears.
- **Launch at login is `SMAppService.mainApp.register()`** — verified to work with an ad-hoc signature. No `LaunchAgent` fallback.
- **Do not tune layout against macOS 26 chrome.** Liquid Glass changed `NSPanel`/`NSStatusItem`/`NSMenu` metrics; the panel is fully custom-drawn so system chrome never participates.
- **Ad-hoc code signing**, no Apple Developer Program. Delivery is a hand-carried `.app`.
- **No system permissions**: no Accessibility, no Screen Recording.
- Sprites are **48x48**, rendered at **3x nearest-neighbour**, aligned bottom-centre; facing is **mirrored in code**, never drawn twice. 32x32 was tried and abandoned — the generator cannot draw that coarsely (see [01](issues/01-pixel-art-pipeline.md)).
- Animation frames are **derived from one base sprite**, not generated as cycles: small hand-edits plus motion in code (a 1px bob for breathing, an eyelid patch for blinking), with genuinely new drawing reserved for the flight wings.
- Needs are **Hunger, Affection, Energy**, deriving a single **Mood**. Decay is slow (~3 days from full to empty). Coco never sickens and never dies.
- Coco is **autonomous**: she wanders and flies on her own, prefers screen edges, avoids the cursor, and is draggable.
- Coco is visible on **all Spaces**; the only hiding is the explicit `Hide Coco` menu item. Over-full-screen visibility is **aspirational, not locked** — set `.canJoinAllApplications`, verify by eye at first build, drop it if it does not hold (see [03](issues/03-floating-panel-behaviour.md)).
- Coco sleeps when **Energy is low** or the Mac has been **idle ~15 minutes** — never by wall-clock hour.
- State persists as readable **JSON in `~/Library/Application Support/Coco/`**.
- The window is a **non-activating `NSPanel`** at level `.statusBar`: clicking Coco never steals focus from the app in front. Settings live in a **separate ordinary `NSWindow`**, because a non-key panel cannot hold a text field.
- The menubar icon is a **monochrome template silhouette** whose shape changes with Mood; the pixel-art status bars live inside the open menu.
- **No audio in v1.**

## Decisions so far

<!-- one line per resolved ticket: gist + link. The detail lives in the ticket, never here. -->

- [01 — Pixel art pipeline and the generation prompt](issues/01-pixel-art-pipeline.md): the generator makes true pixel art, but at ~60 units, so sprites are **48x48 at 3x**, not 32x32; frames are derived from one base sprite rather than generated as cycles; the face always needs a hand pass. Prompt, cleanup script and the first two sprites delivered.
- [02 — Shipping an ad-hoc-signed .app to macOS 15 from a CLT-only toolchain](issues/02-shipping-adhoc-app.md): hand-assembled bundle, `SDKROOT` pinned to the macOS 15.4 SDK (the compiler hard-errors on newer API anyway), sprites via `Bundle.main` because `Bundle.module` crashes off the dev machine, ad-hoc signing, USB delivery to dodge quarantine entirely, and `SMAppService` verified working ad-hoc.
- [03 — The always-on-top, non-activating, pixel-perfect panel](issues/03-floating-panel-behaviour.md): `NSPanel` at level `.statusBar` (not `.floating` — the Dock is above it), `.nonactivatingPanel` + `.accessory` policy for focus, `ignoresMouseEvents` toggled against an alpha mask for click-through (`hitTest` cannot do it), explicit `.none` interpolation, and `CAKeyframeAnimation` `.discrete` for zero-CPU idle loops. Over-full-screen is set-and-verify, not guaranteed.
- [04 — Domain model: needs, mood, and the behaviour state machine](issues/04-domain-model.md): Hunger 48 h, Affection 72 h, Energy 16 h awake; **Mood = min(Hunger, Affection)**, excluding Energy so she isn't sad every evening, and a minimum rather than an average so the menubar icon says what's wrong; catch-up capped at 12 h with a reunion reaction past 24 h away; Nap and Deep Sleep wake differently. Glossary in `CONTEXT.md`.
- [05 — Produce the full asset set](issues/05-asset-production.md): every asset exists. The 29-frame plan was replaced by two generated base poses plus derivation and code motion; the canvas grew to **64x64** to fit the hat and the wingspan; flight frames are aligned on the eye highlight so take-off needs no transition; menubar icons are colour, chosen against the legibility evidence.
- [06 — App skeleton: a bird on the screen](issues/06-app-skeleton.md): `Coco.app` builds from SwiftPM with no Xcode, runs above the Dock at level 25, does not steal focus, passes clicks through where she isn't drawn, and survives `/Applications`. Drag must be **absolute**, not incremental, and click-through must not be re-evaluated mid-gesture.
- [08 — Simulation core and persistence](issues/08-simulation-core.md): Needs, Mood, actions, sleep and the JSON store, with 18 tests. XCTest is unavailable without Xcode but **swift-testing ships with the CLT** — see `scripts/test.sh` for the three flags it needs. State saves at launch, every minute, and on quit.
- [09 — Behaviour driver and animation player](issues/09-behaviour-driver.md): clips only where the drawing differs, everything else motion in code; fractional position rounded at display; she flees the cursor and prefers screen edges; the timer drops to 1 Hz asleep.
- [10 — Menubar UI and settings](issues/10-menubar-ui.md): drawn status block rather than system controls, refusal shown on Coco herself, settings in their own window. Opening Settings used to set the birthday to 1 January in silence.
- [13 — Animated particles](issues/13-particles.md): particles live on a stage taller than the canvas, so no asset had to be re-cut; emitted over time rather than in a burst; sad reads through *movement*, not the face.
- [11 — Birthday easter egg and first-launch welcome](issues/11-birthday-and-welcome.md): the speech bubble is its own window because the stage is too narrow for a sentence; messages are plain text in the bundle; the year is marked celebrated only after the bubble is actually shown — marking it when merely queued silently cost the whole year.

- [Interactive Feed and Play](issues/12-interactive-actions.md): generated food and edge-on hoop sprites follow the cursor; full Coco refuses Feed visibly, hungry Coco approaches, and Play counts complete crossings of a hoop perpendicular to the screen. Visual acceptance is pending in the installation rehearsal.
- [Sleeping somewhere, and startling awake](issues/14-sleep-perching.md): fly to a window or Dock edge when eligible, otherwise the screen floor; use a side-on closed-eye pose and startle when the support changes. Geometry remains best-effort pending target-machine rehearsal.

## Not yet specified

<!-- in-scope fog: real but not yet sharp enough to ticket -->

~~**Balancing numbers**~~ — graduated to [15 — Balancing pass: how the numbers actually feel](issues/15-balancing-pass.md) on 7 September, once the simulation, the behaviour driver and the interactive actions were all running and the numbers could finally be felt rather than guessed.

The fog is otherwise clear: every decision this map set out to find is either made or ticketed, and what remains is the rehearsal itself.

## Out of scope

- ~~**Window- and Dock-aware behaviour**~~ — **brought back into scope** as [14](issues/14-sleep-perching.md). It was ruled out on the grounds that it needed window enumeration; that turned out to be wrong. `CGWindowListCopyWindowInfo` returns window bounds with **no permission prompt**, as used directly in [06](issues/06-app-skeleton.md). It is still the most fragile part of the app and the first thing to cut.
- **Audio** — chirps and effects. Extra assets, undecided need, and a pet that chirps during a call gets uninstalled.
- **Multi-display following** — Coco lives on one screen and is dragged between them.
