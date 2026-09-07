# 02 — Shipping an ad-hoc-signed .app to macOS 15 from a CLT-only toolchain

Research output for [issue 02](../issues/02-shipping-adhoc-app.md). Researched 2026-09-06.

**Dev machine as tested:** macOS 26.5.2 (build 25F84), arm64, Command Line Tools only
(`/Library/Developer/CommandLineTools`), Apple Swift 6.3.3, default target
`arm64-apple-macosx26.0`, `security find-identity -v -p codesigning` → **0 valid identities**.
Xcode absent (`xcodebuild` errors out: "requires Xcode, but active developer directory is a
command line tools instance").

Claims below marked **[verified]** were executed on this machine during the research. Claims
marked **[doc]** come from the cited primary source. Claims marked **[unverified]** could not be
established with confidence — see the "What I could not establish" section.

> **Headline finding (read this first):** the macOS **15.4 SDK is already installed** on the dev
> machine alongside the 26.5 SDK. Building with `SDKROOT=…/MacOSX15.4.sdk` makes macOS 26 API
> *non-existent* rather than merely *unavailable*, which closes the single biggest risk in this
> ticket. See §2.
>
> **Second headline finding:** using SwiftPM's `resources:` / `Bundle.module` in a hand-assembled
> `.app` produces a binary that **works on the dev machine and hard-crashes on the recipient's
> Mac**. See §1.4. This is the most dangerous trap in the whole delivery path.

---

## 1. Bundle assembly

### 1.1 Directory layout

A minimal, valid, signable macOS app bundle:

```
Coco.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── Coco                  ← the SwiftPM executable, renamed to match CFBundleExecutable
    ├── Resources/
    │   ├── Coco.icns
    │   └── Sprites/
    │       ├── idle_0.png
    │       └── …
    └── _CodeSignature/           ← created by codesign, do not author by hand
        └── CodeResources
```

**[verified]** This exact layout, assembled by hand with `mkdir`/`cp`, produced a bundle that
`plutil -lint` accepts, that `codesign -s -` signs, and that `codesign --verify --strict
--verbose=4` reports as `valid on disk` / `satisfies its Designated Requirement`.

`Contents/MacOS` and `Contents/Info.plist` are the only mandatory parts;
`Contents/Resources` is conventional and is what `Bundle.main.resourceURL` points at
**[verified]** — a run of the test app printed
`resourceURL = …/Test.app/Contents/Resources`.

Bundle structure reference:
<https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html>

### 1.2 Info.plist keys

Minimum viable `Info.plist` for Coco (XML plist, `plutil -lint`-clean **[verified]**):

| Key | Value | Why |
|---|---|---|
| `CFBundleIdentifier` | `com.paologiua.coco` | Reverse-DNS, alphanumerics/hyphens/periods only. Identifies the app system-wide **and validates the app's signature**. [doc] |
| `CFBundleExecutable` | `Coco` | Must exactly match the filename in `Contents/MacOS/`. |
| `CFBundleName` | `Coco` | Short display name (≤15 chars recommended). |
| `CFBundleDisplayName` | `Coco` | Name shown to the user in Finder/Login Items. |
| `CFBundleVersion` | `1` | Build number, monotonically increasing. |
| `CFBundleShortVersionString` | `1.0` | User-visible version. |
| `CFBundlePackageType` | `APPL` | "For apps, the code is `APPL`… The default value is derived from the bundle extension or, if it can't be derived, the default value is `BNDL`." [doc] Set it explicitly. |
| `CFBundleInfoDictionaryVersion` | `6.0` | Conventional. |
| `LSUIElement` | `<true/>` | "A Boolean value indicating whether the app is an agent app that runs in the background and doesn't appear in the Dock." [doc] — exactly Coco's menubar-only requirement. |
| `LSMinimumSystemVersion` | `15.0` | "The minimum version of the operating system required for the app to run in macOS." [doc] |
| `CFBundleIconFile` | `Coco` | Filename of the `.icns` in `Contents/Resources`; the `.icns` extension may be omitted. |
| `NSHighResolutionCapable` | `<true/>` | "A Boolean value indicating whether the Cocoa app supports high-resolution displays." [doc] Needed so Coco gets a 2x backing store on the M3's Retina panel; the 4x nearest-neighbour scaling is then done in code via `NSImageInterpolation.none`. Without it the OS upscales a 1x buffer and the pixel art turns to mush. |

Sources (Apple `Information Property List` reference):
- `LSUIElement` — <https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement>
- `LSMinimumSystemVersion` — <https://developer.apple.com/documentation/bundleresources/information-property-list/lsminimumsystemversion>
- `CFBundlePackageType` — <https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlepackagetype>
- `CFBundleIdentifier` — <https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleidentifier>
- `NSHighResolutionCapable` — <https://developer.apple.com/documentation/bundleresources/information-property-list/nshighresolutioncapable>

Notes:
- `LSUIElement` is documented as a Boolean. The historical string form `<string>1</string>` also
  works; prefer `<true/>`.
- **No `NSPrincipalClass` / nib is required.** A SwiftPM executable that creates
  `NSApplication.shared`, sets a delegate and calls `NSApp.run()` works fine. With
  `LSUIElement` set you do not additionally need `setActivationPolicy(.accessory)`, though calling
  it is harmless and makes the intent explicit in code.
- macOS 15 vs 26: no difference in any of these keys.

### 1.3 Producing the `.icns` without Xcode

**[verified] `iconutil` ships with the Command Line Tools** — it is at `/usr/bin/iconutil`
(root:wheel, 136464 bytes) on this Xcode-free machine, and `man iconutil` resolves. Its man page
lists `FILES: /usr/bin/iconutil`. `sips` (`/usr/bin/sips`) is likewise present.

**[verified]** end-to-end, no Xcode: `sips` was used to emit the ten required PNGs into a
`.iconset` directory and `iconutil -c icns Coco.iconset -o Coco.icns` produced a valid `.icns`.

Required `.iconset` member filenames (this naming is what `iconutil` keys off):

```
icon_16x16.png      icon_16x16@2x.png     (16, 32)
icon_32x32.png      icon_32x32@2x.png     (32, 64)
icon_128x128.png    icon_128x128@2x.png   (128, 256)
icon_256x256.png    icon_256x256@2x.png   (256, 512)
icon_512x512.png    icon_512x512@2x.png   (512, 1024)
```

```sh
mkdir Coco.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s          master_1024.png --out Coco.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) master_1024.png --out Coco.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns Coco.iconset -o Coco.icns
```

`iconutil` man page: `man 1 iconutil` (local, CLT). Apple icon-size guidance:
<https://developer.apple.com/design/human-interface-guidelines/app-icons>

**Pixel-art caveat:** `sips -z` resamples with smoothing. For a pixel-art budgie, generate each
size with nearest-neighbour from the source art rather than letting `sips` interpolate down from
1024, or the small icons will be blurry. `sips` has no nearest-neighbour flag — do the downscale
in the art pipeline (ticket 01) and feed `sips` only for format conversion, or write the PNGs
directly.

### 1.4 How the app finds its PNG sprites at runtime — **the big trap**

**Do not use SwiftPM's `resources:` declaration and `Bundle.module` for this app.**

SwiftPM generates a `resource_bundle_accessor.swift` whose logic is **[verified]** (read from
`.build/.../resource_bundle_accessor.swift`):

```swift
extension Foundation.Bundle {
    static nonisolated let module: Bundle = {
        let mainPath  = Bundle.main.bundleURL.appendingPathComponent("Coco_restest.bundle").path
        let buildPath = "/…absolute dev-machine path…/.build/arm64-apple-macosx/debug/Coco_restest.bundle"
        let preferredBundle = Bundle(path: mainPath)
        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }
        return bundle
    }()
}
```

Why this is fatal for a hand-assembled `.app`:

1. For an app bundle, `Bundle.main.bundleURL` is **`Coco.app` itself**, not
   `Coco.app/Contents/Resources`. So `mainPath` resolves to `Coco.app/Coco_restest.bundle` — a
   path that does not exist in a correctly-formed bundle. **[verified]** — placing the resource
   bundle in `Contents/Resources` (the Xcode-conventional location) did **not** satisfy it.
2. It then falls back to a **hard-coded absolute path into the developer's `.build` directory**.
   On the dev machine that path exists, so everything appears to work. **[verified]** — the test
   app happily printed
   `module bundlePath: /tmp/…/restest/.build/arm64-apple-macosx/debug/Coco_restest.bundle`.
3. On any other machine that path does not exist and the app **crashes on launch**.
   **[verified]** — with the `.build` directory renamed to simulate the recipient's Mac:

   ```
   resource_bundle_accessor.swift:12: Fatal error: could not load resource bundle:
   from /…/Test.app/Coco_restest.bundle
   or   /…/restest/.build/arm64-apple-macosx/debug/Coco_restest.bundle
   ```

4. The only placement that satisfies `Bundle.module` is `Coco.app/Coco_restest.bundle` — i.e.
   a sibling of `Contents/` at the bundle root — and **that breaks code signing**.
   **[verified]**: `codesign -s - --force Bad.app` →
   `Bad.app: unsealed contents present in the bundle root`, and `codesign --verify` fails the same
   way. So the workaround is unusable.

This is precisely the class of defect the ticket worries about: **invisible on the dev machine,
fatal on the target machine.**

**Do this instead.** Keep sprites out of the SwiftPM manifest entirely, copy them into
`Contents/Resources/Sprites/` in the build script, and read them via `Bundle.main`:

```swift
// works in the hand-assembled .app
let url = Bundle.main.url(forResource: "idle_0", withExtension: "png", subdirectory: "Sprites")
```

**[verified]** — with `Contents/Resources/Sprites/idle_0.png` present, this returned
`…/Test.app/Contents/Resources/Sprites/idle_0.png`. The flat form
(`Bundle.main.url(forResource:withExtension:)`, no `subdirectory:`) also works for files placed
directly in `Contents/Resources`, but does **not** search subdirectories — **[verified]**, it
returned `NOT FOUND` for a file that was one level down. Pass `subdirectory:` if you nest.

`NSImage(named:)` is *not* a good fit here: it consults the asset catalog and the
`Contents/Resources` root by name and its caching semantics get in the way of frame-by-frame
animation. Prefer explicit `Bundle.main.url(forResource:…)` + `NSImage(contentsOf:)`, loaded once
into an in-memory frame array at launch.

`Bundle` reference: <https://developer.apple.com/documentation/foundation/bundle>

---

## 2. Deployment target

### 2.1 The build invocation

Declare the platform in `Package.swift`:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Coco",
    platforms: [.macOS(.v15)],
    targets: [.executableTarget(name: "Coco")]
)
```

**[verified]** With `platforms: [.macOS(.v15)]`, `swift build` stamps the Mach-O correctly:

```
$ vtool -show-build-version .build/arm64-apple-macosx/debug/Coco
 platform MACOS
    minos 15.0
      sdk 26.5
```

**[verified]** Without any `platforms:` line, SwiftPM's default for macOS is **`minos 11.0`**, not
26.0 — so the default is already conservative. Declare `.v15` anyway so the intent is explicit and
matches `LSMinimumSystemVersion`.

**[verified]** `swift build -Xswiftc -target -Xswiftc arm64-apple-macos15.0` also constrains the
compiler, but `platforms:` is the correct mechanism — it is what SwiftPM feeds to *both* the
compiler and the linker, and it participates in dependency resolution. Use `platforms:`.

`platforms` reference:
<https://developer.apple.com/documentation/packagedescription/package/platforms>

### 2.2 Does the compiler ERROR on macOS 26-only API at a 15.0 target? — **Yes.**

This was the critical question. **[verified]** — real compile against the 26.5 SDK with
`platforms: [.macOS(.v15)]`, using `NSGlassEffectView` (an AppKit class marked
`API_AVAILABLE(macos(26.0))` in the local SDK headers):

```
error: 'NSGlassEffectView' is only available in macOS 26.0 or newer
  |         |- error: 'NSGlassEffectView' is only available in macOS 26.0 or newer
  |         `- note: add 'if #available' version check
```

The build **fails**. It is a hard error, not a warning. **[verified]** the same error appears with
no `platforms:` declaration at all (default `minos 11.0`), and with the explicit
`-target arm64-apple-macos15.0` flag.

**So macOS 26 API cannot silently slip through to a runtime crash via the normal path.** Swift's
availability checking is mandatory and enforced at the declared deployment target. This is a
genuine, load-bearing safety net — considerably stronger than the ticket assumed.

### 2.3 The `@available` / `#available` rules

- Every declaration in an Apple SDK carries an introduced-in version
  (`API_AVAILABLE(macos(26.0))` in the ObjC headers → `@available(macOS 26.0, *)` in Swift).
- Referencing such a declaration from a context whose *minimum* deployment target is lower is a
  **compile error**, as shown above.
- Two ways to satisfy the checker:
  - **`if #available(macOS 26.0, *) { … } else { … }`** — a runtime branch. Inside the `if` body
    the effective deployment target is raised to 26.0, so the new API is legal there; the `else`
    branch must work on 15.0. **[verified]** this compiles cleanly at a 15.0 target.
  - **`@available(macOS 26.0, *)`** on your own function/type — this *propagates* the requirement
    to callers rather than resolving it. Callers must themselves be `@available(macOS 26.0, *)` or
    be inside an `if #available`. This does not create a hole; it moves the check up the call
    chain, and the chain must terminate in an `#available` test.
- The `, *` is required and means "all other platforms": it is what lets the same source compile
  for other Apple platforms.

Reference: *The Swift Programming Language* — Attributes (`available`) and Statements
(`#available`):
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/>
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/>

### 2.4 Where the safety net does NOT protect you

Availability checking covers *symbol references*. It does not cover:

1. **Stringly-typed lookups.** `NSImage(systemSymbolName:accessibilityDescription:)` with an SF
   Symbol name introduced after macOS 15 returns **nil** on the target — no compile error, no
   crash, just a **blank menubar icon**. This is a live risk for Coco's mood-varying template
   silhouette. *Mitigation: ship your own template PNGs in `Contents/Resources` rather than SF
   Symbols, or `guard let` every symbol lookup with a fallback.* Same hazard applies to
   `NSImage(named:)`, `Notification.Name`, and `UserDefaults` keys.
2. **Objective-C runtime lookup** — `NSClassFromString`, `NSSelectorFromString`,
   `responds(to:)`, `perform(_:)`. Invisible to the checker by construction. Avoid.
3. **`Info.plist` keys only honoured on newer systems.** An unrecognised key is silently ignored
   on macOS 15 — the behaviour just doesn't happen.
4. **Behaviour changes in APIs that exist on both versions.** This is the residual risk that
   *cannot* be compiled away. macOS 26 introduced the "Liquid Glass" redesign, which changes the
   metrics, materials and default appearance of `NSPanel`, `NSStatusItem`, `NSMenu` and window
   shadows. Coco's non-activating `NSPanel` and menubar UI will **look different** on macOS 15
   than on the dev machine, and layout that is pixel-tuned on macOS 26 may be misaligned on 15.
   No tool catches this. See "Risks that only surface on the target machine".
5. **Apple's own annotation bugs.** Occasionally an SDK declaration is missing or has a wrong
   availability annotation. Rare, but it is the one way a genuine symbol reference can slip
   through.

### 2.5 Static verification against macOS 15 without a macOS 15 machine

Three levels, strongest first.

**Level 1 — build against the macOS 15 SDK. This is the real answer, and it is available now.**

**[verified]** The Command Line Tools on this machine **already ship the macOS 15.4 SDK**
side-by-side with 26.5:

```
$ ls -la /Library/Developer/CommandLineTools/SDKs/
MacOSX.sdk      -> MacOSX26.5.sdk
MacOSX15.sdk    -> MacOSX15.4.sdk
MacOSX15.4.sdk
MacOSX26.5.sdk
MacOSX26.sdk    -> MacOSX26.5.sdk
```

Building against it makes macOS 26 API **not exist**, rather than merely being unavailable —
a strictly stronger guarantee, and it also removes hazards (1) and (5) above for symbol-shaped
API. **[verified]**:

```
$ SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk swift build -c release
error: cannot find 'NSGlassEffectView' in scope
```

Note the message: **"cannot find … in scope"**, not "is only available in". The header
`NSGlassEffectView.h` is simply absent from the 15.4 SDK **[verified]**.

And the resulting binary is stamped cleanly **[verified]**:

```
$ SDKROOT=…/MacOSX15.4.sdk swift build -c release
$ vtool -show-build-version .build/arm64-apple-macosx/release/Coco
 platform MACOS
    minos 15.0
      sdk 15.4
```

(Passing `--sdk` to `swift build` instead of using `SDKROOT` compiles against 15.4 but still
records `sdk 26.5` in `LC_BUILD_VERSION`, because the link step keeps the default sysroot
**[verified]**. Prefer the `SDKROOT` environment variable — it produces the clean `sdk 15.4`
stamp.)

**This should be the project's standard build invocation.** It converts the deployment-target
question from "will I remember to be careful" into "it will not compile".

**Level 2 — verify the produced Mach-O.**

```sh
vtool -show-build-version Coco.app/Contents/MacOS/Coco   # expect: minos 15.0, sdk 15.4
otool -l  Coco.app/Contents/MacOS/Coco | grep -A4 LC_BUILD_VERSION
otool -L  Coco.app/Contents/MacOS/Coco                   # linked libs; nothing exotic
lipo -archs Coco.app/Contents/MacOS/Coco                 # expect: arm64
```

**[verified]** all four run under CLT-only and give the expected output. `otool -L` on the
15.4-SDK build showed only `libSystem`, `AppKit`, `Foundation`, `libobjc` and the Swift runtime
dylibs — all present on macOS 15.

**Level 3 — audit the undefined-symbol list.**

`nm -mu Coco.app/Contents/MacOS/Coco` lists every symbol the binary expects the OS to provide.
Symbols marked `(weak)` are weak-linked and will be `nil` at runtime on an older OS rather than
causing a launch failure; non-weak undefined symbols that macOS 15 lacks would abort the process
at `dyld` time with `Symbol not found`. Cross-checking that list against the 15.4 SDK's `.tbd`
stubs (`MacOSX15.4.sdk/System/Library/Frameworks/*.framework/*.tbd`) is possible but fiddly;
**Level 1 makes it unnecessary** and is the recommended route. Marked **[unverified]** as a
routine — I did not build a full symbol-diff script.

There is **no supported way to run macOS 15 code paths on a macOS 26 machine.** No simulator
exists for macOS, and Apple ships no macOS-15 VM image usable from a macOS 26 host under CLT
alone. The Level 1 SDK pin is the closest available substitute.

---

## 3. Signing and Gatekeeper

### 3.1 arm64 requires a signature at all times

On Apple Silicon every executable must carry at least an ad-hoc signature or the kernel refuses to
run it; the linker applies one automatically. **[verified]** — a `swift build` output that had
never been touched by `codesign` still reported
`Identifier=smtest-5555494488b43bf4b84e3287a7d5b8779514b47e`, a linker-generated ad-hoc identity.
So "unsigned" is not actually reachable on this hardware; the question is only whether the
*bundle* is signed.

### 3.2 The signing command

```sh
codesign --force --sign - --identifier com.paologiua.coco Coco.app
```

**[verified]** this succeeds with **zero identities in the keychain** — ad-hoc signing needs no
certificate. Result:

```
$ codesign -dvvv Coco.app
Identifier=com.paologiua.coco
CodeDirectory v=20400 … flags=0x2(adhoc) …
Signature=adhoc
TeamIdentifier=not set
Sealed Resources version=2 rules=13 files=3

$ codesign --verify --strict --verbose=4 Coco.app
Coco.app: valid on disk
Coco.app: satisfies its Designated Requirement
```

So an ad-hoc signature **is a valid code signature** in `codesign`'s terms. It simply carries no
identity: `TeamIdentifier=not set`, `Signature=adhoc`. This distinction matters for §4.

`codesign` man page (local): `man 1 codesign`. Apple overview:
<https://developer.apple.com/documentation/security/code-signing-services>

### 3.3 `--deep` — do not use it

**[verified]** from the local `man codesign` on macOS 26:

> `--deep` **(DEPRECATED for signing as of macOS 13.0)** When signing a bundle, specifies that
> nested code content such as helpers, frameworks, and plug-ins, should be recursively signed in
> turn.
> Beware:
> • All signing options will be applied, in turn, to all nested content. **This is almost never
>   what you want.**

Deprecated since macOS 13, and actively harmful because it blanket-applies your options
(entitlements, hardened-runtime flags) to every nested item. The supported approach is
**inside-out signing**: sign each nested code item individually, innermost first, then the
outer bundle last.

**Coco has no nested code** — a single executable, PNGs and an `.icns`. So there is nothing to
sign inside-out and `--deep` is simply unnecessary. **Omit it.**

### 3.4 Hardened runtime and entitlements — not needed

**[verified]** hardened runtime *can* be combined with ad-hoc signing —
`codesign -s - -o runtime Coco.app` yields `flags=0x10002(adhoc,runtime)`. But it buys nothing
here:

- The hardened runtime is a **prerequisite for notarization**, not for local execution. With no
  Apple Developer Program membership there is no notarization, so there is no reason to opt in.
- It enables **library validation**, which restricts what can be loaded into the process — a way
  to create problems, not solve them.

**Recommendation: sign without `-o runtime` and without an entitlements file.**

Coco needs **no entitlements**: it is not sandboxed, and per the map it uses no Accessibility and
no Screen Recording, so it trips no TCC-gated API. An unsandboxed, unentitled app can freely
read/write `~/Library/Application Support/Coco/`.

One thing to watch: **[verified]** SwiftPM auto-generates
`.build/…/Coco-entitlement.plist` containing `com.apple.security.get-task-allow` (the
debugger-attach entitlement) and applies it to *debug* builds. Signing the assembled bundle with
`codesign -s -` **without** `--entitlements` replaces that signature and drops the entitlement.
Building with `-c release` avoids it in the first place. Do both.

Notarization requirements (for context on why hardened runtime exists):
<https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>

### 3.5 What Gatekeeper does with this app

**[verified]** on macOS 26:

```
$ spctl --status
assessments enabled

$ spctl -a -t exec -vvv Coco.app
Coco.app: rejected
```

The assessment verdict is `false` with no authority. **This is expected and unavoidable.**
Gatekeeper approves software that is *notarized* (or Developer ID-signed and known-good); an
ad-hoc signature carries no identity for it to evaluate. There is no flag, plist key or
configuration that makes an ad-hoc app pass `spctl`. **[verified]** the rejection is identical
with and without a quarantine attribute present — `spctl` assesses policy, not quarantine.

Apple Platform Security, "Gatekeeper and runtime protection":
<https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web>
> "Gatekeeper … is designed to help ensure that only trusted software runs on a user's Mac."
> "By default, all software in macOS is checked for known malicious content the first time it's
> opened, regardless of how it arrived on the Mac."
> "Users can override Gatekeeper policies to open any software unless restricted by a device
> management service."

That last sentence is the escape hatch this delivery depends on.

### 3.6 Does quarantine even apply to a hand-copied app?

`com.apple.quarantine` is an extended attribute applied **by the receiving application**, not by
the filesystem. It is opt-in on the part of the transport. Consequences:

| Transport | Quarantined? |
|---|---|
| **AirDrop** | **YES** — macOS attaches a quarantine flag to everything transferred by AirDrop. |
| Safari / any browser download | Yes |
| Mail attachment, Messages | Yes |
| **USB stick / external drive** | **No** |
| SMB/AFP network share | No |
| `scp` / `rsync` / `curl` from Terminal | No |
| `cp` / `ditto` from an already-quarantined source | **Inherits** — the xattr is copied |

**[verified]** locally: a file carrying `com.apple.quarantine` retained the attribute through both
`cp` and `ditto`. So quarantine propagates on copy — if the `.app` ever touches AirDrop it stays
quarantined even after being dragged to `/Applications`.

**[verified]** the quarantine xattr does **not** invalidate the code signature —
`codesign --verify --strict` still passed with the attribute set.

Primary-ish sources (Apple does not document the transport list directly; these are the best
available, from Howard Oakley's long-running analysis of the subsystem):
- <https://eclecticlight.co/2021/12/11/explainer-quarantine/>
- <https://eclecticlight.co/2019/10/24/airdrop-and-quarantine-flags/> — AirDrop specifically
- Apple's `LSFileQuarantineEnabled` documentation confirms the opt-in, per-app model:
  <https://developer.apple.com/documentation/bundleresources/information-property-list/lsfilequarantineenabled>

**Practical consequence: transfer Coco by USB stick, not AirDrop.** A USB transfer sets no
quarantine attribute, and the first-open Gatekeeper prompt described below **does not appear at
all**. This is by far the smoothest path and it is the one to plan for.

### 3.7 First open on macOS 15 when the app *is* quarantined

macOS 15 Sequoia **removed the Control-click → Open workaround.** Apple's own announcement,
"Updates to runtime protection in macOS Sequoia":
<https://developer.apple.com/news/?id=saqachfa>

> "In macOS Sequoia, users will no longer be able to Control-click to override Gatekeeper when
> opening software that isn't signed correctly or notarized. They'll need to visit System
> Settings > Privacy & Security to review security information for software before allowing it to
> run."

The exact click path on **macOS 15**, from Apple Support "Open a Mac app from an unidentified
developer"
(<https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac>):

1. Double-click `Coco.app`. It is blocked, with a dialog along the lines of *"Apple could not
   verify "Coco" is free of malware that may harm your Mac or compromise your privacy."* Click
   **Done**. **This step is required** — the override only becomes available *after* a blocked
   launch attempt.
2. **Apple menu → System Settings → Privacy & Security** (in the sidebar).
3. Scroll down to **Security**. A line reads *"Coco" was blocked to protect your Mac.*
4. Click **Open Anyway**.
5. Enter the login password (Touch ID / admin authentication), click **OK**.
6. Click **Open** in the confirming dialog.

Two details worth knowing, both from that Apple Support page:
- **The "Open Anyway" button is only available for about an hour after you try to open the app.**
  If the user waits too long between steps 1 and 3, they must double-click the app again to
  re-arm it. This trips people up constantly — call it out in the install instructions.
- This is a **one-time** approval per app version. Subsequent launches do not prompt. But because
  the approval is recorded against the app's code identity, **re-signing or rebuilding the app
  invalidates it** and the user must approve again.

**macOS 26 is the same in substance** — the Sequoia change persists, the Settings pane is in the
same place, and the same "Open Anyway" affordance appears. The wording of the blocking dialog has
been tweaked across releases. There is no macOS 26 behaviour here that would mislead you about
macOS 15, **except** that on macOS 26 the pane is titled *Privacy & Security → Security* the same
way — no navigational difference found.

### 3.8 The `xattr` alternative

If the app does end up quarantined, the whole dance can be skipped from Terminal on the
recipient's Mac:

```sh
xattr -dr com.apple.quarantine /Applications/Coco.app
```

**[verified]** `xattr -dr com.apple.quarantine` removes the attribute recursively and the signature
remains valid afterwards. `-d` deletes the named attribute, `-r` recurses — `man 1 xattr`.

After this the app opens with no prompt at all, because Gatekeeper's first-launch check is
triggered by the quarantine attribute. Note this **also** disables app translocation (§5).

Verify the state either way:

```sh
xattr -l /Applications/Coco.app          # silence = not quarantined
```

Do **not** suggest `sudo spctl --master-disable` / `--global-disable`. It disables Gatekeeper
machine-wide, requires root, and is a serious and persistent downgrade to the recipient's
security posture for no benefit over the per-app approval.

---

## 4. Launch at login

### 4.1 Does `SMAppService.mainApp.register()` work for an ad-hoc-signed app? — **Yes. [verified]**

This was the ticket's central uncertainty, and I was able to settle it **empirically**, not just
from docs.

The authoritative documentation is the SDK header itself,
`MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h`
**[verified, read locally]**:

> "Apps that use SMAppService APIs **must be code signed**."
>
> "If the app bundle is not properly code signed, this API will return error
> `kSMErrorInvalidSignature`"
>
> "For SMAppServices initialized as LaunchDaemons … **Apps that contain LaunchDaemons must be
> notarized.**"

Read carefully, this already answers the question. The requirement on a **login item** is
*code signed* — and §3.2 established that an ad-hoc signature **is** a valid code signature
(`codesign --verify --strict` → "valid on disk", "satisfies its Designated Requirement"). The
stricter **notarization** requirement is scoped explicitly and only to **LaunchDaemons**, which
Coco does not use.

**Empirical confirmation [verified]** — I built a minimal `LSUIElement` app bundle, signed it
`codesign -s - --force`, ran it, and called `SMAppService.mainApp.register()`:

```
bundleID: com.cocoresearch.smtest
Signature=adhoc     TeamIdentifier=not set     flags=0x2(adhoc)
BEFORE status = notFound
register() SUCCEEDED
AFTER  status = enabled
```

`register()` succeeded and the service reported `SMAppServiceStatusEnabled` — **not**
`requiresApproval`, and no `kSMErrorInvalidSignature`. It also succeeded with only the
linker-applied ad-hoc signature (bundle never passed through `codesign`). I then called
`unregister()`, which succeeded and returned status to `notRegistered`; **the test login item was
removed and the machine left clean [verified]**.

Caveat on scope: this was executed on **macOS 26.5**, not macOS 15 — the target OS cannot be
tested locally. The documented contract ("must be code signed") is unchanged between the two, and
`SMAppService` has been present since macOS 13, so I rate this **high confidence** for macOS 15,
but it is the one part of §4 not directly verified on the target OS.

### 4.2 Version and location requirements

- **macOS 13.0+.** The header carries `API_AVAILABLE(macos(13.0), macCatalyst(16.0))` on
  `SMAppService` and on the `mainAppService` property **[verified]**. Target macOS 15 is
  comfortably above this.
- One wrinkle: `SMAppServiceErrorDomain` itself is `API_AVAILABLE(macos(15.0), …)`
  **[verified]** — newer than the class. Compare error domains by string or use `NSError.domain`
  defensively if you ever lower the deployment target; at 15.0 it is fine.
- **The app does NOT need to be in `/Applications`.** **[verified]** — registration succeeded from
  a temporary directory under `/private/tmp`. Nothing in the header or documentation imposes a
  location requirement for `mainApp`.

Docs: <https://developer.apple.com/documentation/servicemanagement/smappservice>
and `register()`:
<https://developer.apple.com/documentation/servicemanagement/smappservice/register()>
> "If the service corresponds to the main application, the application launches on subsequent
> logins."
> "If the service is already registered, this method returns [kSMErrorAlreadyRegistered]. If the
> service isn't approved by the user, this method returns [kSMErrorLaunchDeniedByUser]."

### 4.3 Error codes to handle

From `SMErrors.h` **[verified, read locally]** — `kSMErrorInternalFailure = 2`, then in order:

| Code | Constant | Meaning here |
|---|---|---|
| 2 | `kSMErrorInternalFailure` | Generic failure. |
| 3 | `kSMErrorInvalidSignature` | The bundle is not properly code signed. **Should not occur** for a correctly ad-hoc-signed bundle. |
| 4 | `kSMErrorAuthorizationFailure` | — |
| … | `kSMErrorToolNotValid`, `kSMErrorJobNotFound`, `kSMErrorServiceUnavailable`, `kSMErrorJobPlistNotFound`, `kSMErrorJobMustBeEnabled`, `kSMErrorInvalidPlist` | — |
| … | `kSMErrorLaunchDeniedByUser` | User switched the login item off in System Settings. |
| … | `kSMErrorAlreadyRegistered` | Harmless; treat as success. |

Status values are `SMAppServiceStatus`: `.notRegistered`, `.enabled`, `.requiresApproval`,
`.notFound`. `.requiresApproval` means "registered, but the user must act in System Settings";
per the header it is also "returned if the user revokes consent for the service to run in System
Settings" **[verified]**.

### 4.4 Practical gotchas

- **Swift 6 concurrency:** `SMAppService.mainApp` is **MainActor-isolated**. **[verified]** —
  referencing it from a nonisolated context is a compile error:
  `main actor-isolated let 'svc' can not be referenced from a nonisolated context`.
  Mark the calling function `@MainActor`.
- **Re-register after rebuilding.** The header states: "If an app updates either the plist or the
  executable for a LaunchAgent or LaunchDaemon, the SMAppService must be re-registered or it may
  not launch. It is recommended to also call unregister before re-registering if the executable
  has been changed." **[verified, quoted]** An ad-hoc signature has no stable Team ID, so the
  recorded code requirement is pinned to the **cdhash**, which changes with every rebuild. If you
  ship an updated Coco later, call `unregister()` then `register()`.
- **Register lazily, not at every launch.** Check `status` first; only call `register()` when it
  is `.notRegistered`. Calling it repeatedly returns `kSMErrorAlreadyRegistered`, which is noisy
  but harmless.
- **Register in response to a user action** (the "Launch at login" menu item), not silently at
  first launch. It is the recipient's Mac; a background item that appears unasked is the kind of
  thing that gets an app deleted.

### 4.5 User-visible consequences

On macOS 13+ (so on both 15 and 26), registering a login item causes:

1. A Notification Center banner: **"Background Items Added"** — *"Coco added items that can run in
   the background. You can manage this in Login Items Settings."*
2. An entry in **System Settings → General → Login Items & Extensions**, where the recipient can
   toggle Coco off at any time. Toggling off makes `status` report `.requiresApproval` and
   subsequent `register()` calls return `kSMErrorLaunchDeniedByUser`.

Apple's own framing of the benefit, from the Service Management sample project
(<https://developer.apple.com/documentation/servicemanagement/updating-your-app-package-installer-to-use-the-new-service-management-api>):
> "Users can also see which app is providing the launch daemons or launch agents by choosing
> System Settings > General > Login Items."

**Tell the recipient this banner will appear** — an unexplained "Background Items Added"
notification on a birthday gift is alarming rather than charming.

### 4.6 Fallback: a LaunchAgent in `~/Library/LaunchAgents`

`SMAppService` is verified working, so this is a **contingency, not the plan**. Documented for
completeness.

`~/Library/LaunchAgents/com.paologiua.coco.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.paologiua.coco</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Coco.app/Contents/MacOS/Coco</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
```

Keys, from `man 5 launchd.plist` **[verified, read locally]**:
- `Label` — *"This required key uniquely identifies the job to launchd."* The only mandatory key.
- `ProgramArguments` — argv. Required unless `Program` is given.
- `RunAtLoad` — *"This optional key is used to control whether your job is launched once at the
  time the job is loaded. The default is false. This key should be avoided, as speculative job
  launches have an adverse effect on system-boot and user-login scenarios."* Apple discourages it
  generally, but it is exactly what "launch at login" means, so it is correct here.
- `LimitLoadToSessionType` = `Aqua` — load only in a GUI login session, not for ssh/pre-login.
- `ProcessType` = `Interactive` — tells the scheduler this is a foreground-ish UI process.
- `FILES` section confirms `~/Library/LaunchAgents` = *"Per-user agents provided by the user."*

Install and load programmatically:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.paologiua.coco.plist
# and to remove:
launchctl bootout gui/$(id -u)/com.paologiua.coco
rm ~/Library/LaunchAgents/com.paologiua.coco.plist
```

(`launchctl load`/`unload` are the deprecated spellings; `bootstrap`/`bootout` are current.
`man 1 launchctl`.)

Trade-offs versus `SMAppService`:

- **It still triggers the same "Background Items Added" notification and still appears in System
  Settings → General → Login Items & Extensions** on macOS 13+. There is no privacy win, and no
  *additional* prompt beyond the one `SMAppService` also causes. Disabling it is the same toggle.
- **`launchd` will relaunch the process** according to `KeepAlive` semantics; get this wrong and
  Coco respawns after the user quits her. `SMAppService.mainApp` has cleaner semantics for a
  plain login item.
- **The absolute path is baked into the plist.** If the app moves, the agent silently stops
  working. `SMAppService` tracks the bundle.
- Writing directly into `~/Library/LaunchAgents` is the legacy mechanism that `SMAppService`
  exists to replace — the header calls the new API *"a replacement for installing plists in
  ~/Library/LaunchAgents or /Library/LaunchAgents"* **[verified, quoted]**.

**Use `SMAppService.mainApp`. Fall back to the LaunchAgent only if `register()` throws on the
target machine** — and if it does, the thrown `kSMError…` code will say why.

---

## 5. Install location

### 5.1 Does location change anything?

| | `/Applications` | `~/Applications` | `~/Desktop`, `~/Downloads` |
|---|---|---|---|
| Quarantine behaviour | identical | identical | identical |
| Gatekeeper first-open flow | identical | identical | identical |
| `SMAppService` registration | works | works | works **[verified from `/private/tmp`]** |
| Needs admin password to install | **yes** | no | no |
| Translocation risk (if quarantined) | low | low | **highest** |
| Survives migration / is findable later | best | good | poor |

Location affects **none** of the quarantine or Gatekeeper mechanics — those key off the
`com.apple.quarantine` xattr, not the path. `SMAppService` imposes no location requirement
**[verified]**.

**Recommendation: `/Applications`.** It costs one admin-password prompt at install time and buys:
the app is where the recipient will look for it, it is out of the way of a Downloads-folder
cleanup, and translocation becomes a non-issue.

### 5.2 App translocation / Gatekeeper Path Randomization

Introduced in macOS Sierra (WWDC 2016 session 706, "What's New in Security" —
<https://developer.apple.com/videos/play/wwdc2016/706/>).

**How it works.** When macOS decides an app is untrusted-and-freshly-arrived, it does not run the
app from where it sits. It mounts a **read-only disk image** at a randomized temporary path,
copies the whole `.app` onto it, and launches from there. The bundle's path becomes something
like:

```
/private/var/folders/…/T/AppTranslocation/<UUID>/d/Coco.app/Contents/…
```

The purpose is to defeat attacks that rely on an app loading a malicious file sitting *next to* it
in the same folder (the classic "unpacked zip with a poisoned dylib" trick).

**When it happens.** Apple's DTS engineer Quinn, in "App Translocation Notes"
(<https://developer.apple.com/forums/thread/724969>), is explicit that the trigger conditions are
**not contractual**:

> "The exact circumstances where the system translocates an app is not documented and has changed
> over time."
> "It's best to structure your app so that it works regardless of whether it's translocated or
> not."
> "There is no supported way to detect if your app is being run translocated."

In practice it requires the `com.apple.quarantine` attribute and applies to an app launched from
where it was unarchived. **Moving the app in Finder clears it** — Quinn: *"The act of moving the
app has cleared the state that triggered app translocation."* Removing the quarantine xattr also
prevents it.

**Would it break Coco?** **No, not for sprite loading.** Translocation copies the **entire app
bundle** to the read-only image, so everything under `Contents/Resources` travels with it and
`Bundle.main.url(forResource:…)` resolves normally — just under a different prefix. Quinn confirms
the failure mode is specifically *app-relative external* resources:

> "you can run into problems if you load resources relative to your app bundle."

Since §1.4 already commits Coco to reading sprites from **inside** its own bundle via
`Bundle.main`, translocation is harmless to the art pipeline.

**What translocation *would* break for Coco:**

1. **`SMAppService` registration.** Registering while translocated records the randomized,
   ephemeral path. The login item would be dead on the next boot. This is the real hazard.
2. Anything that writes next to the bundle — Coco writes to
   `~/Library/Application Support/Coco/` (per the map), which is **outside** the bundle and
   therefore **unaffected**. Good design, already locked in.
3. The read-only image means the bundle cannot self-modify.

**Mitigation is already implied by the recommended plan:** transfer by **USB** (no quarantine
attribute at all → no translocation, ever) and **drag to `/Applications` in Finder** (which clears
the state even if quarantine somehow got set). Belt and braces. If anything looks wrong, running
`xattr -dr com.apple.quarantine /Applications/Coco.app` removes the trigger entirely.

Additional background: Rogue Amoeba's contemporaneous write-up
<https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/> and
Objective-See's <https://objective-see.org/blog/blog_0x15.html>.

**macOS 15 vs 26:** no documented change to translocation between the two. Since Apple explicitly
declines to specify the trigger conditions, treat this as **[unverified]** across versions and
design so it does not matter — which the plan above does.

---

## Recommended procedure

### A. Build script outline (`Scripts/build-app.sh`)

```sh
#!/bin/bash
set -euo pipefail

APP_NAME="Coco"
BUNDLE_ID="com.paologiua.coco"
VERSION="1.0"
BUILD="1"
SDK15="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/dist/$APP_NAME.app"

# 0. Guard: pin to the macOS 15 SDK. Fail loudly if it disappears after a CLT update.
[ -d "$SDK15" ] || { echo "FATAL: macOS 15 SDK missing at $SDK15"; exit 1; }

# 1. Build release, against the macOS 15.4 SDK, deployment target 15.0.
#    Package.swift must declare: platforms: [.macOS(.v15)]
export SDKROOT="$SDK15"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"

# 2. Verify the deployment target actually landed. Fail the build if not.
vtool -show-build-version "$BIN" | grep -q "minos 15.0" \
  || { echo "FATAL: binary is not minos 15.0"; vtool -show-build-version "$BIN"; exit 1; }

# 3. Assemble the bundle from scratch.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

# 4. Icon: PNGs -> .iconset -> .icns  (iconutil ships with the CLT)
rm -rf build/$APP_NAME.iconset && mkdir -p build/$APP_NAME.iconset
for s in 16 32 128 256 512; do
  cp "Art/icon/icon_${s}.png"        "build/$APP_NAME.iconset/icon_${s}x${s}.png"
  cp "Art/icon/icon_$((s*2)).png"    "build/$APP_NAME.iconset/icon_${s}x${s}@2x.png"
done
iconutil -c icns "build/$APP_NAME.iconset" -o "$APP/Contents/Resources/$APP_NAME.icns"

# 5. Sprites: copied straight into Contents/Resources. NEVER via SwiftPM `resources:`.
cp -R "Art/sprites" "$APP/Contents/Resources/Sprites"

# 6. Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleIconFile</key><string>$APP_NAME</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"

# 7. Ad-hoc sign. No --deep (deprecated since macOS 13). No hardened runtime. No entitlements.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

# 8. Verify.
codesign --verify --strict --verbose=4 "$APP"
echo "--- expect: adhoc, TeamIdentifier not set ---"
codesign -dvv "$APP" 2>&1 | grep -E "Identifier|Signature|TeamIdentifier"
echo "--- expect: spctl 'rejected' — this is EXPECTED for ad-hoc ---"
spctl -a -t exec -vv "$APP" || true

# 9. Smoke test: launch, confirm sprites resolve, quit.
echo "Built $APP"
```

Then ship it on a **USB stick**:

```sh
ditto "$APP" /Volumes/STICK/Coco.app     # ditto preserves the bundle + signature correctly
```

Use `ditto` (or `cp -R`), **not** `zip` — a plain `zip` mangles symlinks and extended attributes.
If you must compress, use `ditto -c -k --sequesterRsrc --keepParent Coco.app Coco.zip`.

**Do not AirDrop it** — that applies quarantine and forces the recipient through §3.7.

### B. Steps the human performs on the recipient's Mac

1. Plug in the USB stick.
2. Drag `Coco.app` from the stick into **Applications** in the Finder sidebar. Authenticate with
   the admin password when asked.
   *(Dragging in Finder — rather than copying in Terminal — is what clears any translocation state.)*
3. Open Terminal and belt-and-braces the quarantine attribute:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Coco.app
   xattr -l /Applications/Coco.app     # expect: no output
   ```
   If step 3 is skipped and the app *was* quarantined, do §3.7 instead:
   double-click → **Done** → **System Settings → Privacy & Security → Security → Open Anyway**
   → password → **Open**. Remember the button expires after ~1 hour.
4. Double-click `Coco.app`. She should appear; **no Dock icon**, menubar icon present
   (`LSUIElement`).
5. In Coco's menu, turn on **Launch at login**. Expect a **"Background Items Added"**
   notification — this is normal, and it is how macOS tells the user something will start at
   login.
6. Verify: **System Settings → General → Login Items & Extensions** shows *Coco*, toggled on.
7. **Reboot and confirm Coco comes back.** Do this before leaving — it is the only real test of
   §4 on the actual target OS.
8. Show her the same Login Items pane and explain that the toggle turns it off, and that dragging
   `Coco.app` to the Trash removes her entirely.

---

## What I could NOT establish with confidence

- **Everything in §4 was verified on macOS 26, not macOS 15.** `SMAppService.mainApp.register()`
  demonstrably works with an ad-hoc signature on 26.5, and the documented contract ("must be code
  signed") is identical for 15. But I have no macOS 15 machine and no way to simulate one. Rated
  **high confidence**, not certainty. Step B.7 (reboot test) is the mitigation and must not be
  skipped.
- **Translocation trigger conditions.** Apple explicitly refuses to document them and says they
  have changed over time. I could not confirm whether macOS 15 and 26 behave identically. The plan
  is designed so it does not matter.
- **A full symbol-level audit** of a built binary against the macOS 15 ABI. Level 3 in §2.5 is
  sound in principle but I did not build and validate the tooling. Level 1 (the `SDKROOT` pin)
  makes it unnecessary.
- **Whether the macOS 15.4 SDK will survive future CLT updates.** It is present today. A CLT
  update could remove it, which is why the build script has an explicit guard (step 0). If it
  disappears, older Command Line Tools packages remain downloadable from
  <https://developer.apple.com/download/all/> with a free Apple ID — **[unverified]**, I did not
  attempt a download.
- **The precise wording of the macOS 15 Gatekeeper blocking dialog.** Apple has revised it across
  releases. The click *path* is confirmed by Apple's own support page, which covers macOS 15
  explicitly.

## Risks that would only surface on the macOS 15 target machine

1. **Liquid Glass visual divergence (highest residual risk).** macOS 26 redesigned `NSPanel`,
   `NSStatusItem` and `NSMenu` rendering. Coco's floating panel and menubar UI will *look
   different* on macOS 15 — different corner radii, materials, shadows and metrics. Anything
   pixel-tuned by eye on the dev machine may be visibly off on hers. No compiler flag catches
   this. **Mitigation:** avoid tuning layout against macOS 26 chrome; use explicit sizes rather
   than system metrics; keep the panel borderless and fully custom-drawn so system chrome does not
   participate at all. This risk is real and is not solved by the SDK pin.
2. **SF Symbol names returning nil.** A symbol introduced after macOS 15 silently yields `nil` on
   the target and the menubar icon disappears. **Mitigation:** ship template PNGs, not SF Symbols,
   for the mood silhouettes — or `guard let` with a fallback. This is the single most likely
   "works here, blank there" bug after the `Bundle.module` trap.
3. **`Bundle.module` crash.** Fully characterised in §1.4 and avoidable — but if any dependency or
   a later refactor reintroduces SwiftPM `resources:`, the app will pass every test on the dev
   machine and `fatalError` on hers. Consider a build-script guard that fails if any
   `*.bundle` appears in the SwiftPM bin path.
4. **Login item not surviving reboot** if registration happened while translocated, or if the app
   was moved after registering. Mitigated by installing to `/Applications` *before* enabling
   launch-at-login, and by step B.7.
5. **Gatekeeper approval invalidated by a rebuild.** If you hand over a v1.1 later, the ad-hoc
   cdhash changes; the approval and the `SMAppService` registration must both be redone.

## Confidence summary

| Claim | Confidence | Basis |
|---|---|---|
| Hand-assembled bundle layout + Info.plist keys work | **Certain** | verified locally, `plutil`/`codesign` clean |
| `iconutil` available without Xcode | **Certain** | verified: `/usr/bin/iconutil`, produced a real `.icns` |
| Compiler errors on macOS 26 API at a 15.0 target | **Certain** | verified: hard compile error |
| macOS 15.4 SDK present; `SDKROOT` pin works | **Certain** | verified: `sdk 15.4` stamp, 26 API "cannot find in scope" |
| `Bundle.module` breaks in a hand-built `.app` | **Certain** | verified: `fatalError` reproduced; root placement breaks signing |
| Ad-hoc signing works with 0 identities | **Certain** | verified |
| `--deep` deprecated since macOS 13 | **Certain** | local `man codesign` |
| `spctl` rejects an ad-hoc app | **Certain** | verified |
| USB transfer sets no quarantine; AirDrop does | **High** | well-established; Apple doesn't document the transport list directly |
| macOS 15 removed Control-click bypass | **Certain** | Apple Developer News (primary) |
| `SMAppService.mainApp.register()` works ad-hoc | **High** | verified on macOS 26 + SDK header contract; not testable on 15 |
| `/Applications` not required for `SMAppService` | **High** | verified from `/private/tmp` on macOS 26 |
| Translocation preserves in-bundle resources | **High** | Apple DTS forum post (Quinn) |
| Translocation triggers identical on 15 and 26 | **Low** | Apple declines to document |
