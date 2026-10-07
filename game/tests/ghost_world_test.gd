extends "res://tests/ghost_state_test.gd"

func run() -> void:
	var state := World.new("province_160x120_v1")
	var origin: Vector2i = state.hero_cell
	var destination := origin + Vector2i(1,0)
	check(state.move_to(destination,true),"Province queues discovered route")
	check(state.hero_cell == origin and state.day == 1,"Planning does not move or advance day")
	var loaded := Save.decode(JSON.parse_string(JSON.stringify(Save.snapshot(state))))
	check(loaded.has("state"),"Whole-world planned route restores")
	if loaded.has("state"):
		loaded.state.end_turn()
		state.end_turn()
		check(state.hero_cell == destination and state.day == 2,"World applies route once")
		check(JSON.parse_string(JSON.stringify(Save.snapshot(state))) == JSON.parse_string(JSON.stringify(Save.snapshot(loaded.state))),"Reload preserves deterministic resolution")
	learn(state)
	finish_case(state,"SX001")
	check(state.ghosts.prepare(state),"Live controller activates eligible opponents")
	check(state.ghosts.actors.has("NK01"),"Started investigation attracts first profile")
	loaded = Save.decode(JSON.parse_string(JSON.stringify(Save.snapshot(state))))
	check(loaded.has("state"),"World save retains active frozen ghost order")
	# Controlled adjacent contact: keep real curriculum, case and actor birth proofs.
	state.ghosts.plan = null
	state.ghosts.countered.clear()
	state.ghosts.actors.NK01.cell = [state.hero_cell.x+1,state.hero_cell.y]
	var positions := {"NK01":state.ghosts.actors.NK01.cell.duplicate()}
	for id in state.ghosts.actors:
		state.ghosts.actors[id].active = id == "NK01"
	var turn = preload("res://src/world/simultaneous_turn.gd").new()
	check(turn.freeze(state,positions,{"NK01":{"kind":"guard","path":[positions.NK01],"target":""}}),"Freeze adjacent contact fixture")
	state.ghosts.plan = turn
	check(state.move_to(Vector2i(positions.NK01[0],positions.NK01[1]),true),"Queue collision route")
	state.end_turn()
	check(not state.ghosts.pending_encounter.is_empty(),"Resolved contact awaits tactical encounter")
	loaded = Save.decode(JSON.parse_string(JSON.stringify(Save.snapshot(state))))
	check(loaded.has("state"),"Pending encounter restores before arena opens")
	var day: int = state.day
	state.end_turn()
	check(state.day == day and not state.move_to(origin,true),"Unsettled contact blocks another travel turn")
	check(state.begin_encounter("NK01"),"Contact starts authored ghost battle")
	check(state.active_battle != null,"Tactical model created")
	if state.active_battle != null:
		state.active_battle.act("retreat")
		check(state.settle_encounter(),"Retreat settles forced encounter")
	check(state.ghosts.pending_encounter.is_empty() and state.movement_remaining == 0,"Retreat clears contact and spends movement")
	check(state.hero_cell != Vector2i(positions.NK01[0],positions.NK01[1]),"Retreat separates opposing actors")
	check(Save.decode(Save.snapshot(state)).has("state"),"Retreat outcome and ghost state save together")
	print("Ghost world checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)