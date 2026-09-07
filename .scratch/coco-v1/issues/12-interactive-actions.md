# 12 — Interactive Feed and Play

Type: task
Status: resolved
Blocked by: 09, 10
Parent: [map](../map.md)

## Question

Turn Feed and Play from menu commands into things you do with the mouse.

**Feed.** Choosing Feed attaches a piece of food to the cursor. If Coco is hungry she comes *towards* the cursor — stopping short of it, never underneath — and clicking gives her the food. If she is not hungry she ignores it entirely, which is a better refusal than turning her back because the human can see why.

**Play.** Choosing Play attaches a hoop to the cursor for up to 20 seconds. Coco flies through it, with passes counted. The hoop is the user's confirmed choice; do not substitute a ball. Three passes end the game early. Escape and timeout always remove the interaction.

Food uses a small click-receiving cursor panel. The larger hoop is click-transparent so its opening does not swallow clicks on Coco or other apps.

Food and hoop use generated transparent PNG assets bundled under `UI/`.

## Answer

Implemented on 2026-09-07 in `InteractionWindow.swift`, `HoopGame.swift`, `AppDelegate.swift` and `BehaviourDriver.swift`.

- Feed displays the generated millet sprite for up to 20 seconds. Hungry, awake Coco approaches with a 65-point offset; clicking within 110 points feeds her once. A full bird ignores the food. No Need changes on entering the interaction.
- Play displays the generated hoop, scaled with Coco, with a visible pass counter. Coco approaches one side and flies completely through to the other. Three passes end the game, otherwise it expires after 20 seconds. At least one completed pass is required for the existing Play reward; cancellation earns nothing.
- `HoopGame` checks entry, crossing the opening, and exit. Moving the hoop significantly resets the approach; hovering near it or sweeping it over Coco does not count.
- Generated transparent pixel-art assets are `Assets/UI/food.png` and `Assets/UI/hoop.png`, copied into the signed bundle by the existing build script. Rendering uses nearest-neighbour interpolation.
- A 60 Hz common-mode timer follows the pointer and independently enforces expiry and Escape cancellation. Opening the menu or Settings, hiding Coco, sleeping, dragging, switching interactions, leaving Coco's screen, and quitting all clean up the interaction. The hoop panel passes all clicks through; food captures only its small square.
- Tests cover complete passes in both directions, proximity without a pass, moving the hoop, missing the opening, and integration with the behaviour driver completing three passes within 20 seconds.

## Comments

### 2026-09-07 — User correction

The initial implementation chose a ball. The user clarified that a hoop had already been agreed; the ball and proximity-based reward were replaced. The user also reported seeing the old behaviour: process inspection confirmed `/Applications/Coco.app` was running while builds had only updated `dist/Coco.app`. The installed copy must be updated and restarted after building.

Validation: all 29 tests passed, the release bundle built with SDK 15.4, and the ad-hoc signature verified. The developer's installed app was gracefully quit, backed up to `/private/tmp/coco-backup.vHKV5Y/Coco.app`, updated and relaunched. The new process runs `/Applications/Coco.app/Contents/MacOS/Coco`; its SHA-256 matches the rebuilt executable (`3968d8d743fd74a93421d2ac3617e67ff94ee4d9ae40c7cdf540201eee08b65d`). This confirms the developer is now running the updated build, not target-machine acceptance.

Manual UI acceptance on macOS 15 remains part of [Install and verify on the recipient's Mac](07-install-on-target.md), particularly Escape from another foreground app and the visual feel of the flight through the hoop.

### 2026-09-07 — Feeding diagnosis and perpendicular hoop

The user reported that Coco fled from the food and clicking did nothing. The saved state showed Hunger at 97.4; Feed is intentionally refused above 85. The UI was nevertheless starting a food interaction, then `updateInteraction` removed its target, exposing normal cursor avoidance, while the click guard silently rejected feeding. The combination looked broken.

`Simulation.canFeed` now exposes the same eligibility rule used by `feed()`. Feed checks it before showing food: a full Coco refuses visibly and no cursor object appears; an eligible Coco approaches and can eat. A regression test covers Hunger 50 increasing to 95, alongside the existing full-bird refusal test. The development state was backed up and Hunger set to 50 for immediate manual verification.

The face-on hoop was replaced with a generated 24x64 transparent sprite viewed nearly edge-on, as a hoop perpendicular to the screen. After visual review, the user clarified that Coco must pass underneath it: the hoop panel therefore sits just above Coco's level. Food was likewise processed to a native 24x24 transparent sprite. Both use the locked palette and nearest-neighbour scaling.

All 30 tests pass. The installed developer copy was rebuilt and restarted; manual confirmation of the mouse interaction remains pending.

### 2026-09-07 — Hoop art refinement

The first edge-on hoop looked irregular at native size. It was regenerated as a clean, symmetrical golden oval at a slight three-quarter angle, with an obvious opening and uniform tube thickness. The source generation is preserved at `.scratch/coco-v1/art-raw/hoop-02.png`; the palette-mapped, hard-alpha 24x64 runtime asset replaces `Assets/UI/hoop.png`. Coco continues to pass underneath it as requested.

### 2026-09-07 — Two-layer depth

The single-layer presentation still could not communicate an actual flight through the hoop. At the user's direction, `InteractionWindow` now renders the same hoop in two synchronized, click-transparent panels: the right half one level below Coco and the left half one level above. Coco therefore aligns outside the opening, flies over the right/rear arc, and passes under the left/front arc. Timeout, pass counter, Escape and cleanup own both panels together.

### 2026-09-07 — Post-feeding cursor grace

The user observed that Coco approached the food but fled when it was clicked. A minimized driver test reproduced the exact sequence: `feed()` succeeded and raised Hunger, the 1.2-second reaction finished, then normal personal-space avoidance immediately changed Behaviour to Flying because the feeding cursor was still beside her. The click and distance guard were not the cause.

After a successful Feed, `BehaviourDriver.welcomeCursor` now suppresses cursor avoidance for three seconds. The eating reaction and particles remain unchanged, and normal autonomy resumes when the grace period expires. The regression test proves both halves: no flight at 1.4 seconds, then normal flight is allowed after 3 seconds. All 31 tests pass.

### 2026-09-07 — The actual missed click

The user retested and Feed still failed. The saved state remained at Hunger 49.96 after clicking, proving `feed()` was never called; the earlier cursor-grace fix addressed a real secondary defect but not the reported failure. A minimized AppKit test then reproduced the cause: `TargetView.acceptsFirstMouse(for:)` inherited `false`. Because Coco is deliberately non-activating, AppKit discarded the first click while another app was frontmost.

`TargetView` now explicitly accepts the first mouse event. This preserves the non-activating panel while delivering the food click. The regression test failed before the override and passes after it; the full suite now has 32 passing tests.

## Comments

### 2026-09-07 — Feed was unfeedable: two defects found in use

Reported from actually using her: *"si avvicina per prendere il cibo ma appena provo a darglielo scappa via."* Both causes were in the code as shipped, and the second was written into a test.

**1. The standoff was maintained, not a stopping point.** `updateInteraction` recomputed `interactionTarget` as `mouse ± 65` every tick, and the driver flew to it every tick. So the 65-point gap was held *continuously*: moving the hand 30 points towards her moved her target 30 points away, and she backed off at flight speed exactly as fast as the hand advanced. She could never be reached, and since retreating plays the flight clip, it read as fleeing the food she had just flown across the screen to get.

She now **latches on arrival** (`hasArrivedBeside`) and holds position while the food stays within her personal space. Bringing the hand closer does nothing, which is the whole point. Carrying it further than `personalSpace` un-latches and she goes after it again — deliberately the same 110 points the click guard uses, so there is no band where she looks reachable and a click silently does nothing.

The latch is food-only: the hoop is a moving target she must keep chasing, so `interactionStyle` (`.waitBeside` / `.chase`) now says which of the two `interactionTarget` means. Without that split, fixing Feed would have broken Play.

**2. Feeding her made her leave.** `welcomeCursor(for: 3)` suppressed cursor-avoidance for three seconds after a feed. The eating pose is 1.2 s, the hand is still sitting right there when the timer expires, so she startled at the person who had just fed her — a timer only ever postpones that. The welcome now lasts **until the hand withdraws** past her personal space; coming back afterwards is a fresh approach and she startles at it like any other.

`feedingDoesNotTurnTheWaitingHandIntoAThreat` asserted `behaviour == .flying` at 3.1 s — the test's own name contradicted its last assertion. Updated, plus `offeredFoodBroughtCloserDoesNotPushHerAway` and `foodCarriedOutOfReachIsWorthFollowing`. **34 tests pass**, `dist/Coco.app` rebuilt and re-signed.

Visual confirmation on the target Mac still belongs to [Install and verify on the recipient's Mac](07-install-on-target.md).

### 2026-09-07 — Feed confirmed working by eye

The dev confirmed Feed behaves correctly after the two fixes above: she flies over, holds position while the food is brought to her, and takes it. Observed on the **dev machine (macOS 26)**, so this closes the behavioural question but not the macOS 15 chrome question — visual acceptance on the target Mac still belongs to [Install and verify on the recipient's Mac](07-install-on-target.md).

Play was not reported on in this session. It shares `interactionTarget` with Feed through the opposite `interactionStyle`, so it remains the regression worth checking first if anything looks wrong later.
