# Measurements (master spec 43)

Written 2026-10-08. `game/tests/measure_critical_path.gd` (a probe, not a suite) walks
the mainline with the game's own rules: real A* paths on the province grid, terrain
costs, 18 movement points per hero per day shared by the party, the northern pass
opened by the opening report, Inés and Elias starting at Cárdena and Monte Ciego, and
the reunion at Santa Lucerna. It counts only what the player must do; optional cases,
side quests, treasures and battles beyond the opening are excluded.

## Measured

| Quantity | Value |
|---|---|
| Game days spent travelling on the mainline | 61 |
| Movement points spent | 1,171 |
| Journeys (legs) | 39 (no destination unreachable) |
| Mainline conclusion cards to write | 35 |
| Mainline decisions (MQ10, the council) | 2 |
| Act I evidence steps (notes and reasoning) | 14 |
| Lesson sentences (31 lessons) | 124 |
| Minimum days the course needs (delayed recall) | 8 |

Travel, not the course, sets the pace: the course fits inside the 61 days.

## Estimate (assumptions, not measurements)

Assuming about one minute per typed sentence for a B1 player (read the prompt, write,
read the feedback) and about one minute per travelled day (plan a route, resolve the
day), the mainline needs roughly 175 sentences ≈ 3 h plus 61 days ≈ 1 h, so about 4 h
before conversations, battles and reading. That is at the low end of the spec's 4–5 h
critical path. The optional content (108 cases with about four sentences each, four
side-quest chains, 30 treasures, battles) adds roughly 450+ sentences, which puts the
total in the region of the spec's 8–10 h. These minutes per action are guesses.

## Not done

No human has played the game; the real critical-path duration, the language-event
cadence (section 31) and the difficulty have not been observed. A first playtest
should time: the opening (Act I), one act of travel, and the council.
