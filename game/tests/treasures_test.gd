extends "res://tests/campaign_test.gd"
## Map treasures: the only source of the 90 optional_treasure items; Marjal Negro holds
## the guarded caches (bible 10.10, master spec 12).
func stand(state: RefCounted, position: Array) -> void:
	state.hero_cell = Vector2i(position[0], position[1])
	state._reveal_from(state.hero_cell)

func run() -> void:
	var state := World.new("province_160x120_v1")
	var economy = state.economy
	var items := {}
	for item: Dictionary in state.equipment.catalog.items:
		if item.source.kind == "optional_treasure":
			items[item.id] = 0
	check(economy.treasures.size() == 30 and items.size() == 90, "Thirty caches for ninety treasure items")
	var start: Vector2i = state.hero_cell
	# The northern pass opens with the opening report; caches beyond it count as reachable then.
	complete_opening(state)
	state._sync_gates()
	var marsh: Array = state.map_data.regions.filter(func(r: Dictionary) -> bool: return r.name == "Marjal Negro")[0].bounds
	for id: String in economy.treasures:
		var cache: Dictionary = economy.treasures[id]
		check(cache.items.size() == 3, "Three items per cache: " + id)
		for item: String in cache.items:
			items[item] = int(items.get(item, -10)) + 1
		var cell := Vector2i(cache.position[0], cache.position[1])
		check(state.terrain_cost(cell) > 0 and state.location_at(cell).is_empty(), "Cache on open ground: " + id)
		check(not state.grid.get_id_path(start, cell).is_empty(), "Cache reachable from the start: " + id)
		if cache.guarded:
			check(Rect2i(marsh[0], marsh[1], marsh[2], marsh[3]).has_point(cell) and not cache.guards.is_empty(), "Guarded cache in Marjal Negro: " + id)
	check(items.values().all(func(count: int) -> bool: return count == 1), "Every treasure item sits in exactly one cache")
	check(economy.treasures.values().filter(func(c: Dictionary) -> bool: return c.guarded).size() == 6, "Six guarded caches")
	var open_cache: Dictionary = economy.treasures.values().filter(func(c: Dictionary) -> bool: return not c.guarded)[0]
	var guarded: Dictionary = economy.treasures.TR01
	check(not economy.claim_treasure(state, open_cache.id, "Quiero abrir el cofre.").ok, "Only on the cache's cell")
	stand(state, open_cache.position)
	check(state.resource_at(state.hero_cell).get("id") == open_cache.id, "The map finds the cache under the hero")
	var vague: Dictionary = economy.claim_treasure(state, open_cache.id, "Hola.")
	check(not economy.claim_treasure(state, open_cache.id, "No quiero abrir el cofre.").ok and not economy.treasure_claimed(state, open_cache.id), "A refusal leaves the cache closed")
	check(not vague.ok and vague.message.contains("el cofre"), "Opening a cache needs Spanish naming the action and the cache")
	check(economy.claim_treasure(state, open_cache.id, "Quiero abrir el cofre.").ok and economy.treasure_claimed(state, open_cache.id), "Typed order opens the cache")
	check(state.equipment.instances.size() == 3, "Its three items go to the active hero's backpack")
	check(not economy.claim_treasure(state, open_cache.id, "Quiero abrir el cofre.").ok, "A cache opens once")
	check(Save.decode(Save.snapshot(state)).has("state"), "An opened unguarded cache restores")
	stand(state, guarded.position)
	check(not state.encounter_definition(guarded.id).enemies.is_empty(), "Bandits guard the Marjal cache")
	check(not economy.claim_treasure(state, guarded.id, "Quiero abrir el cofre.").ok, "No cache while the bandits hold it")
	state.encounters[guarded.id] = {"outcome": "victory", "day": state.day}
	check(economy.claim_treasure(state, guarded.id, "Necesito abrir esta arca.").ok, "After the victory the cache opens")
	var saved := Save.snapshot(state)
	check(Save.decode(saved).has("state"), "Guarded treasure with its victory restores")
	var forged := saved.duplicate(true)
	forged.strategy.encounters.erase(guarded.id)
	check(not Save.decode(forged).has("state"), "Guarded treasure without a victory does not restore")
	var prototype := World.new()
	check(prototype.economy.treasure(prototype, "TR01").is_empty(), "No treasures outside the province")
	print("Treasure checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
