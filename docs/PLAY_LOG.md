# Session event logs

Location on Windows: `%APPDATA%/Godot/app_userdata/El Índice de Ceniza/logs/`.
`session_<UTC>_<process>_<ticks>.jsonl` is one map session. At 5 MB, logging continues
in `_001.jsonl`, `_002.jsonl`, etc. Existing parts and earlier sessions are retained.
The previous `play.log` is not deleted. Logs remain local; nothing is uploaded.

Every line is JSON: `schema`, `session`, `seq`, `utc`, `ticks_ms`, `event`, `context`,
`data`. Order by session and seq, not wall time. World context includes every hero's
cell and health, active hero, day, movement, army, resources, buildings, mines,
evidence IDs and planned simultaneous orders. Times are UTC; ticks measure elapsed
process time. Open/save failure warnings also appear in Godot's own log.

Main event pairs:

- `route_attempt`: accepted/rejected destination, intended path, cost, reason and
  prior context; current context shows the result. A province route is an order,
  not immediate movement. `turn_attempt` / `turn` reveal actual resolved movement.
- `talk_attempt`, `talk_request`, `talk`: exact player text, NPC, intent, reply,
  authored/model/rejected source, model timing/reason/tokens, language feedback.
- `order_offer`, `order_attempt`, `order`: costs, availability reason, typed stage,
  rejection feedback and committed resource/building changes.
- `mine_result`, `treasure_result`, `battle_attempt`, `battle_finished`.
- `ui_attempt`: button down with visible non-secret text fields, before action;
  `ui_action`, `ui_choice`, `ui_submit`, `ui_quantity`: resulting UI activity.
- `hero_select_attempt`, `hero_selected`, `location_open`, `location_close`,
  `camera` (at most twice a second), `save`, `load_result`, `load_applied`, `new_game`.

Raw player messages are retained intentionally for dialogue and usability analysis.
API credentials, request headers and model prompts are excluded/redacted. The log
is diagnostic evidence, not a deterministic replay or a replacement for save files.
A process crash can leave a final incomplete line; ignore that line when reading.

Tests set `PlayLog.test_path` to isolated files and remove them afterwards. Normal
headless tests never write player logs. Windowed smoke tests normally do, unless
using their own test path; identify them by process/session and content.
