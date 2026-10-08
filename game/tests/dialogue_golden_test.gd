extends SceneTree
## Data-driven golden conversations (master spec section 39). Each case feeds a fake
## model reply through the real parser, verifier, learner and dialogue panel.
const Client = preload("res://src/claude/claude_client.gd")
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
const BASELINE := 0.5
class FakeClient extends Client:
	func _api_key() -> String:
		return "test-only"
	func _send() -> void:
		attempts += 1
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func proposal(fields: Dictionary) -> Dictionary:
	return {"npc_reply": fields.get("reply", "Texto del modelo que no es prueba canónica."), "language": {
		"meaning_understood": fields.get("understood", true), "confidence": fields.get("confidence", 0.9),
		"errors": fields.get("errors", []), "successful_grammar": fields.get("success", []), "new_vocabulary": []},
		"conversation": {"player_intent": fields.get("intent", "unknown"), "npc_attitude_delta": fields.get("attitude", 0),
		"suggested_unlock": fields.get("unlock"), "difficulty_observation": "comfortable"}}

# Wraps model text in the API envelope so the production parser decides what survives.
func parsed(model: Variant) -> Dictionary:
	if model == null:
		return {}
	var text: String = model if model is String else JSON.stringify(proposal(model))
	return Client.parse_response(JSON.stringify({"stop_reason": "end_turn", "content": [{"type": "text", "text": text}]}).to_utf8_buffer())

func score(state: RefCounted, tag: String) -> float:
	return state.learner.verbs[tag.trim_prefix("verb:")] if tag.begins_with("verb:") else state.learner.grammar[tag]

# Fixture: marks a campaign task as recorded, in the shape campaign_state.submit writes.
func record(state: RefCounted, id: String) -> void:
	var node: Dictionary = state.campaign.definitions[id]
	state.campaign.records[id] = {"day": state.day, "hero": state.party.active_id, "answer": node.answers[0],
		"classification": node.classification, "supports": []}
	if node.has("unlock_hero"):
		state.party.heroes[node.unlock_hero].unlocked = true

# Fixture: a "requires" entry, either a campaign task or "e:<id>" (the whole verified opening).
func satisfy(state: RefCounted, needed: String) -> void:
	if not needed.begins_with("e:"):
		record(state, needed)
		return
	var proof := {}
	for id: String in state.evidence.definitions:
		var node: Dictionary = state.evidence.definitions[id]
		proof[id] = {"found_day": 1, "classification": node.classification, "spanish_note": node.language.sample}
	check(state.evidence.restore(proof, state.day) and state.evidence.has_evidence(needed.substr(2)), "Opening fixture is canonical: " + needed)

func speakers(panel: Node) -> Array:
	var ids: Array = []
	for index in panel.speaker.item_count:
		ids.append(str(panel.speaker.get_item_metadata(index)))
	return ids

# Stands the hero on a location and opens its panel, as arriving there does.
func enter(map: Node, scene: String) -> void:
	var state = map.state
	for location: Dictionary in state.locations:
		if location.id == scene:
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	# Companions are physically present at their canonical introduction sites.
	for pair in [["LOC05", "smuggler", "ines_arrival"], ["LOC09", "survivor", "elias_arrival"]]:
		if scene == pair[0] and state.campaign.records.has(pair[2]):
			state.party.heroes[pair[1]].cell = state.hero_cell
	state._reveal_from(state.hero_cell)
	map._open_poi(state.hero_cell)

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dialogue_golden.json"))
	check(data.cases.size() >= 30, "At least thirty golden conversations")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var panel = map.dialogue
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.completed.connect(panel._on_reply)
	for id: String in panel.conversations:
		var speaker: Dictionary = panel.conversations[id]
		check(speaker.npc_id in Save.NPC_IDS and not panel.grounding.context_for(speaker.npc_id, "greeting", {}, []).is_empty(), "Conversable NPC is grounded and saveable: " + id)
		check(speaker.has("greeting_again") and not str(speaker.fallback).is_empty() and not speaker.branches.is_empty(), "Conversable NPC has authored offline replies: " + id)
	for id: String in panel.conversations:
		var npc := str(panel.conversations[id].npc_id)
		check(ResourceLoader.exists(panel.PORTRAITS + npc + ".png") or ResourceLoader.exists(panel.OWN_PORTRAITS + npc + ".png"), "Every speaker has a portrait: " + id)
	# Speakers with "requires" are offered only after that campaign task is recorded.
	check(panel.conversations.LOC01_YSABEL.get("requires") == "ysabel_account" and panel.conversations.LOC01_ESTEBAN.get("requires") == "esteban_choice", "Ysabel and Esteban wait for their campaign tasks")
	for id: String in panel.conversations:
		var required: Variant = panel.conversations[id].get("requires", [])
		var needs: Array = required if required is Array else [required]
		if needs.is_empty():
			continue
		map._adopt(World.new("province_160x120_v1"))
		enter(map, panel.scene_for(id))
		check(not panel.visible or id not in speakers(panel), "Speaker is absent from the selector before the task: " + id)
		panel.open_conversation(id)
		# Another speaker present at the place (e.g. a comic speaker) may take the
		# conversation instead; the absent one is never opened.
		check(not (panel.visible and panel.location_id == id) and not panel.histories.has(id), "Speaker cannot be opened before the task: " + id)
		panel.location_id = id
		panel.show()
		panel.submit("Hola")
		check(not fake.busy and not panel.histories.has(id), "Nothing is sent to a speaker who is not there yet: " + id)
		for index in needs.size() - 1:
			satisfy(map.state, needs[index])
			check(not panel.available(id), "Every requirement is needed: " + id)
		satisfy(map.state, needs.back())
		enter(map, panel.scene_for(id))
		panel.open_conversation(panel.scene_for(id))
		check(id in speakers(panel), "Speaker is in the selector after the task: " + id)
		panel.open_conversation(id)
		check(panel.visible and panel.transcript.text.contains(str(panel.conversations[id].greeting)), "Speaker can be opened after the task: " + id)
		var companion := str(panel.conversations[id].get("companion_hero", ""))
		if not companion.is_empty():
			var member = map.state.party.heroes[companion]
			var original: Vector2i = member.cell
			member.cell += Vector2i.RIGHT
			check(not panel.available(id), "Absent companion cannot converse: " + id)
			panel.submit("Hola")
			check(not fake.busy, "Absent companion cannot receive a message: " + id)
			member.cell = original
			member.unlocked = false
			check(not panel.available(id), "Locked companion cannot converse: " + id)
			member.unlocked = true
			check(map.state.select_hero(companion), "Select introduced companion: " + id)
			check(not panel.available(id), "Companion cannot converse with self: " + id)
			check(map.state.select_hero("inquisitor") and panel.available(id), "Return to the other hero restores conversation: " + id)
		map._close_poi()
	check(panel.conversations.LOC05.get("requires") == "ines_arrival" and panel.conversations.LOC09.get("requires") == "elias_arrival", "Companions wait for canonical introductions")
	var names := {}
	for case: Dictionary in data.cases:
		var label: String = case.name
		check(not names.has(label), "Unique case name: " + label)
		names[label] = true
		map._adopt(World.new(case.get("map", "prototype_20x20_v1")))
		panel.histories.clear()
		var state = map.state
		for id: String in case.get("campaign", []):
			satisfy(state, id)
		var recorded: Dictionary = state.campaign.records.duplicate(true)
		var proof := {}
		for id: String in case.evidence:
			var node: Dictionary = state.evidence.definitions[id]
			proof[id] = {"found_day": 1, "classification": node.classification, "spanish_note": node.language.sample}
		check(state.evidence.restore(proof, state.day), "Fixture evidence is canonical: " + label)
		var expect: Dictionary = case.expect
		for tag: String in expect.get("delta", {}):
			if tag.begins_with("verb:"):
				state.learner.verbs[tag.trim_prefix("verb:")] = BASELINE
			else:
				state.learner.grammar[tag] = BASELINE
		enter(map, panel.scene_for(case.conversation))
		panel.open_conversation(case.conversation)
		var before: Array = state.evidence.progress().keys()
		var resources: Dictionary = state.resources.duplicate()
		var day: int = state.day
		var fallback: String = panel.reply_for(case.conversation, str(case.player).strip_edges().left(300))
		for turn in int(case.get("times", 1)):
			panel.submit(case.player)
			check(fake.busy, "Request reaches the transport: " + label)
			fake._finish(parsed(case.model))
		var history: Array = panel.histories[case.conversation]
		check(history.size() == int(case.get("times", 1)) and not fake.busy, "Every turn completes: " + label)
		var reply: String = history.back().reply
		var gained: Array = state.evidence.progress().keys().filter(func(id): return id not in before)
		check(gained == ([] if expect.unlock == null else [expect.unlock]), "Evidence change is exactly the expected one: " + label)
		check(reply.contains("queda anotada") == (expect.unlock != null), "The reply announces a record only when one was made: " + label)
		check(state.resources == resources and state.day == day and state.campaign.records == recorded, "No other canonical state changes: " + label)
		for text: String in expect.get("reply_contains", []):
			check(reply.contains(text), "Reply contains '%s': %s" % [text, label])
		for text: String in expect.get("reply_excludes", []):
			check(not reply.contains(text), "Reply excludes '%s': %s" % [text, label])
		if expect.get("fallback", false):
			check(reply == fallback, "Authored fallback used: " + label)
		if expect.has("feedback_contains"):
			check(panel.feedback.text.contains(expect.feedback_contains), "Feedback shows '%s': %s" % [expect.feedback_contains, label])
		if expect.has("feedback_excludes"):
			check(not panel.feedback.text.contains(expect.feedback_excludes), "Feedback omits '%s': %s" % [expect.feedback_excludes, label])
		for tag: String in expect.get("delta", {}):
			check(is_equal_approx(score(state, tag), BASELINE + float(expect.delta[tag])), "Mastery change for %s: %s" % [tag, label])
		if expect.has("player_max"):
			check(str(history.back().player).length() <= int(expect.player_max), "Stored message is bounded: " + label)
		map._close_poi()
	# Save whitelist and topic memory roundtrip without fabricated campaign records.
	var remembered = World.new()
	remembered.remember("ines_vargas", "ask_identity", remembered.day)
	remembered.remember("elias_venn", "unknown", remembered.day)
	var loaded := Save.decode(Save.snapshot(remembered))
	check(loaded.has("state") and loaded.state.npc_memory == remembered.npc_memory, "Both companions' memory survives save")
	print("Golden conversation checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
