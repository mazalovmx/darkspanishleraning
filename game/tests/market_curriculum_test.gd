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
func advance_to(state: RefCounted, target: int) -> void:
	var course = state.learner.curriculum
	var limit := 0
	while course.index() < target and limit < 250:
		limit += 1
		var task: Dictionary = course.next_task(state.day)
		if task.stage == "wait":
			state.end_turn()
		elif task.stage == "introduce":
			course.introduce(task.card.id, state.day)
		else:
			var answer: String = task.card.model if task.stage == "guided" else task.card.exercises[["first","second","recall"].find(task.stage)].answers[0]
			course.submit(task.card.id, answer, state.day)
	check(course.index() == target, "Prerequisite course completed to target")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state := World.new()
	state.move_to(Vector2i(6, 11), true)
	var trade = state.trade
	check(trade.tier_for(state) == "basic", "New learner uses present requests")
	check(not trade.submit(state, "bread", 2, "Querría comprar 2 panes.").ok, "Cannot use advanced shortcut before learning")
	for setup in [[0,"basic","Quiero"],[2,"past","Decidí"],[5,"plans","Voy a"],[6,"argument","Querría"]]:
		advance_to(state, setup[0])
		check(trade.tier_for(state) == setup[1], "Tier follows taught grammar")
		var models: Dictionary = trade.current_models(state, "bread", 2)
		check(models.request.begins_with(setup[2]), "Request uses appropriate tense")
		if setup[0] > 0:
			check(not trade.submit(state, "bread", 2, trade.models("bread", 2).request).ok, "Higher lesson requires its learned production")
		for stage in ["request","price","confirm"]:
			check(trade.submit(state, "bread", 2, models[stage]).ok, "Tier stage accepted")
		check(trade.pending.is_empty(), "Completed tier clears quote")
	check(trade.inventory.bread == 8 and state.resources.gold == 284, "All language tiers use same canonical prices")
	var decoded := Save.decode(Save.snapshot(state))
	check(decoded.has("state") and decoded.state.trade.receipts.size() == 4, "Mixed historical language tiers restore")
	var bad := Save.snapshot(state)
	bad.strategy.trade.receipts[3].price = "Son 4 monedas."
	check(not Save.decode(bad).has("state"), "Receipt cannot mix unsupported stages")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state = state
	map.dialogue.world_state = state
	map._open_poi(state.hero_cell)
	map.market_button.pressed.emit()
	check(map.market.prompt.text.contains("Querría"), "Shop scaffold follows advanced curriculum")
	map.market.input.text = trade.current_models(state, "bread", 1).request
	map.market.send_button.pressed.emit()
	check(map.market.prompt.text.contains("Si pido"), "Advanced price comprehension shown")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/market-tiers-preview.png")
	map.queue_free()
	await process_frame
	print("Market curriculum checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
