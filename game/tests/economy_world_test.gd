extends "res://tests/strategy_economy_test.gd"
const Save = preload("res://src/save/save_game.gd")
func run() -> void:
	var state := World.new("province_160x120_v1")
	var economy = state.economy
	for resource in state.resources:
		state.resources[resource] = 10000
	check(buy(economy,state,"build","council_hall",1).get("committed",false),"World construction commits")
	var gold: int = state.resources.gold
	state.end_turn()
	check(state.resources.gold == gold + 100,"World day applies building income automatically")
	var phrases: Dictionary = economy.current_models(state,"build","barracks",1)
	economy.submit(state,"build","barracks",1,phrases.request)
	check(not state.select_hero("inquisitor"),"Strategic quote locks active hero")
	check(not state.begin_encounter("opening_road"),"Strategic quote blocks combat")
	economy.cancel()
	check(buy(economy,state,"build","barracks",1).get("committed",false),"Barracks constructed")
	check(buy(economy,state,"recruit","militia",4).get("committed",false),"World army recruitment")
	var site: Dictionary = economy.site(state,"mine_gold")
	state.hero_cell = Vector2i(site.position[0],site.position[1])
	state._reveal_from(state.hero_cell)
	var armies: Array = state.army.duplicate(true)
	check(state.begin_encounter("mine_gold"),"Guarded mine starts actual world battle")
	check(state.active_battle.data.opening.id == "mine_gold","Arena receives correct encounter")
	gold = state.resources.gold
	var steps := 0
	while state.active_battle.outcome.is_empty() and steps < 200:
		var target := -1
		for i in state.active_battle.stacks.size():
			if state.active_battle.stacks[i].side == 1 and state.active_battle.count_at(i) > 0:
				target = i
				break
		state.active_battle.act("attack",target)
		steps += 1
	check(state.active_battle.outcome == "victory","Mine defenders defeated through battle rules")
	check(state.settle_encounter(),"Mine battle settles")
	check(state.resources.gold == gold,"Mine victory does not reuse opening-road reward")
	check(not economy.mines.has("mine_gold"),"Victory alone does not bypass Spanish ownership order")
	check(economy.claim(state,"mine_gold",economy.claim_model(state,"mine_gold")),"Typed order claims won mine")
	check(not state.begin_encounter("mine_gold"),"Cleared mine cannot be farmed")
	state.end_turn()
	check(state.resources.gold == gold + 350,"Mine and building incomes add once")
	var snapshot := Save.snapshot(state)
	var restored := Save.decode(snapshot)
	check(restored.has("state"),"V8 economy and guarded encounter restore")
	if restored.has("state"):
		check(restored.state.economy.snapshot() == economy.snapshot(),"Complete economic ledger retained")
		gold = restored.state.resources.gold
		check(restored.state.economy.advance_day(restored.state).is_empty(),"Reload cannot collect income twice")
		restored.state.end_turn()
		check(restored.state.resources.gold == gold + 350,"Next loaded day pays correct income")
	var bad := snapshot.duplicate(true)
	bad.strategy.encounters.erase("mine_gold")
	check(not Save.decode(bad).has("state"),"Guarded ownership requires its saved victory")
	bad = snapshot.duplicate(true)
	bad.strategy.encounters.mine_wood = {"outcome":"victory","day":state.day}
	check(not Save.decode(bad).has("state"),"Cannot invent encounter on unguarded site")
	var old := Save.snapshot(World.new("province_160x120_v1"))
	old.version = 7
	old.strategy.erase("economy")
	check(Save.decode(old).has("state") and Save.decode(old).state.economy.buildings.is_empty(),"V7 adds empty economy without invented purchases")
	site = economy.site(state,"mine_sulfur")
	state.hero_cell = Vector2i(site.position[0],site.position[1])
	state._reveal_from(state.hero_cell)
	check(state.begin_encounter("mine_sulfur"),"Another site has independent defenders")
	state.active_battle.act("retreat")
	check(state.settle_encounter(),"Retreat from mine settles")
	check(not economy.claim(state,"mine_sulfur",economy.claim_model(state,"mine_sulfur")),"Retreat grants no ownership")
	check(Save.decode(Save.snapshot(state)).has("state"),"Retreated and won mine encounters save together")
	print("Economy world checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)