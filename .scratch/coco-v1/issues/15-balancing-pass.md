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
