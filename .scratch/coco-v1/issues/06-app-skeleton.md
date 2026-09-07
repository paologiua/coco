# 06 — App skeleton: a bird on the screen

Type: task
Status: resolved
Blocked by: 02, 03
Parent: [map](../map.md)

## Question

Build the thinnest thing that proves the platform: a SwiftPM package that produces a `Coco.app` with no Dock icon, showing an animated placeholder sprite in a floating non-activating panel, plus a menubar item with nothing but `Quit`.

Resolved when:

- `swift build` plus a bundle script produces a runnable, ad-hoc-signed `Coco.app` targeting macOS 15.
- The sprite animates on screen above other windows, on every Space.
- Clicking it does not steal focus; clicking a transparent area passes through.
- The menubar item appears and `Quit` works.
- It survives being copied to `/Applications` and launched from Finder.

This ticket also **fixes the code's shape** — where the animation player, simulation, behaviour driver and UI live — which is what lets the rest of the build graduate out of the map's fog.

## Answer

`Coco.app` builds, runs, and passes all seven acceptance checks — five of them confirmed by eye on the dev machine, two verified programmatically.

**Verified by measurement**, not assumption:

```
owner=Coco  layer=25  alpha=1.0  bounds=1328,708  144x144
owner=Dock  layer=20
```

Level 25 against the Dock's 20 — Coco sits above it, avoiding the `.floating` (level 3) trap from [03](03-floating-panel-behaviour.md). `vtool` reports `minos 15.0 / sdk 15.4`, so the SDK pin holds. Copied to `/Applications`, the signature still verifies and she launches from Finder with no quarantine attribute.

**One real bug, found by the human and worth recording** because the cause was not the obvious one. Dragging moved Coco *further* than the mouse. Two faults compounding:

1. The `isDragging` guard was set and cleared inside a single call, so it guarded nothing. Click-through kept being re-evaluated ten times a second *during* the drag; moving the window changes which sprite pixel sits under a stationary pointer, so the moment that pixel was transparent, `ignoresMouseEvents` flipped on and the panel stopped receiving events. Movement then arrived in lurches.
2. Dragging accumulated **relative** deltas, so every dropped event became permanent drift.

Fixed by holding `isDragging` for the whole gesture and switching to **absolute** positioning: record where inside the panel the pointer grabbed her, then keep that point under the pointer. A dropped event now leaves no trace. A 3-point threshold separates a pet from a drag, so a wobble while petting does not send her flying.

**The shape of the code**, which is what unblocks the rest of the build:

| File | Holds |
|---|---|
| `Sources/Coco/main.swift` | entry point, `.accessory` activation policy |
| `Sources/Coco/Sprite.swift` | sprite loading from `Bundle.main` + the alpha mask used for click-through |
| `Sources/Coco/CocoPanel.swift` | the window: level, collection behaviour, non-activating, never key |
| `Sources/Coco/SpriteView.swift` | nearest-neighbour drawing, mouse gesture recognition |
| `Sources/Coco/AppDelegate.swift` | the tick, the status item, click-through, drag |
| `scripts/build-app.sh` | SDK pin, `minos` assertion, `Bundle.module` guard, bundle assembly, ad-hoc signing |

The simulation, the behaviour driver, the menubar UI and settings have no home yet — that is what graduates from the map's fog next.
