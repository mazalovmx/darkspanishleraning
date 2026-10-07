extends "res://tests/campaign_test.gd"
const Side = preload("res://src/world/side_investigations.gd")
func run() -> void:
	var state := World.new("province_160x120_v1")
	# Isolate the full case catalog; live opposition has separate world/scene tests.
	var cases = Side.new()
	check(cases.quests.size() == 108 and cases.battles.size() == 108 and cases.branches.size() == 12,"Complete optional catalog indexed")
	check(not cases.submit(state,"SX001",cases.models("SX001").access,"","","peaceful").ok,"Unpracticed grammar cannot start case")
	check(not cases.reason(state,"SX009").is_empty(),"Branch final cannot skip prerequisites")
	learn(state)
	var scores: Dictionary = state.learner.grammar.duplicate(true)
	for id: String in cases.quests:
		var node: Dictionary = cases.quests[id]
		visit(state,node.location_id)
		var models: Dictionary = cases.models(id)
		var cipher: String = node.get("access_puzzle",{}).get("answer","")
		if not cipher.is_empty():
			check(not cases.submit(state,id,models.access,"","","peaceful","WRONG").ok,"Acrostic must be solved")
		check(not cases.submit(state,id,models.access,"","","battle",cipher).ok,"Battle route requires an actual recorded victory")
		check(cases.submit(state,id,models.access,"","","peaceful",cipher).ok,"Spanish request secures peaceful custody: " + id)
		check(cases.submit(state,id).ok,"Physical inspection recorded separately")
		check(not cases.submit(state,id,"","overreach","supported").ok,"Overreach cannot become supported fact")
		check(cases.submit(state,id,"","supported","overreach").ok,"Supported and rejected explanations compared")
		check(not cases.complete(id,cases.records),"Selecting a puzzle answer cannot finish case")
		check(cases.submit(state,id,models.supported).ok,"Supported Spanish production")
		check(not cases.submit(state,id,models.supported).ok,"Copy of guided sentence cannot pass changed task")
		check(cases.submit(state,id,models.independent).ok,"Changed structure required")
		check(not cases.submit(state,id,models.recall).ok,"Recall requires a later world day")
		state.end_turn()
		check(cases.submit(state,id,models.recall).ok,"Later recall accepted")
		if not node.final_choice.is_empty():
			var choice: String = node.final_choice[int(id.trim_prefix("SX")) % 2]
			check(cases.submit(state,id,cases.choice_model(choice),choice).ok,"Branch conclusion chosen through Spanish proposal")
		check(cases.complete(id,cases.records),"Case fully completed: " + id)
		var count: int = state.equipment.instances.size()
		check(not cases.submit(state,id,models.recall).ok and state.equipment.instances.size() == count,"Completion cannot duplicate rewards")
	check(state.equipment.instances.size() == 24,"All twenty-four unique components earned exactly once")
	check(state.learner.grammar == scores,"Bounded authored exercises do not invent free-language mastery")
	state.side_cases = cases
	check(Save.decode(Save.snapshot(state)).has("state"),"Full world save restores all 108 cases and their rewards")
	var saved: Dictionary = cases.snapshot()
	var restored := Side.new()
	check(restored.restore(saved,state) and restored.snapshot() == saved,"All 108 cases, choices and reward identities restore")
	for fault in ["missing_stage","fake_recall","future_prerequisite","reward_swap","unsupported","false_victory","unknown"]:
		var bad := saved.duplicate(true)
		match fault:
			"missing_stage": bad.SX001.progress.erase("inspect")
			"fake_recall": bad.SX001.progress.recall.day = bad.SX001.progress.independent.day
			"future_prerequisite": bad.SX002.progress.access.day = 1
			"reward_swap": bad.SX001.reward = bad.SX010.reward
			"unsupported": bad.SX001.progress.puzzle.choice = "overreach"
			"false_victory": bad.SX001.progress.access.route = "battle"
			"unknown": bad.SX999 = bad.SX001
		check(not restored.restore(bad,state),"Invalid case history rejected: " + fault)
		check(restored.snapshot() == saved,"Restore rejects atomically")
	# Historical reward ownership may change without duplicating or deleting the reward.
	var reward: String = saved.SX001.reward
	state.equipment.instances[reward].owner = "smuggler"
	check(restored.restore(saved,state),"Reward identity survives later transfer")
	print("Side investigation checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
