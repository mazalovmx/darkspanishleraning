extends "res://tests/market_curriculum_test.gd"
func run() -> void:
	var state := World.new("province_160x120_v1")
	var economy = state.economy
	for resource in state.resources:
		state.resources[resource] = 10000
	var phrases: Dictionary = economy.current_models(state,"build","barracks",1)
	for stage in ["request","price","confirm"]:
		check(economy.submit(state,"build","barracks",1,phrases[stage]).ok,"Initial construction stage")
	for setup in [[0,"basic","Quiero"],[2,"past","Decidí"],[5,"plans","Voy a"],[6,"argument","Querría"]]:
		advance_to(state,setup[0])
		phrases = economy.current_models(state,"recruit","militia",1)
		check(phrases.request.begins_with(setup[2]),"Strategy tier follows taught curriculum")
		if setup[0] > 0:
			check(not economy.submit(state,"recruit","militia",1,economy.models("recruit","militia",1).request).ok,"Cannot bypass current language task with elementary request")
		for stage in ["request","price","confirm"]:
			check(economy.submit(state,"recruit","militia",1,phrases[stage]).ok,"Curriculum tier completes resource transaction")
	check(state.army[0].count == 12,"All four requests recruit exactly once")
	var result := Save.decode(Save.snapshot(state))
	check(result.has("state") and result.state.economy.receipts.size() == 5,"Mixed-tier strategic history restores")
	print("Strategy curriculum checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)