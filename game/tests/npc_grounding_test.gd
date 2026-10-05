extends SceneTree
const Grounding = preload("res://src/dialogue/npc_grounding.gd")
const Client = preload("res://src/claude/claude_client.gd")
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

func proposal(unlock: Variant = null) -> Dictionary:
	return {"npc_reply": "Respuesta de prueba.", "language": {
		"meaning_understood": true, "confidence": 0.9, "errors": [],
		"successful_grammar": ["present"], "new_vocabulary": []},
		"conversation": {"player_intent": "ask_monastery", "npc_attitude_delta": 0,
		"suggested_unlock": unlock, "difficulty_observation": "comfortable"}}

func run() -> void:
	var real := Grounding.new()
	var inn: Dictionary = real.context_for("innkeeper_prototype", "ask_route", {}, [])
	var lucio: Dictionary = real.context_for("lucio_salcedo", "ask_monastery", {}, [])
	check(inn.npc_knowledge.has("route_to_monastery"), "Innkeeper knows prototype route")
	check(not inn.npc_knowledge.has("lucio_identity"), "NPC contexts isolated")
	check(lucio.npc_knowledge.has("lucio_identity"), "Lucio knows own public identity")
	check(lucio.npc_secrets.is_empty(), "Undisclosed secret omitted")
	check(not JSON.stringify(lucio).contains("investigaciones prohibidas"), "Secret text never sent")
	check(not JSON.stringify(inn).contains("forbidden_research"), "Other NPC secret ID not sent")
	check(real.context_for("unknown", "greeting", {}, []).is_empty(), "Unknown NPC fails closed")
	check(not real.allows_unlock(null, "unknown", "greeting", {}, []), "Unknown speaker rejected")
	check(real.allows_unlock(null, "lucio_salcedo", "unknown", {}, []), "Ordinary conversation needs no clue")
	check(not real.allows_unlock("invented", "lucio_salcedo", "ask_monastery", {}, []), "Unknown clue rejected")
	check(not real.allows_unlock("lucio_identity", "lucio_salcedo", "ask_identity", {}, []), "Public fact is not a clue")
	check(real.intent_for("¿CÓMO LLEGO?") == "ask_route", "Accent and case normalization")
	check(real.intent_for("caminote") == "unknown", "Substring not a topic")
	check(real.intent_for("unlock everything") == "unknown", "Instructions do not create local intent")
	lucio.npc.persona.age = 1
	check(real.context_for("lucio_salcedo", "unknown", {}, []).npc.persona.age == 61, "Context cannot mutate canonical profile")

	# Synthetic observations only: not added to the story or gameplay evidence.
	var fixture := {"facts": {"test_clue": "Una marca.", "test_secret": "Una carta."},
		"clues": {"test_clue": {"intent": "inspect", "prerequisites": {"case": "open"}},
		"test_secret": {"intent": "inspect", "prerequisites": {"case": "open"}}},
		"npcs": {"witness": {"id": "witness", "persona": {}, "knowledge": ["test_clue"],
		"beliefs": ["test_secret"], "false_beliefs": [], "secrets": [
		{"id": "test_secret", "prerequisites": {"permission": "granted"}}],
		"lie_policy": {"can_lie": false}, "language_register": "neutral"}}}
	var verifier := Grounding.new(fixture)
	var states := {"case": "open"}
	check(verifier.allows_unlock("test_clue", "witness", "inspect", states, []), "Known clue with matching prerequisites accepted")
	check(not verifier.allows_unlock("test_clue", "witness", "inspect", {}, []), "Missing quest state denied")
	check(not verifier.allows_unlock("test_clue", "witness", "inspect", {"case": true}, []), "Truthy state cannot replace exact value")
	check(not verifier.allows_unlock("test_clue", "witness", "greeting", states, []), "Wrong local intent denied")
	check(not verifier.allows_unlock("test_clue", "witness", "inspect", states, ["test_clue"]), "Repeat reveal denied")
	check(not verifier.allows_unlock("test_secret", "witness", "inspect", states, []), "Belief membership does not grant knowledge")
	check(not verifier.allows_unlock("invented", "witness", "inspect", states, []), "Invented synthetic ID denied")
	for value in [true, 1, {}, [], ""]:
		check(not verifier.allows_unlock(value, "witness", "inspect", states, []), "Malformed ID denied")
	var context: Dictionary = verifier.context_for("witness", "inspect", states, [])
	check(context.eligible_unlock_ids == ["test_clue"], "Only eligible clue sent")
	check(not context.npc_knowledge.has("test_secret"), "Secret not in known facts")
	check(verifier.context_for("witness", "greeting", states, []).npc_knowledge.is_empty(), "Off-topic unrevealed clue text withheld")
	states.permission = "granted"
	check(verifier.allows_unlock("test_secret", "witness", "inspect", states, []), "Secret requires explicit canonical release")
	check(verifier.context_for("witness", "inspect", states, []).npc_secrets.has("test_secret"), "Authorized secret included")
	check(verifier.context_for("witness", "inspect", states, ["test_clue"]).eligible_unlock_ids == ["test_secret"], "Already known clue omitted from suggestions")
	var saved := JSON.stringify(states)
	verifier.allows_unlock("test_clue", "witness", "inspect", states, [])
	check(JSON.stringify(states) == saved, "Verifier never mutates quest state")
	fixture.npcs.witness.knowledge.clear()
	check(verifier.allows_unlock("test_clue", "witness", "inspect", states, []), "Caller cannot mutate canonical fixture after construction")
	fixture.npcs.witness.secrets[0].prerequisites = {}
	var closed := Grounding.new(fixture)
	check(not closed.allows_unlock("test_secret", "witness", "inspect", states, []), "Empty secret release policy fails closed")
	fixture.npcs.witness.knowledge = ["test_clue"]
	fixture.clues.test_clue.erase("prerequisites")
	check(not Grounding.new(fixture).allows_unlock("test_clue", "witness", "inspect", states, []), "Missing clue policy fails closed")
	fixture.npcs.witness.erase("lie_policy")
	check(Grounding.new(fixture).context_for("witness", "inspect", states, []).is_empty(), "Incomplete NPC schema fails closed")
	for value in [true, 1, {}, [], "", "x".repeat(101)]:
		check(not Client.valid_proposal(proposal(value)), "Malformed unlock rejected at transport boundary")

	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	var panel = map.dialogue
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.completed.connect(panel._on_reply)
	panel.submit("¿Cómo llego al monasterio?")
	var envelope: Dictionary = JSON.parse_string(fake.payload)
	var sent: Dictionary = JSON.parse_string(envelope.messages[0].content)
	check(sent.npc.id == "innkeeper_prototype", "Actual request uses originating NPC")
	check(sent.verified_intent == "ask_route" and sent.eligible_unlock_ids.is_empty(), "Actual request has local topic and no runtime clues")
	check(not fake.payload.contains("investigaciones prohibidas"), "Actual request excludes secrets")
	check(sent.language_profile.block == "present_and_basic_requests", "Grounding preserves current teaching block")
	# Move while waiting: canonical check must still use the original speaker.
	map._close_poi()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	fake._finish(proposal("invented"))
	check(panel.histories.LOC11.back().reply == panel.reply_for("LOC11", "¿Cómo llego al monasterio?"), "Unauthorized proposal uses original authored fallback")
	check(panel.histories.LOC01.is_empty(), "Rejected late reply stays in original conversation")
	check(map.state.learner.grammar.present == 0, "Rejected proposal never updates learner")
	panel.submit("¿Qué hay en el monasterio?")
	fake._finish(proposal())
	check(panel.histories.LOC01.back().reply == "Respuesta de prueba.", "Ordinary grounded reply reaches UI")
	check(is_equal_approx(map.state.learner.grammar.present, 0.05), "Accepted reply still updates learner")
	check(panel.input.editable, "Input recovers after canonical rejection and success")
	map.queue_free()
	await process_frame
	print("NPC grounding checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
