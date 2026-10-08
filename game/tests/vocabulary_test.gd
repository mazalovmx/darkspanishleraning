extends SceneTree
## B1 vocabulary practice (Mexican Spanish first): typed answers, Leitner boxes over
## game days, accents only in the last block, saved with the learner.
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
const Vocabulary = preload("res://src/spanish/vocabulary.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var practice := Vocabulary.new()
	var ids: Array = practice.themes().map(func(theme: Dictionary) -> String: return theme.id)
	check(ids == ["cuerpo", "ropa", "objetos", "emociones", "cocina", "conceptos", "conectores"], "Seven themes, connectors last")
	check(practice.items.size() >= 120, "At least 120 words and connectors")
	for id: String in practice.items:
		var item: Dictionary = practice.items[id]
		check(not str(item.word).is_empty() and not str(item.clue).is_empty() and not str(item.example).is_empty(), "Every item has word, clue and example: " + id)
		if item.get("cloze", false):
			check(str(item.clue).contains("___") and not str(item.example).contains("___"), "Connector sentences have a blank, the example fills it: " + id)
	# Answers.
	check(practice.check("cuerpo_01", "el codo", 1).ok, "Word with article accepted")
	var bare: Dictionary = practice.check("cuerpo_02", "rodilla", 1)
	check(bare.ok and bare.message.begins_with("Correcto. Con artículo: «la rodilla»"), "Word without article accepted with a reminder")
	var spain: Dictionary = practice.check("ropa_01", "la camiseta", 1)
	check(spain.ok and spain.message.contains("En México se dice «playera»"), "The Spain word is accepted with the Mexican note")
	check(practice.check("cocina_02", "el sartén", 1).ok, "Mexican gender (el sartén) accepted")
	check(practice.check("conceptos_01", "la justicia.", 1).ok, "Punctuation ignored")
	check(practice.check("conectores_01", "Sin embargo", 1).ok, "Connector typed in the blank")
	check(practice.check("emociones_01", "la verguenza", 1).ok, "Accents ignored before the last block")
	check(not practice.check("emociones_02", "el orgulo", 1, true).ok, "Misspelling rejected")
	check(not practice.check("emociones_03", "la envidía", 1, true).ok and practice.check("emociones_03", "la envidia", 1, true).ok, "Accents count in the last block")
	var wrong: Dictionary = practice.check("objetos_01", "la vela", 1)
	check(not wrong.ok and wrong.message.begins_with("Era «el encendedor»") and practice.progress.objetos_01.box == 0, "A wrong answer shows the word and returns it to box 0")
	# Boxes and days.
	var fresh := Vocabulary.new()
	check(fresh.next_item(1, "cuerpo") == "cuerpo_01", "New words come in order")
	fresh.check("cuerpo_01", "el codo", 1)
	check(fresh.progress.cuerpo_01 == {"box": 1, "due": 2}, "A right answer moves to box 1, back tomorrow")
	check(not fresh.due(1, "cuerpo").has("cuerpo_01") and fresh.due(2, "cuerpo").has("cuerpo_01"), "Due again on the next day")
	fresh.check("cuerpo_02", "nada", 1)
	check(fresh.next_item(1, "cuerpo") != "cuerpo_02", "A missed word does not come back at once")
	for day in [2, 4, 8]:
		fresh.check("cuerpo_01", "el codo", day)
	check(fresh.progress.cuerpo_01.box == 4 and fresh.mastered("cuerpo") == 1, "Four right answers on spaced days master a word")
	# Save.
	var state := World.new("province_160x120_v1")
	state.learner.word_practice.check("cocina_01", "la olla", 1)
	var loaded: Dictionary = Save.decode(Save.snapshot(state))
	check(loaded.has("state") and loaded.state.learner.word_practice.progress == {"cocina_01": {"box": 1, "due": 2}}, "Vocabulary boxes survive a save")
	var older: Dictionary = Save.snapshot(state).duplicate(true)
	older.learner.erase("word_practice")
	check(Save.decode(older).has("state"), "An older save without vocabulary loads")
	var forged: Dictionary = Save.snapshot(state).duplicate(true)
	forged.learner.word_practice = {"invented": {"box": 1, "due": 1}}
	check(not Save.decode(forged).has("state"), "Unknown words rejected")
	# Panel.
	var panel = load("res://src/spanish/curriculum_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open_course(state)
	panel.words_tab.pressed.emit()
	check(panel.words_box.visible and not panel.practice_box.visible and panel.words_theme.item_count == 8, "Vocabulary tab with all themes")
	check(panel.words_clue.text.begins_with("¿QUÉ PALABRA ES?"), "A clue is shown")
	var answer: String = state.learner.word_practice.items[panel.word_id].word
	panel.words_answer.text = answer
	panel.words_check.pressed.emit()
	check(panel.words_feedback.text.begins_with("Correcto") and panel.words_check.disabled, "Typed answer checked in the panel")
	panel.words_theme.select(7)
	panel.words_theme.item_selected.emit(7)
	check(panel.words_clue.text.begins_with("COMPLETA CON UN CONECTOR") and panel.words_clue.text.contains("___"), "Connector theme shows a sentence with a blank")
	panel.queue_free()
	await process_frame
	print("Vocabulary checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
