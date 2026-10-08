extends SceneTree
const Learner = preload("res://src/spanish/learner_profile.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func evaluation() -> Dictionary:
	return {"meaning_understood": true, "confidence": 0.9, "errors": [],
		"successful_grammar": ["present", "verb:tener", "present"], "new_vocabulary": ["pan", "pan"]}
func proposal(language: Dictionary) -> Dictionary:
	return {"npc_reply": "¿Tiene pan? Dígame, ¿qué necesita?", "language": language,
		"conversation": {"player_intent": "request", "npc_attitude_delta": 0,
		"suggested_unlock": null, "difficulty_observation": "comfortable"}}
func run() -> void:
	var learner = Learner.new()
	learner.observe(evaluation(), "Tengo pan", "inn", 1)
	check(is_equal_approx(learner.grammar.present, 0.05), "Duplicate grammar tag credited once")
	check(is_equal_approx(learner.verbs.tener, 0.05), "Irregular verb tracked separately")
	check(learner.vocabulary.size() == 1, "Vocabulary deduplicated")
	learner.observe(evaluation(), " TENGO PAN ", "monastery", 2)
	check(is_equal_approx(learner.grammar.present, 0.05), "Repeated message does not farm mastery")
	var uncertain := evaluation()
	uncertain.confidence = 0.3
	learner.observe(uncertain, "Tengo agua", "inn", 1)
	check(learner.recent_messages.size() == 1, "Low confidence ignored entirely")
	var unknown := evaluation()
	unknown.successful_grammar = ["invented", "verb:invented"]
	learner.observe(unknown, "Algo", "inn", 1)
	check(not learner.grammar.has("invented") and not learner.verbs.has("invented"), "Unknown tags do not create progress")
	for i in 30:
		learner.observe(evaluation(), "Práctica %d" % i, "monastery", 2)
	check(learner.grammar.present == 1 and learner.verbs.tener == 1, "Mastery capped at one")
	check(learner.successful_contexts.present.size() == 2, "Distinct NPC contexts tracked")
	var mistake := evaluation()
	mistake.errors = [{"type": "present|verb:tener", "original": "yo tiene", "better": "yo tengo", "severity": "important"}]
	learner.observe(mistake, "Yo tiene pan", "inn", 3)
	check(is_equal_approx(learner.grammar.present, 0.92), "Error wins over contradictory success tag")
	check(is_equal_approx(learner.verbs.tener, 0.92), "Verb error reduces verb mastery")
	check(learner.errors.present.count == 1 and learner.errors.present.last_seen_day == 3, "Important error tracked with day")
	for i in 30:
		mistake.errors[0].original = "error %d" % i
		learner.observe(mistake, "Error nuevo %d" % i, "inn", 4)
	check(learner.grammar.present == 0 and learner.verbs.tener == 0, "Mastery floored at zero")
	check(learner.errors.present.examples.size() == 3, "Error examples bounded")
	check(learner.recent_messages.size() == 40, "Duplicate memory bounded")
	check(learner.current_block == "present_and_basic_requests", "Mastery never unlocks a new block by itself")
	var unclear := evaluation()
	unclear.meaning_understood = false
	learner.observe(unclear, "Unclear", "inn", 5)
	check(learner.grammar.present == 0, "Unclear meaning awards no success")
	var context: Dictionary = learner.context()
	context.grammar_mastery.present = 0.7
	check(learner.grammar.present == 0, "Prompt context cannot mutate learner")

	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	var panel = map.dialogue
	# Exercise the validated completion boundary without network requests.
	panel.pending_location = "LOC11"
	panel.pending_message = "Yo tiene pan"
	panel.pending_day = 3
	var language := evaluation()
	language.errors = [
		{"type": "present|verb:tener", "original": "yo tiene", "better": "yo tengo", "severity": "important"},
		{"type": "gender_articles", "original": "una pan", "better": "un pan", "severity": "minor"}]
	panel._on_reply(proposal(language))
	check(panel.feedback.text.contains("Sentido comprendido"), "Meaning shown separately from NPC")
	check(panel.feedback.text.count("Mejor:") == 2, "Two corrections shown")
	check(panel.feedback.text.contains("presente · ") and panel.feedback.text.contains("género y artículos · "), "Each correction names its grammar and rule (section 29)")
	panel.pending_location = "LOC11"
	panel.pending_message = "Tomas tiene pan"
	panel.pending_day = 3
	var marks := evaluation()
	marks.errors = [{"type": "present", "original": "Tomas", "better": "Tomás", "severity": "minor"}]
	panel._on_reply(proposal(marks))
	check(not panel.feedback.text.contains("Mejor:"), "Accent-only corrections are not shown outside the last block")
	panel.pending_location = "LOC11"
	panel.pending_message = "Yo tiene pan"
	panel.pending_day = 3
	panel._on_reply(proposal(language))
	check(panel.transcript.text.contains("¿Tiene pan?"), "NPC recast preserved")
	check(map.state.learner.errors.has("verb:tener"), "UI updates canonical learner state")
	# tener started at 0 and the error left it at 0; the later accent-only reply credits it,
	# but the record keeps the mastery of the moment of the error.
	check(is_equal_approx(float(map.state.learner.errors["verb:tener"].mastery_after), 0.0) and map.state.learner.verbs.tener > 0.0, "Error memory stores mastery after the error (section 28)")
	check(map.state.learner.recent_errors()[0].has("mastery_after"), "Claude context includes mastery after the error")
	var saved: String = panel.feedback.text
	map._close_poi()
	map._open_poi(Vector2i(6, 11))
	check(panel.feedback.text == saved, "Feedback survives reopen")
	panel.pending_location = "LOC11"
	panel.pending_message = "Fallo de red"
	panel.pending_fallback = "No sabría decirle."
	panel._on_reply({})
	check(panel.feedback.text.contains("no disponible"), "Offline fallback clears stale evaluation")
	check(map.state.learner.errors["verb:tener"].count == 1, "Fallback never changes mastery")
	panel.pending_location = "LOC11"
	panel.pending_message = "Incierto"
	panel._on_reply(proposal(uncertain))
	check(panel.feedback.text.contains("incierta"), "Uncertain evaluation identified")
	panel.pending_location = "LOC11"
	panel.pending_message = "Sin sentido"
	panel._on_reply(proposal(unclear))
	check(panel.feedback.text.contains("reformularlo"), "Unclear meaning invites reformulation without blocking")
	var invalid := proposal(evaluation())
	invalid.language.confidence = 99
	panel.pending_location = "LOC11"
	panel.pending_message = "Invalid"
	panel._on_reply(invalid)
	check(panel.feedback.text.contains("no disponible"), "Invalid evaluation rejected at learner boundary")
	# Capture a representative correction panel.
	panel.pending_location = "LOC11"
	panel.histories.LOC11.clear()
	panel.pending_message = "Yo tiene una pan"
	panel._on_reply(proposal(language))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://spanish-preview.png")
	map.queue_free()
	await process_frame
	print("Spanish feedback checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
