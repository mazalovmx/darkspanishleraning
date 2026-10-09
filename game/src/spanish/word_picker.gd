extends Control
## Adds a word from any text on screen to the player's dictionary with one click.
## Rich text: select the word (double click selects one) and press the button that
## appears. Plain labels: double click the line and choose the word from the list.
## DeepSeek proposes translation and explanation; the same deterministic checks as the
## dictionary form decide whether the entry is kept.
signal added
const Lookup = preload("res://src/spanish/word_lookup.gd")
const STRIP := [".", ",", ";", ":", "!", "¡", "?", "¿", "«", "»", "\"", "(", ")", "—", "…", "·", "'"]
## Returns the current world state (the map swaps it on load and new game).
var world := Callable()
var lookup = Lookup.new()
var offer := Button.new()
var words_menu := PopupMenu.new()
var toast := PanelContainer.new()
var toast_text := Label.new()
var toast_timer := Timer.new()
var candidate := ""
var pending := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	add_child(lookup)
	lookup.finished.connect(_on_lookup)
	offer.visible = false
	offer.add_theme_font_size_override("font_size", 16)
	# A light note on any background, so it reads as an offer and not as part of the text.
	var note := StyleBoxFlat.new()
	note.bg_color = Color("f4e6c8")
	note.border_color = Color("33241a")
	note.set_border_width_all(2)
	note.set_corner_radius_all(4)
	note.set_content_margin_all(6)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		offer.add_theme_stylebox_override(state, note)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		offer.add_theme_color_override(state, Color("33241a"))
	offer.pressed.connect(func():
		offer.hide()
		pick(candidate))
	add_child(offer)
	words_menu.id_pressed.connect(func(id: int): pick(words_menu.get_item_text(words_menu.get_item_index(id))))
	add_child(words_menu)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f4e6c8")
	paper.border_color = Color("33241a")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(4)
	paper.set_content_margin_all(10)
	toast.add_theme_stylebox_override("panel", paper)
	toast.position = Vector2(240, 60)
	toast.custom_minimum_size = Vector2(800, 0)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_text.add_theme_font_size_override("font_size", 18)
	toast_text.add_theme_color_override("font_color", Color("33241a"))
	toast.add_child(toast_text)
	add_child(toast)
	toast_timer.one_shot = true
	toast_timer.timeout.connect(toast.hide)
	add_child(toast_timer)

## Watches every text under `root`. Call once the interface is built.
func watch(root: Node) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		if node == toast_text or is_ancestor_of(node):
			continue
		if node is RichTextLabel:
			node.selection_enabled = true
			node.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_selected.call_deferred(node.get_selected_text(), node.get_global_mouse_position()))
		elif node is Label:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
			node.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
					_choose_from(node.text, node.get_global_mouse_position()))

static func clean(text: String) -> String:
	var result := text.strip_edges().to_lower()
	for mark: String in STRIP:
		result = result.replace(mark, " ")
	return " ".join(result.split(" ", false))

## Distinct words of a line worth offering (three letters or more), in order.
static func words_of(text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for line: String in text.split("\n"):
		for word: String in clean(line).split(" ", false):
			if word.length() >= 3 and not word.is_valid_int() and word not in result:
				result.append(word)
	return result

func _selected(text: String, at: Vector2) -> void:
	var word := clean(text)
	if word.is_empty() or word.length() > 40 or word.split(" ").size() > 3:
		offer.hide()
		return
	candidate = word
	offer.text = "＋ «%s» al diccionario" % word
	offer.reset_size()
	offer.position = (at + Vector2(12, 14)).clamp(Vector2.ZERO, Vector2(1280, 720) - offer.size)
	offer.show()

func _choose_from(text: String, at: Vector2) -> void:
	var words := words_of(text)
	if words.is_empty():
		return
	words_menu.clear()
	words_menu.add_separator("Añadir al diccionario")
	for word: String in words.slice(0, 16):
		words_menu.add_item(word)
	words_menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))

## Looks the word up and keeps it. A word already in the dictionary is shown instead.
func pick(text: String) -> void:
	var word := clean(text)
	if word.is_empty() or not world.is_valid():
		return
	var practice = world.call().learner.word_practice
	var known: String = practice.find(word)
	if not known.is_empty():
		var item: Dictionary = practice.items[known]
		say("«%s» ya está en tu diccionario: %s. %s" % [item.word, item.en, item.clue])
		return
	if lookup.busy:
		say("Espera: todavía se consulta «%s»." % pending)
		return
	pending = word
	say("Consultando «%s»…" % word, 20.0)
	lookup.lookup(word)

func _on_lookup(entry: Dictionary, error: String) -> void:
	if not error.is_empty():
		say("«%s» no se añadió. %s También puedes escribirla en Español · Diccionario." % [pending, error])
		return
	var practice = world.call().learner.word_practice
	var known: String = practice.find(str(entry.word))
	if not known.is_empty():
		var item: Dictionary = practice.items[known]
		say("«%s» es una forma de «%s», que ya está en tu diccionario: %s. %s" % [pending, item.word, item.en, item.clue])
		return
	var result: Dictionary = practice.add_own(entry, int(world.call().day))
	if not result.ok:
		say("«%s» (%s) no se añadió sola: %s Corrígela en Español · Diccionario." % [entry.word, entry.en, result.message])
		return
	say("＋ %s — %s\n%s\nAñadida a «Mis palabras»: aparecerá en Vocabulario." % [entry.word, entry.en, entry.clue])
	added.emit()

func say(text: String, seconds := 9.0) -> void:
	toast_text.text = text
	toast.reset_size()
	toast.show()
	toast_timer.start(seconds)
