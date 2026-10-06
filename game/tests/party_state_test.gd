extends SceneTree
const Party = preload("res://src/world/party_state.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	var party := Party.new()
	check(party.heroes.size() == 3 and party.active_id == "inquisitor", "Three canonical protagonists")
	party.active().movement_remaining = 4
	party.active().inventory.bread = 5
	check(party.select("smuggler"), "Select Inés")
	check(party.active().movement_remaining == 18 and party.active().inventory.bread == 0, "Movement and supplies independent")
	party.active().cell = Vector2i(6, 11)
	check(party.select("survivor") and party.active().army[0].count == 2, "Elias has small rare-unit escort")
	check(party.select("inquisitor") and party.active().movement_remaining == 4, "Switching does not refill movement")
	check(not party.select("invented"), "Unknown hero rejected")
	check(not party.transfer_supply("inquisitor", "smuggler", "bread", 2), "Distant heroes cannot exchange")
	party.heroes.smuggler.cell = party.active().cell
	check(party.transfer_supply("inquisitor", "smuggler", "bread", 2), "Meeting permits supply transfer")
	check(party.heroes.inquisitor.inventory.bread == 3 and party.heroes.smuggler.inventory.bread == 2, "Supply transfer conserves quantity")
	check(not party.transfer_supply("inquisitor", "smuggler", "bread", 99), "Cannot overdraw supplies")
	check(not party.transfer_supply("inquisitor", "inquisitor", "bread", 1), "Self-transfer rejected")
	check(party.transfer_stack("inquisitor", "smuggler", 1, 2), "Troops transfer")
	check(party.heroes.inquisitor.army[1].count == 2 and party.heroes.smuggler.army[0].count == 8, "Matching units merge and conserve count")
	check(not party.transfer_stack("inquisitor", "smuggler", 1, 3), "Cannot overdraw troops")
	check(party.transfer_stack("inquisitor", "smuggler", 1, 2), "Full stack transfer")
	check(party.heroes.inquisitor.army.size() == 1, "Empty source stack removed")
	var copy := party.snapshot()
	copy.heroes.inquisitor.army[0].count = 999
	check(party.active().army[0].count == 8, "Snapshot does not alias army")
	party.heroes.survivor.unlocked = false
	check(not party.select("survivor"), "Locked hero cannot be selected")
	party.end_day()
	for hero in party.heroes.values():
		check(hero.movement_remaining == 18, "New day restores every hero")
	var snapshot := party.snapshot()
	var loaded := Party.new()
	var passable := func(cell: Vector2i): return cell != Vector2i(3, 3)
	check(loaded.restore(snapshot, Rect2i(0, 0, 20, 20), passable), "Roster restores")
	check(loaded.snapshot() == snapshot, "All hero state round-trips")
	for field in ["position","movement","health","army","inventory","unlocked"]:
		var bad := snapshot.duplicate(true)
		bad.heroes.inquisitor.erase(field)
		check(not loaded.restore(bad, Rect2i(0, 0, 20, 20), passable), "Missing hero field rejected")
	for value in [true, -1, 19, 1.5]:
		var bad := snapshot.duplicate(true)
		bad.heroes.inquisitor.movement = value
		check(not loaded.restore(bad, Rect2i(0, 0, 20, 20), passable), "Invalid movement rejected")
	var bad := snapshot.duplicate(true)
	bad.heroes.inquisitor.position = [3,3]
	check(not loaded.restore(bad, Rect2i(0, 0, 20, 20), passable), "Impassable position rejected")
	bad = snapshot.duplicate(true)
	bad.active = "survivor"
	check(not loaded.restore(bad, Rect2i(0, 0, 20, 20), passable), "Cannot restore locked active hero")
	check(loaded.snapshot() == snapshot, "Invalid restores leave live roster intact")
	print("Party state checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
