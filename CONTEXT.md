# Coco — domain glossary

A macOS desktop pet: a pixel-art budgerigar who lives on the screen.

## Coco

The bird herself. One instance, always present while the app runs. She is a *companion*, not a chore: nothing she does is designed to induce guilt, and she cannot sicken or die.

## Need

A quantity that falls on its own with the passage of **real** time and is raised by an **Action**. Coco has exactly three:

The three run on deliberately different clocks, and which clock a Need is on is the
whole of its character:

- **Hunger** — empties in **5 hours**, raised **one bar segment at a time** by feeding.
  She picks at food all day the way a bird does; a beakful is not a meal. It is a true
  clock: it runs whether or not the app is on screen, so any absence past five hours
  finds her empty.
- **Affection** — empties in **3 hours**, the fastest thing in the model. Raised by
  playing (+60) and by petting (+8 a touch, up to 60 an hour). It is **not** a clock:
  it falls only while the app is actually on screen, because she misses you while she
  is *with* you. Charged against a shut lid it would read zero every morning whatever
  anyone did.
- **Energy** — empties in **8 hours awake**, restored only by sleeping. Also not a
  clock: time the app was not running is time she was not awake for, so it rests her.
  Sitting still is the cheap case — **flying costs three times as much**, charged as it
  happens, so a bird that has spent the afternoon in the air is genuinely tired. Playing
  costs 20 outright on top of the flying the game itself makes her do.

Needs measure *what Coco lacks attention in*, not what she deserves. A Need at its floor changes how she looks and moves; it never changes whether she is there.

## Mood

Coco's visible emotional state, **derived from Hunger and Affection only** — deliberately *not* from Energy, which governs sleep instead. Mood is the **lowest** of the two, not their average, so that the menubar silhouette is actionable: if Mood is low, something specific is wrong and the menu names it.

Mood has four levels: **Happy**, **Content**, **Meh**, **Sad**. Sad is the floor.

## Action

Something the human does *to* Coco that raises a Need.

- **Feed**, **Play**, **Sleep** — invoked from the menubar.
- **Petting** — invoked by clicking Coco directly; the only Action reachable without the menu.

An Action Coco does not currently want is **refused in character** — she turns her head away — never greyed out.

## Behaviour

What Coco is doing right now: resting, walking, flying, eating, playing, sleeping, being dragged, being petted, celebrating. Exactly one at a time. Behaviour is chosen by Coco (autonomously, or in response to her Needs) or forced by the human (dragging, an Action).

## Nap and Deep Sleep

Two different sleeps, distinguished by what wakes her.

- A **Nap** is triggered by the machine going idle. Any human activity ends it.
- **Deep Sleep** is triggered by Energy running out. Human activity does *not* end it; she sleeps until Energy is substantially restored. She can be dragged awake, but stays drowsy. **Sleep** from the menu is a Deep Sleep with a timer on it, and it ends when that timer says so.

The distinction exists so that Energy can actually recover: a sleep that any mouse movement interrupts is a sleep that never happens.

They also **recover at different rates**, which is the lever that decides how often Coco is seen asleep. Deep Sleep fills her in half an hour, so an episode lasts about twelve minutes — long enough to watch, short enough not to be a lock-out, and Feed and Play are both refused throughout. A Nap is worth far less: at the Deep Sleep rate a lunch break would refill her, she would never fall below the threshold again, and the sleeping pose, the perching and the startle would only ever happen with nobody watching.

## Catch-up

What happens to Needs across time when the app was not running — the Mac was asleep, or Coco was quit. Decay is charged against real elapsed time but **capped**, so a long absence costs no more than a short one, and a return after a long absence is greeted as a **reunion** rather than a reckoning.

Only **Hunger** decays across it: those hours without food were real. **Affection is frozen** and **Energy is restored** — a closed lid is neither a waking hour nor an hour spent ignoring her. Without the Energy rule a night was charged as twelve hours awake, and she was found flat out every morning, asleep until nearly lunchtime; without the Affection rule the same night would empty a three-hour bar four times over.

The **12-hour cap** now has almost nothing left to do: five hours already empties Hunger, so capping the charge changes no outcome. It survives as the guarantee that a long absence is never worse than a medium one.

A return after **48 hours** is a **reunion**: she greets it with a line in the speech bubble rather than letting it pass. The threshold sits well clear of a weekend of not opening the laptop, because a greeting that fires most Mondays is not a greeting.

## Birthday

A date the human configures. On that day Coco enters **Party State**, which **overrides Mood entirely** — she is festive regardless of her Needs — and shows a personal message once, on the first launch of the day.

## Party State

The birthday appearance: the **Hat** worn over every frame, a festive resting animation, and confetti when she is clicked. It outranks every Mood but yields to sleep.

## Sprite, Frame, Hat

A **Sprite** is one 48x48 image of Coco. A **Frame** is one Sprite in an animation sequence. Coco is drawn facing right and mirrored when she faces left, so a Frame is never drawn twice.

The **Hat** is drawn *into* the Frames rather than laid over them: every Sprite has a
hatted twin, and Party State swaps the whole set. It was an overlay at a fixed anchor
per pose family, which cost one asset instead of a second copy of every animation — but
one anchor cannot serve poses that hold the head in different places, and it floated
clear of the skull in all four flight Frames. The twins are generated, not drawn twice:
`scripts/make-hatted-sprites.py` finds the head in each Frame by its violet cheek patch
and places the hat against the crown, so a new animation costs nothing beyond re-running
it. A Frame with no hatted twin simply goes bare-headed.
