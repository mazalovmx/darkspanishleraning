extends VBoxContainer
## Authored prototype conversations. This UI never changes canonical world state.

const MAX_EXCHANGES := 12
const MAX_MESSAGE_LENGTH := 300
var conversations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://content/dialogue/authored.json"))
var histories: Dictionary = {}
var location_id := ""
var speaker := Label.new()
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
var last_feedback: Dictionary = {}
var world_state: RefCounted

func _ready() -> void:
	add_child(client)
	client.completed.connect(_on_reply)
	add_theme_constant_override("separation", 10)
	add_child(speaker)
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
	visible = conversations.has(id)
	if not visible:
		return
	if not histories.has(id):
		histories[id] = []
	input.clear()
	send_button.disabled = true
	speaker.text = "Conversación · " + str(conversations[id].name)
	hint.text = "Objetivo: presente y peticiones sencillas. " + str(conversations[id].hint)
	feedback.text = last_feedback.get(location_id, "Evaluación de español no disponible. Puede continuar la conversación.")
	_render_history()

func submit(message: String) -> void:
	if client.busy or not is_visible_in_tree() or not conversations.has(location_id):
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
	send_button.disabled = true
	feedback.text = "Esperando respuesta…"
	client.request_reply({"npc": conversations[location_id], "player_message": clean,
		"recent_dialogue": histories[location_id].slice(-3),
		"language_profile": world_state.learner.context()})

func _on_reply(proposal: Dictionary) -> void:
	if pending_location.is_empty():
		return
	# Recheck the boundary before learner updates, even if a caller bypasses HTTP.
	if not proposal.is_empty() and not client.valid_proposal(proposal):
		proposal = {}
	last_feedback[pending_location] = "Evaluación de español no disponible. Puede continuar la conversación."
	if not proposal.is_empty():
		world_state.learner.observe(proposal.language, pending_message,
			conversations[pending_location].npc_id, pending_day)
		last_feedback[pending_location] = _language_feedback(proposal.language)
	var history: Array = histories[pending_location]
	history.append({"player": pending_message,
		"reply": proposal.get("npc_reply", pending_fallback)})
	while history.size() > MAX_EXCHANGES:
		history.pop_front()
	input.editable = true
	send_button.disabled = input.text.strip_edges().is_empty()
	if location_id == pending_location:
		_render_history()
		feedback.text = last_feedback.get(location_id, "Evaluación de español no disponible. Puede continuar la conversación.")
		if is_visible_in_tree():
			input.grab_focus()
	pending_location = ""
	pending_message = ""
	pending_fallback = ""

func reply_for(id: String, message: String) -> String:
	if not conversations.has(id):
		return ""
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
	var npc: Dictionary = conversations[location_id]
	var lines: Array[String] = [str(npc.name) + ": " + str(npc.greeting)]
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
