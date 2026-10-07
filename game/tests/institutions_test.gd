extends "res://tests/campaign_test.gd"
## Epic 18: an institutional act changes the world only with authority, procedure,
## seal and witness; an invalid act changes nothing (master spec 38.1).
const Institutions = preload("res://src/world/institutions.gd")
func run() -> void:
	var state := World.new("province_160x120_v1")
	var campaign = state.campaign
	var order: Dictionary = campaign.definitions.sealed_order.declaration
	check(Institutions.valid(order), "The bishop's sealed order is a valid act")
	var forged := {"authority": "visitor", "seal": "episcopal"}
	for change in [["authority", "beatriz_orma"], ["authority", "visitor"], ["kind", "sentence"], ["procedure", "court_ruling"],
			["seal", "forged"], ["witness", ""], ["target", ""], ["effect", ""], ["text", ""]]:
		forged = order.duplicate()
		forged[change[0]] = change[1]
		check(not Institutions.valid(forged), "Invalid act refused: %s = '%s'" % change)
	check(not Institutions.valid(null) and not Institutions.valid({}), "A missing act is not valid")
	check(campaign.acts(state).is_empty() and campaign.effects(state).is_empty(), "No act before any record")
	complete_opening(state)
	learn(state)
	visit(state, "LOC14")
	check(campaign.submit(state, "sealed_order", campaign.definitions.sealed_order.answers[0], "declared").ok, "Record the order")
	check(campaign.effects(state) == {"notebooks_in_custody": true}, "The recorded act is in force")
	var bad: Dictionary = campaign.definitions.sealed_order.duplicate(true)
	bad.declaration.seal = "forged"
	campaign.definitions.sealed_order = bad
	check(campaign.effects(state).is_empty(), "A forged seal puts no act in force")
	campaign.definitions.sealed_order.declaration.seal = "episcopal"
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.state = state
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.campaign_journal.open_journal(state)
	check(map.campaign_journal.body.text.contains("ACTOS INSTITUCIONALES EN VIGOR") and map.campaign_journal.body.text.contains("Orden de custodia"), "The journal lists acts in force")
	map.queue_free()
	await process_frame
	print("Institution checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
