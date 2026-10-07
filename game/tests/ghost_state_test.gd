extends "res://tests/campaign_test.gd"
const Ghosts = preload("res://src/world/ghost_state.gd")
func clear_intervention(state: RefCounted,id: String) -> void:
	var knight: String = state.ghosts.blocked(state,id)
	if knight.is_empty():
		return
	var sources: Array = state.ghosts.sources(state,id).slice(0,2 if knight in ["NK02","NK03","NK04","NK08"] else 1)
	check(not sources.is_empty() and state.ghosts.counter(state,knight,id,state.ghosts.counter_model(state,knight,sources[0]),sources),"Real source-backed counter clears live prerequisite intervention")

func finish_case(state: RefCounted,id: String) -> void:
	var cases = state.side_cases
	visit(state,cases.quests[id].location_id)
	var phrases: Dictionary = cases.models(id)
	var cipher: String = cases.quests[id].get("access_puzzle",{}).get("answer","")
	clear_intervention(state,id)
	check(cases.submit(state,id,phrases.access,"","","peaceful",cipher).ok,"Case prerequisite access")
	cases.submit(state,id)
	cases.submit(state,id,"","supported","overreach")
	cases.submit(state,id,phrases.supported)
	cases.submit(state,id,phrases.independent)
	state.end_turn()
	clear_intervention(state,id)
	check(cases.submit(state,id,phrases.recall).ok,"Case prerequisite complete")
func run() -> void:
	var source := Ghosts.new()
	for knight_id: String in source.definitions:
		var state := World.new("province_160x120_v1")
		var ghosts := Ghosts.new()
		learn(state)
		var branch: String = ghosts.definitions[knight_id].spawn.branch_ids[0]
		var ids: Array = state.side_cases.branches[branch].quest_ids
		var prerequisite_count := 2 if knight_id == "NK05" else 8
		for index in prerequisite_count:
			finish_case(state,ids[index])
		var evidence: Dictionary = state.evidence.progress()
		var equipment: Dictionary = state.equipment.snapshot()
		var target: String = ids[prerequisite_count]
		var attempts := 0
		while (not ghosts.effects.has(branch) or ghosts.effects[branch].knight != knight_id) and attempts < 12:
			check(ghosts.prepare(state),"Knight planning from current shared snapshot")
			var active := 0
			for actor in ghosts.actors.values():
				active += 1 if actor.active else 0
			check(active <= 3,"Active knight cap")
			var before: Dictionary = ghosts.plan.snapshot()
			check(ghosts.prepare(state) and ghosts.plan.snapshot() == before,"Repeated prepare preserves frozen orders")
			check(ghosts.resolve(state).ok,"Frozen strategic orders resolve")
			state.end_turn()
			var interventions := 0
			for event: Dictionary in ghosts.journal:
				if event.day == state.day and event.kind == "intervention":
					interventions += 1
			check(interventions <= 2,"At most two interventions per world day")
			for effect: Dictionary in ghosts.effects.values():
				check(effect.expiry-effect.start <= 2 and effect.expiry > state.day,"Effect lifetime bounded and expired effects removed")
			attempts += 1
		check(ghosts.effects.has(branch) and ghosts.effects[branch].knight == knight_id,"Distinct knight intervenes: " + knight_id)
		if not ghosts.effects.has(branch) or ghosts.effects[branch].knight != knight_id:
			continue
		var proof: Array = ghosts.sources(state,target)
		proof = proof.slice(0,2 if knight_id in ["NK02","NK03","NK04","NK08"] else 1)
		check(not ghosts.counter(state,knight_id,target,"Mi fuerza demuestra la verdad.",proof),"Unsupported counter denied")
		check(ghosts.effects.has(branch),"Failed counter preserves bounded effect")
		check(ghosts.counter(state,knight_id,target,ghosts.counter_model(state,knight_id,proof[0]),proof),"Evidence and typed Spanish counter intervention")
		check(not ghosts.effects.has(branch),"Valid counter restores access")
		check(state.evidence.progress() == evidence and state.equipment.snapshot() == equipment,"Intervention and counter preserve owned evidence and equipment")
		check(ghosts.defeat(state,knight_id),"Defeated knight disperses")
		check(ghosts.actors[knight_id].return_day == state.day+3,"Recovery lasts three world turns")
		check(ghosts.prepare(state),"Prepare after defeat")
		check(ghosts.plan.orders[knight_id].kind == "recover","Dispersed knight gets recovery order")
		var position: Array = ghosts.actors[knight_id].cell.duplicate()
		check(ghosts.resolve(state).ok and ghosts.actors[knight_id].cell == position,"Dispersed knight does not move")
		check(ghosts.encounter_definition(knight_id).script == ghosts.definitions[knight_id].battle.script,"Encounter uses own tactical script")
	# Preempt a telegraphed intervention without advancing the world.
	var state := World.new("province_160x120_v1")
	learn(state)
	for index in 8:
		finish_case(state,state.side_cases.branches.SB01.quest_ids[index])
	var ghosts := Ghosts.new()
	check(ghosts.prepare(state),"Prepare telegraphed intervention")
	var target: String = ghosts.plan.orders.NK01.target
	var proof: Array = ghosts.sources(state,target).slice(0,1)
	var day: int = state.day
	check(ghosts.counter(state,"NK01",target,ghosts.counter_model(state,"NK01",proof[0]),proof),"Counter interrupts frozen intervention")
	check(state.day == day,"Typed counter does not advance hostile turn")
	check(ghosts.resolve(state).ok,"Countered plan resolves")
	check(not ghosts.effects.has("SB01") or ghosts.effects.SB01.knight != "NK01","Countered knight cannot apply queued intervention")
	print("Ghost strategy checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
