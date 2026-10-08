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
	# A wider explored area, zoomed out, to see the terrain variants.
	var origin: Vector2i = map.state.hero_cell
	for y in range(origin.y - 30, origin.y + 31):
		for x in range(origin.x - 40, origin.x + 41):
			if map.state.grid.region.has_point(Vector2i(x, y)):
				map.state.fog[Vector2i(x, y)] = 1
	map._refresh()
	var zoom: Vector2 = map.camera.zoom
	map.camera.zoom = Vector2(0.7, 0.7)
	await shot("03b_map_wide")
	map.camera.zoom = zoom
	# Walk six cells down the road and capture the token on its way.
	map.state.hero_cell = origin + Vector2i(0, 6)
	map._refresh()
	await create_timer(0.2).timeout
	await shot("03c_map_walk")
	await create_timer(0.6).timeout
	map.state.hero_cell = origin
	map._refresh()
	await create_timer(0.6).timeout
	var state = map.state
	for location: Dictionary in state.locations:
		if location.id == "LOC01":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map._open_poi(state.hero_cell)
	await shot("04_monastery_dialogue")
	map._close_poi()
	for location: Dictionary in state.locations:
		if location.id == "LOC10":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map._open_poi(state.hero_cell)
	await shot("04b_marsh_dialogue")
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
	for location: Dictionary in state.locations:
		if location.id == "LOC01":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map.strategy_panel.open_site(state)
	await shot("08_town")
	map.strategy_panel.close()
	for location: Dictionary in state.locations:
		if location.id == "LOC11":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	if map.market.open_market(state):
		await shot("09_market")
		map.market.close()
	map.lessons.open_course(state)
	await shot("10_lessons")
	map.lessons.close()
	map.equipment_panel.open_inventory(state)
	await shot("11_equipment")
	map.equipment_panel.close()
	map.side_panel.open_cases(state)
	await shot("12_cases")
	map.side_panel.close()
	map.ghost_panel.open_orders(state)
	await shot("13_ghosts")
	map.ghost_panel.close()
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
	state.party.heroes.inquisitor.army = [{"type": "militia", "count": 24}, {"type": "archers", "count": 14}, {"type": "veteran_guard", "count": 6}, {"type": "relic_sentinel", "count": 2}]
	map._start_battle(raid)
	await shot("07_arena")
	map.arena.attack_button.pressed.emit()
	await create_timer(0.36).timeout
	await shot("07b_arena_strike")
	await create_timer(3.0).timeout
	map.arena.retreat_button.pressed.emit()
	await create_timer(0.5).timeout
	await shot("07c_arena_result")
	quit()
