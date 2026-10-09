extends SceneTree
const Save = preload("res://src/save/save_game.gd")
var checks := 0
var failures := 0
var map: Node
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func select_id(selector: OptionButton, id: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == id:
			selector.select(index)
			selector.item_selected.emit(index)
			return
	check(false, "Missing UI entry: " + id)
func inspect(id: String) -> void:
	map.inspect_button.pressed.emit()
	select_id(map.notebook.entries, id)
	var clue: Dictionary = map.state.evidence.node(id)
	map.notebook.note.text = clue.language.sample
	map.notebook.category.select(4 if clue.source_type == "document" else 1)
	map.notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence(id), "Inspected via UI: " + id)
	map.notebook.close_button.pressed.emit()
func ask(speaker: String, question: String) -> void:
	select_id(map.dialogue.speaker, speaker)
	map.dialogue.input.text = question
	map.dialogue.send_button.pressed.emit()
func compare(id: String, wrong := false) -> void:
	map.notebook_button.pressed.emit()
	map.notebook.compare_button.pressed.emit()
	select_id(map.notebook.entries, id)
	var clue: Dictionary = map.state.evidence.node(id)
	for selector_index in 2:
		var selector: OptionButton = map.notebook.support_a if selector_index == 0 else map.notebook.support_b
		select_id(selector, clue.assessment.supports[selector_index])
	map.notebook.note.text = clue.language.sample
	if wrong:
		select_id(map.notebook.category, "suicide")
		map.notebook.record_button.pressed.emit()
		check(not map.state.evidence.has_evidence(id), "Player can misinterpret without corrupting evidence")
	select_id(map.notebook.category, clue.assessment.answer)
	map.notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence(id), "Comparison solved: " + id)
	map.notebook.close_button.pressed.emit()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var path := "user://vertical_slice_%d.json" % OS.get_process_id()
	map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.dialogue.client.config.dev_flags.offline_mode = true
	check(map.state.move_to(Vector2i(6, 11), true), "Travel to inn")
	map._open_poi(map.state.hero_cell)
	ask("LOC11", "Hola")
	check(map.dialogue.histories.LOC11.size() == 1, "Innkeeper conversation")
	map.market_button.pressed.emit()
	map.market.quantity.value = 2
	var gold_now: int = map.state.resources.gold
	var bread_price: int = map.state.trade.goods.bread.price
	check(map.market.description.text.contains("Cuesta: %d · Te quedará: %d de oro" % [bread_price * 2, gold_now - bread_price * 2]), "The market shows what the order costs and leaves before buying")
	map.state.resources.gold = bread_price
	map.market._refresh()
	check(map.market.description.text.contains("✗ Falta: %d de oro" % bread_price), "An order beyond the purse names the missing gold")
	map.state.resources.gold = gold_now
	map.market._refresh()
	var phrases: Dictionary = map.state.trade.models("bread", 2)
	for stage in ["request", "price", "confirm"]:
		map.market.input.text = phrases[stage]
		map.market.send_button.pressed.emit()
	check(map.state.trade.inventory.bread == 2 and map.state.resources.gold == 296, "Purchase supplies through Spanish UI")
	map.market.close_button.pressed.emit()
	map.poi_close.pressed.emit()
	map._end_turn()
	check(map.state.move_to(Vector2i(7, 10), true), "Discover monastery road")
	check(map.state.move_to(Vector2i(12, 10), true), "Reach monastery")
	map._open_poi(map.state.hero_cell)
	inspect("travel_food")
	ask("LOC01", "¿Qué dice la comunidad?")
	check(map.state.evidence.has_evidence("monastery_claim"), "Abbot's institutional account")
	compare("food_hypothesis", true)
	for id in ["brass_tube", "tower_blood", "scraped_boot", "missing_notebook", "preservation_order"]:
		inspect(id)
	ask("LOC01_GABRIEL", "¿Qué oye por la noche?")
	check(map.state.evidence.has_evidence("gabriel_denial"), "Deliberate lie encountered")
	ask("LOC01_GABRIEL", "¿Oye un caballo?")
	check(map.state.evidence.has_evidence("horse_sound"), "Misleading honest testimony encountered")
	ask("LOC01_GABRIEL", "¿Por qué cambia su relato?")
	check(map.state.evidence.has_evidence("wine_secret"), "Irrelevant secret discovered")
	ask("LOC01_LEONOR", "¿Qué indica la herida?")
	check(map.state.evidence.has_evidence("medical_report"), "Fourth NPC provides examination")
	map._save_game()
	map._load_game()
	check(map.state.evidence.has_evidence("medical_report") and map.state.trade.inventory.bread == 2, "Mid-case save/load preserves purchases and testimony")
	compare("horse_hypothesis")
	compare("opening_conclusion")
	check(map.state.evidence.has_evidence("opening_conclusion"), "Investigative conclusion reached")
	map._end_turn()
	check(map.state.move_to(Vector2i(6, 11), true), "Return to inn")
	map._open_poi(map.state.hero_cell)
	map.battle_button.pressed.emit()
	check(map.arena.visible, "Enter actual map encounter")
	var turns := 0
	while map.arena.battle.outcome.is_empty() and turns < 50:
		map.arena.attack_button.pressed.emit()
		turns += 1
	check(map.arena.battle.outcome == "victory", "Win required battle")
	map.arena.finish_button.pressed.emit()
	check(map.state.resources.gold == 356, "Supply cost and battle reward compose correctly")
	map._save_game()
	map._load_game()
	check(map.state.encounters.opening_road.outcome == "victory", "Battle outcome restored")
	check(map.state.evidence.has_evidence("opening_conclusion"), "Conclusion restored")
	check(map.state.trade.purchase_count == 1, "Purchase not duplicated on load")
	check(map.state.learner.current_block == "present_and_basic_requests", "No premature language block advancement")
	check(map.state.army.size() > 0 and map.state.army.size() <= 7, "Surviving army retained")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Vertical slice Gate F/G checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
