extends VBoxContainer
signal request_started
signal turn_finished
## Authored conversations; evidence changes pass the local canonical verifier.

const MAX_EXCHANGES := 12
const MAX_MESSAGE_LENGTH := 300
var conversations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://content/dialogue/authored.json"))
var histories: Dictionary = {}
var location_id := ""
var speaker := OptionButton.new()
var transcript := RichTextLabel.new()
var input := LineEdit.new()
var send_button := Button.new()
var feedback := Label.new()
var hint := Label.new()
var client = preload("res://src/claude/claude_client.gd").new()
var pending_location := ""
var pending_message := ""
var pending_fallback := ""
var pending_day := 1
var pending_unlocks: Array = []
var pending_focus: Array = []
var last_feedback: Dictionary = {}
var world_state: RefCounted
var grounding = preload("res://src/dialogue/npc_grounding.gd").new()

func _ready() -> void:
	add_child(client)
	client.completed.connect(_on_reply)
	add_theme_constant_override("separation", 10)
	add_child(speaker)
	speaker.item_selected.connect(func(index: int):
		if not client.busy:
			open_conversation(str(speaker.get_item_metadata(index))))
	transcript.custom_minimum_size = Vector2(0, 170)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.bbcode_enabled = false
	transcript.scroll_following = true
	add_child(transcript)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	add_child(hint)
	var row := HBoxContainer.new()
	add_child(row)
	input.placeholder_text = "Escriba en español…"
	input.max_length = MAX_MESSAGE_LENGTH
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(submit)
	input.text_changed.connect(func(text: String): send_button.disabled = client.busy or text.strip_edges().is_empty())
	row.add_child(input)
	send_button.text = "Enviar"
	send_button.pressed.connect(func(): submit(input.text))
	row.add_child(send_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 14)
	add_child(feedback)

func open_conversation(id: String) -> void:
	location_id = id
	world_state.learner.curriculum.begin_conversation()
	visible = available(id)
	if not visible:
		return
	if not histories.has(id):
		histories[id] = []
	input.clear()
	send_button.disabled = true
	speaker.clear()
	for key in conversations:
		if scene_for(key) == scene_for(id) and available(key):
			speaker.add_item("Conversación · " + str(conversations[key].name))
			speaker.set_item_metadata(speaker.item_count - 1, key)
			if key == id:
				speaker.select(speaker.item_count - 1)
	speaker.disabled = client.busy
	hint.text = "Objetivo: presente y peticiones sencillas. " + str(conversations[id].hint)
	feedback.text = last_feedback.get(location_id, "Evaluación de español no disponible. Puede continuar la conversación.")
	_render_history()

func submit(message: String) -> void:
	if client.busy or not is_visible_in_tree() or not available(location_id):
		return
	var clean := message.strip_edges().left(MAX_MESSAGE_LENGTH)
	if clean.is_empty():
		return
	pending_location = location_id
	pending_day = world_state.day
	pending_message = clean
	pending_fallback = reply_for(location_id, clean)
	input.clear()
	input.editable = false
	speaker.disabled = true
	send_button.disabled = true
	feedback.text = "Esperando respuesta…"
	# Capture eligible IDs before sending; recheck live prerequisites on completion.
	var context: Dictionary = grounding.context_for(conversations[location_id].npc_id,
		grounding.intent_for(clean), world_state.evidence.context_flags(), world_state.evidence.progress().keys())
	pending_unlocks = context.get("eligible_unlock_ids", []).duplicate()
	context["player_message"] = clean
	var hero_definition: Dictionary = world_state.party.active().definition
	context["player_hero"] = {"id": world_state.party.active_id, "name": hero_definition.name,
		"role": hero_definition.role, "register": hero_definition.register}
	context["recent_dialogue"] = histories[location_id].slice(-3)
	var npc_id: String = conversations[location_id].npc_id
	var memory: Dictionary = world_state.npc_memory.get(npc_id, {})
	var revealed: Array = []
	for clue_id: String in world_state.evidence.progress():
		if world_state.evidence.node(clue_id).get("npc_id", "") == npc_id:
			revealed.append(clue_id)
	context["npc_memory"] = {"conversation_count": int(memory.get("count", 0)), "last_talk_day": int(memory.get("last_day", 0)),
		"discussed_topics": memory.get("topics", []).duplicate(), "revealed": revealed}
	context["language_profile"] = world_state.learner.context()
	var course = world_state.learner.curriculum
	pending_focus = [course, course.cursor, course.recent_focus.duplicate()]
	context["language_profile"]["focus"] = world_state.learner.curriculum.select_focus(world_state.learner.grammar, world_state.learner.errors)
	request_started.emit()
	client.request_reply(context)

func _on_reply(proposal: Dictionary) -> void:
	if pending_location.is_empty():
		return
	var rejected := false
	var intent: String = grounding.intent_for(pending_message)
	var npc_id: String = conversations[pending_location].npc_id
	var evidence = world_state.evidence
	if not proposal.is_empty() and not client.valid_proposal(proposal):
		proposal = {}
		rejected = true
	if not proposal.is_empty():
		var unlock: Variant = proposal.conversation.suggested_unlock
		if not grounding.allows_unlock(unlock, npc_id, intent, evidence.context_flags(), evidence.progress().keys()):
			rejected = true
		elif unlock != null:
			rejected = unlock not in pending_unlocks or proposal.conversation.player_intent != intent or not evidence.valid_note(unlock, pending_message)
		if rejected:
			proposal = {}
	last_feedback[pending_location] = "Evaluación de español no disponible. Puede continuar la conversación."
	# A turn without an applied proposal (offline, failed, refused) keeps its focus slot.
	if proposal.is_empty() and not pending_focus.is_empty():
		pending_focus[0].cursor = pending_focus[1]
		pending_focus[0].recent_focus = pending_focus[2]
	pending_focus = []
	if not proposal.is_empty():
		world_state.learner.observe(proposal.language, pending_message, npc_id, pending_day)
		last_feedback[pending_location] = _language_feedback(proposal.language)
	var reply: String = proposal.get("npc_reply", pending_fallback)
	# A refused proposal must not show clue text or claim that anything was recorded.
	if rejected:
		reply = reply_for(pending_location, pending_message, false)
	# Authored disclosure also works without API. Rejected proposals never unlock it.
	if not rejected:
		for id: String in pending_unlocks:
			if evidence.record_dialogue(id, npc_id, scene_for(pending_location), pending_message, pending_day):
				reply = evidence.node(id).claim + " Esta declaración queda anotada con su fuente."
				last_feedback[pending_location] += "\nNueva afirmación anotada en el cuaderno."
				break
	var history: Array = histories[pending_location]
	history.append({"player": pending_message, "reply": reply})
	world_state.remember(npc_id, intent, pending_day)
	while history.size() > MAX_EXCHANGES:
		history.pop_front()
	input.editable = true
	speaker.disabled = false
	send_button.disabled = input.text.strip_edges().is_empty()
	if location_id == pending_location:
		_render_history()
		feedback.text = last_feedback[pending_location]
		if is_visible_in_tree():
			input.grab_focus()
	pending_location = ""
	pending_message = ""
	pending_fallback = ""
	pending_unlocks.clear()
	turn_finished.emit()

# disclose=false gives the plain authored reply, without any clue text.
func reply_for(id: String, message: String, disclose := true) -> String:
	if not conversations.has(id):
		return ""
	var evidence = world_state.evidence
	var context: Dictionary = grounding.context_for(conversations[id].npc_id,
		grounding.intent_for(message), evidence.context_flags(), evidence.progress().keys())
	for clue_id: String in context.get("npc_knowledge", {}):
		if disclose and evidence.node(clue_id).get("location_id", "") == scene_for(id) and evidence.valid_note(clue_id, message):
			return evidence.node(clue_id).claim + (" Esta declaración ya consta en el cuaderno." if evidence.has_evidence(clue_id) else "")
	var normalized := message.to_lower()
	var accents := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u"}
	for letter in accents:
		normalized = normalized.replace(letter, accents[letter])
	var punctuation := RegEx.new()
	punctuation.compile("[^a-z0-9ñ]+")
	normalized = " " + punctuation.sub(normalized, " ", true).strip_edges() + " "
	for branch: Dictionary in conversations[id].branches:
		for keyword: String in branch.keywords:
			if normalized.contains(" " + keyword + " "):
				return branch.reply
	return conversations[id].fallback

func _render_history() -> void:
	hint.text = "Objetivo: " + str(world_state.learner.curriculum.blocks[world_state.learner.curriculum.index()].title) + ". " + str(conversations[location_id].hint)
	var evidence = world_state.evidence
	for id in evidence.definitions:
		var clue: Dictionary = evidence.node(id)
		if clue.get("npc_id", "") != conversations[location_id].npc_id or evidence.has_evidence(id):
			continue
		var sample: String = clue.language.get("sample", "")
		if grounding.allows_unlock(id, conversations[location_id].npc_id, grounding.intent_for(sample),
				evidence.context_flags(), evidence.progress().keys()):
			hint.text = "Pregunta: " + sample
			break
	var npc: Dictionary = conversations[location_id]
	# A returning visitor is greeted as one once the earlier transcript is gone.
	var returning: bool = histories[location_id].is_empty() and world_state.npc_memory.has(npc.npc_id)
	var lines: Array[String] = [str(npc.name) + ": " + str(npc.get("greeting_again", npc.greeting) if returning else npc.greeting)]
	for exchange: Dictionary in histories[location_id]:
		lines.append("Tú: " + str(exchange.player))
		lines.append(str(npc.name) + ": " + str(exchange.reply))
	transcript.text = "\n\n".join(lines)

func _language_feedback(language: Dictionary) -> String:
	if language.confidence < 0.7:
		return "Evaluación incierta; no cambia tu progreso. Puedes continuar."
	var lines: Array[String] = ["Sentido comprendido ✓" if language.meaning_understood else "El sentido no está claro. Prueba a reformularlo."]
	for error: Dictionary in language.errors.slice(0, 2):
		lines.append("Mejor: %s → %s" % [_short(error.original), _short(error.better)])
	return "\n".join(lines)

func _short(text: String) -> String:
	text = text.replace("\n", " ").replace("\r", " ")
	return text if text.length() <= 60 else text.left(57) + "…"

func scene_for(conversation_id: String) -> String:
	return str(conversations.get(conversation_id, {}).get("location_id", conversation_id))

# A conversation with "requires" exists only after that campaign task is recorded.
func available(id: String) -> bool:
	if not conversations.has(id):
		return false
	var needed := str(conversations[id].get("requires", ""))
	if not needed.is_empty() and not world_state.campaign.records.has(needed):
		return false
	var companion := str(conversations[id].get("companion_hero", ""))
	if not companion.is_empty():
		if companion == world_state.party.active_id or not world_state.party.heroes.has(companion):
			return false
		var hero = world_state.party.heroes[companion]
		if not hero.unlocked or hero.cell != world_state.hero_cell:
			return false
		if world_state.location_at(world_state.hero_cell).get("id", "") != scene_for(id):
			return false
	return true
