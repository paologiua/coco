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

An Action Coco does not currently want is **refused in character** — she turns her head
away — never greyed out. That holds while there is a Coco on screen to do the refusing.
**Hidden or asleep she cannot answer at all**, and those menu items are disabled: not
because she would say no, but because there is nobody there to say it. Left live they did
nothing whatsoever when clicked, which is worse than either.

## Behaviour

What Coco is doing right now: resting, walking, flying, eating, playing, sleeping, being dragged, being petted, celebrating. Exactly one at a time. Behaviour is chosen by Coco (autonomously, or in response to her Needs) or forced by the human (dragging, an Action).

## Nap and Deep Sleep

Two different sleeps, distinguished by what wakes her.

- A **Nap** is triggered by the machine going idle. Any human activity ends it.
- **Deep Sleep** is triggered by Energy running out. Human activity does *not* end it; she sleeps until Energy is substantially restored. She can be dragged awake, but stays drowsy. **Sleep** from the menu is a Deep Sleep with a timer on it, and it ends when that timer says so.

The distinction exists so that Energy can actually recover: a sleep that any mouse movement interrupts is a sleep that never happens.

They also **recover at different rates**, which is the lever that decides how often Coco is seen asleep. Deep Sleep fills her in half an hour, so an episode lasts about twelve minutes — long enough to watch, short enough not to be a lock-out, and Feed and Play are both refused throughout. A Nap is worth far less: at the Deep Sleep rate a lunch break would refill her, she would never fall below the threshold again, and the sleeping pose, the perching and the startle would only ever happen with nobody watching.

## Catch-up

What happens to Needs across time when the app was not running — the Mac was asleep, or Coco was quit. Decay is charged against real elapsed time but **capped**, so a long absence costs no more than a short one. A long absence is no longer greeted: see below.

Only **Hunger** decays across it: those hours without food were real. **Affection is frozen** and **Energy is restored** — a closed lid is neither a waking hour nor an hour spent ignoring her. Without the Energy rule a night was charged as twelve hours awake, and she was found flat out every morning, asleep until nearly lunchtime; without the Affection rule the same night would empty a three-hour bar four times over.

The **12-hour cap** now has almost nothing left to do: five hours already empties Hunger, so capping the charge changes no outcome. It survives as the guarantee that a long absence is never worse than a medium one.

The greeting that used to mark a long absence is gone, along with every other speech
bubble: the welcome, the reunion and the birthday line. Coco says things by doing them
now — she hatches out of an egg the first time, and hands over a letter on her birthday.

## Birthday

A date the human configures. On that day Coco enters **Party State**, which **overrides Mood entirely** — she is festive regardless of her Needs — and shows a personal message once, on the first launch of the day.

## Party State

The birthday appearance: the **Hat** worn over every frame, a festive resting animation, and confetti when she is clicked. It outranks every Mood but yields to sleep.

## Sprite, Frame, Hat

A **Sprite** is one 192x144 image of Coco, drawn at one point per pixel — the size
she is shown at, with no magnification. She was stored at 48 pixels and doubled on
screen, which discarded seven eighths of what the sheets hold and then made every
surviving pixel twice as coarse; that, and not the conversion, was what made her look
grainy. There is one size and no setting for it. A **Frame** is one Sprite in an animation
sequence. Coco is drawn facing right and mirrored when she faces left, so a Frame is
never drawn twice.

Frames arrive as large drawn sheets and are brought in by `scripts/import-sheets.py`,
which normalises them: the sheets are drawn at different scales — nearly 1.9x between
the widest and narrowest — so each is scaled by the bird's *standing height* rather than
by its bounding box, and every frame in a sheet is anchored on the **tail tip and the
ground line** so the frames register against each other. The tail is the anchor because
the feet are not reliable: with her head down at the ground, the lowest pixels are her
beak.

The **Hat** is drawn *into* the Frames: every Sprite has a hatted twin, and Party State
swaps the whole set. It was briefly an overlay stamped on at a computed anchor, and
before that at one fixed anchor per pose family; both are gone. The twins are now drawn
as part of the art itself, so nothing is positioned at runtime and the hat sits on her
head in every pose because it was painted there. A Frame with no hatted twin simply goes
bare-headed.
