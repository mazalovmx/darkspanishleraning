extends ColorRect
signal closed
signal evidence_recorded
var world_state: RefCounted
var active_id := ""
var inspection_mode := false
var reasoning_mode := false
var compare_button := Button.new()
var support_row := HBoxContainer.new()
var support_a := OptionButton.new()
var support_b := OptionButton.new()
var prompt := Label.new()
var entries := OptionButton.new()
var body := RichTextLabel.new()
var note := LineEdit.new()
var category := OptionButton.new()
var record_button := Button.new()
var feedback := Label.new()
var exercise := VBoxContainer.new()
var close_button := Button.new()
## Says, for the page on screen, what the player is expected to do next.
var guide := Label.new()
## Failed attempts at the page on screen: the example is shown from the second one.
var attempts := 0
const KINDS := ["", "observation", "interpretation", "accusation", "institutional_declaration"]
const KIND_HELP := {
	"observation": "Una OBSERVACIÓN dice solo lo que ves tú. Empieza con: Hay… / Veo… / … tiene… / … está… / Falta…",
	"interpretation": "Una INTERPRETACIÓN dice lo que supones: Creo que… / Quizá… / Parece que…",
	"accusation": "Una ACUSACIÓN culpa a alguien: … es culpable / … mata a…",
	"institutional_declaration": "Una DECLARACIÓN INSTITUCIONAL repite lo que ordena o afirma una autoridad: El abad ordena… / La orden exige…"}

func _ready() -> void:
	color = Color(0, 0, 0, 0.8)
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(180, 35)
	panel.size = Vector2(920, 650)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel", background)
	# The paper frame is taller than the flat one: start higher and tighten the inner margin.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	if paper:
		panel.position.y = 8
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "CUADERNO DE INVESTIGACIÓN"
	box.add_child(title)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", preload("res://src/common/ui_tokens.gd").CAPTION)
	box.add_child(guide)
	entries.tooltip_text = "Páginas del cuaderno. ✓ ya anotada · ● falta anotarla.\nNotebook pages: ✓ recorded, ● still to record."
	compare_button.tooltip_text = "Cuando tengas varias pruebas: elige una hipótesis, dos pruebas que la apoyan y escribe una conclusión.\nWith several pieces recorded: pick a hypothesis, two supporting pieces and write a conclusion."
	category.tooltip_text = "Observación: lo que ves tú. Interpretación: lo que supones. Acusación: culpar a alguien. Declaración institucional: lo que dice una autoridad.\nObservation = what you see; interpretation = what you suppose; accusation = blaming someone; institutional declaration = what an authority states."
	record_button.tooltip_text = "Guarda tu frase en el cuaderno. Si falta algo, el texto de abajo dice qué.\nSaves your sentence; the line below says what is missing."
	box.add_child(entries)
	compare_button.text = "Comparar pruebas"
	compare_button.pressed.connect(open_reasoning)
	box.add_child(compare_button)
	entries.item_selected.connect(func(index: int):
		active_id = str(entries.get_item_metadata(index))
		_render())
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size", 16)
	body.custom_minimum_size = Vector2(880, 300)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	box.add_child(exercise)
	prompt.text = "Describe lo que ves: Hay… / Veo… / Tomás tiene…\nPalabras: comida · comida para un viaje"
	prompt.add_theme_font_size_override("font_size", 16)
	exercise.add_child(prompt)
	note.placeholder_text = "Escribe una frase en español."
	note.max_length = 300
	exercise.add_child(note)
	exercise.add_child(support_row)
	for selector in [support_a, support_b]:
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.clip_text = true
		support_row.add_child(selector)
	var row := HBoxContainer.new()
	exercise.add_child(row)
	category.add_item("Esta frase es…")
	category.add_item("Una observación")
	category.add_item("Una interpretación")
	category.add_item("Una acusación")
	category.add_item("Una declaración institucional")
	row.add_child(category)
	record_button.text = "Anotar la prueba"
	record_button.pressed.connect(_record)
	row.add_child(record_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 16)
	box.add_child(feedback)
	close_button.text = "Volver"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_journal(state: RefCounted) -> void:
	inspection_mode = false
	reasoning_mode = false
	world_state = state
	active_id = "travel_food" if state.evidence.has_evidence("travel_food") else ""
	if state.evidence.has_evidence("monastery_claim"):
		active_id = "monastery_claim"
	_render()
	show()
	close_button.grab_focus()

func inspect(state: RefCounted) -> bool:
	var location: Dictionary = state.location_at(state.hero_cell)
	if location.get("id", "") != "LOC01":
		return false
	world_state = state
	inspection_mode = true
	reasoning_mode = false
	active_id = "travel_food"
	_render()
	show()
	if exercise.visible:
		note.grab_focus()
	return true

func close() -> void:
	hide()
	closed.emit()

func _render() -> void:
	entries.clear()
	var ids: Array = world_state.evidence.progress().keys()
	if reasoning_mode:
		ids = world_state.evidence.reviewable_ids(world_state.day)
	if inspection_mode:
		var location: Dictionary = world_state.location_at(world_state.hero_cell)
		for id in world_state.evidence.inspectable_ids(location.get("id", "")):
			if id not in ids:
				ids.append(id)
	if not active_id.is_empty() and active_id not in ids and not active_id.contains(":"):
		ids.append(active_id)
	var pending := 0
	for id: String in ids:
		var done: bool = world_state.evidence.has_evidence(id)
		pending += int(not done)
		entries.add_item(("✓ " if done else "● ") + str(world_state.evidence.node(id).title))
		entries.set_item_metadata(entries.item_count - 1, id)
		if id == active_id:
			entries.select(entries.item_count - 1)
	# Optional local cases and their comparisons (read-only pages of the notebook).
	if not inspection_mode and not reasoning_mode and world_state.map_id == "province_160x120_v1":
		for branch: String in world_state.side_cases.started_branches():
			entries.add_item("Investigación local · " + str(world_state.side_cases.branches[branch].title))
			entries.set_item_metadata(entries.item_count - 1, "case:" + branch)
			if active_id == "case:" + branch:
				entries.select(entries.item_count - 1)
		for link: Dictionary in world_state.side_cases.open_links():
			entries.add_item("Comparación · %s y %s" % [world_state.side_cases.branches[link.from].title, world_state.side_cases.branches[link.to].title])
			entries.set_item_metadata(entries.item_count - 1, "link:" + str(link.id))
			if active_id == "link:" + str(link.id):
				entries.select(entries.item_count - 1)
	entries.visible = entries.item_count > 1 or (entries.item_count == 1 and str(entries.get_item_metadata(0)).contains(":"))

	note.clear()
	category.clear()
	for label in ["Mi frase es…", "Una observación: lo que veo yo", "Una interpretación: lo que supongo", "Una acusación: culpo a alguien", "Una declaración institucional: lo que ordena una autoridad"]:
		category.add_item(label)
	category.select(0)
	support_row.hide()
	category.show()
	record_button.text = "Anotar la prueba"
	compare_button.visible = not reasoning_mode
	body.custom_minimum_size.y = 300
	feedback.text = ""
	guide.text = ""
	exercise.hide()
	if active_id.is_empty():
		body.text = "Todavía no hay pruebas anotadas. Examina las pertenencias de Tomás en Santa Lucerna."
		guide.text = "QUÉ HACER: ve con el héroe al monasterio de Santa Lucerna, haz clic en él para entrar y pulsa «Examinar pertenencias». Allí escribes tu primera prueba.\nWhat to do: enter the monastery and press «Examinar pertenencias» to record your first piece of evidence."
		return
	if active_id.begins_with("case:"):
		body.text = world_state.side_cases.case_summary(active_id.trim_prefix("case:"))
		body.scroll_to_line(0)
		return
	if active_id.begins_with("link:"):
		var link_id := active_id.trim_prefix("link:")
		for link: Dictionary in world_state.side_cases.open_links():
			if str(link.id) == link_id:
				body.text = "COMPARACIÓN ENTRE EXPEDIENTES\n%s\n\n%s\n\nNo cambia la resolución de ninguno de los dos casos." % [link.prompt, "Casos: %s · %s" % [world_state.side_cases.branches[link.from].title, world_state.side_cases.branches[link.to].title]]
		body.scroll_to_line(0)
		var answered: Dictionary = world_state.side_cases.comparisons.get(link_id, {})
		if answered.is_empty():
			# The player writes the comparison: both cases and a comparing word.
			exercise.show()
			category.hide()
			body.custom_minimum_size.y = 190
			record_button.text = "Anotar la comparación"
			prompt.text = "Compara los dos casos en una frase: nombra algo de cada uno y usa pero, en cambio, mientras, aunque o igual que."
			feedback.text = "Una comparación no es una prueba nueva: ordena lo que ya sabes."
		else:
			feedback.text = "Tu comparación (día %d): %s" % [int(answered.day), answered.answer]
		return
	var clue: Dictionary = world_state.evidence.node(active_id)
	if clue.source_type == "reasoning" and not world_state.evidence.has_evidence(active_id):
		_render_assessment(clue)
		return
	var graph = world_state.evidence
	if graph.has_evidence(active_id):
		prompt.text = ""
		body.text = "%s\n\nLO QUE VISTE (observación)\n%s\nFuente: %s\n\nLO QUE DICEN OTROS (no lo has visto tú)\n%s\nLo dice: %s\n\nQUÉ PODRÍA SIGNIFICAR (interpretaciones, ninguna probada)\n• %s\n\nESTADO INSTITUCIONAL\n%s\n\nVÍNCULO CAUSAL\n%s" % [
			clue.title, clue.observation, clue.source, clue.claim, clue.claim_source,
			"\n• ".join(clue.interpretations), clue.institutional_status, clue.causal_link]
		body.scroll_to_line(0)
		guide.text = "✓ Esta prueba ya está en tu cuaderno. " + ("Quedan %d sin anotar (●): elígelas en la lista de arriba." % pending if pending > 0 else "Aquí no queda nada por anotar: habla con la gente del lugar sobre lo que has visto, o pulsa Volver.")
		feedback.text = ("Tu pregunta: " if clue.source_type == "testimony" else "Tu anotación: ") + str(graph.progress()[active_id].spanish_note)
		if clue.source_type != "testimony":
			feedback.text += "\nOtra forma de decirlo: " + str(clue.language.get("sample", ""))
		return
	# Not recorded yet: read the scene, then write the kind of sentence the task asks for.
	attempts = 0
	exercise.show()
	body.custom_minimum_size.y = 190
	var scene := str(graph.practice.get(active_id, {}).get("scene", clue.observation))
	body.text = "HALLAZGO · %s\n\n%s\n\nTAREA: escribe %s sobre esto, en español y con tus palabras.\n%s" % [
		clue.title, scene, graph.KIND_NAMES.get(clue.classification, "una frase"), KIND_HELP.get(clue.classification, "")]
	body.scroll_to_line(0)
	prompt.text = "Palabras útiles: %s" % clue.language.get("vocabulary", "")
	guide.text = "CÓMO ANOTAR: 1) Lee el hallazgo. 2) Escribe tu frase. 3) Di qué clase de frase es. 4) Pulsa «Anotar la prueba». Si falta algo, abajo se explica qué.\nRead the finding, write your sentence, say what kind it is, press the button."
	feedback.text = ""

func _record() -> void:
	if active_id.is_empty() or world_state == null:
		return
	if reasoning_mode:
		_record_assessment()
		return
	if active_id.begins_with("link:"):
		var result: Dictionary = world_state.side_cases.answer_comparison(world_state, active_id.trim_prefix("link:"), note.text)
		feedback.text = result.message
		if result.ok:
			_render()
			evidence_recorded.emit()
		return
	var location: Dictionary = world_state.location_at(world_state.hero_cell)
	var clue: Dictionary = world_state.evidence.node(active_id)
	var graph = world_state.evidence
	var wanted: String = clue.classification
	var chosen: String = KINDS[category.selected] if category.selected > 0 else ""
	var written: String = graph.kind_of(note.text)
	var needs: Array[String] = graph.missing_note(active_id, note.text)
	var problems: Array[String] = []
	if not needs.is_empty():
		problems.append("Tu frase necesita: " + "; ".join(needs) + ".")
	if chosen.is_empty():
		problems.append("Elige en la lista qué clase de frase has escrito.")
	elif not note.text.strip_edges().is_empty() and chosen != written:
		# The choice is checked against the player's own words, not against a hidden answer.
		problems.append("Has marcado %s, pero tu frase es %s. %s" % [graph.KIND_NAMES[chosen], graph.KIND_NAMES[written], KIND_HELP[written]])
	elif chosen != wanted:
		problems.append("Aquí se pide %s. %s" % [graph.KIND_NAMES.get(wanted, wanted), KIND_HELP.get(wanted, "")])
	if problems.is_empty() and graph.record(active_id, location.get("id", ""), note.text, chosen, world_state.day):
		_render()
		evidence_recorded.emit()
		return
	attempts += 1
	if problems.is_empty():
		problems.append("Esta prueba no se puede anotar aquí ahora.")
	if attempts >= 2:
		problems.append("Un ejemplo (cámbialo a tu manera): " + str(clue.language.get("sample", "")))
	feedback.text = "\n".join(problems)

func open_reasoning() -> void:
	var ids: Array = world_state.evidence.reviewable_ids(world_state.day)
	if ids.is_empty():
		feedback.text = "Anota la comida y pregunta al abad antes de comparar las versiones."
		return
	reasoning_mode = true
	inspection_mode = false
	active_id = str(ids.back())
	for id: String in ids:
		if not world_state.evidence.has_evidence(id):
			active_id = id
			break
	_render()

func _render_assessment(clue: Dictionary) -> void:
	body.custom_minimum_size.y = 230
	body.text = str(clue.assessment.question) + "\n\nPRUEBAS DISPONIBLES"
	for id in world_state.evidence.progress():
		var item: Dictionary = world_state.evidence.node(id)
		if item.source_type != "reasoning":
			body.text += "\n• " + str(item.title) + ": " + str(item.observation)
	body.scroll_to_line(0)
	prompt.text = "Formula una conclusión prudente con tus palabras. Palabras útiles: " + str(clue.language.get("vocabulary", ""))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	category.clear()
	category.add_item("Selecciona una hipótesis…")
	category.set_item_metadata(0, "")
	for option: Dictionary in clue.assessment.options:
		category.add_item(option.text)
		category.set_item_metadata(category.item_count - 1, option.id)
	category.clip_text = true
	category.custom_minimum_size.x = 570
	for selector in [support_a, support_b]:
		selector.clear()
		selector.add_item("Selecciona una prueba de apoyo…")
		selector.set_item_metadata(0, "")
		for id in world_state.evidence.progress():
			var item: Dictionary = world_state.evidence.node(id)
			if item.source_type != "reasoning":
				selector.add_item(item.title)
				selector.set_item_metadata(selector.item_count - 1, id)
	support_row.show()
	exercise.show()
	feedback.text = "Elige una hipótesis, dos pruebas distintas y escribe tu conclusión."
	guide.text = "CÓMO COMPARAR: 1) Lee la pregunta y las pruebas. 2) Elige una hipótesis. 3) Elige dos pruebas distintas que la apoyan. 4) Escribe una conclusión prudente y pulsa el botón.\nPick a hypothesis, two different supporting pieces, write a cautious conclusion."

func _record_assessment() -> void:
	var clue: Dictionary = world_state.evidence.node(active_id)
	var supports: Array = [support_a.get_item_metadata(support_a.selected),
		support_b.get_item_metadata(support_b.selected)]
	var choice: String = str(category.get_item_metadata(category.selected))
	if world_state.evidence.record_reasoning(active_id, note.text, choice, supports, world_state.day):
		_render()
		evidence_recorded.emit()
	else:
		attempts += 1
		var needs: Array[String] = world_state.evidence.missing_note(active_id, note.text)
		feedback.text = str(clue.assessment.feedback) + " Revisa también la hipótesis y los dos apoyos."
		if not needs.is_empty():
			feedback.text += "\nTu frase necesita: " + "; ".join(needs) + "."
		if attempts >= 2:
			feedback.text += "\nUn ejemplo (cámbialo a tu manera): " + str(clue.language.sample)
