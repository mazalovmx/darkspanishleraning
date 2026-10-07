extends SceneTree
const World = preload("res://src/world/world_state.gd")
const Economy = preload("res://src/economy/strategy_economy.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func buy(economy: RefCounted, state: RefCounted, kind: String, id: String, quantity: int) -> Dictionary:
	var models: Dictionary = economy.current_models(state,kind,id,quantity)
	var result := {}
	for stage in ["request","price","confirm"]:
		result = economy.submit(state,kind,id,quantity,models[stage])
	return result
func next_day(economy: RefCounted,state: RefCounted) -> void:
	state.end_turn()
	economy.advance_day(state)
func run() -> void:
	var state := World.new("province_160x120_v1")
	var economy := Economy.new()
	var amounts: Dictionary = state.resources.duplicate()
	var models := economy.models("build","council_hall",1)
	check(not economy.submit(state,"build","council_hall",1,"Sí").ok,"Click-only construction denied")
	check(economy.submit(state,"build","council_hall",1,models.request).ok,"Spanish construction request")
	check(economy.submit(state,"build","council_hall",1,models.price).ok,"Full multi-resource cost understood")
	check(state.resources == amounts and economy.buildings.is_empty(),"Quote does not spend or build")
	economy.cancel()
	check(state.resources == amounts,"Cancellation costs nothing")
	# Own wording passes on content; a rejection names the gap and never prints the model.
	check(economy.submit(state,"build","council_hall",1,"Buenos días, quiero levantar una casa de administración aquí.").ok,"Own construction request accepted")
	var rejected: Dictionary = economy.submit(state,"build","council_hall",1,"Cuesta 300 monedas.")
	check(not rejected.ok and rejected.message.contains("el coste completo") and not rejected.message.contains(models.price),"Partial cost named without the model")
	check(economy.submit(state,"build","council_hall",1,"Cuesta 300 monedas de oro, cinco unidades de madera y 5 de mineral.").ok,"Own cost sentence accepted")
	check(not economy.submit(state,"build","council_hall",1,"Confirmo la casa de administración.").ok,"Confirmation without the cost rejected")
	check(economy.cue(state,"build","council_hall",1).contains("Recuerda:") and not economy.cue(state,"build","council_hall",1).contains(models.confirm),"Cue gives facts and a rule, not the model")
	economy.cancel()
	check(buy(economy,state,"build","council_hall",1).get("committed",false),"Construction settles")
	check(state.resources.gold == 0 and state.resources.wood == 0 and state.resources.ore == 0,"All construction costs deducted")
	check(not buy(economy,state,"build","council_hall",1).ok,"Duplicate construction denied")
	for resource in state.resources:
		state.resources[resource] = 10000
	check(not buy(economy,state,"build","barracks",1).ok,"One building per town per day")
	next_day(economy,state)
	check(state.resources.gold == 10100,"Building produces daily income")
	var gold: int = state.resources.gold
	check(economy.advance_day(state).is_empty() and state.resources.gold == gold,"Daily income cannot be collected twice")
	check(buy(economy,state,"build","barracks",1).get("committed",false),"Next-day construction works")
	check(economy.stock("LOC01","militia",state.day) == 12,"Barracks creates weekly pool")
	var count_before: int = state.army[0].count
	check(buy(economy,state,"recruit","militia",12).get("committed",false),"Recruitment uses same Spanish transaction")
	check(state.army[0].count == count_before + 12 and economy.stock("LOC01","militia",state.day) == 0,"Recruits merge and deplete town pool")
	check(not buy(economy,state,"recruit","militia",1).ok,"Depleted stock denied")
	while state.day < 8:
		next_day(economy,state)
	check(economy.stock("LOC01","militia",state.day) == 12,"New week grows army pool")
	check(buy(economy,state,"build","forge",1).get("committed",false),"Prerequisite unlocks forge")
	var army_count := 0
	for stack in state.army:
		army_count += stack.count
	check(buy(economy,state,"upgrade","militia",3).get("committed",false),"Paid upgrade succeeds")
	var after_count := 0
	for stack in state.army:
		after_count += stack.count
	check(after_count == army_count and state.army.back().type == "veteran_guard","Upgrade conserves troop count")
	check(not buy(economy,state,"upgrade","militia",20).ok,"Unavailable upgrade quantity denied")
	next_day(economy,state)
	check(buy(economy,state,"build","laboratory",1).get("committed",false),"Rare resources buy laboratory")
	var crystal: int = state.resources.crystal
	check(buy(economy,state,"recruit","relic_sentinel",2).get("committed",false),"Rare recruitment available")
	check(state.resources.crystal == crystal - 2,"Rare troops consume crystal")
	var before: Dictionary = state.resources.duplicate()
	models = economy.models("recruit","militia",1)
	economy.submit(state,"recruit","militia",1,models.request)
	economy.submit(state,"recruit","militia",1,models.price)
	state.resources.gold = 0
	check(not economy.submit(state,"recruit","militia",1,models.confirm).ok,"Resources rechecked at settlement")
	check(state.resources.wood == before.wood and economy.pending.is_empty(),"Failed settlement atomic")
	state.resources = before
	state.army.clear()
	for i in 7:
		state.army.append({"type":"archers","count":1})
	check(not buy(economy,state,"recruit","militia",1).ok,"Seven full stacks block new unit type")
	state.army = [{"type":"militia","count":1}]
	check(buy(economy,state,"upgrade","militia",1).get("committed",false),"Complete-stack upgrade can reuse freed slot")
	check(state.army.size() == 1 and state.army[0].type == "veteran_guard","Empty source stack removed")
	var mine: Dictionary = economy.site(state,"mine_wood")
	check(not economy.claim(state,"mine_wood",economy.claim_model(state,"mine_wood")),"Remote mine capture denied")
	state.hero_cell = Vector2i(mine.position[0],mine.position[1])
	state._reveal_from(state.hero_cell)
	check(not economy.claim(state,"mine_wood","Sí"),"Mine order requires Spanish")
	check(not economy.claim(state,"mine_wood","Quiero la mina.") and economy.claim_feedback(state,"mine_wood","Quiero la mina.").contains("la mina y su recurso"),"Claim without its resource named as missing")
	check(not economy.claim_cue(state,"mine_wood").contains(economy.claim_model(state,"mine_wood")),"Claim cue hides the model")
	check(economy.claim(state,"mine_wood","Necesito controlar esta mina de madera."),"Reached unguarded mine claimed in own words")
	var wood: int = state.resources.wood
	next_day(economy,state)
	check(state.resources.wood == wood + 2,"Mine generates daily resource income")
	mine = economy.site(state,"mine_gold")
	state.hero_cell = Vector2i(mine.position[0],mine.position[1])
	state._reveal_from(state.hero_cell)
	check(not economy.claim(state,"mine_gold",economy.claim_model(state,"mine_gold")),"Guarded mine needs actual victory")
	# A world-encounter fixture; full combat wiring is the following integration task.
	state.encounters.mine_gold = {"outcome":"victory","day":state.day}
	check(economy.claim(state,"mine_gold",economy.claim_model(state,"mine_gold")),"Victory allows ownership")
	var saved := economy.snapshot()
	var restored := Economy.new()
	check(restored.restore(saved,state) and restored.snapshot() == saved,"Economy restores exactly")
	check(economy.models("build","forge",1).request == "Quiero construir una forja.", "Building article agrees")
	check(economy.models("recruit","militia",1).request == "Quiero contratar 1 miliciano.", "Singular recruitment agrees")
	check(economy.models("upgrade","militia",1,"plans").confirm.contains("la mejora de 1 miliciano a guardia veterano"), "Upgrade confirmation names source and result")
	var legacy := saved.duplicate(true)
	for receipt in legacy.receipts:
		var old_models: Dictionary = economy.models(receipt.kind,receipt.id,receipt.quantity,receipt.tier,true)
		for stage in ["request","price","confirm"]:
			receipt[stage] = old_models[stage]
	check(restored.restore(legacy,state), "Earlier economic receipt wording remains readable")
	check(restored.restore(saved,state), "Current receipt wording remains readable")
	for mutation in ["unknown_building","same_day","prerequisite","negative_stock","income_future","fake_claim","fake_phrase"]:
		var bad := saved.duplicate(true)
		match mutation:
			"unknown_building": bad.buildings.LOC01.invented = 1
			"same_day": bad.buildings.LOC01.barracks = bad.buildings.LOC01.council_hall
			"prerequisite": bad.buildings.LOC01.erase("forge")
			"negative_stock": bad.recruited.LOC01.militia = -1
			"income_future": bad.last_income_day = state.day + 1
			"fake_claim": bad.mines.mine_gold.message = "Sí"
			"fake_phrase": bad.receipts[0].confirm = "gratis"
		check(not restored.restore(bad,state),"Invalid ledger denied: " + mutation)
		check(restored.snapshot() == saved,"Rejected restore is atomic")
	print("Strategy economy checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)