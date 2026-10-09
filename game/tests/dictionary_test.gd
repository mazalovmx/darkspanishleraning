extends SceneTree
const Vocabulary = preload("res://src/spanish/vocabulary.gd")
const Lookup = preload("res://src/spanish/word_lookup.gd")
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
var checks := 0
var failures := 0
var sent: Array = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func reply(content: Variant) -> String:
	return JSON.stringify({"choices": [{"message": {"content": content if content is String else JSON.stringify(content)}}]})
func run() -> void:
	root.size = Vector2i(1280, 720)
	var words := Vocabulary.new()
	for id: String in words.items:
		check(not str(words.items[id].en).is_empty(), "Every built-in word has an English gloss: " + id)
	check(words.items.cuerpo_02.en == "knee" and words.find("Rodilla") == "cuerpo_02" and words.find("la bodega") == "cardena_06", "Words are found by form, article or alternative")
	check(words.check("cuerpo_02", "la rodilla", 1).message.contains("(en inglés: knee)"), "Practice feedback shows the English gloss")
	# Own words.
	var entry := {"word": "el farol", "en": "lantern, street lamp", "clue": "Caja con cristales que protege una luz y se cuelga o se lleva en la mano.", "example": "Colgó el farol junto a la puerta."}
	var added: Dictionary = words.add_own(entry, 3)
	check(added.ok and added.id == "mia_0001" and words.items.mia_0001.theme == "mias" and words.own.size() == 1, "A complete own word is kept")
	check(words.due(3, "mias") == ["mia_0001"] and words.next_item(3, "mias") == "mia_0001", "An own word is due for practice on the day it is added")
	check(words.check("mia_0001", "farol", 3).ok and words.progress.mia_0001 == {"box": 1, "due": 4}, "An own word is practised and scheduled like any other")
	check(not words.add_own(entry, 3).ok and not words.add_own({"word": "la rodilla", "en": "knee", "clue": "Parte de la pierna.", "example": ""}, 3).ok, "A word already in the dictionary is not added twice")
	for bad: Dictionary in [{"word": "", "en": "x", "clue": "y"}, {"word": "el pozo", "en": "", "clue": "y"}, {"word": "el pozo", "en": "well", "clue": ""},
			{"word": "el pozo", "en": "well", "clue": "Un pozo es un agujero con agua."}, {"word": "el pozo", "en": "well", "clue": "Agujero\ncon agua."}, {"word": "p".repeat(61), "en": "well", "clue": "Agujero con agua."}]:
		check(not words.add_own(bad, 3).ok, "Incomplete, oversized or self-revealing own word rejected: " + str(bad).left(50))
	check(words.own.size() == 1, "Rejected words leave the list unchanged")
	check(words.add_own({"word": "el pozo", "en": "well", "clue": "Agujero profundo del que se saca agua.", "example": ""}, 3).id == "mia_0002", "Own ids grow; the example is optional")
	check(words.remove_own("mia_0001") and not words.items.has("mia_0001") and not words.progress.has("mia_0001") and not words.remove_own("cuerpo_01"), "Only own words can be removed, with their boxes")
	check(words.add_own(entry, 5).id == "mia_0003", "A removed id is not reused while a later one exists")
	# Save.
	var state := World.new("province_160x120_v1")
	state.learner.word_practice.add_own(entry, 1)
	state.learner.word_practice.check("mia_0001", "el farol", 1)
	var loaded: Dictionary = Save.decode(Save.snapshot(state))
	check(loaded.has("state") and loaded.state.learner.word_practice.own == [{"id": "mia_0001", "word": "el farol", "en": "lantern, street lamp", "clue": entry.clue, "example": entry.example}], "Own words survive a save")
	check(loaded.has("state") and loaded.state.learner.word_practice.progress.mia_0001 == {"box": 1, "due": 2} and loaded.state.learner.word_practice.items.mia_0001.en == "lantern, street lamp", "Their boxes and glosses survive too")
	var older: Dictionary = Save.snapshot(state).duplicate(true)
	older.learner.erase("own_words")
	older.learner.word_practice.erase("mia_0001")
	check(Save.decode(older).has("state"), "A save written before own words existed still loads")
	for forgery: Array in [["id", "cuerpo_01"], ["id", "mia_x"], ["clue", ""], ["word", "la rodilla"], ["extra", "x"]]:
		var forged: Dictionary = Save.snapshot(state).duplicate(true)
		forged.learner.own_words[0][forgery[0]] = forgery[1]
		check(not Save.decode(forged).has("state"), "Forged own word rejected: " + str(forgery))
	var doubled: Dictionary = Save.snapshot(state).duplicate(true)
	doubled.learner.own_words.append(doubled.learner.own_words[0].duplicate())
	check(not Save.decode(doubled).has("state"), "Duplicated own word rejected")
	# DeepSeek lookup behind a fake transport: no network in tests.
	var lookup = Lookup.new()
	root.add_child(lookup)
	var results: Array = []
	lookup.finished.connect(func(found: Dictionary, error: String): results.append([found, error]))
	lookup.transport = Callable()
	lookup.model = ""
	lookup.lookup("farol")
	check(results.size() == 1 and results[0][0].is_empty() and results[0][1].contains("DEEPSEEK_API_KEY") and not lookup.busy, "Without a key the lookup explains itself and asks nothing")
	lookup.model = "deepseek-flash"
	lookup.transport = func(body: String): sent.append(JSON.parse_string(body))
	lookup.lookup("  lantern ")
	check(lookup.busy and sent.size() == 1 and sent[0].model == "deepseek-flash" and sent[0].messages[1].content == "lantern" and sent[0].response_format == {"type": "json_object"} and sent[0].thinking == {"type": "disabled"}, "One JSON-mode request carries only the word")
	lookup.lookup("otra")
	check(sent.size() == 1, "A second lookup waits for the first")
	lookup.answer(200, reply(entry))
	check(results.size() == 2 and results[1][0] == entry and results[1][1].is_empty() and not lookup.busy, "A complete answer becomes a proposal")
	for case: Array in [[402, "", "saldo"], [500, "", "código 500"], [200, "not json", "no reconoció"], [200, reply({"error": "unknown"}), "no reconoció"], [200, reply({"word": "el farol", "en": 5, "clue": "x", "example": "y"}), "no sirve"]]:
		lookup.lookup("farol")
		lookup.answer(case[0], case[1])
		check(results.back()[0].is_empty() and results.back()[1].contains(case[2]) and not lookup.busy, "A failed or malformed answer gives a message, not an entry: " + str(case[2]))
	lookup.answer(200, reply(entry))
	check(results.size() == 7, "An answer nobody asked for is ignored")
	lookup.queue_free()
	# Panel.
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = "user://dictionary_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	var play = map.state
	play.learner.vocabulary.assign(["rodilla", "candil"])
	var panel = map.lessons
	var saves := [0]
	panel.progressed.connect(func(): saves[0] += 1)
	map.language_button.pressed.emit()
	panel.dictionary_tab.pressed.emit()
	check(panel.dictionary_box.visible and not panel.words_box.visible and not panel.practice_box.visible, "Dictionary tab opens alone")
	check(panel.dict_list.item_count == play.learner.word_practice.items.size() + 1 and panel.dict_list.get_item_text(0).contains("candil"), "Every word is listed; an unknown conversation word is offered first")
	panel.dict_search.text = "knee"
	panel.dict_search.text_changed.emit("knee")
	check(panel.dict_list.item_count == 1 and panel.dict_list.get_item_text(0) == "la rodilla — knee", "Search works on the English gloss")
	panel.dict_list.select(0)
	panel.dict_list.item_selected.emit(0)
	check(panel.dict_detail.text.contains("EN: knee") and panel.dict_detail.text.contains("Articulación") and panel.dict_remove.disabled, "A built-in word shows gloss and explanation and cannot be removed")
	panel.dict_search.text = ""
	panel.dict_search.text_changed.emit("")
	panel.dict_list.select(0)
	panel.dict_list.item_selected.emit(0)
	check(panel.dict_word.text == "candil", "Choosing a conversation word fills the new-word field")
	panel.dict_add.pressed.emit()
	check(play.learner.word_practice.own.is_empty() and panel.dict_notice.text.contains("inglés") and saves[0] == 0, "Adding without a translation is refused with the reason")
	panel.lookup.model = "deepseek-flash"
	panel.lookup.transport = func(body: String): sent.append(JSON.parse_string(body))
	panel.dict_lookup.pressed.emit()
	check(panel.dict_lookup.disabled and panel.dict_notice.text.contains("Consultando") and sent.back().messages[1].content == "candil", "The button asks DeepSeek for the typed word")
	var proposal := {"word": "el candil", "en": "oil lamp", "clue": "Lámpara pequeña de aceite con una mecha.", "example": "Encendió el candil para leer la carta."}
	panel.lookup.answer(200, reply(proposal))
	check(panel.dict_word.text == "el candil" and panel.dict_en.text == "oil lamp" and panel.dict_clue.text == proposal.clue and play.learner.word_practice.own.is_empty() and not panel.dict_lookup.disabled, "The proposal fills the fields and adds nothing by itself")
	panel.dict_en.text = "oil lamp (old)"
	panel.dict_add.pressed.emit()
	var own: Array = play.learner.word_practice.own
	check(own.size() == 1 and own[0].en == "oil lamp (old)" and saves[0] == 1 and panel.dict_word.text.is_empty() and Save.read_save(map.save_path).state.learner.word_practice.own.size() == 1, "The player's corrected entry is kept and written to the save file")
	var chosen: PackedInt32Array = panel.dict_list.get_selected_items()
	check(chosen.size() == 1 and panel.dict_list.get_item_text(chosen[0]) == "★ el candil — oil lamp (old)" and not panel.dict_remove.disabled and not panel.dict_list.get_item_text(0).contains("conversación"), "The new word is marked, selected and no longer offered")
	panel.words_tab.pressed.emit()
	check(panel.words_theme.item_count == 20, "Vocabulary lists Mis palabras after the place themes")
	panel.words_theme.select(19)
	panel.words_theme.item_selected.emit(19)
	check(panel.word_id == "mia_0001" and panel.words_clue.text.contains("Lámpara pequeña"), "The own word comes up in practice by its explanation")
	panel.words_answer.text = "candil"
	panel.words_check.pressed.emit()
	check(panel.words_feedback.text.begins_with("Correcto") and panel.words_feedback.text.contains("oil lamp"), "It is checked like any word")
	panel.dictionary_tab.pressed.emit()
	if DisplayServer.get_name() != "headless":
		for index in panel.dict_list.item_count:
			if panel.dict_list.get_item_metadata(index) == "mia_0001":
				panel.dict_list.select(index)
				panel.dict_list.item_selected.emit(index)
				panel.dict_list.ensure_current_is_visible()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://dictionary-preview.png")
	for index in panel.dict_list.item_count:
		if panel.dict_list.get_item_metadata(index) == "mia_0001":
			panel.dict_list.select(index)
			panel.dict_list.item_selected.emit(index)
	panel.dict_remove.pressed.emit()
	check(play.learner.word_practice.own.is_empty() and saves[0] == 3 and panel.dict_list.get_item_text(0).contains("candil"), "Removing an own word saves and offers the conversation word again")
	check(Rect2(Vector2.ZERO, root.size).encloses(panel.close_button.get_global_rect()) and Rect2(Vector2.ZERO, root.size).encloses(panel.dict_add.get_global_rect()), "Dictionary controls fit the viewport")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	for file in [path, path + ".bak", path.get_basename() + ".talks.json"]:
		DirAccess.remove_absolute(file)
	print("Dictionary checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
