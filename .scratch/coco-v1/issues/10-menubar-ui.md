# 10 — Menubar UI and settings

Type: task
Status: resolved
Blocked by: 05, 08
Parent: [map](../map.md)

## Question

The menu, and the settings window behind it.

- Status row: the colour mood head, and the three Needs as **pixel-art bars** with the icons in `Assets/UI/`.
- Actions: Feed, Play, Sleep — refused **in character** rather than greyed out.
- `Hide Coco`, and `Quit`.
- Settings: the **birthday date**, launch at login, and Coco's size. This must be a **separate ordinary `NSWindow`**, not the panel: a non-activating panel can never become key and therefore cannot hold a text insertion point.
- Launch at login is `SMAppService.mainApp.register()`, verified to work with an ad-hoc signature. Handle and surface its error cases rather than failing silently.

## Answer

The menu carries a drawn status block, the three actions, hiding, settings and quit; settings live in their own ordinary window.

`Sources/Coco/StatusView.swift`, `Sources/Coco/SettingsWindow.swift`, plus the menu in `AppDelegate`.

**The status block is drawn, not assembled from controls.** A system progress bar next to a pixel bird looks borrowed from another app, so the Needs are ten discrete blocks in the palette's colours. Text and empty blocks use semantic colours, so the block reads correctly in both a light and a dark menu.

**Refusal is shown on Coco, not in the menu.** Feeding her when she is full turns her back for a moment rather than greying an item — free, because mirroring already existed for facing, and it says something about her rather than about the interface.

**Two bugs found by the human, one of them serious.**

1. **Opening Settings silently set the birthday to 1 January.** The month popup started on January whether or not a birthday had ever been chosen, so any interaction in that window — even ticking launch-at-login — wrote 1 January. On this app that is close to fatal: the birthday is the entire point, and the failure is silent and plausible-looking. Fixed by leading the list with "Not set" and writing `nil` until a real month is chosen.
2. **The bars overlapped the mood sentence.** Now the sentence sits on top and the bars are pinned to the right edge with their icons immediately left, so the three rows stay aligned however long the sentence is.

**Sizes were renumbered** to Small 1x / Medium 2x / Large 3x, with Medium the default — that is the size the recipient meets Coco at.

**`scripts/dev-state.py`** edits the saved state from outside and relaunches her. This is the payoff for keeping state as readable JSON: no debug menu inside the app that would then have to be remembered and hidden before the gift is given.
