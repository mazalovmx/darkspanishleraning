extends SceneTree
## Visual review helper, not a test: renders key screens to PNG files.
## Run under a display: godot --path game --script res://tests/screenshots.gd -- <out_dir>
const World = preload("res://src/world/world_state.gd")
var out := ""
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots"
	root.size = Vector2i(1280, 720)
	var menu = load("res://src/ui/title_menu.tscn").instantiate()
	menu.save_path = "user://none.json"
	root.add_child(menu)
	await shot("01_title")
	menu.settings_button.pressed.emit()
	await shot("02_title_settings")
	menu.queue_free()
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	await shot("03_map")
	var state = map.state
	for location: Dictionary in state.locations:
		if location.id == "LOC01":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map._open_poi(state.hero_cell)
	await shot("04_monastery_dialogue")
	map._close_poi()
	map.campaign_journal.open_journal(state)
	await shot("05_journal")
	map.campaign_journal.close()
	var cache: Dictionary = state.economy.treasures.TR07
	state.hero_cell = Vector2i(cache.position[0], cache.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map.strategy_panel.open_site(state, "TR07")
	await shot("06_treasure")
	map.strategy_panel.close()
	state.encounters.erase("opening_road")
	if state.begin_encounter("TR01") or true:
		pass
	var raid := "raid_mine_wood"
	state.economy.mines["mine_wood"] = {"day": 1, "hero": "inquisitor", "message": "x", "tier": "basic"}
	var site: Dictionary = state.economy.site(state, "mine_wood")
	state.hero_cell = Vector2i(site.position[0], site.position[1])
	state._reveal_from(state.hero_cell)
	state.day = 9
	map._refresh()
	map._start_battle(raid)
	await shot("07_arena")
	quit()
