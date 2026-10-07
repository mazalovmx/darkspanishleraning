extends "res://tests/ghost_state_test.gd"
const Battle = preload("res://src/combat/stack_battle.gd")
func run() -> void:
	var state := World.new("province_160x120_v1")
	learn(state)
	for index in 8:
		finish_case(state,state.side_cases.branches.SB01.quest_ids[index])
	var ghosts := Ghosts.new()
	check(ghosts.prepare(state),"Prepare persistent frozen orders")
	var saved := ghosts.snapshot()
	var restored := Ghosts.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved)),state),"Frozen plan restores from JSON")
	check(restored.snapshot() == saved,"Plan and actors round trip exactly")
	var left: Dictionary = ghosts.resolve(state)
	var right: Dictionary = restored.resolve(state)
	check(left == right and ghosts.snapshot() == restored.snapshot(),"Reload cannot reroll interventions")
	state.end_turn()
	saved = ghosts.snapshot()
	check(restored.restore(saved,state) and restored.effects.has("SB01"),"Active intervention restores")
	for fault in ["duration","target","cooldown","actor","duplicate_event","missing_event"]:
		var bad := saved.duplicate(true)
		match fault:
			"duration": bad.effects.SB01.expiry = state.day+9
			"target": bad.effects.SB01.target = "SX999"
			"cooldown": bad.target_days.clear()
			"actor": bad.actors.NK01.active = 1
			"duplicate_event":
				var event: Dictionary = bad.journal.back().duplicate(true)
				bad.event_count += 1
				event.id = bad.event_count
				bad.journal.append(event)
			"missing_event": bad.journal.clear(); bad.event_count = 0
		check(not restored.restore(bad,state) and restored.snapshot() == saved,"Invalid ghost history rejected atomically: "+fault)
	var target: String = ghosts.effects.SB01.target
	var proof: Array = ghosts.sources(state,target).slice(0,1)
	check(ghosts.counter(state,"NK01",target,ghosts.counter_model(state,"NK01",proof[0]),proof),"Counter stores its language and source proof")
	var counter_snapshot := ghosts.snapshot()
	check(restored.restore(counter_snapshot,state),"Verified Spanish counter restores")
	var bad := counter_snapshot.duplicate(true)
	bad.effects = saved.effects.duplicate(true)
	check(not restored.restore(bad,state),"Cancelled effect cannot resurrect on reload")
	bad = counter_snapshot.duplicate(true)
	bad.journal.back().proof.answer = "Sí"
	check(not restored.restore(bad,state),"Click-only counter cannot be forged")
	bad = counter_snapshot.duplicate(true)
	bad.journal.back().proof.sources = ["AX108"]
	check(not restored.restore(bad,state),"Uninspected or unrelated source cannot support counter")
	# A real tactical victory backs the recovery state.
	var encounter: Dictionary = ghosts.encounter_definition("NK01")
	var battle := Battle.new()
	battle.start([{"type":"archers","count":500}],encounter.enemies,17,{},encounter.script)
	var turns := 0
	while battle.outcome.is_empty() and turns < 100:
		var enemy := -1
		for i in battle.stacks.size():
			if battle.stacks[i].side == 1 and battle.count_at(i) > 0:
				enemy = i
				break
		battle.act("attack",enemy)
		turns += 1
	check(battle.outcome == "victory","Tactical victory fixture actually won")
	state.encounters.NK01 = {"outcome":battle.outcome,"day":state.day}
	ghosts.defeat(state,"NK01")
	check(restored.restore(ghosts.snapshot(),state),"Recovery state has recorded victory")
	state.encounters.erase("NK01")
	check(not restored.restore(ghosts.snapshot(),state),"Invented dispersion without victory rejected")
	state.encounters.NK01 = {"outcome":"victory","day":state.day}
	ghosts.prepare(state)
	check(restored.restore(JSON.parse_string(JSON.stringify(ghosts.snapshot())),state),"Recovering actor and frozen plan serialize together")
	# Optional soul route still records consent and the daily special use.
	var soul_world := World.new("province_160x120_v1")
	learn(soul_world)
	for index in 8:
		finish_case(soul_world,soul_world.side_cases.branches.SB01.quest_ids[index])
	for index in 4:
		finish_case(soul_world,soul_world.side_cases.branches.SB02.quest_ids[index])
	visit(soul_world,"LOC01")
	var gear = soul_world.equipment
	for part: Dictionary in gear.sets.SA01.components:
		var found := ""
		for id: String in gear.instances:
			if gear.instances[id].item == part.item_id:
				found = id
				break
		check(not found.is_empty() and gear.equip(soul_world,found,part.slot),"Soul parts actually earned from cases")
	for stage: String in gear.STAGES:
		if stage == "delayed_recall":
			soul_world.end_turn()
		check(gear.persuade(soul_world,"SA01",gear.expected("SA01",stage),gear.sets.SA01.ritual.required_memories if stage == "compare_memories" else []).ok,"Actual soul consent stage")
	check(gear.assemble(soul_world,"SA01"),"Assemble consenting soul for counter")
	var soul_ghosts := Ghosts.new()
	soul_ghosts.prepare(soul_world)
	soul_ghosts.resolve(soul_world)
	soul_world.end_turn()
	target = soul_ghosts.effects.SB01.target
	proof = soul_ghosts.sources(soul_world,target).slice(0,1)
	check(soul_ghosts.counter(soul_world,"NK01",target,soul_ghosts.counter_model(soul_world,"NK01",proof[0]),proof,true),"Soul counter requires typed Spanish and source")
	check(gear.special_used.get("SA01",0) == soul_world.day,"Soul ability use recorded once")
	check(Ghosts.new().restore(soul_ghosts.snapshot(),soul_world),"Soul-backed counter proof restores")
	print("Ghost persistence checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
