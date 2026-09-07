# 08 — Simulation core and persistence

Type: task
Status: resolved
Blocked by: 04, 06
Parent: [map](../map.md)

## Question

Build the model layer: Needs, Mood, Actions and the saved state, with no UI attached.

Graduated from the map's fog once [06](06-app-skeleton.md) fixed the code's shape.

- The three Needs decaying against **real elapsed time** at the rates fixed in [04](04-domain-model.md), with the **12-hour catch-up cap** and a guard clamping a backwards clock to zero elapsed.
- `Mood = min(Hunger, Affection)`, bucketed into the four levels. Energy deliberately excluded.
- The Actions and their refusal conditions, including the **+20/hour cap on petting**.
- State as readable JSON in `~/Library/Application Support/Coco/`, written on change and on quit, and surviving a missing or corrupt file by starting fresh rather than crashing.
- The "away more than 24 hours" flag that later makes the return a reunion rather than a reckoning.

This layer must be testable without a window: it is the one part of Coco that has nothing to do with AppKit.

## Answer

The model layer exists, is wired into the app, and is covered by **18 passing tests**.

| File | Holds |
|---|---|
| `Sources/Coco/Needs.swift` | the three Needs and their decay rates, `Mood`, `SleepState` |
| `Sources/Coco/Simulation.swift` | time advance, catch-up, actions and refusals, sleep transitions, the birthday checks |
| `Sources/Coco/SavedState.swift` | the on-disk shape and the `Store` that reads and writes it |
| `Tests/CocoTests/SimulationTests.swift` | 18 tests |
| `scripts/test.sh` | runs them |

`Simulation` knows nothing about AppKit and advances only when handed an explicit date, which is what makes every rule above testable without a window.

### Testing without Xcode — a gap ticket 02 did not cover

**XCTest ships with Xcode and is therefore not available here.** But **swift-testing is** — `Testing.framework` is in the Command Line Tools, just not on any path SwiftPM looks at. Three flags are needed and each failure looked different, so they are recorded in `scripts/test.sh`:

1. `-Xswiftc -F <CLT>/Library/Developer/Frameworks` — without it, "no such module 'Testing'" at compile time.
2. `-Xlinker -rpath` to the same directory — without it, it compiles and links, then fails to `dlopen` at run time.
3. A second `-Xlinker -rpath` to `<CLT>/Library/Developer/usr/lib`, because `Testing.framework` itself loads `lib_TestingInterop.dylib` from elsewhere.

### Behaviour worth noting

- **The catch-up cap changes what a test must look like.** "Hunger empties in 48 hours" cannot be asserted with a single 48-hour jump — that jump is charged as 12. The test steps through in 12-hour increments, which is also how the app experiences it.
- **State is saved at launch, every 60 seconds, and on quit.** A force-quit or a crash should cost a minute of Coco's life, not all of it.
- **A corrupt state file is moved aside, not overwritten**, and Coco starts fresh. Losing her needs is a disappointment; refusing to launch on her birthday is a disaster — and if the file can be salvaged by hand later, it is the only record of how long she has been alive.
- **A one-frame reaction is no reaction.** Setting the petted sprite was immediately undone by the idle loop on the next tick; reaction poses now hold for a set number of ticks. The animation player in [09](09-behaviour-driver.md) inherits this problem properly.
