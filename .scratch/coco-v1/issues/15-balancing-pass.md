# 15 — Balancing pass: how the numbers actually feel

Type: grilling
Status: open
Blocked by: —
Parent: [map](../map.md)

## Question

Graduated from the map's fog. The fog patch said the decay rates and action deltas "need something running before they can be felt" — the simulation, the behaviour driver and the interactive actions now all exist and have been run, so the question is sharp enough to ticket.

Settle, with the app running and `scripts/dev-state.py` used to jump to the states worth judging:

- **Decay rates.** [04](04-domain-model.md) fixed Hunger 48 h, Affection 72 h, Energy 16 h awake. A week of real use is not available before the deadline, so judge them by forcing states: what does she look like after a working day untouched, after a night, after a weekend? Is "about three days from full to empty" still the feel we want for a gift, or is a gift-pet better off decaying more slowly than a tamagotchi?
- **Action deltas.** How much one Feed, one Play session and one Pet actually restore, and whether that makes attention feel rewarding or makes the needs meaningless.
- **The +20/hour petting cap.** Does it bite at a point the human would notice, and is a visible refusal the right response when it does?
- **Sleep durations.** Nap versus Deep Sleep length — long enough to read as sleeping, short enough not to feel like the app has hung.
- **The reunion.** The 12-hour catch-up cap and the 24-hour reunion reaction, judged against the most likely real pattern on the recipient's Mac: closed overnight, opened each morning.

The bias to hold: this is a gift, not a game. If a number is wrong in a way that produces guilt, it is wrong.

Resolved when the numbers are either confirmed as they stand or changed in `Simulation.swift` / `Needs.swift`, with the tests updated and the reasoning recorded here.

## Comments

### 2026-09-07 — Energy and sleep settled; the rest of the numbers untouched

Prompted by watching her actually sleep. Measured live, twice, three minutes apart: **12.5 energy per hour**, exactly the modelled rate. The question that provoked the change was *"non è troppo?"* — and it was.

**What the human experiences is the length of a sleep, not the time from empty to full.** A Deep Sleep runs from ~20 to the waking threshold of 60, so at 12.5/h it lasted **3 hours 12**, with Feed and Play refused throughout. That is not a pet, it is a lock-out. The energy bar is ten blocks of ten points, so it also moved one visible block every 48 minutes — below the resolution of its own display for anything under an hour.

Three changes, agreed with the dev:

1. **Two recovery rates instead of one.** Deep Sleep — and the menu's Sleep, which is a Deep Sleep with a timer — fills her in **half an hour**, making an episode about **twelve minutes**. A Nap from machine idle fills in **four hours**. The split is what protects [Sleeping somewhere, and startling awake](14-sleep-perching.md): at the deep rate a lunch break refills her completely, she never falls below the threshold again, and the perching, the closed-eye pose and the startle would only ever happen overnight with nobody watching. One rate could not serve both.
2. **Time the app was not ticking no longer tires her.** `advance` charged elapsed time against `state.sleep`, which says `awake` for a lid that has been shut all night — so a night cost up to the full 12-hour cap of awake decay, **–75 energy**. She was found flat out and asleep every morning and stayed under until nearly lunchtime. Any advance covering more than two minutes (the live tick is about a second) is now treated as rest. Hunger and Affection still decay across it: she really was unfed.
3. **The hand-asked nap ends when it says it does.** `putToSleep` promises ten seconds to five minutes, then fell through to the energy rules, which hold her under until 60 — so asking for a five-minute nap while she was tired put her out for hours. It now wakes her on expiry. If she is genuinely exhausted the ordinary rule puts her back under on the next advance, which now costs twelve minutes rather than an afternoon, so letting that happen is honest rather than punishing. The new rate also fixes the opposite complaint for free: a five-minute hand-asked nap is now worth ~17 points, a block and a half, instead of one point nobody could see.

Five tests added or rewritten — `aClosedLaptopRestsHerRatherThanTiringHer`, `aDozeIsWorthLessThanRealSleep`, `aHandAskedNapEndsWhenItSaysItDoes`, `aDeepSleepLastsMinutesNotAnAfternoon`, and `emptyEnergyPutsHerIntoDeepSleep` now ticks a minute at a time because a flat one-hour advance is, correctly, no longer wakeful time. **38 tests pass**, three consecutive runs. `CONTEXT.md` updated.

**Deliberately not judged, so this ticket stays open:** Hunger's 48 hours, Affection's 72, Feed +45, Play +30, the +20/hour petting cap, and the 12-hour catch-up / 24-hour reunion rules. None of them can be felt without living with her for days, and there are seven left before the deadline. Current live state after a day of use is Hunger 94 / Affection 99, which suggests they are generous rather than harsh — the failure mode worth having in a gift. Recommendation is to accept them as they stand unless the rehearsal on the target Mac says otherwise.

**Noted, not fixed:** `BehaviourDriver.rest(for:)` schedules against the wall clock while `tick(now:)` takes an injected date. It makes her wandering non-deterministic under test — one assertion here had to park her with `stay(for: 60)` to isolate a startle from a flight she chose herself. Worth threading `now` through if that layer is ever touched again.
