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
# Speaker portrait (game/CREDITS.md); hidden when a character has none.
const PORTRAITS := "res://assets/third_party/claw_and_blade/portraits/"
const OWN_PORTRAITS := "res://assets/portraits/"
var portrait := TextureRect.new()
var input := LineEdit.new()
var send_button := Button.new()
var feedback := Label.new()
var hint := Label.new()
var client = preload("res://src/claude/claude_client.gd").new()
var pending_location := ""
var pending_message := ""
var pending_fallback := ""
# Authored branch behind the offline reply ("" for none): the next turn may follow it.
var pending_branch: Dictionary = {}
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
	var talk := HBoxContainer.new()
	talk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(talk)
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	talk.add_child(portrait)
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talk.add_child(transcript)
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
	# A place whose own speaker is absent (or who has none) opens the first one present.
	if not available(id):
		for key: String in conversations:
			if scene_for(key) == id and available(key):
				id = key
				break
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
	var face := PORTRAITS + str(conversations[id].npc_id) + ".png"
	# Speakers added later have the project's own portraits (tools/make_portraits.py).
	if not ResourceLoader.exists(face):
		face = OWN_PORTRAITS + str(conversations[id].npc_id) + ".png"
	portrait.texture = load(face) if ResourceLoader.exists(face) else null
	portrait.visible = portrait.texture != null
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
	pending_branch = branch_for(location_id, clean)
	if pending_branch.get("reply", "") != pending_fallback:
		pending_branch = {}
	input.clear()
	input.editable = false
	speaker.disabled = true
	send_button.disabled = true
	feedback.text = "Esperando respuesta…"
	# Capture eligible IDs before sending; recheck live prerequisites on completion.
	var context: Dictionary = grounding.context_for(conversations[location_id].npc_id,
		grounding.intent_for(clean), context_flags(), world_state.evidence.progress().keys())
	pending_unlocks = context.get("eligible_unlock_ids", []).duplicate()
	var place: Dictionary = world_state.location_at(world_state.hero_cell)
	context["scene"] = {"map_id": world_state.map_id, "day": world_state.day,
		"location_id": str(place.get("id", "")), "name": str(place.get("name", "")),
		"conversation_location_id": scene_for(location_id)}
	context["player_message"] = clean
	var hero_definition: Dictionary = world_state.party.active().definition
	context["player_hero"] = {"id": world_state.party.active_id, "name": hero_definition.name,
		"role": hero_definition.role, "register": hero_definition.register}
	context["recent_dialogue"] = histories[location_id].slice(-4).duplicate(true)
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
		if not grounding.allows_unlock(unlock, npc_id, intent, context_flags(), evidence.progress().keys()):
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
		# Outside the last block a tilde, ü or apostrophe is not an error (master spec 1.3).
		var course = world_state.learner.curriculum
		if not course.is_last_block(course.index()):
			proposal.language.errors = proposal.language.errors.filter(func(error: Dictionary) -> bool:
				return course.fold(error.original) != course.fold(error.better))
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
	history.append({"player": pending_message, "reply": reply, "branch": str(pending_branch.get("id", ""))})
	world_state.remember(npc_id, intent, pending_day)
	# A finished survival exchange of master spec 30 counts once it has been carried through.
	if pending_branch.has("survival"):
		world_state.note_survival(npc_id, str(pending_branch.survival))
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
	pending_branch = {}
	pending_unlocks.clear()
	turn_finished.emit()

# disclose=false gives the plain authored reply, without any clue text.
## Evidence flags plus the flags confirmed by recorded campaign tasks.
func context_flags() -> Dictionary:
	var flags: Dictionary = world_state.evidence.context_flags()
	flags.merge(grounding.campaign_flags(world_state.campaign.records))
	# Publication or protected copy chosen at the end of an optional case.
	flags.merge(world_state.side_cases.outcome_flags())
	return flags

func reply_for(id: String, message: String, disclose := true) -> String:
	if not conversations.has(id):
		return ""
	var evidence = world_state.evidence
	var context: Dictionary = grounding.context_for(conversations[id].npc_id,
		grounding.intent_for(message), context_flags(), evidence.progress().keys())
	for clue_id: String in context.get("npc_knowledge", {}):
		if disclose and evidence.node(clue_id).get("location_id", "") == scene_for(id) and evidence.valid_note(clue_id, message):
			return evidence.node(clue_id).claim + (" Esta declaración ya consta en el cuaderno." if evidence.has_evidence(clue_id) else "")
	return str(branch_for(id, message).get("reply", conversations[id].fallback))

## The first authored branch whose keyword the message contains. A branch with
## "follows" answers only right after the branch with that id (a short exchange such
## as "¿Cuántas?" → "Tres."); one with "requires_flag" only once that flag is confirmed.
func branch_for(id: String, message: String) -> Dictionary:
	if not conversations.has(id):
		return {}
	var history: Array = histories.get(id, [])
	var previous: String = str(history.back().get("branch", "")) if not history.is_empty() else ""
	var normalized := message.to_lower()
	var accents := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u"}
	for letter in accents:
		normalized = normalized.replace(letter, accents[letter])
	var punctuation := RegEx.new()
	punctuation.compile("[^a-z0-9ñ]+")
	normalized = " " + punctuation.sub(normalized, " ", true).strip_edges() + " "
	var flags := context_flags()
	for branch: Dictionary in conversations[id].branches:
		if branch.has("requires_flag") and flags.get(branch.requires_flag, "") != "confirmed":
			continue
		if branch.has("follows") and branch.follows != previous:
			continue
		for keyword: String in branch.keywords:
			if normalized.contains(" " + keyword + " "):
				return branch
	return {}

func _render_history() -> void:
	hint.text = "Objetivo: " + str(world_state.learner.curriculum.blocks[world_state.learner.curriculum.index()].title) + ". " + str(conversations[location_id].hint)
	var evidence = world_state.evidence
	for id in evidence.definitions:
		var clue: Dictionary = evidence.node(id)
		if clue.get("npc_id", "") != conversations[location_id].npc_id or evidence.has_evidence(id):
			continue
		var sample: String = clue.language.get("sample", "")
		if grounding.allows_unlock(id, conversations[location_id].npc_id, grounding.intent_for(sample),
				context_flags(), evidence.progress().keys()):
			hint.text = "Pregunta: " + sample
			break
	var npc: Dictionary = conversations[location_id]
	# A returning visitor is greeted as one once the earlier transcript is gone.
	var returning: bool = histories[location_id].is_empty() and world_state.npc_memory.has(npc.npc_id)
	var greeting: String = str(npc.get("greeting_again", npc.greeting) if returning else npc.greeting)
	# The dark side breaks through now and then: every third exchange on a return visit.
	if returning and npc.has("dark_line") and int(world_state.npc_memory[npc.npc_id].get("count", 0)) % 3 == 2:
		greeting += " " + str(npc.dark_line)
	var lines: Array[String] = [str(npc.name) + ": " + greeting]
	for exchange: Dictionary in histories[location_id]:
		lines.append("Tú: " + str(exchange.player))
		lines.append(str(npc.name) + ": " + str(exchange.reply))
	transcript.text = "\n\n".join(lines)

func _language_feedback(language: Dictionary) -> String:
	if language.confidence < 0.7:
		return "Evaluación incierta; no cambia tu progreso. Puedes continuar."
	var lines: Array[String] = ["Sentido comprendido ✓" if language.meaning_understood else "El sentido no está claro. Prueba a reformularlo."]
	var course = world_state.learner.curriculum if world_state != null else null
	# Tildes, ü and apostrophes count only in the last block (master spec 1.3).
	var strict: bool = course == null or course.is_last_block(course.index())
	var shown := 0
	for error: Dictionary in language.errors:
		if shown >= 2:
			break
		if not strict and course.fold(str(error.original)) == course.fold(str(error.better)):
			continue
		lines.append("Mejor: %s → %s" % [_short(error.original), _short(error.better)])
		var why: String = course.explain(str(error.get("type", ""))) if course != null else ""
		if not why.is_empty():
			lines.append("   " + why)
		shown += 1
	return "\n".join(lines)

func _short(text: String) -> String:
	text = text.replace("\n", " ").replace("\r", " ")
	return text if text.length() <= 60 else text.left(57) + "…"

func scene_for(conversation_id: String) -> String:
	return str(conversations.get(conversation_id, {}).get("location_id", conversation_id))

# A conversation with "requires" exists only after those campaign tasks or evidence are recorded.
func available(id: String) -> bool:
	if not conversations.has(id):
		return false
	var required: Variant = conversations[id].get("requires", [])
	for needed: String in (required if required is Array else [required]):
		# "e:<id>" names canonical evidence; anything else a recorded campaign task.
		if not (world_state.evidence.has_evidence(needed.substr(2)) if needed.begins_with("e:") else world_state.campaign.records.has(needed)):
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
