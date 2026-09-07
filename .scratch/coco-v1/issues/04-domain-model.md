# 04 — Domain model: needs, mood, and the behaviour state machine

Type: grilling
Status: resolved
Blocked by: —
Parent: [map](../map.md)

## Question

Turn the agreed shape of the simulation into a written model precise enough to implement, captured in `CONTEXT.md`.

Settle:

- **Needs.** Hunger, Affection, Energy: units, range, and the decay rate for each. "Full to empty in about three days of neglect" is the agreed feel — turn it into numbers, and decide whether decay is linear.
- **Mood.** How a single Mood is derived from three Needs, and its discrete levels (these drive the menubar silhouette and the idle animation, so the level count is an art decision too).
- **The floor.** Coco never sickens or dies — what does the worst state actually look like, and does anything about her behaviour change beyond looking sad?
- **Actions.** Feed, Play, Sleep: what each does to which Need, whether they can be spammed, and any cooldown. Petting by clicking is an action too — decide what it gives and how it differs from Play.
- **The behaviour state machine.** The states (idle, walking, flying, eating, playing, sleeping, being dragged, being petted, celebrating) and the legal transitions between them — including which states interrupt which. Dragging Coco mid-meal has to do something sensible.
- **Sleep and waking.** Energy-low sleep versus idle-machine sleep, and what wakes her.
- **Offline catch-up.** The app is quit and reopened three days later, or the Mac is closed overnight. Needs decay against *real elapsed time*, so decide what happens on wake: instant application of three days of decay, a capped catch-up, or a gentler rule. This is the decision that determines whether reopening the app after a holiday is a happy moment or a guilt trip.
- **Time-of-day and the birthday check.** How the app notices 14 September, and what happens if the app is already running when midnight passes.

Consult `domain-modeling`. Output is `CONTEXT.md` (glossary only, no implementation detail) plus the numbers recorded in this ticket's answer.

## Answer

Glossary written to [`CONTEXT.md`](../../../CONTEXT.md). The tuning numbers live here, not there.

**Needs** are 0–100. Decay is linear, charged against real elapsed time:

| Need | Full → empty | Restored by |
|---|---|---|
| Hunger | 48 h | Feed |
| Affection | 72 h | Play, petting |
| Energy | 16 h **awake** | sleeping, 8 h to full |

Hunger falls faster than Affection because feeding is the action with the most immediate payoff; Affection is slow because it is what rewards showing up every day.

**Mood = min(Hunger, Affection)** — bucketed **Happy ≥70, Content 40–69, Meh 20–39, Sad <20**. Four levels, four menubar silhouettes.

Two decisions here overturned what charting had assumed:

1. **Energy is excluded from Mood.** With Energy in the average, Coco is sad every evening purely because she is tired — and the evening is when she is most looked at. Energy drives *sleep*, which is a state, not a sentiment.
2. **Mood is the minimum, not the average.** The average hides which Need is starving. The minimum makes the menubar icon actionable.

**Actions**

| Action | Effect | Refused when |
|---|---|---|
| Feed | Hunger +45 | Hunger > 85 |
| Play | Affection +30, Energy −10 | asleep, or Energy < 15 |
| Sleep | forces Deep Sleep | — |
| Petting (click) | Affection +4, **capped at +20/hour** | asleep |

Refusal is **in character** — she turns her head away — never a greyed-out control. The petting cap exists because without it, holding down the mouse maxes Affection in ten seconds and the toy is over.

**Sleep.** Deep Sleep below Energy 20; Nap after 15 minutes of machine idle. A Nap ends on any human activity; Deep Sleep persists until Energy ≥ 60 (about three hours) and can only be interrupted by dragging her, which leaves her drowsy.

**Catch-up.** Decay on return is **capped at 12 hours** no matter how long the absence. Beyond 24 hours away, the return plays the *happy* reaction, not the sad one — a holiday should read as a reunion, not a fine. Uncapped decay is what gets tamagotchis uninstalled; freezing time while quit feels fake. Guard against a backwards clock (timezone change, manual adjustment) by clamping elapsed time at zero.

**Birthday.** Party State overrides Mood entirely for the whole day — a birthday where the celebrant is sad because you forgot to feed them is a bug, not realism — but yields to sleep. The entry sequence with the personal message fires on the first launch of that day, tracked **by year** in the saved state so it still fires if the app was already running at midnight, and only once.
