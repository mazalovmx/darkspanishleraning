extends SceneTree
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
func run() -> void:
	root.size = Vector2i(1280,720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	check(map.save_path != Save.PATH, "Province preserves original prototype save")
	map.save_path = "user://province_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	await process_frame
	check(map.state.grid.region.size == Vector2i(160,120), "Launch scene loads province")
	check(map.hero.position == map.tiles.map_to_local(Vector2i(52,39)), "Hero starts at canonical monastery")
	var screen: Vector2 = map.get_canvas_transform() * map.hero.position
	check(Rect2(0,0,950,720).has_point(screen), "Camera shows hero beside sidebar")
	check(map.hero_buttons.smuggler.disabled and map.hero_buttons.survivor.disabled, "Story heroes visibly locked")
	check(map.tiles.get_used_cells().size() == map.state.fog.size(), "Only discovered terrain instantiated")
	check(map.tiles.get_used_cells().size() < 100, "No hidden province tiles rendered")
	map._open_poi(map.state.hero_cell)
	check(map.poi_modal.visible and map.dialogue.visible and map.inspect_button.visible, "Opening investigation works on full map")
	map.inspect_button.pressed.emit()
	map.notebook.note.text = "Hay comida."
	map.notebook.category.select(1)
	map.notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence("travel_food"), "First physical clue recorded through Spanish UI")
	map.notebook.close()
	map.dialogue.client.config.dev_flags.offline_mode = true
	map.dialogue.submit("¿Qué dice la comunidad?")
	check(map.state.evidence.has_evidence("monastery_claim"), "Opening witness available")
	map.inspect_button.pressed.emit()
	check(map.notebook.visible, "Physical clue inspection opens")
	map.notebook.close()
	map._close_poi()
	map.camera.position = Vector2(4800,3300)
	map._clamp_camera()
	check(map.camera.position.x > 640 and map.camera.position.y > 640, "Camera pans beyond prototype boundary")
	map.camera.position = Vector2(9000,9000)
	map._clamp_camera()
	check(map.camera.position == Vector2(5120,3840), "Camera constrained to actual world size")
	map._switch_hero("inquisitor")
	check(map.camera.position == map.hero.position, "Portrait recenters on hero")
	map._save_game()
	check(Save.read_save(map.save_path).state.map_id == "province_160x120_v1", "Province autosave map identity")
	map.state.move_to(Vector2i(53,39),true)
	map._load_game()
	check(map.state.hero_cell == Vector2i(52,39) and map.state.evidence.has_evidence("monastery_claim"), "Province load retains investigation")
	check(map.tiles.get_used_cells().size() == map.state.fog.size(), "Reload rebuilds discovered tiles")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/province-preview.png")
	var kinds := {}
	for location: Dictionary in map.state.locations:
		kinds[location.kind] = true
	for kind: String in kinds:
		check(map.location_textures.has(kind), "Every location kind has a sprite: " + kind)
	for site: Dictionary in map.state.map_data.resource_sites:
		check(map.site_textures.has(site.resource), "Every resource site has a sprite: " + str(site.resource))
	for id: String in map.state.party.heroes:
		check(map.hero_textures.has(id), "Every hero has a sprite: " + id)
	check(map.hero.texture == map.hero_textures[map.state.party.active_id] and map.knight_texture != null, "Active hero and knights use sprites")
	var atlas: Image = map.tiles.tile_set.get_source(0).texture.get_image()
	var cell_colours := {}
	for index in map.COLORS.size():
		cell_colours[atlas.get_pixel(index * map.CELL_SIZE + 16, 16).to_html()] = true
	check(cell_colours.size() >= 7, "Terrain cells are baked from distinct art")
	check(map.music_track == "minstrel_dance.mp3" and map.music.stream != null, "Travel music is selected on the map")
	map._open_poi(map.state.hero_cell)
	check(map.music_track == "kings_feast.mp3", "Entering a location changes the track")
	map._play_sfx("no_such_event")
	map._close_poi()
	check(map.music_track == "minstrel_dance.mp3" and map.sfx.stream != null, "Leaving restores travel music and plays a sound")
	check(map.vignette.get_parent() == null, "Full-screen shader stays off by default")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Province scene checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)