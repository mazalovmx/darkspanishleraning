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
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	explanation.bbcode_enabled = false
	explanation.custom_minimum_size.y = 240
	explanation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(explanation)
	answer.max_length = 300
	answer.placeholder_text = "Escribe una frase en español."
	answer.text_submitted.connect(func(_text: String): _submit())
	box.add_child(answer)
	advance.pressed.connect(_submit)
	box.add_child(advance)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 55
	box.add_child(feedback)
	close_button.text = "Volver al viaje"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_course(state: RefCounted) -> void:
	world_state = state
	feedback.text = ""
	refresh()
	show()

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
