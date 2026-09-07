# 03 — The always-on-top, non-activating, pixel-perfect panel

Type: research findings
Ticket: [03](../issues/03-floating-panel-behaviour.md)
Researched: 2026-09-06

## How this was researched

Three source classes, in descending order of trust:

1. **SDK headers on this machine** — `/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk` and
   `MacOSX26.sdk`. These are the authoritative declarations for the exact deployment target.
2. **Empirical tests** — Swift 6.3.3 (`swift-driver 1.148.6`, `arm64-apple-macosx26.0`) compiled and
   run on this machine (macOS 26, single 1512x982 display at `backingScaleFactor` 2.0). Every
   number labelled *measured* below came from a program actually executed here.
3. **Apple developer documentation**, fetched from the doc site's JSON backend.

**Deployment-target check:** the full reference implementation at the end of this document compiles
clean under `swiftc -target arm64-apple-macosx15.0`. Every API recommended here exists on macOS 15.

**Stability across macOS 15 → 26:** `NSWindow.h` and `NSPanel.h` were diffed between the two SDKs.
`NSPanel.h` is byte-identical. `NSWindow.h` differs only in doc-comment reformatting and one
paragraph reordering — **no API, no constant, and no semantic change**. This is a strong signal that
the configuration below behaves the same on the target machine (15) as on the dev machine (26).

---

## 1. Floating above everything

### NSPanel vs NSWindow

Use **`NSPanel`**. It is not a style preference — one thing Coco needs is only reachable through
`NSPanel`. `NSWindowStyleMaskNonactivatingPanel` is documented in the header as:

> `@const NSWindowStyleMaskNonactivatingPanel` Specifies that a panel that does not activate the
> owning application. **Only applicable for `NSPanel` (or a subclass thereof).**
>
> — `MacOSX26.sdk/.../AppKit.framework/Headers/NSWindow.h:51`

A plain `NSWindow` cannot carry that bit meaningfully, and requirement 2 (never steal focus) depends
on it. `NSPanel` is otherwise a thin subclass — its entire public surface is three properties:

```objc
@interface NSPanel : NSWindow
@property (getter=isFloatingPanel) BOOL floatingPanel;
@property BOOL becomesKeyOnlyIfNeeded;
@property BOOL worksWhenModal;
@end
```
— entire `NSPanel.h` interface, identical in the 15 and 26 SDKs.

### Window levels — the actual numbers

`NSWindow.Level` is a typed `NSInteger` whose constants are literally the `CGWindowLevel` macros:

```objc
typedef NSInteger NSWindowLevel NS_TYPED_EXTENSIBLE_ENUM;
static const NSWindowLevel NSNormalWindowLevel   = kCGNormalWindowLevel;
static const NSWindowLevel NSFloatingWindowLevel = kCGFloatingWindowLevel;
static const NSWindowLevel NSStatusWindowLevel   = kCGStatusWindowLevel;
static const NSWindowLevel NSPopUpMenuWindowLevel = kCGPopUpMenuWindowLevel;
static const NSWindowLevel NSScreenSaverWindowLevel = kCGScreenSaverWindowLevel;
```
— `NSWindow.h:192-201`

*Measured* by printing `.rawValue` and `CGWindowLevelForKey()` on this machine:

| Level | Swift | Value | Sits above the Dock (20)? |
|---|---|---|---|
| `kCGNormalWindowLevel` | `.normal` | **0** | no |
| `kCGFloatingWindowLevel` | `.floating` | **3** | **no** |
| `kCGModalPanelWindowLevel` | `.modalPanel` | **8** | no |
| `kCGUtilityWindowLevel` | — | 19 | no |
| **`kCGDockWindowLevel`** | (deprecated `NSDockWindowLevel`) | **20** | — |
| `kCGMainMenuWindowLevel` | `.mainMenu` | **24** | yes |
| `kCGStatusWindowLevel` | `.statusBar` | **25** | **yes** |
| `kCGPopUpMenuWindowLevel` | `.popUpMenu` | **101** | yes |
| `kCGScreenSaverWindowLevel` | `.screenSaver` | **1000** | yes |

Header source for the raw numbers: `CoreGraphics.framework/Headers/CGWindowLevel.h:67-80`.
`NSDockWindowLevel` is deprecated (`macos(10.0, 10.13)`, `NSWindow.h:1066`) but the *level value* 20
is still what the Dock occupies.

**The important consequence: `.floating` (3) is BELOW the Dock (20).** The obvious-looking choice is
the wrong one — a `.floating` bird would be covered by the Dock. This is the single most common
mistake in this area.

**Recommendation: `.statusBar` (25).** It clears the Dock (20) and the menu bar (24) by the smallest
margin that works. Avoid `.popUpMenu` (101) and `.screenSaver` (1000): a pet that draws over open
menus and over the screen saver / login-adjacent UI is obnoxious and, at 1000, arguably a
misrepresentation of system UI. `.statusBar` is the right altitude for an ambient overlay.

*Measured verification* — a panel configured exactly as recommended, queried through
`CGWindowListCopyWindowInfo` while running:

```
our windowNumber: 11270 level: 25 onActiveSpace: true visible: true
FOUND in CGWindowList -> layer: 25 alpha: 1.0
--- non-negative layers on screen ---
   Arc layer=0
   Arc layer=26
   Window Server layer=24 name=Menubar
   swift-frontend layer=25          <-- our panel, above the Menubar
```

The panel really does land at layer 25, above the menu bar. (Note `CGWindowListCopyWindowInfo` with
`.optionOnScreenOnly` returns *metadata* only and needs **no** Screen Recording permission — only
capturing pixels does. It is fine to use for debugging, though the shipped app needs none of it.)

### ⚠️ Gotcha: `isFloatingPanel` silently overwrites `level`

`NSPanel.isFloatingPanel` is not an independent flag — its setter forces the level to
`.floating` (3). *Measured*:

```
level=.statusBar THEN isFloatingPanel=true  -> level: 3     <-- clobbered
isFloatingPanel=true THEN level=.statusBar  -> level: 25    <-- correct
level=.statusBar only                       -> level: 25, isFloatingPanel: false
fresh borderless nonactivating panel        -> level: 0, isFloatingPanel: false
```

**Always set `isFloatingPanel` before `level`.** Getting this backwards silently drops the bird
behind the Dock, and looks like a Dock bug rather than an ordering bug. Note also that a
code-created `NSPanel` starts at level **0**, not floating — the level must be set explicitly.

### Collection behaviour — visible on every Space

The header states the mutual-exclusion rules precisely (`NSWindow.h:94-125`):

> You may specify at most one of `NSWindowCollectionBehaviorManaged`, `NSWindowCollectionBehaviorTransient`,
> or `NSWindowCollectionBehaviorStationary`.
> - `Managed` Participates in spaces, exposé. Default behavior if `windowLevel == NSNormalWindowLevel`.
> - `Transient` Floats in spaces, hidden by exposé. Default behavior if `windowLevel != NSNormalWindowLevel`.
> - **`Stationary` Unaffected by exposé. Stays visible and stationary, like desktop window.**
>
> You may specify at most one of `ParticipatesInCycle` or `IgnoresCycle`.
>
> You may specify at most one of `FullScreenPrimary`, `FullScreenAuxiliary`, or `FullScreenNone`.
> - `FullScreenAuxiliary` Windows with this collection behavior can be shown with the fullscreen window.
>
> You may specify at most one of `Primary`, `Auxiliary`, or `CanJoinAllApplications`.

Three *separate* exclusion groups — so `.stationary`, `.ignoresCycle`, `.fullScreenAuxiliary` and
`.canJoinAllApplications` can all be combined. *Measured*: setting all four together raised no
assertion and produced `collectionBehavior.rawValue = 262481`.

Recommended set, and why each bit is there:

| Bit | Why |
|---|---|
| `.canJoinAllSpaces` | the bird appears on every Space rather than being tied to one |
| `.stationary` | **not** swept away or shrunk by Mission Control / Exposé — she stays put |
| `.fullScreenAuxiliary` | can be shown alongside a full-screen window |
| `.ignoresCycle` | keeps her out of Cmd-Tab / window cycling (already the default at level != 0, but explicit is better) |
| `.canJoinAllApplications` | macOS 13+; see below — the full-screen-over-*other*-apps bit |

Deliberately **not** used: `.transient` (would hide her in Exposé — `.stationary` is the desired
opposite), `.moveToActiveSpace` (that *moves* the window on Space switch rather than showing it
everywhere; `.canJoinAllSpaces` is the correct choice), `.managed`.

### Over another app's full-screen space — can it be done?

**Documented answer: yes, and without any entitlement or permission** — via
`NSWindowCollectionBehaviorCanJoinAllApplications`, added in macOS 13. Apple's documentation:

> **The behavior marking this window as one that can join all apps for both Stage Manager and full screen.**
>
> Windows marked with this behavior don't participate in Stage Manager layout but **can join the
> windows of other apps in full screen spaces when eligible.**
>
> **Use this collection behavior for floating windows and system overlays.** To opt out of joining
> other apps' full screen spaces use `fullScreenPrimary`.
>
> This property is mutually exclusive. Set only one of `primary`, `auxiliary`, or
> `canJoinAllApplications` on a window handled by Stage Manager at a time.
>
> — https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications
>   (availability: macOS 13.0+)

That is close to a description of this exact use case — "floating windows and system overlays" that
"join the windows of other apps in full screen spaces". It requires **no entitlement, no Accessibility,
no Screen Recording**, and it is available on the macOS 15 target. It is in the SDK as
`NSWindowCollectionBehaviorCanJoinAllApplications API_AVAILABLE(macos(13.0)) = 1 << 18`
(`NSWindow.h`), present identically in both the 15 and 26 SDKs.

The distinction that matters, and which is easy to get wrong:

- **`.fullScreenAuxiliary`** — "The window displays on the same space as the full screen window"
  (https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary,
  macOS 10.7+). Historically this works for a full-screen window **owned by the same application**.
  It is what a video player uses to float its own controls over its own full-screen window.
- **`.canJoinAllApplications`** — the newer bit that extends this to **other applications'**
  full-screen spaces.

Both should be set. `.fullScreenAuxiliary` alone is the classic recipe and is *not* sufficient for
the "over Safari in full screen" case.

### ⚠️ What I could NOT establish — read this before locking the requirement

**I could not empirically verify that the panel actually draws over another app's full-screen space.**
Doing so requires driving a real app into full screen and looking at the result. Synthesising that
interaction (`CGEvent` posting or `osascript` UI scripting) requires **Accessibility permission**,
and triggering a permission prompt on this machine would have been both intrusive and contrary to
the project's no-permissions constraint. So this rests on Apple's documentation, not on a test I ran.

Two specific residual risks:

1. **"when eligible" is undefined.** Apple's sentence is "can join the windows of other apps in full
   screen spaces **when eligible**". Apple does not document what makes a window eligible. It
   plausibly interacts with window level, activation policy, and whether the app is an accessory.
   This is the weakest link in the whole document.
2. **WWDC did not cover it.** The WWDC22 "What's new in AppKit" session
   (https://developer.apple.com/videos/play/wwdc2022/10074/) discusses collection behaviours and
   Stage Manager at length — "Stage Manager also respects your window's collectionBehavior… it now
   also helps Stage Manager understand that a window is considered to be auxiliary or floating" —
   but the transcript **never mentions `canJoinAllApplications`**. There is no WWDC demo of the
   over-another-app's-full-screen case to corroborate the doc page.

**Recommendation for the project.** Set the bits, and treat over-full-screen as a
*best-effort* behaviour rather than a guaranteed one. This costs nothing — the same configuration is
what you would ship anyway — but the requirement should not be load-bearing for v1 acceptance until
someone has watched a bird sit on top of a full-screen Safari with their own eyes. That test is
**five minutes of manual work** on the dev machine and should happen at the first running build,
well before the deadline. The map currently lists "visible on all Spaces, including over full-screen
apps" as a locked constraint; it is worth downgrading the full-screen half to "verify early, drop if
it does not hold".

---

## 2. Never stealing focus

Three independent mechanisms, all of which should be applied.

### 2a. Activation policy

```swift
NSApplication.shared.setActivationPolicy(.accessory)
```

> The application doesn't appear in the Dock and doesn't have a menu bar, but it may be activated
> programmatically or by clicking on one of its windows. This corresponds to value of the
> `LSUIElement` key in the application's `Info.plist` being `1`.
>
> — https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory

Set `LSUIElement` to `1` in `Info.plist` **as well as** calling this. The plist form applies from
process start, which avoids a Dock icon flashing during launch; the programmatic call is the
belt-and-braces. This matters for a hand-assembled bundle (ticket 02) where the plist is written by
hand.

### 2b. Style mask

```swift
styleMask: [.borderless, .nonactivatingPanel]
```

> The window is a panel or a subclass of `NSPanel` that does not activate the owning app.
>
> — https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel

`.borderless` is `NSWindowStyleMaskBorderless = 0` (`NSWindow.h:55`) — no titlebar, no chrome.
Note that `[.borderless, .nonactivatingPanel]` is really just `1 << 7`, since borderless is zero.

### 2c. Key/main overrides

```swift
final class CocoPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

`canBecomeKeyWindow` / `canBecomeMainWindow` are declared readonly on `NSWindow` (`NSWindow.h:438-439`),
so overriding is the documented way to change them. *Measured*: the overrides take effect
(`canBecomeKey: false  canBecomeMain: false`), and after `orderFrontRegardless()` the app reported
`NSApp.isActive == false` — the app never activated.

Also set, for the same goal:

```swift
panel.hidesOnDeactivate = false   // NSWindow.h:416 — stay visible when another app is frontmost
panel.animationBehavior = .none   // no order-front animation (NSWindowAnimationBehaviorNone = 2)
```

Use **`orderFrontRegardless()`**, never `makeKeyAndOrderFront(_:)`. The latter's entire purpose is to
take key status.

### Does a non-activating panel still get mouseDown / mouseDragged?

**Yes.** Mouse event delivery is a property of the *window* receiving the event; it does not require
the window to be key or the app to be active. Key-window status gates **keyboard** input, not mouse
input. This is exactly the mechanism every menu-bar-extra overlay and Spotlight-style panel relies on.

Two consequences worth stating plainly:

- **Dragging works.** `mouseDown` / `mouseDragged` / `mouseUp` arrive on the panel's content view and
  can drive `setFrameOrigin`, with the frontmost app's focus and text insertion point untouched.
- **Keyboard input does not work, by construction.** With `canBecomeKey == false` the panel can never
  hold a text insertion point. That is correct for the bird. **But it means any UI that needs typing
  — the settings window with a birthday date field — must be a separate, ordinary `NSWindow`**, not
  this panel and not a subview of it. Worth carrying into the settings ticket.

⚠️ *Not empirically clicked in this session.* I did not synthesise mouse clicks, for the permission
reason given in section 1. This claim rests on the documented role of key-window status and on the
`.nonactivatingPanel` doc text. It is low-risk and trivially confirmed at the first running build:
click the bird while a text cursor blinks in another app and check the caret keeps blinking.

---

## 3. Hit testing on transparency

### The central correction

**`NSView.hitTest(_:)` cannot make clicks pass through to another application.** This is the most
important finding in this section, and the ticket's framing invites the wrong answer. Apple's
documentation defines hitTest's scope:

> Returns the farthest descendant of the view in the view hierarchy (including itself) that contains
> a specified point, or `nil` if that point lies completely outside the view. … **This method is used
> primarily by an `NSWindow` object to determine which view should receive a mouse-down event.**
>
> — https://developer.apple.com/documentation/appkit/nsview/hittest(_:)

hitTest chooses **which view inside your window** gets the event. If it returns `nil`, the window
still received and consumed the click — the event does not fall through to whatever app is
underneath. Alpha-based hitTest alone gives you a bird that ignores clicks on its transparent
corners *while still blocking the app below from receiving them*. That is a dead zone, and it is a
worse bug than no hit-testing at all, because it is invisible.

The only documented mechanism for true cross-application pass-through is:

> **`ignoresMouseEvents`** — A Boolean value that indicates whether the window is transparent to
> mouse events. The value of this property is `true` when the window is transparent to mouse events;
> otherwise, `false`.
>
> — https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents

(`@property BOOL ignoresMouseEvents;` — `NSWindow.h:795`)

### The recommended approach: poll the cursor, toggle `ignoresMouseEvents`

Because the app already runs an animation tick at ~10 fps, the cheapest correct design is to fold the
hit test into that tick:

1. Read `NSEvent.mouseLocation` (screen coordinates, **no permission required** — *measured*, returns
   a live cursor position with no prompt).
2. Convert to sprite pixel coordinates.
3. Look up the current frame's alpha mask.
4. Set `window.ignoresMouseEvents = !opaque`.

No event monitor, no tracking area, no extra timer. It reuses a tick that already exists.

**Why not `NSEvent.addGlobalMonitorForEvents`?** It would work and needs no permission for mouse
events —

> Key-related events may only be monitored if accessibility is enabled or if your application is
> trusted for accessibility access.
>
> — https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)

— mouse events carry no such restriction. But the same page warns:

> Note that your handler will not be called for events that are sent to your own application.

So once the cursor is over the bird and the panel is *not* ignoring events, the global monitor goes
silent, and you need a local monitor too to know when to switch back. Polling `NSEvent.mouseLocation`
sidesteps that split-brain entirely. **Polling is both cheaper and less bug-prone here.**

### The alpha mask

Precompute one bitmask per sprite frame at load time. A 32x32 frame is **128 bytes** packed one bit
per pixel — *measured*, along with lookup cost:

```
opaque pixels in 32x32 mask: 305 -> mask size: 128 bytes/frame
1M mask lookups: 0.50 ms (0.5 ns/lookup)
```

**0.5 ns per lookup.** Even a hundred frames of animation is 12.8 KB of masks. The cost is
indistinguishable from zero; there is no reason to sample the image at click time.

```swift
struct HitMask {
    let w: Int, h: Int
    private var bits: [UInt8]

    init(cgImage img: CGImage, threshold: UInt8 = 8) {
        w = img.width; h = img.height
        var alpha = [UInt8](repeating: 0, count: w * h)
        alpha.withUnsafeMutableBytes { raw in
            if let ctx = CGContext(data: raw.baseAddress,
                                   width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) {
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }
        var packed = [UInt8](repeating: 0, count: (w * h + 7) / 8)
        for i in 0..<(w * h) where alpha[i] >= threshold {
            packed[i >> 3] |= (1 << UInt8(i & 7))
        }
        bits = packed
    }

    /// x, y in sprite pixel coordinates, origin top-left.
    func isOpaque(x: Int, y: Int) -> Bool {
        guard x >= 0, x < w, y >= 0, y < h else { return false }
        let i = y * w + x
        return bits[i >> 3] & (1 << UInt8(i & 7)) != 0
    }
}
```

An `alphaOnly` `CGContext` extracts the alpha channel directly, which avoids unpacking RGBA by hand.

And the per-tick test (note the y-flip: AppKit screen coordinates are origin-bottom-left, sprite
pixels are origin-top-left):

```swift
func updateMousePassthrough(scale: CGFloat) {
    let p = NSEvent.mouseLocation
    let f = panel.frame
    guard f.contains(p) else { panel.ignoresMouseEvents = true; return }
    let lx = Int((p.x - f.minX) / scale)
    let ly = Int((f.maxY - p.y) / scale)          // flip to top-left origin
    panel.ignoresMouseEvents = !currentMask.isOpaque(x: lx, y: ly)
}
```

**A generous threshold is a feature.** A 32x32 budgie at 4x is a small target; alpha `>= 8` counts
near-transparent antialiased edge pixels as grabbable. If the art is hard-edged pixel art with no
partial alpha (which ticket 01 should produce), the threshold is irrelevant and any value works.
Consider *dilating* the mask by one sprite pixel to make the bird easier to grab.

### Why not the alternatives

- **A dynamically-updated ignore region.** There is no supported public API for a per-region
  ignore mask on `NSWindow` — `ignoresMouseEvents` is whole-window. Shaped-window APIs that would do
  this (`CGSSetWindowShape` and friends) are private SPI: not shippable, and exactly the kind of
  thing that breaks between macOS releases. **Rejected.**
- **`NSWindow.setContentSize` / shrink-wrapping the window to the bird.** Making the window exactly
  the bird's bounding box reduces the transparent dead area but does not eliminate it (a budgie is
  not rectangular), and it forces a window resize on every animation frame — far more expensive than
  a 0.5 ns mask lookup, and resizes are a window-server round trip. **Rejected** as a primary
  mechanism. Do keep the window snug around the sprite anyway (128x128 for a 32x32 at 4x) — a
  smaller window is less to composite.
- **hitTest alpha override alone.** Rejected per the analysis above — it creates invisible dead zones.

**Do still override `hitTest`** as a secondary refinement *inside* the window, once there is more
than one interactive element (say a birthday hat with its own click behaviour). It is the right tool
for intra-window routing and the wrong tool for cross-app pass-through.

---

## 4. Pixel-perfect scaling

The target: a 32x32 PNG shown at 4x logical size (128x128 points) on a 2x Retina display, i.e.
**256x256 backing pixels — 8 physical pixels per source pixel** — with no blur.

### The default is wrong; nearest must be set explicitly

*Measured*, rendering the 32x32 checkerboard to 256x256 and counting distinct luminance levels
(a hard-edged nearest-neighbour result must contain exactly two: 0 and 255):

```
interpolation .none:    2 distinct levels, sample=[0, 255]     <-- correct
interpolation .high:   22 distinct levels, sample=[0, 15, 30, 31, 44, 56, 63, 72]
interpolation .default: 22 distinct levels                      <-- identical to .high
interpolation .low:    22 distinct levels
```

**`.default` blurs exactly as much as `.high`.** Nearest-neighbour is never the default anywhere in
the stack — not in `NSGraphicsContext`, not in `CALayer` — so it must be set explicitly on every
path that touches the sprite.

### Path A (recommended): CALayer with nearest filtering

```swift
sprite.magnificationFilter = .nearest   // kCAFilterNearest
sprite.minificationFilter  = .nearest
sprite.contentsGravity     = .resize
sprite.allowsEdgeAntialiasing = false
```

> **magnificationFilter** — The filter used when increasing the size of the content. The possible
> values for this property are listed in Scaling Filters. **The default value of this property is
> `linear`.**
>
> — https://developer.apple.com/documentation/quartzcore/calayer/magnificationfilter

`kCAFilterNearest` / `kCAFilterLinear` / `kCAFilterTrilinear` are declared at `CALayer.h:1045-1054`.
Set `minificationFilter` too: it costs nothing and protects against any transient sub-1.0 scale
(a scared-bird shrink animation, say) reintroducing blur.

`allowsEdgeAntialiasing` matters because CoreAnimation may antialias layer *edges* independently of
content filtering, producing a soft one-pixel border around an otherwise crisp sprite.

### contentsScale

```swift
sprite.contentsScale = window.backingScaleFactor
```

> Defines the scale factor applied to the contents of the layer. If the physical size of the contents
> is `(w, h)` then the logical size (i.e. for contentsGravity calculations) is defined as
> `(w / contentsScale, h / contentsScale)`. Applies to both images provided explicitly and content
> provided via `-drawInContext:`… **Defaults to one.** Animatable.
>
> — `QuartzCore.framework/Headers/CALayer.h:398-407`

Leaving it at the default 1.0 on a 2x display makes CoreAnimation upload a half-resolution buffer and
scale it — soft output even with `.nearest`. Set it, and re-set it on display change (below).

### Path B: manual drawing

If drawing through `NSGraphicsContext` (for the menu-bar status art, for instance) rather than
assigning `layer.contents`:

```swift
NSGraphicsContext.current?.imageInterpolation = .none
NSGraphicsContext.current?.shouldAntialias = false
image.draw(in: destRect, from: .zero, operation: .copy, fraction: 1.0)
```

`NSImageInterpolationNone = 1` (`NSGraphicsContext.h:32-38`);
`@property NSImageInterpolation imageInterpolation;` (`NSGraphicsContext.h:87`).

Use `operation: .copy` rather than `.sourceOver` when the destination is known-empty — it skips
blending. `shouldAntialias = false` prevents edge softening on the destination rectangle.

### Half-pixel offsets — a smaller problem than expected

Two *measured* results, both reassuring:

**Sub-pixel draw origins do not blur under `.none`.** Drawing the sprite at fractional destination
origins and counting levels:

```
origin offset 0.00 px -> 2 distinct levels
origin offset 0.25 px -> 2 distinct levels
origin offset 0.50 px -> 2 distinct levels
origin offset 0.75 px -> 2 distinct levels
```

Nearest-neighbour never blends, so a fractional origin cannot produce an intermediate colour. The
theoretical risk is *uneven block widths* ("pixel wobble") rather than blur — but measuring run
lengths along a striped test image showed uniform blocks at every offset:

```
offset 0.00 -> run lengths: [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8]
offset 0.50 -> run lengths: [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8]
offset 0.30 -> run lengths: [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8]
```

**`NSWindow` snaps frame origins to whole points anyway.** *Measured*:

```
requested 100.00 -> actual 100.0000
requested 100.25 -> actual 100.0000
requested 100.50 -> actual 100.0000
requested 100.70 -> actual 100.0000
```

AppKit quantises the window origin to integral points. On a 2x display one point is two backing
pixels, so a window placed by `setFrameOrigin` is **always** backing-pixel aligned. The half-pixel
problem the ticket worries about does not arise for window placement.

**The real consequence is motion granularity, not sharpness.** Because origins snap to whole points,
window movement is quantised to 1 pt = 2 physical px = **half a source pixel** at 4x. For a
pixel-art pet this is not merely acceptable, it is desirable — sub-pixel gliding would look wrong
next to chunky 4x pixels. But it does mean fractional positions must be accumulated in the
simulation's own `CGFloat` state and only rounded at the point of display, or slow movement will
stall entirely:

```swift
var position: CGPoint          // fractional, owned by the simulation
func present() {
    panel.setFrameOrigin(NSPoint(x: position.x.rounded(), y: position.y.rounded()))
}
```

Keep sprite dimensions and the scale factor **integers** (32 x 4 = 128 points). Non-integral scale
factors are what actually produce uneven pixel blocks.

### Moving between displays with different scale factors

The documented notification is `NSWindowDidChangeBackingPropertiesNotification`:

> `NSWindowDidChangeBackingPropertiesNotification` is posted on 10.7.3 and later, when a window's
> `backingScaleFactor` and/or its `colorSpace` changes. … applications … that manually manage their
> own caches of window-resolution-and/or/colorspace-appropriate bitmapped images will find this
> notification useful, as a prompt to invalidate their caches… The notification's `userInfo`
> dictionary specifies the window's previous `backingScaleFactor` and `colorSpace`.
>
> — `NSWindow.h:956`

For a view, AppKit already funnels this into an override — simpler and less error-prone than
observing the notification:

```swift
override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    let s = window?.backingScaleFactor ?? 2.0
    layer?.contentsScale = s
    sprite.contentsScale = s
}
```

This fires on the move to a display with a different scale factor, and also at first window
attachment — so it doubles as the initial setup. **Do not hardcode 2.0.** The recipient's M3
MacBook is 2x internally, but an external monitor may be 1x, and the bird is draggable.

Note that the map lists multi-display following as out of scope, but *dragging* between displays is
explicitly in scope, which is exactly the case this override handles.

Two supporting points:
- `backingScaleFactor` is `@property (readonly) CGFloat backingScaleFactor API_AVAILABLE(macos(10.7));`
  (`NSWindow.h:488`). The old `userSpaceScaleFactor` is deprecated and its header note says
  "The implementation of this method will always return 1.0" (`NSWindow.h:1003`) — never use it.
- If sprites are pre-scaled into bitmaps rather than left to CoreAnimation, those caches must be
  regenerated here. **Simpler: don't pre-scale.** Hand CoreAnimation the 32x32 `CGImage`, let
  `.nearest` + `contentsScale` do the scaling on the GPU. Then a scale change needs only the two
  assignments above and no cache invalidation at all.

---

## 5. Battery cost

### Headline measurements

Benchmarked on this machine, 2000 iterations each:

```
window.setFrameOrigin                  88.547 ms total,    44.3 us/op
layer.position (implicit anim off)      0.477 ms total,     0.2 us/op
layer.contents swap                     0.378 ms total,     0.2 us/op
```

`setFrameOrigin` is **~200x** more expensive than moving a layer, because each call is a round trip
to the window server, whereas a layer mutation is a local write flushed once per transaction.

**But put it in context: at 10 fps, 44.3 µs/frame is 0.44 ms per second — about 0.04% of one core.**
That is negligible. The 200x ratio sounds alarming and is practically irrelevant at this frame rate.

**Conclusion: move the window directly with `setFrameOrigin`. Do not build a large-transparent-window
+ inner-moving-layer architecture.** The latter is the standard trick for 60 fps window motion, and
it would be premature complexity here — it means a much larger window to composite every frame, a
harder hit-test coordinate mapping, and a window big enough to matter for occlusion. The measured
cost does not justify it. (If a future version wants smooth 60 fps flight, revisit: at 60 fps the
same call is 2.7 ms/s, still small but no longer free.)

### Timer vs CVDisplayLink vs CADisplayLink

**`CVDisplayLink` is deprecated as of macOS 15.0 — precisely the deployment target.** From the
header, identical in both SDKs:

```objc
API_DEPRECATED_BEGIN("use NSView.displayLink(target:selector:), NSWindow.displayLink(target:selector:),
                      or NSScreen.displayLink(target:selector:) ", macos(10.4, 15.0))
```
— `CoreVideo.framework/Headers/CVDisplayLink.h:51`

Apple names the replacement in the deprecation message itself. **Do not use `CVDisplayLink` in new
code for this project** — it would ship deprecated on day one. (It also has a genuine hazard: its
callback arrives on a high-priority *background* thread, requiring a hop to the main thread for any
AppKit work.)

The replacement is on `NSWindow` (macOS 14.0+, so fine for the target):

```objc
API_AVAILABLE(macos(14.0))
@interface NSWindow (NSDisplayLink)
/** Returns a new display link whose callback will be invoked in-sync with the display the window
    is on.  If the window is not on any display the callback will not be invoked. */
- (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)selector
    NS_SWIFT_NAME(displayLink(target:selector:));
@end
```
— `NSWindow.h:818-826`. *Measured*: `displayLink obtainable: true` on this machine.

Two properties of the `NSWindow` variant make it the right choice for a window that wanders:

1. It **follows the window's display automatically** — on a mixed 60 Hz / 120 Hz setup it retimes
   itself when the bird is dragged across.
2. "**If the window is not on any display the callback will not be invoked**" — free suspension.

Comparison for this workload:

| Mechanism | Verdict |
|---|---|
| `Timer` | Simple, but fires on wall-clock time unaligned to the display refresh, causing visible judder as frames land inconsistently relative to vsync. Its saving grace is `tolerance`, which lets the OS coalesce wakeups — genuinely good for battery. Acceptable fallback, not the best choice. |
| `CVDisplayLink` | **Deprecated in macOS 15.** Background-thread callback. Rejected. |
| **`NSWindow.displayLink(target:selector:)` → `CADisplayLink`** | **Recommended.** Main-thread, vsync-aligned, display-following, auto-suspending off-display, and `preferredFrameRateRange` lets the system pick an energy-efficient cadence. |
| `CAKeyframeAnimation` on a layer | **Recommended, in combination** — for the sprite cycle specifically. See below. |

### CAKeyframeAnimation with discrete calculation mode — the cheap sprite cycle

This is the highest-leverage battery trick available here. A sprite flipbook is exactly a
**discrete** keyframe animation over the `contents` property:

```swift
func discreteSpriteAnimation(frames: [CGImage], fps: Double) -> CAKeyframeAnimation {
    let a = CAKeyframeAnimation(keyPath: "contents")
    a.values = frames
    a.calculationMode = .discrete          // kCAAnimationDiscrete — no interpolation between frames
    a.duration = Double(frames.count) / fps
    a.repeatCount = .greatestFiniteMagnitude
    a.isRemovedOnCompletion = false
    return a
}
```

`kCAAnimationDiscrete` is declared at `QuartzCore/CAAnimation.h:240`, alongside `kCAAnimationLinear`
and `kCAAnimationPaced`.

Once installed, this animation runs **in the render server** — the app process is not woken per
frame at all. **Zero CPU in Coco's process while a loop plays.** For long stationary idle loops
(preening, sleeping, the birthday festive idle) this is dramatically cheaper than ticking the app 10
times a second to assign `layer.contents`.

The natural split:

- **Stationary states** (idle, preen, sleep) → install a discrete `CAKeyframeAnimation` and **stop
  the display link entirely**. The bird animates with the app fully idle.
- **Moving states** (walk, fly, drag) → run the display link, because position must be recomputed per
  frame anyway; drive `contents` from the same tick.

Sleep is the big win: a sleeping budgie is a slow two-frame loop that costs the app process nothing.

**Pausing a CoreAnimation loop** is documented in `CAMediaTiming.h:52-59`:

> `@property float speed;` … One use of this is to "pause" a layer by setting `speed` to zero.

```swift
layer.speed = 0     // freeze
layer.speed = 1     // resume
```

### Throttling and suspension

Every hook below is public API and needs no permission.

**App hidden / fully occluded** — `NSApplicationDidChangeOcclusionStateNotification`
(macOS 10.9+, `NSApplication.h:675`), `NSApp.occlusionState` (`NSApplication.h:335`), and per-window
`NSWindowDidChangeOcclusionStateNotification` / `window.occlusionState` (`NSWindow.h:638, 984`):

```swift
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeOcclusionStateNotification, object: nil, queue: .main) { _ in
    let visible = NSApp.occlusionState.contains(.visible)
    driver.isPaused = !visible
}
```

Caveat from the header (`NSWindow.h`): a window counts as visible if its *bounding box* falls in a
visible region, and "Windows that are completely transparent may also still count as visible" — so
for a mostly-transparent panel expect `.visible` most of the time. Treat occlusion as an
opportunistic saving, not a reliable off switch. The explicit `Hide Coco` menu item should call
`orderOut(_:)` and stop the driver outright — that is the dependable path.

**Display sleep** — `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification`
(macOS 10.6+, `NSWorkspace.h:325-326`), on `NSWorkspace.shared.notificationCenter`:

```swift
let wc = NSWorkspace.shared.notificationCenter
wc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
    driver.stop()
}
wc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
    driver.start()
}
```

Also available and worth wiring: `NSWorkspaceWillSleepNotification` / `NSWorkspaceDidWakeNotification`
(system sleep, `NSWorkspace.h:322-323`) and `NSWorkspaceSessionDidResignActiveNotification` /
`SessionDidBecomeActive` (fast user switching, `NSWorkspace.h:329-330`). Stop the driver on
resign/sleep, restart on wake. On wake, **re-read the wall clock** — the simulation must not assume
the elapsed time equals ticks missed. This also matters for the 3-day decay curve and the birthday
check: both must be driven by absolute dates, not tick counts.

**Low Power Mode — yes, there is a supported API, and it works on macOS.**

```swift
ProcessInfo.processInfo.isLowPowerModeEnabled
```

> A Boolean value that indicates the current state of Low Power Mode. … Your app can also register to
> receive notifications when the Low Power Mode state of a device changes. … a notification name of
> `NSProcessInfoPowerStateDidChange`. When your app receives a notification of a power state change,
> query `isLowPowerModeEnabled` to determine the current power state. If Low Power Mode is active,
> take appropriate steps to reduce activity in your app.
>
> — https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled
>   (availability: **macOS 12.0+**, iOS 9.0+)

*Measured*: reads without error on this machine, returning `false`.

```swift
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
    driver.fps = ProcessInfo.processInfo.isLowPowerModeEnabled ? 6 : 10
}
```

⚠️ **Important distinction: this detects Low Power Mode, not "on battery".** It is `true` only when
the user has explicitly enabled Low Power Mode in System Settings > Battery. A laptop merely running
unplugged reports `false`. There is no equally clean, permission-free AppKit/Foundation property for
"currently on battery" — that requires IOKit power-source APIs
(`IOPSCopyPowerSourcesInfo` in `IOKit.ps`), which are public and permission-free but a noticeably
clunkier C API.

**Recommendation: respond to Low Power Mode only, and do not implement battery detection.** Low Power
Mode is the user's explicit signal that they want background activity reduced, and honouring it is
both correct and sufficient. Reacting to mere unplugging risks the bird visibly changing behaviour
for no reason the recipient understands. Given the 8-day deadline, IOKit power sources are not worth
the schedule.

**Bird asleep** — the largest saving, and it is behavioural rather than API-driven. When Coco sleeps
(low Energy, or ~15 minutes idle): stop the display link, install a slow discrete keyframe loop, and
let the simulation tick from a coarse `Timer` with a generous `tolerance`:

```swift
let t = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in sim.step() }
t.tolerance = 2.0     // lets the OS coalesce this wakeup with others — real battery saving
```

`Timer.tolerance` is the supported way to tell the OS a wakeup is not urgent, letting it batch
timer fires and stay in low-power states longer. Use it on every non-animation timer in the app.

For detecting user idle without permissions: `CGEventSource.secondsSinceLastEventType(_:eventType:)`
with `.combinedSessionState` and `.null` gives system-wide idle time and requires **no Accessibility
permission** (it reads an aggregate counter, not event content). ⚠️ *I did not verify this
permission claim empirically in this session* — worth a five-minute check at the first build, since
the 15-minute-idle sleep rule depends on it.

### Recommended render/animation loop architecture

A single state machine with two modes, chosen by whether the bird is moving:

```
                    ┌─────────────── STATIONARY ────────────────┐
                    │ display link: STOPPED                     │
                    │ sprite: CAKeyframeAnimation .discrete      │
                    │         (runs in render server, 0% app CPU)│
                    │ sim:    Timer 1-5 s, large tolerance       │
                    └───────────────────────────────────────────┘
                             ▲                    │
             reaches target  │                    │ decides to move
             / starts idling │                    ▼
                    ┌─────────────── MOVING ────────────────────┐
                    │ display link: RUNNING, throttled to ~10fps │
                    │ per tick:                                  │
                    │   1. accumulate dt, skip if < 1/fps        │
                    │   2. sim.step(dt)  -> fractional position   │
                    │   3. sprite.contents = frames[i]           │
                    │   4. panel.setFrameOrigin(rounded position) │
                    │   5. updateMousePassthrough()              │
                    └───────────────────────────────────────────┘

  Suspend both modes on: Hide Coco · screens asleep · system sleep · session resigned
  Throttle fps on:       NSProcessInfoPowerStateDidChange (Low Power Mode) -> 6 fps
```

Folding the hit-test update (step 5) into the existing tick is what makes section 3 free.

The display link is throttled with an accumulator rather than by asking for a 10 Hz link, because
`preferredFrameRateRange` is a hint the system may not honour exactly, and the accumulator guarantees
the sprite cadence regardless of whether the display is 60 Hz or 120 Hz:

```swift
@objc private func tick(_ l: CADisplayLink) {
    let now = l.timestamp
    let dt = now - last; last = now
    accum += dt
    let step = 1.0 / fps
    guard accum >= step else { return }
    accum = accum.truncatingRemainder(dividingBy: step)
    // advance sprite frame, step simulation, move window, update passthrough
}
```

Setting `preferredFrameRateRange` as well lets the OS reduce its own wakeups on a ProMotion display:

```swift
l.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 12, preferred: 10)
```

`CAFrameRateRange` is `API_AVAILABLE(macos(12.0))` (`QuartzCore/CAFrameRateRange.h:16`), and
`CADisplayLink.preferredFrameRateRange` exists on the macOS 14+ class. Both fine on the target.

**Expected cost.** At 10 fps the per-frame work is one window move (44 µs), one layer contents
assignment (0.2 µs), one mask lookup (0.5 ns) and the simulation step. That is well under
**0.5 ms of CPU per second — roughly 0.05% of one core** — plus compositing of a 128x128 window,
which the GPU handles as a trivially small quad. In the stationary state the app process does
essentially nothing at all. This is an unmeasurable load on an M3 battery.

---

## Recommended configuration

### The panel

```swift
import AppKit

final class CocoPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        // ORDER MATTERS: isFloatingPanel forces level to .floating (3), which is
        // BELOW the Dock (20). Set it first, then set the real level.
        isFloatingPanel = true
        level = .statusBar                      // 25: above Dock (20) and menu bar (24)

        collectionBehavior = [.canJoinAllSpaces,     // every Space
                              .fullScreenAuxiliary,  // alongside full-screen windows
                              .stationary,           // unaffected by Mission Control
                              .ignoresCycle]         // out of Cmd-Tab
        if #available(macOS 13.0, *) {
            collectionBehavior.insert(.canJoinAllApplications)  // other apps' full-screen spaces
        }

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovableByWindowBackground = false      // dragging is driven by our own mouse handling
        isReleasedWhenClosed = false
    }
}
```

Show it with **`panel.orderFrontRegardless()`** — never `makeKeyAndOrderFront(_:)`.

At startup, and in `Info.plist`:

```swift
NSApplication.shared.setActivationPolicy(.accessory)   // plus LSUIElement = 1 in Info.plist
```

### The sprite view

```swift
final class SpriteView: NSView {
    let sprite = CALayer()

    init(spriteSize: NSSize, scale: CGFloat) {          // 32x32, scale 4 -> 128x128 points
        super.init(frame: NSRect(origin: .zero,
                                 size: NSSize(width: spriteSize.width * scale,
                                              height: spriteSize.height * scale)))
        wantsLayer = true
        layer?.addSublayer(sprite)
        sprite.frame = bounds
        sprite.magnificationFilter = .nearest
        sprite.minificationFilter  = .nearest
        sprite.contentsGravity = .resize
        sprite.allowsEdgeAntialiasing = false
        sprite.isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let s = window?.backingScaleFactor ?? 2.0
        layer?.contentsScale = s
        sprite.contentsScale = s
    }
}
```

Assign frames as `CGImage` directly (`sprite.contents = frame`) — never pre-scale bitmaps; let
`.nearest` plus `contentsScale` do the work on the GPU, so a display change needs no cache
invalidation.

Mirror facing with a transform rather than a second sprite sheet (per the locked constraint):

```swift
sprite.transform = facingLeft ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
```

### The driver

```swift
final class Driver {
    private var link: CADisplayLink?
    private weak var panel: NSWindow?
    private var accum: CFTimeInterval = 0
    private var last: CFTimeInterval = 0
    var fps: Double = 10

    init(panel: NSWindow) { self.panel = panel }

    func start() {
        guard link == nil, let w = panel else { return }
        let l = w.displayLink(target: self, selector: #selector(tick(_:)))   // macOS 14+
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 12, preferred: 10)
        l.add(to: .main, forMode: .common)
        link = l
        last = CACurrentMediaTime()
    }

    func stop() { link?.invalidate(); link = nil }

    var isPaused: Bool {
        get { link?.isPaused ?? true }
        set { link?.isPaused = newValue }
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = now - last; last = now
        accum += dt
        let step = 1.0 / fps
        guard accum >= step else { return }
        accum = accum.truncatingRemainder(dividingBy: step)
        // 1. sim.step(dt)  2. sprite.contents  3. setFrameOrigin(rounded)  4. passthrough
    }
}
```

Run this **only while moving**. When stationary, `stop()` it and install a discrete
`CAKeyframeAnimation` so the loop plays in the render server at zero app CPU.

### Summary of decisions

| Question | Answer |
|---|---|
| `NSPanel` or `NSWindow`? | **`NSPanel`** — `.nonactivatingPanel` is `NSPanel`-only |
| Window level | **`.statusBar` (25)** — `.floating` (3) is below the Dock (20) |
| Ordering hazard | **`isFloatingPanel` before `level`** — it forces level to 3 |
| Collection behaviour | `.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .canJoinAllApplications` |
| Over other apps' full screen | Documented as achievable, no permissions — **but unverified; treat as best-effort** |
| Focus | `.nonactivatingPanel` + `canBecomeKey/Main = false` + `.accessory` + `orderFrontRegardless()` |
| Mouse events on a non-activating panel | **Yes** — key status gates keyboard, not mouse |
| Click-through | **`window.ignoresMouseEvents`, toggled from a cursor poll in the existing tick.** `hitTest` cannot pass clicks to other apps |
| Hit mask | Precomputed 1-bit-per-pixel mask, 128 B/frame, 0.5 ns/lookup |
| Nearest-neighbour | `magnificationFilter = .nearest` + `contentsScale` (or `imageInterpolation = .none`) — **never the default** |
| Half-pixel offsets | Not a real risk — `NSWindow` snaps origins to whole points |
| Display change | `viewDidChangeBackingProperties()` |
| Animation clock | **`NSWindow.displayLink(target:selector:)`** — `CVDisplayLink` is **deprecated in macOS 15** |
| Stationary loops | `CAKeyframeAnimation` + `.discrete`, display link stopped — 0% app CPU |
| Window movement | `setFrameOrigin` directly — 44 µs is negligible at 10 fps |
| Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` + `.NSProcessInfoPowerStateDidChange` (macOS 12+) |
| "On battery" | **No clean API; deliberately not implemented** |
| Permissions required | **None** |

---

## Open items and confidence

**High confidence (empirically measured on this machine):** all window level numbers; the
`isFloatingPanel`/`level` ordering hazard; the panel reaching layer 25 above the menu bar;
`.none` vs `.default` interpolation behaviour; window origin snapping to whole points; the
`setFrameOrigin` vs layer-move cost ratio; mask size and lookup cost; `NSEvent.mouseLocation`
requiring no permission; the reference implementation compiling for the macOS 15 target.

**High confidence (unambiguous primary-source text):** `CVDisplayLink`'s macOS 15 deprecation and its
named replacement; `magnificationFilter` defaulting to `linear`; `contentsScale` semantics;
`isLowPowerModeEnabled` on macOS 12+; hitTest's documented intra-window scope; collection-behaviour
mutual-exclusion groups; the API-level stability of `NSWindow.h`/`NSPanel.h` from 15 to 26.

**Flagged as NOT established:**

1. **Rendering over another app's full-screen space was not visually verified.** Documented by Apple
   as supported without entitlements, but Apple's "when eligible" is undefined and WWDC never
   demonstrated it. **Test this manually at the first running build.** If it fails, drop the
   requirement — everything else in this configuration is unaffected.
2. **Mouse delivery to a non-activating panel was not click-tested.** Not synthesised, to avoid
   triggering an Accessibility prompt. Low risk; confirm by clicking the bird while a caret blinks
   elsewhere.
3. **`CGEventSource.secondsSinceLastEventType` needing no Accessibility permission was not verified.**
   The 15-minute-idle sleep rule depends on it; check early.
4. **Nothing here was tested on macOS 15 itself** — only macOS 26, with a macOS 15 compile check. The
   header diff makes divergence unlikely but cannot rule it out, and per the map the target OS cannot
   be tested locally.
