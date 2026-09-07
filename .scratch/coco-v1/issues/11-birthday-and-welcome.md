# 11 — Birthday easter egg and first-launch welcome

Type: task
Status: resolved
Blocked by: 09, 10
Parent: [map](../map.md)

## Question

The two moments that make this a gift rather than a toy.

- **First launch ever**: Coco flies in from the edge of the screen and introduces herself in a speech bubble. Reuses the flight clip; the bubble is drawn in code in the canvas headroom.
- **The birthday**: on the configured date, Party State overrides Mood entirely for the whole day — `hat_side` / `hat_front` over every frame, festive resting animation, confetti when she is clicked. It yields to sleep.
- The **personal message**, read from a text file in the bundle so it can be changed in later years without recompiling, shown once on the first launch of that day. Tracked **by year** in the saved state so it still fires if the app was already running at midnight, and only once.
- A timer that notices midnight passing while the app runs.

## Answer

Both moments work. `Sources/Coco/BubbleWindow.swift`, plus the welcome and birthday logic in `AppDelegate`.

**The speech bubble is its own window.** Coco's stage is 64 pixels wide — 128 points at Medium — and neither "Hi! I'm Coco." nor a line written by a human fits in that. A separate borderless, non-activating, click-transparent panel can be as wide as the sentence needs without touching a single sprite, mask or hat anchor. It is drawn to match Coco rather than macOS: a chunky bordered box with a three-step tail.

**Messages are plain text in the bundle** (`Contents/Resources/Text/`), so the birthday line can be rewritten in later years by editing a file — no toolchain, no rebuild.

**The birthday is checked once a second, not by a midnight timer.** The app is already awake every second, and a date comparison is cheaper and far more robust than a scheduled wake-up that has to survive system sleep, time zones and the clock being changed by hand.

### The bug that mattered

**The year was marked as celebrated when the message was *queued*, not when it was *shown*.** Delivery waits for Coco to land and stand still — a bubble over a bird in flight is absurd — so on the very first test the message was queued while she was walking, the year was consumed, and nothing ever appeared. `lastBirthdayCelebrated: 2026` in the state file, and silence.

On the recipient's Mac that reads: the app starts on the morning of 14 September, Coco happens to be walking, no message appears, and none ever will — not that day, not that year. Perfect silence in the single moment the whole app exists for.

Now the year is marked **only after the bubble has actually been shown**. A second net: if the text file cannot be read, a built-in line is used rather than nothing.

Two things found by watching her: she **stands still while speaking** (she used to walk out from under her own bubble), and on the birthday her slow breath becomes a bounce.

### Also fixed here

**A nap asked for from the menu now scales with how much rest she needs** — about ten seconds when she is already wide awake, up to five minutes when she is running on empty. Before, `putToSleep` set deep sleep and the energy rule woke her on the very next tick whenever energy was above 60, so the menu item did nothing at all for a rested bird. Three tests cover it.
