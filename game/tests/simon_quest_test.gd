extends "res://tests/campaign_test.gd"
const MACHINE_CASE := ["simon_engine", "simon_demands", "simon_choice", "simon_review"]
func run() -> void:
	var state := World.new("province_160x120_v1")
	complete_opening(state)
	learn(state)
	for id in state.campaign.definitions:
		if id == "council_resolution" or id in MACHINE_CASE:
			continue
		var node: Dictionary = state.campaign.definitions[id]
		if node.hero != "any":
			state.select_hero(node.hero)
		visit(state, node.location)
		if node.get("reunite", false):
			for member in state.party.heroes.values():
				member.cell = state.hero_cell
			state._reveal_from(state.hero_cell)
		check(state.campaign.submit(state, id, node.answers[0], node.classification, node.get("supports", [])).ok, "Prepare canonical prerequisite: " + id)
	var base := Save.snapshot(state)
	var campaign = state.campaign
	var resolution: Dictionary = campaign.definitions.council_resolution
	for outcome: Dictionary in resolution.outcomes:
		var current = Save.decode(base).state
		current.select_hero("inquisitor")
		visit(current, resolution.location)
		check(current.campaign.submit(current, resolution.id, outcome.answer, "declared", resolution.supports).ok, "Every ending remains possible without SQ05: " + outcome.id)
	for id: String in MACHINE_CASE:
		check(campaign.definitions[id].optional, "SQ05 remains optional: " + id)
		check(id not in resolution.outcomes[3].requires, "Charter never requires SQ05: " + id)
	var engine: Dictionary = campaign.definitions.simon_engine
	var demands: Dictionary = campaign.definitions.simon_demands
	var review: Dictionary = campaign.definitions.simon_review
	state.select_hero("survivor")
	visit(state, review.location)
	check(not campaign.submit(state, review.id, review.answers[0], review.classification, review.supports).ok, "Tradeoff requires both prior sources")
	visit(state, engine.location)
	check(not campaign.submit(state, engine.id, "La máquina beneficia a todos.", "observed").ok, "Functioning engine does not prove universal benefit")
	check(campaign.submit(state, engine.id, engine.variants[0], engine.classification).ok, "Observe functioning engine")
	visit(state, demands.location)
	check(not campaign.submit(state, demands.id, demands.answers[0], demands.classification).ok, "Ines must gather the competing requests")
	state.select_hero("smuggler")
	visit(state, demands.location)
	check(not campaign.submit(state, demands.id, demands.answers[0], "declared").ok, "Requested ban is not an enacted declaration")
	check(campaign.submit(state, demands.id, demands.variants[1], demands.classification).ok, "Report all three competing requests")
	state.select_hero("survivor")
	visit(state, review.location)
	var course = state.learner.curriculum
	var conditional_id := ""
	for block: Dictionary in course.blocks:
		for card: Dictionary in block.cards:
			if card.tag == "conditional":
				conditional_id = card.id
	check(not conditional_id.is_empty(), "Conditional has an ordered lesson")
	var learned: Dictionary = course.records[conditional_id].duplicate(true)
	course.records[conditional_id].erase("second")
	check(not campaign.submit(state, review.id, review.answers[0], review.classification, review.supports).ok, "Narrative progress cannot bypass conditional practice")
	course.records[conditional_id] = learned
	check(not campaign.submit(state, review.id, review.answers[0], "observed", review.supports).ok, "Future tradeoff is an inference, not an observation")
	check(not campaign.submit(state, review.id, review.answers[0], review.classification, ["simon_engine", "simon_engine"]).ok, "Tradeoff needs two distinct sources")
	var resources: Dictionary = state.resources.duplicate(true)
	check(campaign.submit(state, review.id, review.variants[0], review.classification, review.supports).ok, "Conditional tradeoff accepted with both sources")
	check(state.resources == resources, "Recorded inference does not enact a ban or create production")
	var saved := Save.snapshot(state)
	check(Save.decode(saved).has("state"), "All SQ05 records survive a save")
	var forged := saved.duplicate(true)
	forged.campaign.erase("simon_demands")
	check(not Save.decode(forged).has("state"), "Saved tradeoff cannot omit requests")
	forged = saved.duplicate(true)
	forged.campaign.simon_review.answer = "La máquina no tiene ningún coste."
	check(not Save.decode(forged).has("state"), "Save rejects an invented clean solution")
	# SQ05 decision: every option has a price and a lasting consequence.
	var choice: Dictionary = campaign.definitions.simon_choice
	check(choice.decision and choice.outcomes.size() == 3, "SQ05 offers destroy, scale or ban")
	for outcome: Dictionary in choice.outcomes:
		var world = Save.decode(saved).state
		world.select_hero("inquisitor")
		visit(world, choice.location)
		check(not world.campaign.submit(world, choice.id, "Hago lo que quiera el propietario.", "").ok, "Only the stated options decide")
		check(world.campaign.submit(world, choice.id, outcome.answer, "").ok, "Decide SQ05: " + outcome.id)
		var gold: int = world.resources.gold
		world.end_turn()
		world.economy.advance_day(world)
		var scaled: bool = outcome.id == "scale"
		check((world.resources.gold - gold >= 50) == scaled, "Only the scaled engine adds daily gold: " + outcome.id)
		check(world.campaign.effects(world).has("engine_banned") == (outcome.id == "ban"), "Only the ban is an act in force: " + outcome.id)
		var loaded := Save.decode(Save.snapshot(world))
		check(loaded.has("state") and loaded.state.campaign.income(loaded.state) == world.campaign.income(world), "Decision and its income survive a restart: " + outcome.id)
	print("Simon quest checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)