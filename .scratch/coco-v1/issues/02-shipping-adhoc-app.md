# 02 — Shipping an ad-hoc-signed .app to macOS 15 from a CLT-only toolchain

Type: research
Status: resolved
Blocked by: —
Parent: [map](../map.md)

## Question

How exactly does a SwiftPM executable become a double-clickable `.app` that runs on someone else's macOS 15 Mac, launches at login, and does not require Xcode to build?

Answer all of:

1. **Bundle assembly.** The directory layout of a minimal `.app` (`Contents/MacOS`, `Contents/Resources`, `Contents/Info.plist`) and the required `Info.plist` keys — bundle id, version, `LSUIElement` for a menubar-only app with no Dock icon, `LSMinimumSystemVersion`, icon.
2. **Deployment target.** The exact `swift build` flags to target macOS 15.0 while building on macOS 26 with the macOS 26 SDK, and — critically — **how to prevent macOS 26-only API creep**, given the target OS cannot be tested locally. Does the compiler reject unavailable APIs at the 15.0 target, or can they slip through to a runtime crash on her Mac?
3. **Signing and Gatekeeper.** How to ad-hoc sign (`codesign -s -`), what happens on first open on macOS 15 for an app with no Developer ID, whether the quarantine flag even applies to a file hand-copied rather than downloaded, and the precise click path or `xattr` command to open it the first time on macOS 15 (the Settings path moved in recent versions).
4. **Launch at login.** Does `SMAppService.mainApp.register()` work for an **ad-hoc-signed** app? It is documented to require a valid signature — establish whether ad-hoc counts. If not, what is the fallback (a `LaunchAgent` plist in `~/Library/LaunchAgents`), and what are its trade-offs and its own permission prompts?
5. **Install location.** Does the app need to live in `/Applications` for any of the above, or does anywhere work?

Cite primary sources (Apple documentation, release notes). Where behaviour differs between macOS 15 and 26, say so explicitly — the dev machine and the target machine differ.

## Answer

Full findings, with a build-script outline and a step-by-step install checklist: [`research/02-shipping-adhoc-app.md`](../research/02-shipping-adhoc-app.md). Most claims were settled by compiling and running test programs on this machine, not from documentation alone.

**1. Bundle assembly — and the trap that would have killed the gift.** A hand-assembled bundle works, `iconutil` ships with the CLT so the `.icns` needs no Xcode. But **SwiftPM's `resources:` declaration and `Bundle.module` must not be used.** The generated accessor looks for a resource bundle at `Coco.app/<name>.bundle` — a path that cannot exist in a correctly-formed bundle — and then falls back to a **hard-coded absolute path into the developer's `.build` directory**. On the dev machine that path exists and everything appears to work; on any other machine the app `fatalError`s on launch. Reproduced. The only placement satisfying it breaks code signing (`unsealed contents present in the bundle root`). **Sprites go into `Contents/Resources/Sprites/` via the build script and are read with `Bundle.main.url(forResource:withExtension:subdirectory:)`.**

**2. Deployment target — the safety net is stronger than assumed.** The Swift compiler **hard-errors** on a macOS 26-only API at a 15.0 deployment target (verified with `NSGlassEffectView`). Better still, **the macOS 15.4 SDK is present on this machine** and can be pinned via `SDKROOT`, so macOS 26 symbols are not even in scope. The build script guards for its disappearance after a CLT update.

Where the net does **not** hold: stringly-typed lookups (an SF Symbol introduced after 15 returns `nil` — a blank menubar icon, no error), Obj-C runtime lookup, unrecognised `Info.plist` keys, and **behaviour or appearance changes in APIs present on both versions**. The last is the residual risk: macOS 26's Liquid Glass redesign changes `NSPanel`, `NSStatusItem` and `NSMenu` metrics, so anything pixel-tuned by eye here may sit wrong on hers.

**3. Signing and Gatekeeper.** Ad-hoc signing works with zero identities; arm64 requires *some* signature at all times. No `--deep` (deprecated since macOS 13), no hardened runtime, no entitlements. macOS 15 **removed the Control-click → Open bypass**; the path is now System Settings → Privacy & Security → Open Anyway, and that button expires after about an hour.

But it need not arise at all: `com.apple.quarantine` is applied by the *receiving app*, not the filesystem. **AirDrop quarantines; a USB stick does not.** Deliver Coco on a USB stick and the Gatekeeper prompt never appears. Quarantine does propagate through `cp`/`ditto`, so if it ever touches AirDrop it stays flagged.

**4. Launch at login — settled empirically.** `SMAppService.mainApp.register()` **works with an ad-hoc signature.** The header requires only "code signed", and an ad-hoc signature satisfies `codesign --verify --strict`; the stricter *notarization* requirement is scoped to LaunchDaemons, which Coco does not use. A minimal ad-hoc-signed `LSUIElement` bundle registered successfully, reported `enabled` (not `requiresApproval`), and was cleanly unregistered afterwards. Verified on macOS 26, not 15 — high confidence, not certainty; the reboot test on her Mac is the mitigation. No `LaunchAgent` fallback needed.

**5. Install location.** `/Applications` is not required, but install there **before** enabling launch-at-login. Dragging in Finder (not `cp` in Terminal) clears translocation state.

### Consequences for the build

- Sprites via `Bundle.main`, never `Bundle.module`. Consider a build-script guard that fails if any `*.bundle` appears in the SwiftPM bin path.
- Menubar mood icons must be **our own template PNGs, not SF Symbols**.
- Do not tune layout against macOS 26 chrome; draw the panel fully custom so system chrome never participates.
- A rebuilt v1.1 changes the ad-hoc cdhash: Gatekeeper approval and `SMAppService` registration must both be redone.
