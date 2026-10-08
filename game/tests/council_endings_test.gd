extends "res://tests/campaign_test.gd"
const Institutions = preload("res://src/world/institutions.gd")
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
	# MQ10: granting emergency powers is an institutional act with consequences.
	var purge: Dictionary = defs.purge_decision
	check(base.campaign.purge_decision.answer == purge.outcomes[0].answer and not state.campaign.effects(state).has("emergency_powers"), "Refusing emergency powers puts no act in force")
	check(not Institutions.valid(defs.crisis_forged_order.claimed_act), "The forged purge order is not a valid act")
	var granted := base.duplicate(true)
	granted.campaign.purge_decision.answer = purge.outcomes[1].answer
	var powers = Save.decode(granted).state
	check(powers != null and powers.campaign.effects(powers).has("emergency_powers"), "Granting emergency powers is an act in force")
	check(not powers.campaign.effects(powers).has("miralba_purge"), "The forged order never takes effect")
	var closed: Dictionary = powers.campaign.submit(powers,resolution.id,resolution.answers[3],"declared",resolution.supports)
	check(not closed.ok, "Emergency powers close the Charter")
	check(powers.campaign.submit(powers,resolution.id,resolution.answers[2],"declared",resolution.supports).ok, "Another ending remains")
	check(powers.campaign.ending(powers).text.contains("descripción falsa en verdadera"), "The ending carries the consequence of the act")
	var calm = Save.decode(base).state
	calm.campaign.submit(calm,resolution.id,resolution.answers[2],"declared",resolution.supports)
	check(not calm.campaign.ending(calm).text.contains("descripción falsa"), "Without the act there is no such epilogue")
	var unrelated := base.duplicate(true)
	unrelated.campaign.purge_decision.answer = "Propongo que el obispo decida."
	check(not Save.decode(unrelated).has("state"), "A decision outside the proposals does not restore")
	# SQ01, SQ02, SQ06: decisions with consequences; the harsh ones close their review.
	for case in [["bakery_choice", "threaten", "grain_review"], ["ventilation_choice", "keep_ban", "ventilation_review"], ["capacitor_choice", "destroy", "capacitor_review"], ["capacitor_choice", "silence", "capacitor_review"]]:
		var decision: Dictionary = defs[case[0]]
		var picked: Dictionary = decision.outcomes.filter(func(o: Dictionary) -> bool: return o.id == case[1])[0]
		var shut := base.duplicate(true)
		shut.campaign[case[0]].answer = picked.answer
		check(not Save.decode(shut).has("state"), "A review recorded after a decision that closed it does not restore: " + case[1])
		shut.campaign.erase(case[2])
		var world = Save.decode(shut).state
		check(world != null and world.campaign.reason(world, case[2]) == "Una decisión anterior cerró esta vía.", "The decision closes the review: " + case[1])
		world.select_hero("inquisitor")
		visit(world, "LOC02")
		check(not world.campaign.submit(world, resolution.id, resolution.answers[3], "declared", resolution.supports).ok, "Without the review there is no Charter: " + case[1])
		check(world.campaign.submit(world, resolution.id, resolution.answers[1], "declared", resolution.supports).ok, "Another ending remains: " + case[1])
		var line: String = str(resolution.epilogues[picked.effect])
		check(world.campaign.ending(world).text.contains(line), "The ending remembers the decision: " + case[1])
	var fan = Save.decode(base).state
	check(fan.campaign.income(fan) == {"ore": 1}, "The approved fan adds ore each day")
	var bargain := base.duplicate(true)
	bargain.campaign.bakery_choice.answer = defs.bakery_choice.outcomes.filter(func(o: Dictionary) -> bool: return o.id == "bargain")[0].answer
	check(Save.decode(bargain).has("state"), "A bargain keeps the supply review open")
	# A wrong council category is recorded and closes the Charter, not the other endings.
	var mistaken := base.duplicate(true)
	mistaken.campaign.erase("council_inferred")
	var council = Save.decode(mistaken).state
	var inferred: Dictionary = defs.council_inferred
	check(not council.campaign.submit(council,inferred.id,inferred.answers[0],"invented").ok,"An unknown category is still refused")
	check(council.campaign.submit(council,inferred.id,inferred.answers[0],"observed").ok,"A wrong council category is recorded")
	check(council.campaign.records.council_inferred.classification == "observed" and council.campaign.misclassified(council.campaign.records) == 1,"The mistake is kept")
	var reloaded = Save.decode(Save.snapshot(council))
	check(reloaded.has("state") and reloaded.state.campaign.misclassified(reloaded.state.campaign.records) == 1,"The mistake survives a restart")
	var refused: Dictionary = council.campaign.submit(council,resolution.id,resolution.answers[3],"declared",resolution.supports)
	check(not refused.ok and refused.message.contains("sin clasificaciones erróneas"),"A misclassified council closes the Charter")
	check(council.campaign.submit(council,resolution.id,resolution.answers[1],"declared",resolution.supports).ok and council.campaign.ending(council).id == "preserve","Other endings stay open")
	check(not defs.council_resolution.get("council",false) and not defs.sealed_order.get("council",false),"Only council statements accept any category")
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
		root.get_texture().get_image().save_png("user://council-preview.png")
	map.queue_free()
	await process_frame
	print("Council ending checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)