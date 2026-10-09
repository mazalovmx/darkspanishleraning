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
func select_offer(kind: String,id: String) -> void:
	var panel = map.strategy_panel
	for index in panel.category.item_count:
		if panel.category.get_item_metadata(index) == kind:
			panel.category.select(index)
			panel.category.item_selected.emit(index)
			break
	for index in panel.entries.item_count:
		var entry: Dictionary = panel.entries.get_item_metadata(index)
		if entry.kind == kind and entry.id == id:
			panel.entries.select(index)
			panel.entries.item_selected.emit(index)
			return
	check(false,"Missing offer: " + id)
func buy(kind: String,id: String,quantity: int) -> void:
	var panel = map.strategy_panel
	select_offer(kind,id)
	panel.quantity.value = quantity
	var models: Dictionary = map.state.economy.current_models(map.state,kind,id,quantity)
	for stage in ["request","price","confirm"]:
		panel.input.text = models[stage]
		panel.send_button.pressed.emit()
func run() -> void:
	root.size = Vector2i(1280,720)
	map = load("res://src/world/province_map.tscn").instantiate()
	map.save_path = "user://economy_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	for resource in map.state.resources:
		map.state.resources[resource] = 10000
	map._open_poi(map.state.hero_cell)
	check(map.strategy_button.visible,"Settlement action at monastery")
	map.strategy_button.pressed.emit()
	var panel = map.strategy_panel
	check(panel.visible and panel.resources.text.contains("mercurio"),"Complete strategic wallet visible")
	check(not panel.quantity.visible, "Buildings do not ask for a quantity")
	for index in panel.entries.item_count:
		check(panel.entries.get_item_metadata(index).kind == "build", "Building category hides other purchases")
	panel.input.text = "Sí"
	panel.send_button.pressed.emit()
	check(map.state.economy.buildings.is_empty(),"Click-like text cannot build")
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day,"Language panel blocks world day")
	buy("build","council_hall",1)
	check(map.state.economy.buildings.LOC01.has("council_hall"),"Construction through three Spanish UI stages")
	check(Save.read_save(map.save_path).state.economy.buildings.LOC01.has("council_hall"),"Building autosaves")
	select_offer("build","barracks")
	check(panel.send_button.disabled,"Daily construction limit explained in UI")
	panel.close_button.pressed.emit()
	map._close_poi()
	var gold: int = map.state.resources.gold
	map._end_turn()
	check(map.state.resources.gold == gold + 40,"End-turn button pays building income")
	map._open_poi(map.state.hero_cell)
	map.strategy_button.pressed.emit()
	buy("build","barracks",1)
	buy("recruit","militia",4)
	check(map.state.army[0].count == 12,"Recruits reach active army")
	check(panel.description.text.contains("8"),"Remaining weekly stock displayed")
	select_offer("recruit","militia")
	panel.quantity.value = 1
	var models: Dictionary = map.state.economy.current_models(map.state,"recruit","militia",1)
	panel.input.text = models.request
	panel.send_button.pressed.emit()
	check(panel.entries.disabled and not panel.quantity.editable,"Quoted product and amount locked")
	var before_cancel: Dictionary = map.state.resources.duplicate()
	panel.cancel_button.pressed.emit()
	check(map.state.economy.pending.is_empty() and map.state.resources == before_cancel and not panel.category.disabled, "Change order cancels and unlocks categories without spending")
	panel.input.text = models.request
	panel.send_button.pressed.emit()
	gold = map.state.resources.gold
	panel.close_button.pressed.emit()
	check(map.state.economy.pending.is_empty() and map.state.resources.gold == gold,"Closing cancels without charge")
	map._close_poi()
	var site: Dictionary = map.state.economy.site(map.state,"mine_gold")
	# The gold mine's guard needs more than the starting army (balance pass, BALANCE.md).
	map.state.army = [{"type":"veteran_guard","count":20},{"type":"archers","count":30},{"type":"militia","count":24}]
	map.state.hero_cell = Vector2i(site.position[0],site.position[1])
	map.state._reveal_from(map.state.hero_cell)
	map._refresh()
	map._open_poi(map.state.hero_cell)
	check(panel.visible and panel.battle_button.visible and not panel.input.visible,"Guarded mine offers combat before claim")
	panel.battle_button.pressed.emit()
	check(map.arena.visible and not panel.visible,"Mine battle replaces economy panel")
	var steps := 0
	while map.state.active_battle.outcome.is_empty() and steps < 200:
		var target := -1
		for i in map.state.active_battle.stacks.size():
			if map.state.active_battle.stacks[i].side == 1 and map.state.active_battle.count_at(i) > 0:
				target = i
				break
		map.state.active_battle.act("attack",target)
		steps += 1
	check(map.state.active_battle.outcome == "victory","Actual mine battle won")
	map.arena.refresh()
	map.arena.finish_button.pressed.emit()
	check(panel.visible and not panel.battle_button.visible and panel.input.visible,"Victory returns to Spanish ownership order")
	panel.input.text = map.state.economy.claim_model(map.state,"mine_gold")
	panel.send_button.pressed.emit()
	check(map.state.economy.mines.has("mine_gold") and not panel.input.visible,"Mine ownership shown")
	check(Save.read_save(map.save_path).state.economy.mines.has("mine_gold"),"Ownership autosaves")
	panel.close_button.pressed.emit()
	gold = map.state.resources.gold
	map._end_turn()
	check(map.state.resources.gold == gold + 140,"Owned mine and building pay on actual map turn")
	map._load_game()
	check(map.state.economy.mines.has("mine_gold") and not panel.visible,"Load restores economy and closes stale panel")
	# Final settlement preview.
	for location: Dictionary in map.state.locations:
		if location.id == "LOC01":
			map.state.hero_cell = Vector2i(location.position[0],location.position[1])
	map.state._reveal_from(map.state.hero_cell)
	map._refresh()
	map._open_poi(map.state.hero_cell)
	map.strategy_button.pressed.emit()
	select_offer("build","forge")
	var original_prompt: String = panel.prompt.text
	panel.prompt.text = "Una explicación extensa. ".repeat(200)
	panel.feedback.text = "Corrige la frase y vuelve a intentarlo. ".repeat(200)
	for frame in 8:
		await process_frame
	for control: Control in [panel.input, panel.send_button, panel.close_button]:
		check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "Long construction text keeps actions on screen")
	panel.prompt.text = original_prompt
	panel.feedback.text = "Solo se paga al confirmar el último paso."
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://economy-preview.png")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Economy scene checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)