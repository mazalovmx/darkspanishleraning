extends "res://tests/campaign_test.gd"
## Owned mines are contested on the map (master spec 12): weekly raiders stop the
## income until a victory over them.
func run() -> void:
	var state := World.new("province_160x120_v1")
	var economy = state.economy
	var mine: Dictionary = economy.site(state, "mine_wood")
	state.hero_cell = Vector2i(mine.position[0], mine.position[1])
	state._reveal_from(state.hero_cell)
	check(economy.claim(state, "mine_wood", economy.claim_model(state, "mine_wood")), "Claim the wood mine on day 1")
	check(not economy.contested(state, "mine_wood") and economy.raid_day(state, "mine_wood") == 0, "Not contested in its first week")
	state.day = 6
	var wood: int = state.resources.wood
	economy.advance_day(state)
	check(state.resources.wood == wood + 2, "An uncontested mine pays")
	state.day = 8
	check(economy.raid_day(state, "mine_wood") == 8 and economy.contested(state, "mine_wood"), "Raiders arrive a week after the claim")
	wood = state.resources.wood
	economy.advance_day(state)
	check(state.resources.wood == wood, "A contested mine pays nothing")
	var raid: Dictionary = state.encounter_definition(economy.raid_id("mine_wood"))
	check(not raid.enemies.is_empty() and raid.position == mine.position, "The raid is a battle on the mine")
	state.encounters[economy.raid_id("mine_wood")] = {"outcome": "defeat", "day": 8}
	check(economy.contested(state, "mine_wood"), "A lost battle leaves it contested")
	state.encounters[economy.raid_id("mine_wood")] = {"outcome": "victory", "day": 9}
	state.day = 9
	check(not economy.contested(state, "mine_wood"), "A victory frees the mine")
	wood = state.resources.wood
	economy.advance_day(state)
	check(state.resources.wood == wood + 2, "Income resumes after the victory")
	check(Save.decode(Save.snapshot(state)).has("state"), "A raid victory survives a save")
	state.day = 15
	check(economy.contested(state, "mine_wood"), "The next raid comes a week later")
	check(state.encounter_definition("raid_mine_invented").is_empty(), "Unknown raid ids are refused")
	print("Mine contest checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
