extends ColorRect
signal closed
signal progressed
var world_state: RefCounted
var task: Dictionary = {}
var title := Label.new()
var explanation := RichTextLabel.new()
var answer := LineEdit.new()
var advance := Button.new()
var feedback := Label.new()
var close_button := Button.new()
# Progress tab: blocks, frequent errors and review of lessons already studied.
var practice_tab := Button.new()
var progress_tab := Button.new()
var practice_box := VBoxContainer.new()
var progress_box := VBoxContainer.new()
var report := RichTextLabel.new()
var review_select := OptionButton.new()
var review_text := Label.new()
var review_answer := LineEdit.new()
var review_check := Button.new()
var review_next := Button.new()
var review_feedback := Label.new()
var review_exercise := 0
# Vocabulary tab: typed words from Spanish clues, Mexican Spanish first.
var words_tab := Button.new()
var words_box := VBoxContainer.new()
var words_theme := OptionButton.new()
var words_count := Label.new()
var words_clue := Label.new()
var words_answer := LineEdit.new()
var words_check := Button.new()
var words_next := Button.new()
var words_feedback := Label.new()
var word_id := ""
# Dictionary tab: every word with its English gloss, and the player's own additions.
var dictionary_tab := Button.new()
var dictionary_box := VBoxContainer.new()
var dict_search := LineEdit.new()
var dict_list := ItemList.new()
var dict_detail := RichTextLabel.new()
var dict_word := LineEdit.new()
var dict_en := LineEdit.new()
var dict_clue := LineEdit.new()
var dict_example := LineEdit.new()
var dict_lookup := Button.new()
var dict_add := Button.new()
var dict_remove := Button.new()
var dict_notice := Label.new()
var lookup = preload("res://src/spanish/word_lookup.gd").new()
var words_location := ""
static func tag_name(tag: String) -> String:
	return preload("res://src/spanish/curriculum.gd").tag_name(tag)
func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	z_index = 26
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 65)
	panel.size = Vector2(860, 590)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#22252a")
	panel.add_theme_stylebox_override("panel", style)
	# Parchment like the journal; its frame is thicker, so the inner margin shrinks.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	if paper:
		panel.position.y = 18
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var tabs := HBoxContainer.new()
	for pair in [[practice_tab, "Práctica"], [progress_tab, "Progreso y repaso"], [words_tab, "Vocabulario"], [dictionary_tab, "Diccionario"]]:
		pair[0].text = pair[1]
		pair[0].toggle_mode = true
		pair[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(pair[0])
	practice_tab.pressed.connect(func(): _show_tab(false))
	progress_tab.pressed.connect(func(): _show_tab(true))
	words_tab.pressed.connect(func(): _show_tab(false, true))
	dictionary_tab.pressed.connect(func(): _show_tab(false, false, true))
	practice_tab.tooltip_text = "Lecciones del bloque actual: escribe frases para avanzar.\nLessons of the current block."
	progress_tab.tooltip_text = "Tu avance, tus errores frecuentes y repaso sin crédito.\nYour progress, frequent errors and free review."
	words_tab.tooltip_text = "Practica palabras: lees la explicación y escribes la palabra.\nPractise words from their Spanish explanation."
	dictionary_tab.tooltip_text = "Consulta todas las palabras con su traducción y añade las tuyas.\nLook up every word and add your own."
	box.add_child(tabs)
	practice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	practice_box.add_theme_constant_override("separation", 12)
	box.add_child(practice_box)
	explanation.bbcode_enabled = false
	explanation.custom_minimum_size.y = 200
	explanation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	practice_box.add_child(explanation)
	answer.max_length = 300
	answer.placeholder_text = "Escribe una frase en español."
	answer.text_submitted.connect(func(_text: String): _submit())
	practice_box.add_child(answer)
	advance.pressed.connect(_submit)
	practice_box.add_child(advance)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 48
	practice_box.add_child(feedback)
	progress_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_box.add_theme_constant_override("separation", 8)
	box.add_child(progress_box)
	report.bbcode_enabled = false
	report.custom_minimum_size.y = 118
	report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_box.add_child(report)
	review_select.clip_text = true
	review_select.item_selected.connect(func(_index: int): review_exercise = 0; _show_review())
	progress_box.add_child(review_select)
	review_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_box.add_child(review_text)
	var review_row := HBoxContainer.new()
	review_answer.max_length = 300
	review_answer.placeholder_text = "Escribe la frase del repaso."
	review_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_answer.text_submitted.connect(func(_text: String): _check_review())
	review_row.add_child(review_answer)
	review_check.text = "Comprobar"
	review_check.pressed.connect(_check_review)
	review_row.add_child(review_check)
	review_next.text = "Otro ejercicio"
	review_next.pressed.connect(func(): review_exercise = (review_exercise + 1) % 3; _show_review())
	review_row.add_child(review_next)
	progress_box.add_child(review_row)
	review_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_box.add_child(review_feedback)
	words_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words_box.add_theme_constant_override("separation", 10)
	box.add_child(words_box)
	var words_top := HBoxContainer.new()
	words_theme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words_theme.item_selected.connect(func(_index: int): _next_word())
	words_top.add_child(words_theme)
	words_top.add_child(words_count)
	words_box.add_child(words_top)
	words_clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words_clue.custom_minimum_size.y = 120
	words_clue.add_theme_font_size_override("font_size", 20)
	words_box.add_child(words_clue)
	var words_row := HBoxContainer.new()
	words_answer.max_length = 120
	words_answer.placeholder_text = "Escribe la palabra (con su artículo) o el conector."
	words_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words_answer.text_submitted.connect(func(_text: String): _check_word())
	words_row.add_child(words_answer)
	words_check.text = "Comprobar"
	words_check.pressed.connect(_check_word)
	words_row.add_child(words_check)
	words_next.text = "Siguiente"
	words_next.pressed.connect(_next_word)
	words_row.add_child(words_next)
	words_box.add_child(words_row)
	words_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words_feedback.custom_minimum_size.y = 90
	words_box.add_child(words_feedback)
	dictionary_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dictionary_box.add_theme_constant_override("separation", 6)
	box.add_child(dictionary_box)
	dict_search.placeholder_text = "Buscar en el diccionario (español o inglés)"
	dict_search.max_length = 60
	dict_search.text_changed.connect(func(_text: String): _fill_dictionary())
	dictionary_box.add_child(dict_search)
	var dict_top := HBoxContainer.new()
	dict_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dict_list.custom_minimum_size = Vector2(330, 215)
	dict_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dict_list.item_selected.connect(_dictionary_selected)
	dict_top.add_child(dict_list)
	dict_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dict_detail.add_theme_font_size_override("normal_font_size", 15)
	dict_top.add_child(dict_detail)
	dictionary_box.add_child(dict_top)
	var dict_row := HBoxContainer.new()
	dict_word.placeholder_text = "Palabra nueva para mi lista (español o inglés)"
	dict_word.max_length = 60
	dict_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_word.text_submitted.connect(func(_text: String): _lookup_word())
	dict_row.add_child(dict_word)
	dict_lookup.text = "Completar con DeepSeek"
	dict_lookup.tooltip_text = "Pide a DeepSeek la traducción, la explicación y un ejemplo. Puedes corregirlos antes de añadir.\nAsks DeepSeek to fill in the fields below."
	dict_lookup.pressed.connect(_lookup_word)
	dict_row.add_child(dict_lookup)
	dictionary_box.add_child(dict_row)
	var dict_fields := HBoxContainer.new()
	dict_en.placeholder_text = "Traducción al inglés"
	dict_en.max_length = 80
	dict_en.custom_minimum_size.x = 230
	dict_fields.add_child(dict_en)
	dict_clue.placeholder_text = "Explicación en español (sin usar la palabra)"
	dict_clue.max_length = 200
	dict_clue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_fields.add_child(dict_clue)
	dictionary_box.add_child(dict_fields)
	var dict_last := HBoxContainer.new()
	dict_example.placeholder_text = "Frase de ejemplo (opcional)"
	dict_example.max_length = 200
	dict_example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_last.add_child(dict_example)
	dict_add.text = "Añadir"
	dict_add.tooltip_text = "Guarda la palabra en «Mis palabras»; aparecerá en Vocabulario para practicarla.\nSaves the word; it joins the practice."
	dict_add.pressed.connect(_add_word)
	dict_last.add_child(dict_add)
	dict_remove.text = "Quitar"
	dict_remove.tooltip_text = "Quita de tu lista la palabra seleccionada (solo las tuyas).\nRemoves the selected word of yours."
	dict_remove.pressed.connect(_remove_word)
	dict_last.add_child(dict_remove)
	dictionary_box.add_child(dict_last)
	dict_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dict_notice.add_theme_font_size_override("font_size", 14)
	dictionary_box.add_child(dict_notice)
	add_child(lookup)
	lookup.finished.connect(_lookup_finished)
	close_button.text = "Volver al viaje"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_course(state: RefCounted) -> void:
	if world_state != state:
		words_location = ""
	world_state = state
	feedback.text = ""
	refresh()
	_show_tab(false)
	show()

func _show_tab(progress: bool, words := false, dictionary := false) -> void:
	practice_tab.set_pressed_no_signal(not progress and not words and not dictionary)
	dictionary_tab.set_pressed_no_signal(dictionary)
	dictionary_box.visible = dictionary
	if dictionary:
		dict_notice.text = ""
		_fill_dictionary()
	progress_tab.set_pressed_no_signal(progress)
	words_tab.set_pressed_no_signal(words)
	practice_box.visible = not progress and not words and not dictionary
	progress_box.visible = progress
	words_box.visible = words
	if progress:
		_fill_progress()
	if words:
		if words_theme.item_count == 0:
			words_theme.add_item("Todos los temas")
			words_theme.set_item_metadata(0, "")
			for theme: Dictionary in world_state.learner.word_practice.themes():
				words_theme.add_item(theme.name)
				words_theme.set_item_metadata(words_theme.item_count - 1, theme.id)
		var location: String = str(world_state.location_at(world_state.hero_cell).get("id", ""))
		if location != words_location:
			words_location = location
			var theme: String = world_state.learner.word_practice.city_theme(location)
			for index in words_theme.item_count:
				if words_theme.get_item_metadata(index) == theme:
					words_theme.select(index)
					break
		_next_word()

## Lists the dictionary: conversation words not kept yet, then every entry by word.
func _fill_dictionary(select_id := "") -> void:
	var practice = world_state.learner.word_practice
	var wanted: String = practice._normal(dict_search.text, false)
	dict_list.clear()
	for word: String in world_state.learner.vocabulary:
		if practice.find(word).is_empty() and (wanted.is_empty() or practice._normal(word, false).contains(wanted)):
			dict_list.add_item("＋ %s  (de una conversación)" % word)
			dict_list.set_item_metadata(dict_list.item_count - 1, "+" + word)
	var ids: Array = practice.items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return practice._bare(practice._normal(practice.items[a].word, false)) < practice._bare(practice._normal(practice.items[b].word, false)))
	for id: String in ids:
		var item: Dictionary = practice.items[id]
		if not wanted.is_empty() and not practice._normal(item.word, false).contains(wanted) and not str(item.en).to_lower().contains(wanted):
			continue
		dict_list.add_item("%s%s — %s" % ["★ " if item.theme == practice.OWN_THEME else "", item.word, item.en])
		dict_list.set_item_metadata(dict_list.item_count - 1, id)
		if id == select_id:
			dict_list.select(dict_list.item_count - 1)
	dict_remove.disabled = true
	dict_lookup.disabled = lookup.busy
	dict_detail.text = "%d palabras · %d tuyas (★).\nElige una palabra para ver su traducción al inglés, su explicación y un ejemplo." % [practice.items.size(), practice.own.size()]
	if not select_id.is_empty() and not dict_list.get_selected_items().is_empty():
		_dictionary_selected(dict_list.get_selected_items()[0])

func _dictionary_selected(index: int) -> void:
	var practice = world_state.learner.word_practice
	var id := str(dict_list.get_item_metadata(index))
	if id.begins_with("+"):
		dict_word.text = id.substr(1)
		dict_remove.disabled = true
		dict_detail.text = "«%s» apareció en una conversación. Complétala con DeepSeek o escribe tú la traducción y la explicación; después pulsa Añadir." % id.substr(1)
		return
	var item: Dictionary = practice.items[id]
	var theme_name := ""
	for theme: Dictionary in practice.themes():
		if theme.id == item.theme:
			theme_name = theme.name
	var record: Dictionary = practice.progress.get(id, {})
	var status := "Todavía sin practicar."
	if not record.is_empty():
		status = "Nivel %d de 5 · %s" % [record.box, "toca practicarla hoy" if int(record.due) <= world_state.day else "vuelve el día %d" % record.due]
	var note := ("\n" + str(item.note)) if not str(item.note).is_empty() else ""
	dict_detail.text = "%s\nEN: %s\n\n%s\n\nEjemplo: %s%s\n\nTema: %s\n%s" % [str(item.word).to_upper(), item.en, item.clue, item.example, note, theme_name, status]
	dict_remove.disabled = item.theme != practice.OWN_THEME

func _lookup_word() -> void:
	if lookup.busy:
		return
	if dict_word.text.strip_edges().is_empty():
		dict_notice.text = "Escribe primero la palabra."
		return
	dict_notice.text = "Consultando a DeepSeek…"
	lookup.lookup(dict_word.text)
	dict_lookup.disabled = lookup.busy

func _lookup_finished(entry: Dictionary, error: String) -> void:
	dict_lookup.disabled = false
	if not error.is_empty():
		dict_notice.text = error
		return
	dict_word.text = entry.word
	dict_en.text = entry.en
	dict_clue.text = entry.clue
	dict_example.text = entry.example
	var problem: String = world_state.learner.word_practice.own_error(entry)
	dict_notice.text = "Propuesta de DeepSeek: revísala y pulsa Añadir." if problem.is_empty() else "Propuesta de DeepSeek, por corregir: " + problem

func _add_word() -> void:
	var practice = world_state.learner.word_practice
	var result: Dictionary = practice.add_own({"word": dict_word.text, "en": dict_en.text, "clue": dict_clue.text, "example": dict_example.text}, world_state.day)
	dict_notice.text = result.message
	if not result.ok:
		return
	for field: LineEdit in [dict_word, dict_en, dict_clue, dict_example]:
		field.clear()
	dict_search.clear()
	_fill_dictionary(result.id)
	progressed.emit()

func _remove_word() -> void:
	var chosen := dict_list.get_selected_items()
	if chosen.is_empty():
		return
	var id := str(dict_list.get_item_metadata(chosen[0]))
	var word := str(world_state.learner.word_practice.items.get(id, {}).get("word", ""))
	if world_state.learner.word_practice.remove_own(id):
		dict_notice.text = "«%s» ya no está en tus palabras." % word
		_fill_dictionary()
		progressed.emit()

## Shows the next due word of the chosen theme.
func _next_word() -> void:
	var practice = world_state.learner.word_practice
	var theme := str(words_theme.get_selected_metadata()) if words_theme.selected >= 0 else ""
	word_id = practice.next_item(world_state.day, theme)
	words_answer.clear()
	words_feedback.text = ""
	words_count.text = "Para hoy: %d · Dominadas: %d" % [practice.due(world_state.day, theme).size(), practice.mastered(theme)]
	words_answer.editable = not word_id.is_empty()
	words_check.disabled = word_id.is_empty()
	if word_id.is_empty():
		words_clue.text = "No quedan palabras para hoy en este tema. Vuelven otro día del viaje."
		return
	var item: Dictionary = practice.items[word_id]
	var heading := "COMPLETA CON UN CONECTOR" if item.get("cloze", false) else "¿QUÉ PALABRA ES?"
	words_clue.text = "%s\n%s" % [heading, item.clue]
	if words_answer.is_inside_tree():
		words_answer.grab_focus()

func _check_word() -> void:
	if word_id.is_empty() or world_state == null or words_check.disabled:
		return
	var course = world_state.learner.curriculum
	var result: Dictionary = world_state.learner.word_practice.check(word_id, words_answer.text, world_state.day, course.is_last_block(course.index()))
	words_feedback.text = result.message
	if result.ok:
		words_check.disabled = true
		words_answer.editable = false
	# Boxes change either way: save.
	progressed.emit()

## Blocks with their consolidated lessons, the most frequent errors, and the lessons
## the player can review.
func _fill_progress() -> void:
	var course = world_state.learner.curriculum
	var lines: PackedStringArray = ["PROGRESO · Bloque %d de 7" % (course.index() + 1)]
	for i in course.blocks.size():
		var block: Dictionary = course.blocks[i]
		var done := 0
		for card: Dictionary in block.cards:
			done += 1 if course.card_status(card.id) == "consolidada" else 0
		var mark := "✓" if done == block.cards.size() else "▸" if i == course.index() else "·"
		lines.append("%s Bloque %d · %s: %d de %d lecciones consolidadas" % [mark, i + 1, block.title, done, block.cards.size()])
	var errors: Dictionary = world_state.learner.errors
	var tags: Array = errors.keys()
	tags.sort_custom(func(a: String, b: String): return int(errors[a].count) > int(errors[b].count) if int(errors[a].count) != int(errors[b].count) else a < b)
	lines.append("")
	lines.append("ERRORES FRECUENTES" if not tags.is_empty() else "ERRORES FRECUENTES: ninguno registrado todavía.")
	for tag: String in tags.slice(0, 5):
		var example: String = str(errors[tag].examples.back()) if not errors[tag].examples.is_empty() else ""
		var level: float = float(errors[tag].get("mastery_after", world_state.learner.mastery(tag)))
		lines.append("· %s: %d %s (último día %d, dominio %d %%)%s" % [tag_name(tag), int(errors[tag].count),
			"vez" if int(errors[tag].count) == 1 else "veces", int(errors[tag].last_seen_day), roundi(level * 100), (" · «%s»" % example.left(80)) if not example.is_empty() else ""])
	# Survival dialogues of master spec 30, typed in conversation with the characters.
	var survival: Dictionary = world_state.SURVIVAL
	var done: Array = world_state.survival_done()
	lines.append("")
	lines.append("DIÁLOGOS DE SUPERVIVENCIA: %d de %d" % [done.size(), survival.size()])
	for key: String in survival:
		lines.append(("✓ " + str(survival[key][0])) if key in done else "· %s · con %s" % survival[key])
	var words: Array = world_state.learner.vocabulary.slice(-20)
	lines.append("")
	lines.append(("VOCABULARIO NUEVO DE LAS CONVERSACIONES: " + ", ".join(words)) if not words.is_empty() else "VOCABULARIO NUEVO: aparecerá al conversar.")
	report.text = "\n".join(lines)
	var selected: String = str(review_select.get_selected_metadata()) if review_select.selected >= 0 else ""
	review_select.clear()
	for i in course.blocks.size():
		for card: Dictionary in course.blocks[i].cards:
			var status: String = course.card_status(card.id)
			if status != "pendiente":
				review_select.add_item("Bloque %d · %s · «%s» (%s)" % [i + 1, tag_name(str(card.tag)), str(card.model).left(48), status])
				review_select.set_item_metadata(review_select.item_count - 1, card.id)
				if card.id == selected:
					review_select.select(review_select.item_count - 1)
	if review_select.item_count > 0 and review_select.selected < 0:
		review_select.select(0)
	_show_review()

func _show_review() -> void:
	var has_card := review_select.item_count > 0 and review_select.selected >= 0
	review_answer.visible = has_card
	review_check.visible = has_card
	review_next.visible = has_card
	review_feedback.text = ""
	review_answer.clear()
	if not has_card:
		review_text.text = "REPASO: aquí aparecerán las lecciones que ya has empezado."
		return
	var card: Dictionary = world_state.learner.curriculum.card_for(str(review_select.get_selected_metadata()))
	review_text.text = "REPASO (no cambia tu progreso)\nRegla: %s\nModelo: %s\nEjercicio %d de 3: %s" % [card.rule, card.model, review_exercise + 1, card.exercises[review_exercise].prompt]

func _check_review() -> void:
	if not review_check.visible or world_state == null:
		return
	var id := str(review_select.get_selected_metadata())
	var card: Dictionary = world_state.learner.curriculum.card_for(id)
	if world_state.learner.curriculum.review_check(id, review_exercise, review_answer.text):
		review_feedback.text = "Bien: es una de las respuestas esperadas."
	else:
		review_feedback.text = "Todavía no. Una respuesta posible: %s" % card.exercises[review_exercise].answers[0]

func refresh() -> void:
	var course = world_state.learner.curriculum
	task = course.next_task(world_state.day)
	title.text = "ESPAÑOL · Bloque %d de 7 · %s" % [course.index() + 1, course.blocks[course.index()].title]
	answer.clear()
	answer.visible = task.stage in ["guided", "first", "second", "recall"]
	advance.disabled = task.stage in ["wait", "complete"]
	if task.stage == "wait":
		explanation.text = "La práctica de hoy está completa.\n\nVuelve en un día posterior del juego para recordar sin el modelo. Puedes seguir investigando y viajando.\n\nEl siguiente bloque espera a que consolides todas las formas actuales."
		advance.text = "Repaso pendiente"
	elif task.stage == "complete":
		explanation.text = "Has completado los siete bloques de este curso.\n\nLas conversaciones siguen repasando lo aprendido; completar ejercicios no demuestra dominio de todas las situaciones reales."
		advance.text = "Curso completado"
	elif task.stage == "introduce":
		explanation.text = "NUEVA FORMA · " + str({"road":"Camino", "monastery":"Monasterio", "archive":"Archivo", "inn":"Posada", "market":"Mercado", "guard":"Guardia", "stable":"Establo", "clinic":"Hospital", "witness":"Testigo"}.get(task.card.context, "Conversación")) + "\n\n" + str(task.card.rule) + "\n\nModelo: " + str(task.card.model)
		advance.text = "Entendido · practicar"
	elif task.stage == "guided":
		explanation.text = "PRÁCTICA CON APOYO\n\n" + str(task.card.rule) + "\n\nEscribe el modelo: " + str(task.card.model) + "\n\nDespués cambiará la situación."
		advance.text = "Comprobar"
	else:
		var number: int = ["first", "second", "recall"].find(task.stage)
		explanation.text = ("RECUERDO SIN MODELO" if task.stage == "recall" else "APLICACIÓN SIN MODELO") + "\n\n" + str(task.card.exercises[number].prompt)
		if task.stage != "recall":
			explanation.text += "\n\nRecuerda: " + str(task.card.rule)
		advance.text = "Comprobar"
	if answer.visible:
		answer.grab_focus()

func _submit() -> void:
	if world_state == null or not visible or advance.disabled:
		return
	var course = world_state.learner.curriculum
	if task.stage == "introduce":
		if course.introduce(task.card.id, world_state.day):
			feedback.text = "Ahora practica la forma."
			refresh()
			progressed.emit()
		return
	var result: Dictionary = course.submit(task.card.id, answer.text, world_state.day)
	feedback.text = result.message
	if result.ok:
		refresh()
		progressed.emit()

func close() -> void:
	hide()
	closed.emit()
