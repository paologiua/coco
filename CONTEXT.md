# Coco — domain glossary

A macOS desktop pet: a pixel-art budgerigar who lives on the screen.

## Coco

The bird herself. One instance, always present while the app runs. She is a *companion*, not a chore: nothing she does is designed to induce guilt, and she cannot sicken or die.

## Need

A quantity that falls on its own with the passage of **real** time and is raised by an **Action**. Coco has exactly three:

- **Hunger** — raised by feeding.
- **Affection** — raised by playing and by petting.
- **Energy** — spent by being awake, restored only by sleeping.

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
- **Deep Sleep** is triggered by Energy running out. Human activity does *not* end it; she sleeps until Energy is substantially restored. She can be dragged awake, but stays drowsy.

The distinction exists so that Energy can actually recover: a sleep that any mouse movement interrupts is a sleep that never happens.

## Catch-up

What happens to Needs across time when the app was not running — the Mac was asleep, or Coco was quit. Decay is charged against real elapsed time but **capped**, so a long absence costs no more than a short one, and a return after a long absence is greeted as a **reunion** rather than a reckoning.

## Birthday

A date the human configures. On that day Coco enters **Party State**, which **overrides Mood entirely** — she is festive regardless of her Needs — and shows a personal message once, on the first launch of the day.

## Party State

The birthday appearance: the **Hat** worn over every frame, a festive resting animation, and confetti when she is clicked. It outranks every Mood but yields to sleep.

## Sprite, Frame, Hat

A **Sprite** is one 48x48 image of Coco. A **Frame** is one Sprite in an animation sequence. Coco is drawn facing right and mirrored when she faces left, so a Frame is never drawn twice.

The **Hat** is an overlay Sprite drawn on top of any Frame at a fixed anchor on Coco's head, so Party State costs one asset rather than a second copy of every animation.
