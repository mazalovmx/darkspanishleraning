extends SceneTree
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func purchase(state: RefCounted, id: String, quantity: int) -> bool:
	var models: Dictionary = state.trade.current_models(state, id, quantity)
	var result := {}
	for stage in ["request", "price", "confirm"]:
		result = state.trade.submit(state, id, quantity, models[stage])
	return result.get("committed", false)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state := World.new()
	check(state.move_to(Vector2i(7, 10), true), "Mateo moves")
	check(state.fog_at(Vector2i(2, 5)) == World.Fog.VISIBLE, "Other heroes retain shared vision")
	check(state.select_hero("smuggler"), "Select Ines")
	check(state.hero_cell == Vector2i(2, 10) and state.movement_remaining == 18, "Independent position and movement")
	check(state.move_to(Vector2i(6, 11), true), "Ines travels to shop")
	check(purchase(state, "bread", 2), "Ines buys using three Spanish stages")
	check(purchase(state, "militia", 1), "Ines recruits")
	check(state.party.heroes.smuggler.inventory.bread == 2 and state.party.heroes.inquisitor.inventory.bread == 0, "Supplies belong to purchaser")
	check(state.party.heroes.smuggler.army.size() == 2 and state.party.heroes.inquisitor.army[0].count == 8, "Recruit joins purchaser")
	var models: Dictionary = state.trade.current_models(state, "water", 1)
	state.trade.submit(state, "water", 1, models.request)
	check(not state.select_hero("survivor"), "Pending purchase locks hero")
	state.trade.cancel()
	check(state.select_hero("inquisitor") and state.movement_remaining == 13, "Switching never refunds movement")
	check(state.trade.inventory.bread == 0 and state.resources.gold == 281, "Personal inventory and shared gold")
	check(state.trade.stock.bread == 28 and state.trade.purchase_count == 2, "Shared finite shop and receipts")
	check(state.evidence.record("travel_food", "LOC01", "Hay comida.", "observation", 1), "Shared evidence recorded")
	state.select_hero("smuggler")
	var other_army: Array = state.party.heroes.inquisitor.army.duplicate(true)
	check(state.evidence.has_evidence("travel_food"), "Evidence available to another hero")
	check(state.begin_encounter("opening_road"), "Ines starts encounter with her army")
	check(not state.select_hero("survivor"), "Battle locks active hero")
	state.active_battle.act("retreat")
	check(state.settle_encounter() and state.movement_remaining == 0, "Retreat settles on Ines")
	check(state.party.heroes.inquisitor.army == other_army and state.party.heroes.inquisitor.movement_remaining == 13, "Battle leaves other hero army and movement intact")
	state.select_hero("survivor")
	check(state.army[0].type == "relic_sentinel" and state.army[0].count == 2, "Elias keeps rare escort")
	check(state.learner.current_block == "present_and_basic_requests", "Hero register cannot skip curriculum")
	state.move_to(Vector2i(3, 10), true)
	var snapshot := Save.snapshot(state)
	var restored := Save.decode(snapshot)
	check(restored.has("state"), "V6 with three moved heroes restores")
	if restored.has("state"):
		check(restored.state.party.snapshot() == state.party.snapshot(), "All three inventories armies positions and movement persist")
		check(restored.state.party.active_id == "survivor", "Active hero persists")
		restored.state.select_hero("smuggler")
		check(restored.state.trade.inventory.bread == 2, "Loaded shop inventory follows active hero")
	for field in ["movement", "army", "inventory"]:
		var bad := snapshot.duplicate(true)
		match field:
			"movement": bad.party.heroes.survivor.movement = 0
			"army": bad.party.heroes.survivor.army = []
			"inventory": bad.party.heroes.survivor.inventory.bread = 9
		check(not Save.decode(bad).has("state"), "Mismatched active aliases rejected: " + field)
	var bad := snapshot.duplicate(true)
	bad.party.heroes.smuggler.position = [19, 19]
	check(not Save.decode(bad).has("state"), "Unexplored inactive hero rejected")
	state.select_hero("inquisitor")
	var legacy := Save.snapshot(state)
	legacy.version = 5
	legacy.erase("party")
	legacy.erase("campaign")
	var migrated := Save.decode(legacy)
	check(migrated.has("state"), "V5 migration accepted")
	if migrated.has("state"):
		check(migrated.state.hero_cell == state.hero_cell and migrated.state.army == state.army, "V5 Mateo position and army retained")
		check(migrated.state.party.active_id == "inquisitor", "Legacy state belongs to Mateo")
	state.end_turn()
	for member in state.party.heroes.values():
		check(member.movement_remaining == 18, "One world day refreshes every hero")
	check(state.day == 2, "Day advances once for whole party")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	await process_frame
	check(map.hero_buttons.size() == 3, "Three portrait controls")
	key(KEY_F2)
	check(map.state.party.active_id == "smuggler" and map.selected, "F2 selects Ines")
	key(KEY_F3)
	check(map.state.party.active_id == "survivor", "F3 selects Elias")
	map.hero_buttons.inquisitor.pressed.emit()
	check(map.state.party.active_id == "inquisitor", "Portrait selects Mateo")
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(map.state.hero_cell)
	key(KEY_F2)
	check(map.state.party.active_id == "inquisitor", "POI modal blocks shortcut")
	map.hero_buttons.smuggler.pressed.emit()
	check(map.state.party.active_id == "inquisitor" and map.hero_buttons.inquisitor.button_pressed, "Portrait cannot bypass modal")
	map._close_poi()
	map.lessons.open_course(map.state)
	key(KEY_F3)
	check(map.state.party.active_id == "inquisitor", "Course modal blocks shortcut")
	map.lessons.close()
	key(KEY_F2)
	check(map.state.party.active_id == "smuggler" and map.state.hero_cell == Vector2i(2, 10), "Independent map position after modal")
	check(map.hero.position == map.tiles.map_to_local(map.state.hero_cell) and map.status.text.contains("Inés"), "Token and HUD reflect active hero")
	var path := "user://party_integration_%d.json" % OS.get_process_id()
	map.persistence_enabled = true
	map.save_path = path
	map._save_game()
	map._switch_hero("survivor")
	map.state.select_hero("inquisitor")
	map._load_game()
	check(map.state.party.active_id == "survivor" and map.hero_buttons.survivor.button_pressed, "Map load restores saved active portrait")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/party-preview.png")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Party integration checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)