# 15 — Balancing pass: how the numbers actually feel

Type: grilling
Status: resolved
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

## Answer

Worked as a grilling over several rounds on 7–8 September, against the running app rather than against the model on paper. The dev's direction throughout was **a much needier Coco than the map had charted**, and where the arithmetic said a number could not work the objection was put with the numbers and then the dev's call was taken.

**Energy and sleep** (see the comment above): Deep Sleep fills in half an hour so an episode lasts ~12 minutes instead of 3 hours; a Nap fills in four, so a lunch break cannot erase every reason she ever sleeps properly; time the app was not ticking rests her instead of charging it as waking hours; the hand-asked nap ends when its timer says so.

**Hunger — 5 hours, +10 a feed.** One segment of the menu's ten-block bar per feeding: a beakful, not a meal, because she picks at food all day the way a bird does. It stays a true clock and runs through the night, so she is empty every morning and after any absence past five hours.

**Affection — 3 hours, and it is not a clock.** The fastest thing in the model by a factor of nearly two over Hunger. It falls only while the app is on screen: she misses you while she is *with* you. This one was the dev's own idea and it removed a hard blocker — at three hours to empty, twelve hours of catch-up is four whole bars, so charging a night against it would have read zero every morning whatever anyone did. Play +60, petting +8 a touch with the hourly cap raised 20 → 60, because a cap below the decay rate is unwinnable by anyone.

**Mood stays `min(Hunger, Affection)`.** Put to the dev twice with the arithmetic: Affection is much the faster Need, so it is nearly always the minimum, and the icon will mostly report Affection while Hunger goes unseen. The dev chose to keep it. Recorded here as a known, accepted consequence rather than an oversight: **Coco will read sad for a large part of most days**, and the menubar will rarely name Hunger.

**Energy — 8 hours awake, and flying is no longer free.** Halved from 16. More to the
point, the drain was previously *uniform*: a bird crossing the screen all afternoon cost
exactly what a bird asleep on the desk edge cost, which is the sort of thing you only
notice once you watch her. Flight is now charged at **three times** the resting rate as
it happens, driven from the tick because the model has no notion of behaviour. Play costs
20 outright, and the hoop game charges its own flying on top, so a play session is
genuinely tiring. The multiplier is held as a multiplier, not a rate, so it follows
`energyAwakeHours` instead of needing to be retuned beside it. Flying to a perch with
sleep already requested is exempt — charging it would fight the recovery the flight
exists to reach.

**The reunion — 48 hours, and it now exists.** `returnedFromLongAbsence` was computed and tested from the beginning and **never read by any code**: returning after a fortnight looked exactly like never having left. It now queues a line into the same speech bubble the welcome and the birthday use, from `Assets/Text/reunion.txt`, so the feature cost a text file. The threshold moved 24 → 48 hours: at 24 it fired most Monday mornings.

40 tests pass. `CONTEXT.md` rewritten around the idea that *which clock a Need is on* is the whole of its character, and the map's locked "~3 days" constraint struck out rather than adjusted.

### Left open deliberately

The **12-hour catch-up cap is now nearly dead**. Five hours already empties Hunger, Affection is frozen and Energy is restored, so capping the charge changes no outcome any more. It has not been removed — it still guarantees a long absence is never worse than a medium one — but nothing depends on its value.

**Feeding is currently one beakful per menu invocation.** At 5 hours Hunger falls two segments an hour and a feed returns one, so a single feed can never keep up. The obvious next move, offered and not yet taken: leave the food on the cursor for its full 20 seconds so several beakfuls can be given in one session, which makes the dev's own "one segment per feed" rule add up.
