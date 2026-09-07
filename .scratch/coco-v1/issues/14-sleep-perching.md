# 14 — Sleeping somewhere, and startling awake

Type: task
Status: resolved
Blocked by: 09, 13
Parent: [map](../map.md)

## Question

Sleep should last a few minutes and happen *somewhere*, not in mid-air.

Three levels, cheapest first, each shippable on its own:

1. **Bottom of the screen.** She walks or flies down and sleeps there. Needs a side-on sleeping sprite; the existing `sleep.png` is front-facing, which reads as looking at you rather than perching.
2. **The Dock's edge.** The Dock's frame is available with no permissions.
3. **The edge of a real window.** She perches on the top edge of whatever window is beneath her.

And the reaction the human asked for during charting, recorded then and deferred: **when a window moves or the Dock changes size, Coco startles and flies away.** She reacts; she does not track. That is far cheaper than following a window, and truer to a bird.

## Scope note

This was ruled **out of scope** while charting, on the grounds that it needed system window enumeration and was the most fragile feature in the idea. That assessment is now partly wrong, and it is worth recording why: `CGWindowListCopyWindowInfo` returns window **bounds** with **no permission prompt at all** — used directly during [06](06-app-skeleton.md) to verify Coco's own window level. Only window *titles* and *images* require Screen Recording.

So levels 2 and 3 are cheaper than the map claimed. They remain the most fragile part of the app, and the last thing that should be attempted before the deadline.

## Answer

Implemented on 2026-09-07 in `BehaviourDriver.swift` and `Perches.swift`, alongside [Interactive Feed and Play](12-interactive-actions.md) as explicitly requested by the user.

Coco flies to a support before entering the visible sleeping behaviour. The existing side-on blink frame supplies the closed-eye pose without introducing inconsistent new artwork. Zzz begin after landing. Existing simulation sleep durations and wake rules are preserved.

The support is the first eligible on-screen window or Dock surface below Coco, with enough room above it for her stage. Geometry is sampled once per second while sleep is requested, and immediately when it begins. Missing geometry falls back to the bottom of the visible screen. Bounds are converted from Quartz coordinates to AppKit coordinates. No titles, screenshots or Accessibility API are used.

A changed or missing support causes a short upward flight, followed by selection of a new support if Coco still needs sleep. She does not track a moving window. Dragging clears the support and interrupts sleep as before.

Tests cover flying down before sleeping, landing on a window edge, and taking flight when that support disappears. All 24 tests pass. Real Dock geometry, window occlusion, Spaces, and the appearance of the closed-eye pose still need visual rehearsal on the target Mac; this remains deliberately best-effort, with the screen floor as fallback.
