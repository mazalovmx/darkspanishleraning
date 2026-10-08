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
const TAG_NAMES := {"ser_estar": "ser / estar", "hay": "hay", "gender_articles": "género y artículos",
	"present": "presente", "preterite": "pretérito indefinido", "imperfect": "imperfecto",
	"preterite_vs_imperfect": "pretérito frente a imperfecto", "object_pronouns": "pronombres de objeto",
	"gustar": "gustar", "por_para": "por / para", "se": "se impersonal", "reflexive": "verbos reflexivos",
	"relative_clauses": "oraciones de relativo", "imperative": "imperativo", "ir_a_future": "ir a + infinitivo",
	"future_simple": "futuro simple", "perfect": "pretérito perfecto", "conditional": "condicional",
	"subjunctive_basic": "subjuntivo", "reported_speech": "estilo indirecto"}

static func tag_name(tag: String) -> String:
	if tag.begins_with("verb:"):
		return "verbo " + tag.trim_prefix("verb:")
	return str(TAG_NAMES.get(tag, tag.replace("_", " ")))
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
	for pair in [[practice_tab, "Práctica"], [progress_tab, "Progreso y repaso"]]:
		pair[0].text = pair[1]
		pair[0].toggle_mode = true
		pair[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(pair[0])
	practice_tab.pressed.connect(func(): _show_tab(false))
	progress_tab.pressed.connect(func(): _show_tab(true))
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
	close_button.text = "Volver al viaje"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_course(state: RefCounted) -> void:
	world_state = state
	feedback.text = ""
	refresh()
	_show_tab(false)
	show()

func _show_tab(progress: bool) -> void:
	practice_tab.set_pressed_no_signal(not progress)
	progress_tab.set_pressed_no_signal(progress)
	practice_box.visible = not progress
	progress_box.visible = progress
	if progress:
		_fill_progress()

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
		lines.append("· %s: %d %s (último día %d)%s" % [tag_name(tag), int(errors[tag].count),
			"vez" if int(errors[tag].count) == 1 else "veces", int(errors[tag].last_seen_day), (" · «%s»" % example.left(80)) if not example.is_empty() else ""])
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
