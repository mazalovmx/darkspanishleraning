extends "res://tests/campaign_test.gd"
func run() -> void:
	var state := World.new("province_160x120_v1")
	complete_opening(state)
	learn(state)
	for id in state.campaign.definitions:
		if id == "council_resolution":
			continue
		var node: Dictionary = state.campaign.definitions[id]
		if node.hero != "any":
			state.select_hero(node.hero)
		visit(state,node.location)
		if node.get("reunite",false):
			for member in state.party.heroes.values():
				member.cell = state.hero_cell
			state._reveal_from(state.hero_cell)
		check(state.campaign.submit(state,id,node.answers[0],node.classification,node.get("supports",[])).ok,"Prepare verified conclusion: " + id)
	state.select_hero("inquisitor")
	visit(state,"LOC02")
	var base := Save.snapshot(state)
	var resolution: Dictionary = state.campaign.definitions.council_resolution
	var charter: RefCounted
	for outcome: Dictionary in resolution.outcomes:
		var current = Save.decode(base).state
		check(current.campaign.submit(current,resolution.id,outcome.answer,"declared",resolution.supports).ok,"Valid resolution: " + outcome.id)
		if outcome.id == "charter":
			charter = current
		check(current.campaign.ending(current).id == outcome.id,"Ending derives from recorded statement")
		check(not current.campaign.submit(current,resolution.id,resolution.answers[0],"declared",resolution.supports).ok,"Council decision cannot be overwritten")
		var loaded := Save.decode(Save.snapshot(current))
		check(loaded.has("state") and loaded.state.campaign.ending(loaded.state).id == outcome.id,"Ending survives restart")
	var no_optional := base.duplicate(true)
	for id in state.campaign.definitions:
		if state.campaign.definitions[id].get("optional",false):
			no_optional.campaign.erase(id)
	var limited = Save.decode(no_optional).state
	check(not limited.campaign.submit(limited,resolution.id,resolution.answers[3],"declared",resolution.supports).ok,"Charter requires optional field evidence")
	check(limited.campaign.ending(limited).is_empty(),"Failed charter produces no ending")
	check(limited.campaign.submit(limited,resolution.id,resolution.answers[2],"declared",resolution.supports).ok,"Other reasoned policy remains possible")
	var forged := Save.snapshot(limited)
	forged.campaign.council_resolution.answer = resolution.answers[3]
	check(not Save.decode(forged).has("state"),"Cannot forge charter by replacing saved sentence")
	# SQ03/SQ04 are optional lessons: no mainline step or ending depends on them.
	var defs: Dictionary = state.campaign.definitions
	var extras := ["confession_record","confession_review","letter_seal","letter_review"]
	for id in defs:
		if not defs[id].get("optional",false):
			for dep: String in defs[id].requires + defs[id].get("supports",[]):
				check(not defs.get(dep,{}).get("optional",false),"Mainline never waits for an optional case: " + id)
	var plain := base.duplicate(true)
	for id: String in extras:
		check(defs[id].get("optional",false) and id not in resolution.outcomes[3].requires,"Side lesson stays outside the Charter: " + id)
		plain.campaign.erase(id)
	var without = Save.decode(plain).state
	check(without.campaign.submit(without,resolution.id,resolution.answers[3],"declared",resolution.supports).ok,"Charter needs neither the confession nor the letter case")
	var reviews := base.duplicate(true)
	reviews.campaign.erase("confession_review")
	reviews.campaign.erase("letter_review")
	var open = Save.decode(reviews).state
	var echo: Dictionary = defs.confession_review
	check(not open.campaign.submit(open,echo.id,"El muchacho robó la reliquia.","observed",echo.supports).ok,"Echoed confession is not an observed theft")
	check(not open.campaign.submit(open,echo.id,echo.answers[0],"reported",echo.supports).ok,"Echo judgement is an inference")
	check(open.campaign.submit(open,echo.id,echo.answers[0],"inferred",echo.supports).ok,"Confession separated from independent evidence")
	var letter: Dictionary = defs.letter_review
	check(not open.campaign.submit(open,letter.id,"La carta es verdadera.","inferred",letter.supports).ok,"True claim does not make the letter authentic")
	check(not open.campaign.submit(open,letter.id,"La carta es falsa.","inferred",letter.supports).ok,"False provenance does not settle the claim")
	check(not open.campaign.submit(open,letter.id,letter.answers[0],"declared",letter.supports).ok,"Forged letter carries no institutional force")
	check(not open.campaign.submit(open,letter.id,letter.answers[0],"inferred",["letter_seal","letter_seal"]).ok,"Claim needs a source other than the letter")
	check(open.campaign.submit(open,letter.id,letter.variants[0],"inferred",letter.supports).ok,"Provenance separated from accuracy")
	check(Save.decode(Save.snapshot(open)).has("state"),"Side lessons survive save")
	var missing := base.duplicate(true)
	missing.campaign.erase("council_unknown")
	var incomplete = Save.decode(missing).state
	check(not incomplete.campaign.submit(incomplete,resolution.id,resolution.answers[0],"declared",resolution.supports).ok,"Council must acknowledge unresolved uncertainty")
	root.size = Vector2i(1280,720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.state = charter
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.campaign_button.pressed.emit()
	map.campaign_journal.active_id = "council_resolution"
	map.campaign_journal.refresh()
	check(map.campaign_journal.body.text.begins_with("FINAL · La Carta"),"Final consequences lead the screen")
	check(map.campaign_journal.body.text.contains("autoridad humana responsable"),"Charter guarantees displayed")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/council-preview.png")
	map.queue_free()
	await process_frame
	print("Council ending checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)