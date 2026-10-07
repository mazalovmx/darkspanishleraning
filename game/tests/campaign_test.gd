extends SceneTree
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func complete_opening(state: RefCounted) -> void:
	var proof := {}
	for id in state.evidence.definitions:
		var node: Dictionary = state.evidence.definitions[id]
		proof[id] = {"found_day":1, "classification":node.classification, "spanish_note":node.language.sample}
	check(state.evidence.restore(proof, state.day), "Verified opening fixture")
func learn(state: RefCounted) -> void:
	var course = state.learner.curriculum
	var iterations := 0
	while not course.completed() and iterations < 400:
		iterations += 1
		var task: Dictionary = course.next_task(state.day)
		if task.stage == "wait":
			state.end_turn()
		elif task.stage == "introduce":
			course.introduce(task.card.id, state.day)
		else:
			var answer: String = task.card.model if task.stage == "guided" else task.card.exercises[["first","second","recall"].find(task.stage)].answers[0]
			check(course.submit(task.card.id, answer, state.day).ok, "Real curriculum prerequisite")
	check(course.completed(), "Entire ordered course completed")
func visit(state: RefCounted, location_id: String) -> void:
	for location: Dictionary in state.locations:
		if location.id == location_id:
			state.hero_cell = Vector2i(location.position[0], location.position[1])
			state._reveal_from(state.hero_cell)
			return
func run() -> void:
	var state := World.new("province_160x120_v1")
	var campaign = state.campaign
	check(campaign.chapter(state) == 1 and campaign.available(state).is_empty(), "Later acts hidden before opening")
	for id: String in campaign.definitions:
		var node: Dictionary = campaign.definitions[id]
		check(node.has("keys") != (id == "council_resolution"), "Every free conclusion has authored keys: " + id)
		if node.has("keys"):
			# A probe whose exact texts never match, so the keys alone decide.
			var probe := {"answers": [node.answers[0] + " ~"], "variants": node.variants.map(func(v: String) -> String: return v + " ~"), "keys": node.keys}
			for accepted: String in node.answers + node.variants:
				check(campaign.missing(state, probe, accepted).is_empty(), "Authored wording meets its own keys: " + id)
	complete_opening(state)
	check(campaign.chapter(state) == 2 and campaign.available(state) == ["sealed_order"], "Opening unlocks official order")
	visit(state, "LOC14")
	var order: Dictionary = campaign.definitions.sealed_order
	check(not campaign.submit(state, order.id, order.answers[0], order.classification).ok, "Language cannot skip prerequisite block")
	check(campaign.records.is_empty(), "Language denial has no progress")
	learn(state)
	var bad_order := order.duplicate(true)
	bad_order.declaration.authority = "visitor"
	check(not campaign._declaration_valid(bad_order), "Unauthorized order denied")
	for id in campaign.definitions:
		var node: Dictionary = campaign.definitions[id]
		if node.hero != "any":
			check(state.select_hero(node.hero), "Required hero already introduced")
		visit(state, node.location)
		var before: Dictionary = campaign.snapshot()
		var supports: Array = node.get("supports", [])
		check(not campaign.submit(state, id, "Sí", node.classification, supports).ok, "Click-like Spanish cannot advance: " + id)
		check(not campaign.submit(state, id, node.answers[0], "invented", supports).ok, "Wrong classification denied")
		check(campaign.snapshot() == before, "Invalid production remains atomic")
		if node.get("reunite", false):
			check(not campaign.submit(state, id, node.answers[0], node.classification).ok, "Archive requires physical reunion")
			for member in state.party.heroes.values():
				member.cell = state.hero_cell
			state._reveal_from(state.hero_cell)
		if not supports.is_empty():
			check(not campaign.submit(state,id,node.answers[0],node.classification,[supports[0],supports[0]]).ok, "Distinct supporting evidence required")
		var variants: Array = node.get("variants", [])
		check(variants.size() == (0 if id == "council_resolution" else 2), "Two authored paraphrases per task: " + id)
		var wording: String = node.answers[0]
		if not variants.is_empty():
			wording = variants[checks % 2]
			var distinct := {state.learner.curriculum.normalized(node.answers[0]): true}
			for variant: String in variants:
				distinct[state.learner.curriculum.normalized(variant)] = true
			check(distinct.size() == 3, "Paraphrases differ from the model: " + id)
			check(not campaign.submit(state,id,wording + " Además, la Orden mató a todos.",node.classification,supports).ok, "Added claim is not a paraphrase: " + id)
		if id == "tomas_cause":
			var gap: Dictionary = campaign.submit(state,id,"Roque mató a Tomás.",node.classification,supports)
			check(not gap.ok and gap.message.contains("en qué circunstancias") and not gap.message.contains(node.answers[0]), "Missing need named without the answer")
			check(not campaign.submit(state,id,"Roque no mató a Tomás durante la disputa.",node.classification,supports).ok, "Reversed claim rejected")
			check(not campaign.submit(state,id,"Roque mató a Tomás durante una disputa. Gabriel mintió.",node.classification,supports).ok, "Second sentence rejected")
			wording = "Durante una pelea en el taller, Esteban Roque mató a Tomás."
		if id == "confession_review":
			check(not campaign.submit(state,id,"La confesión es una prueba independiente.",node.classification,supports).ok, "Dropped negation rejected")
			wording = "Esa confesión del muchacho no es ninguna prueba independiente."
		check(campaign.submit(state,id,wording,node.classification,supports).ok, "Canonical act task completes: " + id)
		check(not campaign.submit(state,id,node.answers[0],node.classification,supports).ok, "Task cannot grant duplicate progress")
		check(Save.decode(Save.snapshot(state)).has("state"), "Every intermediate campaign state restores: " + id)
	check(state.party.heroes.smuggler.unlocked and state.party.heroes.survivor.unlocked, "Both story introductions earned")
	check(campaign.chapter(state) == 7 and campaign.records.size() == campaign.definitions.size(), "All authored mainline steps reach council")
	var snapshot := Save.snapshot(state)
	var restored := Save.decode(snapshot)
	check(restored.has("state") and restored.state.campaign.snapshot() == campaign.snapshot(), "Whole campaign ledger survives save")
	for fault in ["missing_intro","early_day","classification","answer","hero","locked","bad_intro"]:
		var bad := snapshot.duplicate(true)
		match fault:
			"missing_intro": bad.campaign.erase("ines_arrival")
			"early_day": bad.campaign.archive_bias.day = 1
			"classification": bad.campaign.leon_cause.classification = "observed"
			"answer": bad.campaign.elias_arrival.answer = "invented"
			"hero": bad.campaign.ines_arrival.hero = "smuggler"
			"locked": bad.party.heroes.smuggler.unlocked = false
			"bad_intro": bad.campaign.ines_arrival = false
		check(not Save.decode(bad).has("state"), "Malformed campaign rejected: " + fault)
	var saved_records := campaign.snapshot()
	check(not campaign.restore({"unknown":{}},state) and campaign.snapshot() == saved_records, "Invalid ledger restore is atomic")
	print("Campaign checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)