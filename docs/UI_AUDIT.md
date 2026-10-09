# UI audit

Written 2026-10-09 for stage 0 of `UI_PLAN.md`, from `tests/screenshots.gd` rendered at
1280x720, 1366x768 and 1920x1080 and from the code. It lists what each screen is for and
what gets in the way; the stages of the plan work through the last column. Update the row
when a problem is fixed.

Shared findings:

- Sizes are literal numbers: 31 font overrides of 12-17 px and 13 of 20-34 px, each panel
  with its own position, size and margins. Text looks the same at the three window sizes
  because the canvas is stretched, so small text stays small on a larger monitor.
- Each window builds its own frame; titles, the "what to do" line and the close button sit
  in different places and are named differently (Volver / Volver al mapa / Volver al viaje /
  Volver sin pedido pendiente).
- Every window closed with Esc already, but no window opened from the keyboard and no
  control showed keyboard focus (both themes used an empty focus box). Fixed in stage 2:
  map keys as input actions, a focus frame in both themes, an "Ayuda" page.
- "Which window is open" was a hand-written list repeated in `world_map.gd`; the four
  identical copies are now `_modal_open()`. Shorter, differing lists in the button handlers
  remain.
- Explanations lived in hover tooltips only; the "Ayuda" page (H) now repeats them as text.

| Screen | The player's task | Always visible | Hidden until asked | Problems found | Stage |
|---|---|---|---|---|---|
| Map (`world_map.gd`) | plan travel, see what to do next | resources, day, heroes, movement, army count, buttons | terrain costs and controls (tooltip) | no line saying the current objective; no minimap on a 160x120 map; "Resolver órdenes" shares a row with "Tareas"; no warning before ending a day with things undone; an unaffordable route differs only by colour; hovering a cell says nothing about terrain | 3 |
| Location window (`world_map.gd`) | talk, inspect, buy, build | place name, description, speaker, input | topics and Spanish hints (tabs) | description box shows two lines and scrolls; action buttons at the bottom are small and unordered | 1, 3 |
| Task journal (`campaign_panel.gd`) | know what is open, done, not started | summary page | task text | tasks chosen from a dropdown instead of a list beside the detail; no way to show a task's place on the map; empty band under the text | 3 |
| Evidence notebook (`evidence_notebook.gd`) | record and compare evidence | guide line, finding, input | other pages (dropdown) | "Comparar pruebas" is the largest button although it is rarely available; pages in a dropdown | 1 |
| Lessons, vocabulary, dictionary (`curriculum_panel.gd`) | practise Spanish | four tabs | - | a locked block gives a general reason only | 4 |
| Equipment (`equipment_panel.gd`) | see what is worn, change it, hand over | body slots, backpack, item text | souls and troops (tabs) | no comparison with the item already worn; rarity by word exists, no reason shown when a piece cannot be equipped; recipient chosen from a plain list; no backpack capacity or undo | 4, 7 |
| Settlement (`strategy_panel.gd`, `town_view.gd`) | build, recruit, see income | buildings with state and yield, cost | - | resources written as one long sentence instead of the icon row; no "what will be left"; three-step order shown as scrolling text | 4 |
| Market (`market_panel.gd`) | buy by asking in Spanish | product, price, stock, gold | - | total shown, remaining gold not; close button changes its label | 4 |
| Local cases (`side_panel.gd`) | work an optional case | case text | other cases (dropdown) | a locked case says only "consolida los bloques anteriores"; mostly empty window | 4 |
| Knights (`ghost_panel.gd`) | counter a knight | list, orders | - | not reviewed in a window yet | 4 |
| Battle (`stack_arena.gd`) | choose the best action | round, acting stack, turn order, actions | - | no forecast of damage, losses or retaliation before confirming; reachable cells and the hovered target differ by tint only; turn order tiles are small and the next unit is not marked; no log of what happened; no keys on the action buttons | 5 |
| Title and settings (`ui/title_menu`) | start, continue, sound | - | - | no interface size setting | 6 |

Not planned (personal Windows game, COPILOT rule 14): gamepad, touch, TV safe zones, screen
narration, haptics, 4:3 and ultrawide reflow, a separate high-contrast theme.

## Status after the 2026-10-09 work (see STATE.md for each entry)

| Finding | Status |
|---|---|
| No objective line on the map | done: "▶ AHORA: …", click opens the journal |
| No minimap | done: bottom-left, click or drag moves the view, M toggles |
| End of day shares a row with "Tareas" | done: pinned under the panel, cannot scroll away |
| Unaffordable route by colour only | done: dashed, with the missing points in text |
| Hovering a cell says nothing | done: terrain and cost |
| No warning before ending a day | partly: a reminder line for a task recordable here; no confirmation by design |
| Journal: no "show on map" | done; list-beside-detail layout still open |
| Equipment: no comparison, silent failures | done: comparison line, swap, reasons |
| Equipment: recipient list, capacity, undo | open |
| Settlement and market: no "what is left" | done |
| Local cases and lessons: general lock reason | open |
| Battle: no forecast, no keys | done: forecast line, A D E H R |
| Battle: target states by tint, turn order, log | open |
| No keyboard reach, no focus frame, tooltips only | done: map keys, focus frames, "Ayuda" page |
| No interface size setting | done as window size / full screen, F11 |
| Literal sizes, each window its own frame | partly: tokens and a frame builder exist and the help page uses them; secondary texts inside windows raised to 16 px (body text there was already 18). The map panel keeps 13-15 px for lack of room, and no existing window was moved onto the shared frame |
| Close buttons named differently | open |
