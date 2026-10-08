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
func services() -> void:
	# Innkeeper (Epic 13, spec 30 "Inn"): a room booked with the player's own words.
	var state := World.new("province_160x120_v1")
	var trade = state.trade
	for location: Dictionary in state.locations:
		if location.id == "LOC11":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state.party.active().cell = state.hero_cell
	state._reveal_from(state.hero_cell)
	check(trade.offers_at("LOC11").has("room") and not trade.offers_at("LOC11").has("treatment"), "The inn rents rooms, the healer is elsewhere")
	check(trade.models("room", 2).request == "Quiero reservar una habitación para 2 noches.", "Room request model")
	check(trade.reminder("room", "request", "basic").contains("(reservar)") and not trade.reminder("room", "request", "basic").contains("comprar"), "The reminder names the service's verb")
	check(not trade.submit(state, "treatment", 1, "Necesito una cura.").ok, "No healer at the inn")
	var gold: int = state.resources.gold
	check(trade.submit(state, "room", 2, "Necesito una habitación para dos noches.").ok, "Own wording books the room")
	check(trade.submit(state, "room", 2, "Son diez monedas.").ok, "Price of two nights")
	check(trade.submit(state, "room", 2, "Confirmo la reserva de dos noches por diez monedas.").get("committed", false), "Booking confirmed")
	check(state.resources.gold == gold - 10 and state.party.active().inventory.room == 2, "Room paid and booked")
	state.party.active().health = 50
	state.end_turn()
	check(state.party.active().health == 80 and state.party.active().inventory.room == 1 and state.turn_notice.contains("habitación"), "A night in the room heals 30")
	# Healer at the Hospital de Miralba (LOC15).
	for location: Dictionary in state.locations:
		if location.id == "LOC15":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state.party.active().cell = state.hero_cell
	state._reveal_from(state.hero_cell)
	check(trade.offers_at("LOC15") == ["medicine", "treatment"], "The hospital sells bandages and cures")
	state.party.active().health = 40
	gold = state.resources.gold
	check(trade.submit(state, "treatment", 1, "Quiero pagar una cura.").ok and trade.submit(state, "treatment", 1, "Cuesta doce monedas.").ok, "Cure requested and priced")
	check(trade.submit(state, "treatment", 1, "Confirmo el pago de una cura por doce monedas.").get("committed", false), "Cure confirmed")
	check(state.party.active().health == 80 and state.resources.gold == gold - 12, "The healer treats at once")
	check(not trade.submit(state, "room", 1, "Quiero una habitación para una noche.").ok, "No rooms at the hospital")
	# Stable master and food sellers (Epic 13).
	check(trade.offers_at("LOC12") == ["horse_feed"], "The farm's stable sells horse feed")
	check(trade.offers_at("LOC07") == ["bread", "water"] and trade.offers_at("LOC02") == ["bread", "water"], "Food sellers in San Vélaro and Valdora")
	check(trade.offers_at("LOC03").is_empty(), "Places without a counter sell nothing")
	# Toll collector at Puente Seco: the pass removes the wait at bridges.
	var bridge := Vector2i(97, 44)
	check(state.bridges.has(bridge) and state.bridges.size() >= 4, "Bridges found where roads cross the river")
	var plain: int = state.terrain_cost(bridge)
	check(state.step_cost(bridge) == plain + state.TOLL_WAIT, "Without the pass a bridge costs the wait")
	check(state.step_cost(bridge, "NK01") == plain and state.step_cost(Vector2i(63, 60)) == state.terrain_cost(Vector2i(63, 60)), "Knights and ordinary cells pay terrain only")
	for location: Dictionary in state.locations:
		if location.id == "LOC06":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state.party.active().cell = state.hero_cell
	state._reveal_from(state.hero_cell)
	check(trade.offers_at("LOC06") == ["salvoconducto"], "The bridge post sells the pass")
	check(trade.submit(state, "salvoconducto", 1, "Quiero comprar un salvoconducto.").ok and trade.submit(state, "salvoconducto", 1, "Son quince monedas.").ok, "Pass requested and priced")
	check(trade.submit(state, "salvoconducto", 1, "Confirmo la compra de un salvoconducto por quince monedas.").get("committed", false), "Pass bought")
	check(state.step_cost(bridge) == plain, "With the pass the bridge costs terrain only")
	# Smuggler at Marjal Negro: rare resources for gold.
	for location: Dictionary in state.locations:
		if location.id == "LOC10":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state.party.active().cell = state.hero_cell
	state._reveal_from(state.hero_cell)
	check(trade.offers_at("LOC10") == ["smuggled_mercury", "smuggled_sulfur", "smuggled_crystal", "smuggled_gems"], "The smuggler sells rare resources")
	state.resources.gold = 500
	var crystal: int = state.resources.crystal
	check(trade.submit(state, "smuggled_crystal", 2, "Necesito dos cristales.").ok, "Two crystals requested")
	check(trade.submit(state, "smuggled_crystal", 2, "Son 120 monedas.").ok, "Two crystals priced")
	check(trade.submit(state, "smuggled_crystal", 2, "Confirmo la compra de dos cristales por 120 monedas.").get("committed", false), "Crystals bought")
	check(state.resources.crystal == crystal + 2 and state.resources.gold == 380, "Crystals go to the treasury")
	check(trade.submit(state, "smuggled_gems", 1, "Quiero una gema.").ok, "Gems: feminine quantity")
	trade.cancel()
	# A save written before the services existed still loads, with them empty.
	var snapshot: Dictionary = Save.snapshot(state).duplicate(true)
	for table in [snapshot.strategy.trade.stock, snapshot.strategy.trade.inventory]:
		table.erase("room")
		table.erase("treatment")
	for entry in snapshot.party.heroes.values():
		entry.inventory.erase("room")
		entry.inventory.erase("treatment")
	var older: Dictionary = Save.decode(snapshot)
	check(older.has("state") and older.state.party.active().inventory.room == 0, "An older save without services loads")

func run() -> void:
	root.size = Vector2i(1280, 720)
	services()
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
	# Own wording is accepted on content; rejections name the gap, never the sentence.
	var rejected: Dictionary = trade.submit(state, "bread", 3, "Quiero comprar pan.")
	check(not rejected.ok and rejected.message.contains("la cantidad con el producto"), "Rejection names the missing element")
	check(not rejected.message.contains(trade.models("bread", 3).request), "Rejection does not print the model sentence")
	check(trade.submit(state, "bread", 3, "Buenas tardes, necesito tres panes para el camino.").ok, "Own request with a number word accepted")
	rejected = trade.submit(state, "bread", 3, "Cuestan 3 monedas.")
	check(not rejected.ok and rejected.message.contains("el total en monedas") and not rejected.message.contains("6"), "Wrong total named without revealing it")
	check(trade.submit(state, "bread", 3, "Entonces cuestan seis monedas en total.").ok, "Own price sentence accepted")
	rejected = trade.submit(state, "bread", 3, "Confirmo la compra.")
	check(not rejected.ok and rejected.message.contains("Recuerda:") and not rejected.message.contains(trade.models("bread", 3).confirm), "Confirmation rejection gives a rule reminder only")
	check(trade.submit(state, "bread", 3, "Vale, confirmo: 3 panes por 6 monedas.").get("committed", false), "Own confirmation commits")
	check(not trade.submit(state, "bread", 1, "Quiero comprar una pan.").ok and trade.submit(state, "bread", 1, "Quiero un pan.").ok, "Article for one item follows gender")
	trade.cancel()
	check(trade.submit(state, "water", 1, "Necesito una botella de agua.").ok, "Feminine one accepted")
	trade.cancel()
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
	check(trade.inventory.bread == 5 and trade.stock.bread == 25, "Failed transaction leaves goods intact")
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
	old.erase("npc_memory")
	old.erase("party")
	old.erase("campaign")
	old.strategy.erase("economy")
	old.strategy.erase("equipment")
	old.strategy.erase("side_cases")
	old.strategy.erase("ghosts")
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
	check(panel.visible and panel.products.item_count == 7, "The inn offers supplies, recruits and a room")
	check(panel.prompt.text.contains("Recuerda:") and not panel.prompt.text.contains(map.state.trade.models("bread", 1).request), "Shop shows a cue and a rule, not the model")
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
		root.get_texture().get_image().save_png("user://market-preview.png")
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
