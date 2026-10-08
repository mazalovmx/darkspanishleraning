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
func ready_world() -> RefCounted:
	var state := World.new()
	state.move_to(Vector2i(6, 11), true)
	state.evidence.record("travel_food", "LOC01", "Hay comida.", "observation", 1)
	return state
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state := World.new()
	check(not state.begin_encounter("opening_road"), "Remote encounter rejected")
	state.move_to(Vector2i(6, 11), true)
	check(not state.begin_encounter("opening_road"), "Encounter has story prerequisite")
	state = ready_world()
	check(not state.begin_encounter("invented"), "Unknown encounter rejected")
	var movement: int = state.movement_remaining
	check(state.begin_encounter("opening_road"), "Reached encounter starts")
	check(state.movement_remaining == movement - 2, "Encounter spends movement once")
	check(not state.begin_encounter("opening_road"), "Cannot start parallel combat")
	var day: int = state.day
	state.end_turn()
	check(state.day == day, "Active combat blocks world day")
	check(not state.move_to(Vector2i(7, 10), true), "Active combat blocks travel")
	check(Save.write_save(state, "user://battle_not_written.json") == "battle_active", "Cannot serialize half-resolved combat")
	check(not state.settle_encounter(), "Cannot settle unfinished fight")
	state.active_battle.act("retreat")
	check(state.settle_encounter(), "Retreat settles")
	check(state.resources.gold == 300 and state.movement_remaining == 0, "Retreat has no reward and ends movement")
	check(state.encounters.opening_road.outcome == "retreated", "Retreat recorded")
	check(Save.decode(Save.snapshot(state)).has("state"), "Retreat state saves")
	check(not state.settle_encounter(), "Result cannot settle twice")
	state.end_turn()
	check(state.begin_encounter("opening_road"), "Retry allowed after retreat")
	var steps := 0
	while state.active_battle.outcome.is_empty() and steps < 100:
		state.active_battle.act("attack", 2)
		steps += 1
	check(state.active_battle.outcome == "victory", "Actual encounter can be won")
	check(state.settle_encounter(), "Victory settles")
	check(state.resources.gold == 360, "Canonical reward granted once")
	check(not state.begin_encounter("opening_road"), "Won encounter cannot be farmed")
	check(not state.settle_encounter() and state.resources.gold == 360, "Duplicate settlement cannot grant gold")
	var saved := Save.snapshot(state)
	check(Save.decode(saved).state.army == state.army, "Army losses persist")
	check(Save.decode(saved).state.encounters == state.encounters, "Outcome persists")
	for resource in state.resources:
		for invalid in [-1, true, 1.5, "5"]:
			var bad := saved.duplicate(true)
			bad.strategy.resources[resource] = invalid
			check(not Save.decode(bad).has("state"), "Invalid resource rejected")
	for invalid in [[{"type":"unknown","count":2}], [{"type":"militia","count":0}], true]:
		var bad := saved.duplicate(true)
		bad.strategy.army = invalid
		check(not Save.decode(bad).has("state"), "Invalid army rejected")
	var old := saved.duplicate(true)
	old.version = 2
	old.erase("npc_memory")
	old.erase("party")
	old.erase("campaign")
	old.learner.erase("curriculum")
	old.learner.grammar.erase("future_simple")
	old.erase("strategy")
	check(Save.decode(old).has("state"), "V2 migrates")
	check(Save.decode(old).state.resources.gold == 300 and Save.decode(old).state.encounters.is_empty(), "Migration adds defaults without fabricated victories")
	var path := "user://battle_map_%d.json" % OS.get_process_id()
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.state = ready_world()
	map.dialogue.world_state = map.state
	map._open_poi(map.state.hero_cell)
	check(map.battle_button.visible, "Encounter action appears at inn")
	map.battle_button.pressed.emit()
	check(map.arena.visible and not map.poi_modal.visible, "Arena replaces location modal")
	check(map.save_button.disabled and map.load_button.disabled and map.notebook_button.disabled, "World controls disabled in combat")
	map._end_turn()
	check(map.state.day == 1, "End-turn handler cannot bypass battle")
	map._save_game()
	check(not FileAccess.file_exists(path), "Save handler cannot bypass battle")
	map.arena.retreat_button.pressed.emit()
	map.arena.finish_button.pressed.emit()
	check(not map.arena.visible and not map.save_button.disabled, "Returning restores world controls")
	check(Save.read_save(path).state.encounters.opening_road.outcome == "retreated", "Settlement autosaves")
	check(map.resource_labels.gold.text == "300", "Resource HUD refreshes")
	map.state.end_turn()
	map._open_poi(map.state.hero_cell)
	map.battle_button.pressed.emit()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://map-battle-preview.png")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Battle integration checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
