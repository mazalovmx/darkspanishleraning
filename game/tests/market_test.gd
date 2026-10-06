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
func purchase(state: RefCounted, id: String, quantity: int) -> Dictionary:
	var models: Dictionary = state.trade.models(id, quantity)
	var result: Dictionary = {}
	for stage in ["request", "price", "confirm"]:
		result = state.trade.submit(state, id, quantity, models[stage])
	return result
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state := World.new()
	check(not purchase(state, "bread", 2).ok, "Remote purchase denied")
	state.move_to(Vector2i(6, 11), true)
	var trade = state.trade
	var gold: int = state.resources.gold
	check(not trade.submit(state, "bread", 2, "pan").ok, "Keyword is not a request")
	check(not trade.submit(state, "unknown", 2, "Quiero pan").ok, "Unknown good denied")
	check(not trade.submit(state, "bread", 0, "Quiero pan").ok, "Zero quantity denied")
	var models: Dictionary = trade.models("bread", 2)
	check(trade.submit(state, "bread", 2, models.request).ok, "Spanish request creates quote")
	check(state.resources.gold == gold and trade.inventory.bread == 0, "Quote does not spend or grant")
	check(not trade.submit(state, "bread", 2, models.confirm).ok, "Cannot skip price comprehension")
	check(not trade.submit(state, "bread", 2, "Son 2 monedas.").ok, "Wrong total rejected")
	check(trade.submit(state, "bread", 2, models.price).ok, "Correct total accepted")
	check(not trade.submit(state, "bread", 2, "Sí").ok, "Click-like confirmation insufficient")
	check(trade.submit(state, "bread", 2, models.confirm).get("committed", false), "Complete transaction commits")
	check(state.resources.gold == gold - 4 and trade.inventory.bread == 2 and trade.stock.bread == 28, "Price stock and inventory change together")
	check(not trade.submit(state, "bread", 2, models.confirm).ok, "Repeated confirmation cannot duplicate purchase")
	check(trade.purchase_count == 1, "Receipt count changes once")
	check(trade.models("water", 1).price == "Es 1 moneda.", "Singular money grammar")
	check(purchase(state, "water", 1).get("committed", false), "Second product works")
	var army_before: int = state.army[0].count
	check(purchase(state, "militia", 2).get("committed", false), "Spanish recruitment works")
	check(state.army[0].count == army_before + 2 and state.army.size() == 2, "Recruit merges with existing stack")
	state.army = []
	check(purchase(state, "militia", 1).get("committed", false) and state.army.size() == 1, "Empty defeated army can recruit")
	state.army.clear()
	for i in 7:
		state.army.append({"type":"archers","count":1})
	gold = state.resources.gold
	check(not purchase(state, "militia", 1).ok and state.resources.gold == gold, "Full army rejects recruitment without charge")
	models = trade.models("bread", 2)
	trade.submit(state, "bread", 2, models.request)
	trade.submit(state, "bread", 2, models.price)
	state.resources.gold = 0
	check(not trade.submit(state, "bread", 2, models.confirm).ok, "Insufficient funds rechecked at commit")
	check(trade.inventory.bread == 2 and trade.stock.bread == 28, "Failed transaction leaves goods intact")
	state.resources.gold = gold
	trade.submit(state, "bread", 2, models.request)
	check(not trade.submit(state, "water", 2, models.price).ok and trade.phase == "request", "Changed basket invalidates quote")
	trade.submit(state, "bread", 2, models.request)
	state.end_turn()
	check(not trade.submit(state, "bread", 2, models.price).ok, "Old-day quote invalidated")
	check(not purchase(state, "medicine", 20).ok, "Out-of-stock order rejected")
	var saved := Save.snapshot(state)
	check(Save.decode(saved).has("state"), "Purchases and recruitment save")
	check(Save.decode(saved).state.trade.snapshot() == trade.snapshot(), "Receipt Spanish and stocks persist")
	for field in ["request", "price", "confirm"]:
		var bad := saved.duplicate(true)
		bad.strategy.trade.receipts[0][field] = "sí"
		check(not Save.decode(bad).has("state"), "Unverified receipt language rejected")
	var bad := saved.duplicate(true)
	bad.strategy.trade.receipts[0].total = 1
	check(not Save.decode(bad).has("state"), "Receipt price forged in save rejected")
	bad = saved.duplicate(true)
	bad.strategy.trade.stock.bread = -1
	check(not Save.decode(bad).has("state"), "Negative stock rejected")
	var old := saved.duplicate(true)
	old.version = 3
	old.erase("party")
	old.learner.erase("curriculum")
	old.learner.grammar.erase("future_simple")
	old.strategy.erase("trade")
	check(Save.decode(old).has("state") and Save.decode(old).state.trade.purchase_count == 0, "V3 adds empty trade without fabricated purchases")
	var path := "user://market_test_%d.json" % OS.get_process_id()
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(map.state.hero_cell)
	check(map.market_button.visible, "Inn offers market")
	map.market_button.pressed.emit()
	var panel = map.market
	check(panel.visible and panel.products.item_count == 6, "Shop displays all supplies and recruits")
	panel.quantity.value = 2
	models = map.state.trade.models("bread", 2)
	for stage in ["request", "price"]:
		panel.input.text = models[stage]
		panel.send_button.pressed.emit()
	check(panel.products.disabled and not panel.quantity.editable, "Quoted basket locked during practice")
	check(map.state.resources.gold == 300, "UI has not charged before confirmation")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/market-preview.png")
	panel.input.text = models.confirm
	panel.send_button.pressed.emit()
	check(map.state.trade.inventory.bread == 2 and map.state.resources.gold == 296, "UI transaction commits")
	check(Save.read_save(path).state.trade.inventory.bread == 2, "Purchase autosaves")
	check(map.state.learner.grammar.present == 0, "Guided purchase does not fake mastery")
	panel.input.text = models.request
	panel.send_button.pressed.emit()
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day, "Language retries do not advance day")
	panel.close_button.pressed.emit()
	check(not panel.visible and map.state.trade.pending.is_empty(), "Closing cancels incomplete basket")
	check(map.state.resources.gold == 296, "Cancel never charges")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Market checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
