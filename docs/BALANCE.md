# Balance pass

Written 2026-10-08. This is an automated probe, not a playtest: no human has played
these battles. `game/tests/balance_sim.gd` (not part of the test runner) auto-plays
every guarded encounter 20 times (seeds 1-20) with a simple player policy (attack the
enemy stack with the least health; no abilities, no defending, no equipment bonuses),
using three reference armies:

| Army | Stacks |
|---|---|
| start | 8 militia, 4 archers (the starting army) |
| mid | 24 militia, 14 archers, 6 veteran guards |
| strong | 20 veteran guards, 30 archers, 6 relic sentinels, 30 militia |

Run: `godot --headless --path game --script res://tests/balance_sim.gd`.

## What the first run showed

The mid army won every encounter, and the starting army beat every ghost knight, every
mine guard and every raid. Four side-case enemy units (watchman, hired blade, crossbow
guard, enforcer) had attack and defense 0.

## Changes

- Unit stats: watchman 2/4, hired blade 4/2, crossbow guard 4/1, enforcer 5/5
  (attack/defense).
- Side-case battles scale with the case's curriculum block: counts × (1 + 0.5 ×
  (block − 1)), so ×1 in block 1 up to ×4 in block 7.
- Ghost knights scale with their minimum block: counts × (1 + 0.5 × block).
- Mine guards: gold 24 bandits + 8 hired blades; mercury 14 bandits + 4 crossbow
  guards; sulfur 16 bandits + 4 crossbow guards; crystal 8 ghost guards; gems 10 ghost
  guards. Raids are half the guard, rounded up.
- Treasure guards × 2.5.

## Result after the changes (win rate over 20 seeds)

| Group | start | mid | strong |
|---|---|---|---|
| Opening road | 100% | 100% | 100% |
| Side battles, block 1-2 | mostly 100% | 100% | 100% |
| Side battles, block 6-7 | 0% | 0-90% | 100% |
| Ghost knights NK02-NK08 | 0% | 100% | 100% |
| Guarded mines | 0-15% | 100% | 100% |
| Raids on wood/ore/mercury/crystal/gems | 100% | 100% | 100% |
| Marjal Negro caches | 0% | 100% | 100% |

Full table of the final run:

```text
encounter	start	mid	strong
opening	100%	100%	100%
BX001	100%	100%	100%
BX002	100%	100%	100%
BX003	55%	100%	100%
BX004	0%	100%	100%
BX005	0%	100%	100%
BX006	0%	100%	100%
BX007	0%	70%	100%
BX008	0%	0%	100%
BX009	0%	0%	100%
BX010	100%	100%	100%
BX011	100%	100%	100%
BX012	0%	100%	100%
BX013	80%	100%	100%
BX014	0%	100%	100%
BX015	0%	100%	100%
BX016	0%	10%	100%
BX017	0%	30%	100%
BX018	0%	0%	100%
BX019	100%	100%	100%
BX020	100%	100%	100%
BX021	95%	100%	100%
BX022	65%	100%	100%
BX023	0%	100%	100%
BX024	0%	100%	100%
BX025	0%	100%	100%
BX026	0%	0%	100%
BX027	0%	0%	100%
BX028	100%	100%	100%
BX029	100%	100%	100%
BX030	95%	100%	100%
BX031	35%	100%	100%
BX032	0%	100%	100%
BX033	0%	100%	100%
BX034	0%	90%	100%
BX035	0%	0%	100%
BX036	0%	0%	100%
BX037	100%	100%	100%
BX038	100%	100%	100%
BX039	55%	100%	100%
BX040	0%	100%	100%
BX041	0%	100%	100%
BX042	0%	100%	100%
BX043	0%	70%	100%
BX044	0%	0%	100%
BX045	0%	0%	100%
BX046	100%	100%	100%
BX047	100%	100%	100%
BX048	0%	100%	100%
BX049	80%	100%	100%
BX050	0%	100%	100%
BX051	0%	100%	100%
BX052	0%	10%	100%
BX053	0%	30%	100%
BX054	0%	0%	100%
BX055	100%	100%	100%
BX056	100%	100%	100%
BX057	95%	100%	100%
BX058	65%	100%	100%
BX059	0%	100%	100%
BX060	0%	100%	100%
BX061	0%	100%	100%
BX062	0%	0%	100%
BX063	0%	0%	100%
BX064	100%	100%	100%
BX065	100%	100%	100%
BX066	95%	100%	100%
BX067	35%	100%	100%
BX068	0%	100%	100%
BX069	0%	100%	100%
BX070	0%	90%	100%
BX071	0%	0%	100%
BX072	0%	0%	100%
BX073	100%	100%	100%
BX074	100%	100%	100%
BX075	55%	100%	100%
BX076	0%	100%	100%
BX077	0%	100%	100%
BX078	0%	100%	100%
BX079	0%	70%	100%
BX080	0%	0%	100%
BX081	0%	0%	100%
BX082	100%	100%	100%
BX083	100%	100%	100%
BX084	0%	100%	100%
BX085	80%	100%	100%
BX086	0%	100%	100%
BX087	0%	100%	100%
BX088	0%	10%	100%
BX089	0%	30%	100%
BX090	0%	0%	100%
BX091	100%	100%	100%
BX092	100%	100%	100%
BX093	95%	100%	100%
BX094	65%	100%	100%
BX095	0%	100%	100%
BX096	0%	100%	100%
BX097	0%	100%	100%
BX098	0%	0%	100%
BX099	0%	0%	100%
BX100	100%	100%	100%
BX101	100%	100%	100%
BX102	95%	100%	100%
BX103	35%	100%	100%
BX104	0%	100%	100%
BX105	0%	100%	100%
BX106	0%	90%	100%
BX107	0%	0%	100%
BX108	0%	0%	100%
NK01	100%	100%	100%
NK02	0%	100%	100%
NK03	0%	100%	100%
NK04	0%	100%	100%
NK05	0%	100%	100%
NK06	0%	100%	100%
NK07	0%	100%	100%
NK08	0%	100%	100%
raid_mine_wood	100%	100%	100%
raid_mine_ore	100%	100%	100%
guard_mine_gold	0%	100%	100%
raid_mine_gold	10%	100%	100%
guard_mine_mercury	0%	100%	100%
raid_mine_mercury	100%	100%	100%
guard_mine_sulfur	0%	100%	100%
raid_mine_sulfur	95%	100%	100%
guard_mine_crystal	15%	100%	100%
raid_mine_crystal	100%	100%	100%
guard_mine_gems	0%	100%	100%
raid_mine_gems	100%	100%	100%
TR01	0%	100%	100%
TR02	0%	100%	100%
TR03	0%	100%	100%
TR04	0%	100%	100%
TR05	0%	100%	100%
TR06	0%	100%	100%
```

## Limits

The policy is naive, so a human using defend and abilities should do better than these
numbers. The battle probe measures battles only; economy pacing is the next section. The 4-5 h critical path is not measured here (see
MEASUREMENTS.md). All values remain authored estimates until someone plays them.

## Economy pass

Written 2026-10-08. This is arithmetic, not a playtest. The check compares weekly gold
income with the most gold a player could spend each week on recruits and militia
upgrades. It counts the default recruits only, not hero-specific ones, and leaves out
building costs. Run: `python3 tools/economy_check.py game/content/economy/strategy.json 100` (the last
argument is the gold mine's daily income).

Before the pass, income was 3.4 to 4.1 times the weekly recruit spend at every stage,
so gold stopped being a constraint after the first days:

| Stage | Income/week | Max recruit spend/week | Ratio |
|---|---|---|---|
| Weeks 1-2: LOC01 hall and barracks | 700 | 180 | 3.89 |
| Mid: 3 towns with hall, barracks and range, plus the gold mine | 3,850 | 1,140 | 3.38 |
| Late: every building in every town, plus the gold mine | 10,500 | 2,540 | 4.13 |

Changes:

- Income: council hall 100 → 40 gold/day; treasury 250 → 80; gold mine 250 → 100;
  the SQ05 "scale the engine" outcome +100 → +50.
- Recruit prices (gold): militia 15 → 20 (also at the market), archers 25 → 35, relic
  sentinel 90 → 120, novice 12 → 16, hospitaller 45 → 60, inquisitorial guard 70 → 95,
  thief 14 → 18, knife fighter 35 → 45, crossbow mercenary 40 → 55, relay automaton
  200 → 260; militia → veteran upgrade 20 → 30.
- Unchanged: building costs, starting resources (300 gold, 5 wood, 5 ore), weekly
  recruit counts, the other mines.

After the pass:

| Stage | Income/week | Max recruit spend/week | Ratio |
|---|---|---|---|
| Weeks 1-2 | 280 | 240 | 1.17 |
| Mid | 1,540 | 1,560 | 0.99 |
| Late | 3,780 | 3,520 | 1.07 |

Since building costs come on top, the player now has to choose between buildings and
recruits for most of the game. The "strong" army in the battle table costs about 3,370
gold at the new prices (50 militia, 20 upgrades, 30 archers, 6 sentinels), about a week
of late-game income. Whether that pacing feels right is not known until someone plays it.

## Hex field (Heroes-style battles)

Written 2026-10-08, after battles moved to an 11×7 hex field with movement (master spec
13): stacks start in the outer columns, walk up to their speed, melee needs contact,
shooters shoot unless an enemy is next to them, ghosts fly, one to four rocks block
hexes. Unit speeds: militia, archers, veteran guard, watchman, crossbow guard,
hospitaller, inquisitorial guard, crossbow mercenary 4; bandits, hired blade, novice 5;
thief, knife fighter, ghost guard (flying) 6; relic sentinel, enforcer, relay automaton 3.

The probe's policy now also walks: "attack the weakest enemy" moves next to it when it
can, else advances towards it. It never waits, defends or uses rocks, so it charges into
enemy shooters; a human who lets the enemy come to the archers should do better.

Compared with the table above: the low blocks stay won by the starting army (some move
either way, e.g. BX003 55% → 0%, BX013 80% → 100%); the medium army loses more of the
block 6 side battles (BX007 70% → 0%, BX034 90% → 25%, BX017 30% → 75%); the strong
army still wins everything except BX027/063/099 at 95%; ghost knights, mines, raids and
caches are unchanged in shape. No unit numbers were changed for the hex field: the
ramp with the curriculum holds, and the probe cannot judge positional play.

```text
encounter	start	mid	strong
opening	100%	100%	100%
BX001	100%	100%	100%
BX002	100%	100%	100%
BX003	0%	100%	100%
BX004	0%	100%	100%
BX005	0%	100%	100%
BX006	0%	100%	100%
BX007	0%	0%	100%
BX008	0%	0%	100%
BX009	0%	0%	100%
BX010	100%	100%	100%
BX011	100%	100%	100%
BX012	10%	100%	100%
BX013	100%	100%	100%
BX014	0%	100%	100%
BX015	0%	100%	100%
BX016	0%	35%	100%
BX017	0%	75%	100%
BX018	0%	0%	100%
BX019	100%	100%	100%
BX020	100%	100%	100%
BX021	100%	100%	100%
BX022	30%	100%	100%
BX023	0%	100%	100%
BX024	0%	100%	100%
BX025	0%	100%	100%
BX026	0%	0%	100%
BX027	0%	0%	95%
BX028	100%	100%	100%
BX029	100%	100%	100%
BX030	70%	100%	100%
BX031	0%	100%	100%
BX032	0%	100%	100%
BX033	0%	100%	100%
BX034	0%	25%	100%
BX035	0%	0%	100%
BX036	0%	0%	100%
BX037	100%	100%	100%
BX038	100%	100%	100%
BX039	0%	100%	100%
BX040	0%	100%	100%
BX041	0%	100%	100%
BX042	0%	100%	100%
BX043	0%	0%	100%
BX044	0%	0%	100%
BX045	0%	0%	100%
BX046	100%	100%	100%
BX047	100%	100%	100%
BX048	10%	100%	100%
BX049	100%	100%	100%
BX050	0%	100%	100%
BX051	0%	100%	100%
BX052	0%	35%	100%
BX053	0%	75%	100%
BX054	0%	0%	100%
BX055	100%	100%	100%
BX056	100%	100%	100%
BX057	100%	100%	100%
BX058	30%	100%	100%
BX059	0%	100%	100%
BX060	0%	100%	100%
BX061	0%	100%	100%
BX062	0%	0%	100%
BX063	0%	0%	95%
BX064	100%	100%	100%
BX065	100%	100%	100%
BX066	70%	100%	100%
BX067	0%	100%	100%
BX068	0%	100%	100%
BX069	0%	100%	100%
BX070	0%	25%	100%
BX071	0%	0%	100%
BX072	0%	0%	100%
BX073	100%	100%	100%
BX074	100%	100%	100%
BX075	0%	100%	100%
BX076	0%	100%	100%
BX077	0%	100%	100%
BX078	0%	100%	100%
BX079	0%	0%	100%
BX080	0%	0%	100%
BX081	0%	0%	100%
BX082	100%	100%	100%
BX083	100%	100%	100%
BX084	10%	100%	100%
BX085	100%	100%	100%
BX086	0%	100%	100%
BX087	0%	100%	100%
BX088	0%	35%	100%
BX089	0%	75%	100%
BX090	0%	0%	100%
BX091	100%	100%	100%
BX092	100%	100%	100%
BX093	100%	100%	100%
BX094	30%	100%	100%
BX095	0%	100%	100%
BX096	0%	100%	100%
BX097	0%	100%	100%
BX098	0%	0%	100%
BX099	0%	0%	95%
BX100	100%	100%	100%
BX101	100%	100%	100%
BX102	70%	100%	100%
BX103	0%	100%	100%
BX104	0%	100%	100%
BX105	0%	100%	100%
BX106	0%	25%	100%
BX107	0%	0%	100%
BX108	0%	0%	100%
NK01	100%	100%	100%
NK02	0%	100%	100%
NK03	0%	100%	100%
NK04	0%	100%	100%
NK05	0%	100%	100%
NK06	0%	100%	100%
NK07	0%	100%	100%
NK08	0%	100%	100%
raid_mine_wood	100%	100%	100%
raid_mine_ore	100%	100%	100%
guard_mine_gold	0%	100%	100%
raid_mine_gold	5%	100%	100%
guard_mine_mercury	0%	100%	100%
raid_mine_mercury	100%	100%	100%
guard_mine_sulfur	0%	100%	100%
raid_mine_sulfur	100%	100%	100%
guard_mine_crystal	40%	100%	100%
raid_mine_crystal	100%	100%	100%
guard_mine_gems	0%	100%	100%
raid_mine_gems	100%	100%	100%
TR01	0%	100%	100%
TR02	0%	100%	100%
TR03	0%	100%	100%
TR04	0%	100%	100%
TR05	0%	100%	100%
TR06	0%	100%	100%
```

## Wait and range penalty

Written 2026-10-08. Added the Heroes III "wait" command (the probe never uses it) and
half damage for shots beyond 6 hexes. The player's archers start 10 hexes from the
enemy, so the probe's opening volleys halve: several medium-army side battles got
harder (BX016/017 35%/75% → 15%/15%, BX024/025 100% → 90%/85%, NK08 100% → 85%), a few
easier (BX034 25% → 40%, BX007 0% → 10%). The strong army still wins everything. A
player who waits for the enemy to come within 6 hexes keeps full damage.

```text
encounter	start	mid	strong
opening	100%	100%	100%
BX001	100%	100%	100%
BX002	100%	100%	100%
BX003	0%	100%	100%
BX004	0%	100%	100%
BX005	0%	100%	100%
BX006	0%	100%	100%
BX007	0%	10%	100%
BX008	0%	0%	100%
BX009	0%	0%	100%
BX010	100%	100%	100%
BX011	100%	100%	100%
BX012	0%	100%	100%
BX013	100%	100%	100%
BX014	0%	100%	100%
BX015	0%	100%	100%
BX016	0%	15%	100%
BX017	0%	15%	100%
BX018	0%	0%	100%
BX019	100%	100%	100%
BX020	100%	100%	100%
BX021	100%	100%	100%
BX022	15%	100%	100%
BX023	0%	100%	100%
BX024	0%	90%	100%
BX025	0%	85%	100%
BX026	0%	0%	100%
BX027	0%	0%	95%
BX028	100%	100%	100%
BX029	100%	100%	100%
BX030	40%	100%	100%
BX031	0%	100%	100%
BX032	0%	100%	100%
BX033	0%	100%	100%
BX034	0%	40%	100%
BX035	0%	0%	100%
BX036	0%	0%	100%
BX037	100%	100%	100%
BX038	100%	100%	100%
BX039	0%	100%	100%
BX040	0%	100%	100%
BX041	0%	100%	100%
BX042	0%	100%	100%
BX043	0%	10%	100%
BX044	0%	0%	100%
BX045	0%	0%	100%
BX046	100%	100%	100%
BX047	100%	100%	100%
BX048	0%	100%	100%
BX049	100%	100%	100%
BX050	0%	100%	100%
BX051	0%	100%	100%
BX052	0%	15%	100%
BX053	0%	15%	100%
BX054	0%	0%	100%
BX055	100%	100%	100%
BX056	100%	100%	100%
BX057	100%	100%	100%
BX058	15%	100%	100%
BX059	0%	100%	100%
BX060	0%	90%	100%
BX061	0%	85%	100%
BX062	0%	0%	100%
BX063	0%	0%	95%
BX064	100%	100%	100%
BX065	100%	100%	100%
BX066	40%	100%	100%
BX067	0%	100%	100%
BX068	0%	100%	100%
BX069	0%	100%	100%
BX070	0%	40%	100%
BX071	0%	0%	100%
BX072	0%	0%	100%
BX073	100%	100%	100%
BX074	100%	100%	100%
BX075	0%	100%	100%
BX076	0%	100%	100%
BX077	0%	100%	100%
BX078	0%	100%	100%
BX079	0%	10%	100%
BX080	0%	0%	100%
BX081	0%	0%	100%
BX082	100%	100%	100%
BX083	100%	100%	100%
BX084	0%	100%	100%
BX085	100%	100%	100%
BX086	0%	100%	100%
BX087	0%	100%	100%
BX088	0%	15%	100%
BX089	0%	15%	100%
BX090	0%	0%	100%
BX091	100%	100%	100%
BX092	100%	100%	100%
BX093	100%	100%	100%
BX094	15%	100%	100%
BX095	0%	100%	100%
BX096	0%	90%	100%
BX097	0%	85%	100%
BX098	0%	0%	100%
BX099	0%	0%	95%
BX100	100%	100%	100%
BX101	100%	100%	100%
BX102	40%	100%	100%
BX103	0%	100%	100%
BX104	0%	100%	100%
BX105	0%	100%	100%
BX106	0%	40%	100%
BX107	0%	0%	100%
BX108	0%	0%	100%
NK01	100%	100%	100%
NK02	0%	100%	100%
NK03	0%	100%	100%
NK04	0%	100%	100%
NK05	0%	100%	100%
NK06	0%	100%	100%
NK07	0%	100%	100%
NK08	0%	85%	100%
raid_mine_wood	100%	100%	100%
raid_mine_ore	100%	100%	100%
guard_mine_gold	0%	100%	100%
raid_mine_gold	5%	100%	100%
guard_mine_mercury	0%	100%	100%
raid_mine_mercury	100%	100%	100%
guard_mine_sulfur	0%	100%	100%
raid_mine_sulfur	95%	100%	100%
guard_mine_crystal	30%	100%	100%
raid_mine_crystal	100%	100%	100%
guard_mine_gems	0%	100%	100%
raid_mine_gems	100%	100%	100%
TR01	0%	100%	100%
TR02	0%	100%	100%
TR03	0%	100%	100%
TR04	0%	100%	100%
TR05	0%	100%	100%
TR06	0%	100%	100%
```
