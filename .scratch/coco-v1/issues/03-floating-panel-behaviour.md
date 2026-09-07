# 03 — The always-on-top, non-activating, pixel-perfect panel

Type: research
Status: resolved
Blocked by: —
Parent: [map](../map.md)

## Question

What is the exact AppKit configuration for a window that hosts a desktop pet, and what does it cost in battery?

Answer all of:

1. **Floating above everything.** `NSPanel` vs `NSWindow`, which `NSWindow.Level` sits above ordinary windows and the Dock, and the `collectionBehavior` combination (`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`) that makes it visible on every Space **including over full-screen apps**. Confirm whether over-full-screen is actually achievable without special permissions — if it is not, that is an acceptable answer and v1 drops it.
2. **Never stealing focus.** The `.nonactivatingPanel` style mask and `canBecomeKey`/`canBecomeMain` overrides such that clicking or dragging Coco leaves the frontmost app's focus and text cursor untouched.
3. **Hit testing on transparency.** The window is a transparent rectangle with an opaque bird in the middle. How to make clicks pass through to whatever is underneath everywhere except on Coco's actual opaque pixels.
4. **Pixel-perfect scaling.** Rendering a 32x32 sprite at 4x on a Retina display with **nearest-neighbour** interpolation and no blur — the correct image interpolation setting and how to avoid half-pixel offsets from the backing scale factor.
5. **Battery cost.** This is a laptop and the window animates continuously. What is the cheapest way to run a ~8-12 fps sprite animation — timer, `CVDisplayLink`, layer-backed animation — and how should the app throttle or stop when Coco is asleep, hidden, or the machine is on battery?

Cite Apple documentation. Where an approach is known to be fragile across macOS versions, say so.

## Answer

Full findings, with measurements and a compiling reference implementation: [`research/03-floating-panel-behaviour.md`](../research/03-floating-panel-behaviour.md).

Verified structurally: `NSPanel.h` is byte-identical between the macOS 15 and 26 SDKs and `NSWindow.h` differs only in comment formatting — no API drift on the one surface we cannot test locally. The reference implementation compiles under `-target arm64-apple-macosx15.0`.

**1. Floating above everything.** Use `NSPanel` at level **`.statusBar` (25)**, not `.floating` (3) — the Dock sits at level 20, so `.floating` puts Coco *behind* the Dock. Landmine: setting `isFloatingPanel = true` **silently resets the level back to 3**, so it must be set *before* the level, or not at all. This failure presents as "the Dock is drawing over my bird" and is easy to misdiagnose.

Over full-screen spaces: `.canJoinAllApplications` (macOS 13+) is documented for exactly this case and needs no entitlement, but Apple never defines what makes a window "eligible" and the behaviour could not be verified without triggering an Accessibility prompt. **Set the bits; verify by eye at first build; drop the requirement if it does not hold.**

**2. Never stealing focus.** `.nonactivatingPanel` + `canBecomeKey = false` + `NSApplication.setActivationPolicy(.accessory)`. A non-activating panel still receives `mouseDown`/`mouseDragged`. **Consequence for a later ticket:** a panel that can never become key cannot hold a text insertion point, so the settings UI with the birthday date field must be a separate ordinary `NSWindow`.

**3. Hit testing — the ticket's premise was wrong.** `NSView.hitTest` only chooses which view *inside your own window* receives an event; it cannot pass a click through to another application. Alpha-based `hitTest` alone produces a window that ignores clicks on its transparent corners while still blocking the app underneath — an invisible dead zone. Real pass-through requires `window.ignoresMouseEvents`, toggled by polling `NSEvent.mouseLocation` against an alpha mask in the animation tick that already exists. Measured: 128 bytes per frame mask, 0.5 ns per lookup.

**4. Pixel-perfect scaling.** `.default` interpolation blurs identically to `.high` (22 grey levels across an edge, versus exactly 2 for `.none`) — nearest is never the default anywhere in the stack and must be set explicitly. The half-pixel worry is a non-issue: `NSWindow` snaps frame origins to whole points. The real consequence is **motion granularity** — position must be accumulated fractionally in the simulation and rounded only at display time, or slow movement stalls entirely.

**5. Battery.** `CVDisplayLink` is **deprecated as of macOS 15.0** — our exact deployment target; the replacement is `NSWindow.displayLink(target:selector:)`. `setFrameOrigin` costs ~200x a layer move (44µs vs 0.2µs) but at 10 fps that is 0.04% of a core, so the big-window-with-inner-layer architecture is premature complexity and is **not** recommended. The real win is `CAKeyframeAnimation` in `.discrete` mode for stationary loops: it runs in the render server at **zero app CPU**, so a sleeping Coco costs nothing.

`ProcessInfo.isLowPowerModeEnabled` is **not** "on battery" — it is true only when the user explicitly turns on Low Power Mode. Recommendation: do not build unplugged-detection at all.
