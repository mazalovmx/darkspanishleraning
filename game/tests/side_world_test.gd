extends "res://tests/campaign_test.gd"
func run() -> void:
	var state := World.new("province_160x120_v1")
	check(not state.begin_encounter("BX001"),"Side battle cannot bypass language gate")
	learn(state)
	check(not state.begin_encounter("BX009"),"Side battle cannot bypass branch prerequisites")
	var gold: int = state.resources.gold
	check(state.begin_encounter("BX001"),"Actual world side encounter starts")
	var steps := 0
	while state.active_battle.outcome.is_empty() and steps < 200:
		var target := -1
		for i in state.active_battle.stacks.size():
			if state.active_battle.stacks[i].side == 1 and state.active_battle.count_at(i) > 0:
				target = i
				break
		state.active_battle.act("attack",target)
		steps += 1
	check(state.active_battle.outcome == "victory" and state.settle_encounter(),"Actual authored encounter won and settled")
	check(state.resources.gold == gold and state.side_cases.records.is_empty() and state.equipment.instances.is_empty(),"Victory grants custody only, no truth or component")
	check(not state.begin_encounter("BX001"),"Won side battle cannot be farmed")
	var saved := Save.snapshot(state)
	check(Save.decode(saved).has("state"),"Victory before inspection is a valid save")
	var cases = state.side_cases
	var models: Dictionary = cases.models("SX001")
	check(cases.submit(state,"SX001",models.access,"","","battle").ok,"Spanish inspection request uses actual victory")
	check(cases.submit(state,"SX001").ok,"Won evidence inspected")
	check(cases.submit(state,"SX001","","supported","overreach").ok,"Battle still requires reasoned comparison")
	cases.submit(state,"SX001",models.supported)
	cases.submit(state,"SX001",models.independent)
	check(Save.decode(Save.snapshot(state)).has("state"),"Partial language progress saves")
	state.end_turn()
	check(cases.submit(state,"SX001",models.recall).ok and state.equipment.instances.size() == 1,"Later recall awards unique component")
	check(Save.decode(Save.snapshot(state)).has("state"),"Completed violent route and reward save together")
	var definition: Dictionary = cases.battles.BX010
	visit(state,definition.location_id)
	state.end_turn()
	check(state.begin_encounter("BX010"),"Another branch has independent encounter")
	state.active_battle.act("retreat")
	check(state.settle_encounter(),"Side encounter retreat settles")
	check(cases.submit(state,"SX010",cases.models("SX010").access,"","","peaceful").ok,"Retreat leaves peaceful route available")
	saved = Save.snapshot(state)
	check(Save.decode(saved).has("state"),"Retreat and peaceful custody restore together")
	var bad := saved.duplicate(true)
	bad.strategy.encounters.BX009 = {"outcome":"victory","day":1}
	check(not Save.decode(bad).has("state"),"Encounter cannot predate branch prerequisites")
	var old := Save.snapshot(World.new("province_160x120_v1"))
	old.version = 10
	old.strategy.erase("side_cases")
	var restored := Save.decode(old)
	check(restored.has("state") and restored.state.side_cases.records.is_empty(),"V10 migration invents no optional progress")
	print("Side world checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
