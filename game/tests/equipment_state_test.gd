extends "res://tests/campaign_test.gd"
const Equipment = preload("res://src/world/equipment_state.gd")
func ritual(gear: RefCounted,state: RefCounted,set_id: String) -> void:
	for need_stage: String in gear.language[set_id].keys:
		check(gear.missing(set_id,need_stage,gear.expected(set_id,need_stage)).is_empty(),"Authored model meets its own keys")
	for stage: String in gear.STAGES:
		if stage == "delayed_recall":
			check(not gear.persuade(state,set_id,gear.expected(set_id,stage)).ok,"Recall cannot happen on the same day")
			state.end_turn()
		var memories: Array = gear.sets[set_id].ritual.required_memories if stage == "compare_memories" else []
		if stage == "independent_argument":
			var copied: Dictionary = gear.persuade(state,set_id,gear.sets[set_id].ritual.supported_frame)
			check(not copied.ok,"Copied model cannot replace independent argument")
			check(copied.message.contains("Tu frase necesita:") and not copied.message.contains(gear.expected(set_id,stage)),"Rejection names the missing need, not the answer")
		if stage == "answer_objection":
			check(not gear.persuade(state,set_id,gear.sets[set_id].ritual.wrong_reason).ok,"The soul's false reason is not an answer")
		if stage == "compare_memories":
			check(not gear.persuade(state,set_id,gear.expected(set_id,stage),[memories[0],memories[0]]).ok,"Same memory cannot stand for two sources")
		var answer: String = gear.language[set_id].alternatives.answer_objection[0] if stage == "answer_objection" else gear.expected(set_id,stage)
		if set_id == "SA01" and stage == "independent_argument":
			answer = "Cuando llega un testigo, lo protejo: escucho su relato antes de juzgar."
		var result: Dictionary = gear.persuade(state,set_id,answer,memories)
		check(result.ok,"Distinct ritual stage: " + stage)
		if set_id == "SA01" and stage == "independent_argument":
			check(result.message == "La conversación continúa.","Own independent argument accepted without a correction")
		if stage == "answer_objection":
			check(result.message.contains("Forma sugerida"),"Understood grammatical error receives correction")
func run() -> void:
	var state := World.new("province_160x120_v1")
	var gear := Equipment.new()
	check(gear.items.size() == 180 and gear.types.size() == 30,"Full equipment catalog indexed")
	check(gear.catalog.slots.size() == 14,"Fourteen equipment slots")
	var ordinary: String = gear.grant("EQ001","inquisitor")
	check(not ordinary.is_empty() and gear.bonuses("inquisitor").army_defense == 0,"Backpack gives no bonus")
	check(gear.equip(state,ordinary,"head") and gear.bonuses("inquisitor").army_defense == 1,"Equipped item applies")
	check(not gear.equip(state,ordinary,"weapon"),"Wrong slot denied")
	check(gear.unequip(state,ordinary) and gear.bonuses("inquisitor").army_defense == 0,"Unequip removes bonus")
	check(gear.grant("SA01","inquisitor").is_empty(),"Assembled artifact cannot be granted directly")
	for part: Dictionary in gear.sets.SA01.components:
		var id := gear.grant(part.item_id,"inquisitor")
		check(gear.equip(state,id,part.slot),"Equip matching soul component")
	check(not gear.persuade(state,"SA01",gear.expected("SA01","listen")).ok,"Soul cannot bypass curriculum prerequisites")
	check(not gear.assemble(state,"SA01"),"Components alone do not grant assembly")
	learn(state)
	for set_id: String in gear.sets.keys():
		gear = Equipment.new()
		var original_ids := []
		for part: Dictionary in gear.sets[set_id].components:
			var id := gear.grant(part.item_id,"inquisitor")
			original_ids.append(id)
			check(not id.is_empty() and gear.equip(state,id,part.slot),"All four unique components equipped")
			check(gear.grant(part.item_id,"survivor").is_empty(),"Unique component cannot duplicate")
		var evidence_before: Dictionary = state.evidence.progress()
		var base: Dictionary = gear.bonuses("inquisitor")
		check(not gear.persuade(state,set_id,gear.sets[set_id].soul.rejected_argument).ok,"Soul rejects coercive/false argument")
		ritual(gear,state,set_id)
		check(gear.consent("inquisitor",set_id),"Consent belongs to speaking hero")
		check(gear.assemble(state,set_id),"Consent enables manual assembly")
		var effect: String = gear.sets[set_id].bonus.effect
		var expected_bonus: int = mini(int(gear.catalog.effects[effect].cap),int(base[effect])+int(gear.sets[set_id].bonus.amount))
		check(gear.bonuses("inquisitor")[effect] == expected_bonus,"Parts retained and set effect added once")
		check(gear.instances.keys() == original_ids,"Assembly creates or destroys no component instances")
		check(not gear.unequip(state,original_ids[0]),"Assembled slots remain reserved")
		check(gear.disassemble(state,set_id) and gear.bonuses("inquisitor") == base,"Disassembly restores exact component bonuses")
		check(gear.components("inquisitor",set_id) == original_ids,"Disassembly preserves component slots")
		check(gear.assemble(state,set_id),"Existing consent allows reassembly")
		check(not gear.consume_special(state,set_id).is_empty(),"Consenting owner can use special once")
		check(gear.consume_special(state,set_id).is_empty(),"Special cannot repeat in same day")
		state.party.heroes.smuggler.unlocked = true
		state.party.heroes.smuggler.cell = state.hero_cell + Vector2i.RIGHT
		check(not gear.transfer_set(state,set_id,"smuggler"),"Remote transfer denied")
		state.party.heroes.smuggler.cell = state.hero_cell
		check(gear.transfer_set(state,set_id,"smuggler"),"Co-located set transfers atomically")
		check(gear.bonuses("smuggler") == base and not gear.consent("smuggler",set_id),"New owner gets components but no soul bonus")
		check(gear.bonuses("inquisitor")[effect] == 0,"Old owner loses transferred bonuses")
		state.select_hero("smuggler")
		ritual(gear,state,set_id)
		check(gear.bonuses("smuggler")[effect] == expected_bonus,"New owner's own argument activates assembled set")
		check(state.evidence.progress() == evidence_before,"Equipment never consumes evidence")
		var saved: Dictionary = gear.snapshot()
		var restored := Equipment.new()
		check(restored.restore(saved,state) and restored.snapshot() == saved,"Transferred set and both consents restore")
		for fault in ["slot","duplicate","missing_part","fake_consent","early_recall","reused_id"]:
			var bad := saved.duplicate(true)
			match fault:
				"slot": bad.instances[original_ids[0]].slot = "invented"
				"duplicate":
					bad.instances["I000005"] = bad.instances[original_ids[0]].duplicate(true)
					bad.next_instance = 6
				"missing_part": bad.instances.erase(original_ids[0])
				"fake_consent": bad.rituals.smuggler[set_id] = {"consent":true}
				"early_recall": bad.rituals.smuggler[set_id].delayed_recall.day = bad.rituals.smuggler[set_id].answer_objection.day
				"reused_id": bad.next_instance = 1
			check(not restored.restore(bad,state),"Invalid equipment snapshot rejected: " + fault)
			check(restored.snapshot() == saved,"Invalid restore cannot change equipment")
		state.select_hero("inquisitor")
	print("Equipment model checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)