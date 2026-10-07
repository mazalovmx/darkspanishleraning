extends Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func index_by_id(records: Array) -> Dictionary:
	var result := {}
	for record: Dictionary in records:
		check(not result.has(record.id), "Unique ID: " + str(record.id))
		result[record.id] = record
	return result

func _ready() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string("res://content/scenario/side_investigations.json")) != OK:
		push_error("Catalog JSON failed to parse.")
		get_tree().quit(1)
		return
	var data: Dictionary = parser.data
	check(data.status == "runtime_integrated_unbalanced", "Runtime connected; balance remains untested")
	check("gate_i" in data.activation_requires, "Expansion remains gated")
	check(data.quests.size() == 108 and data.battles.size() == 108, "Requested quest and battle counts")
	check(data.artifacts.size() == 108 and data.branches.size() == 12, "Artifact and branch counts")
	var quests := index_by_id(data.quests)
	var artifacts := index_by_id(data.artifacts)
	var battles := index_by_id(data.battles)
	var branches := index_by_id(data.branches)
	var units := index_by_id(data.units)
	var blocks := index_by_id(data.curriculum_blocks)
	var titles := {}
	for quest: Dictionary in data.quests:
		check(not titles.has(quest.title), "Distinct quest title")
		titles[quest.title] = true
		check(branches.has(quest.branch_id), "Known investigation branch")
		check(quest.location_id in ["LOC01", "LOC02", "LOC03", "LOC04", "LOC05", "LOC06", "LOC07", "LOC08", "LOC11", "LOC15"], "Canonical location")
		check(artifacts.has(quest.artifact_id), "Quest artifact exists")
		check(battles.has(quest.encounter_id), "Quest encounter exists")
		check(quest.hook.length() > 40 and quest.objective.length() > 40, "Authored premise and objective")
		check(quest.investigation.observation != quest.investigation.misleading_claim, "Observation separate from false inference")
		check(quest.investigation.supported_interpretation != quest.investigation.misleading_claim, "Competing interpretations differ")
		check(quest.requires_mode == "all", "Join requirements explicit")
		for dependency: String in quest.requires:
			check(quests.has(dependency) and dependency != quest.id, "Valid prerequisite")
			check(quests[dependency].branch_id == quest.branch_id, "Independent branch prerequisites")
			check(quests[dependency].language.block <= quest.language.block, "No language regression in dependency")
		var option_ids := {}
		var option_texts := {}
		for option: Dictionary in quest.puzzle.options:
			check(not option_ids.has(option.id) and not option_texts.has(option.text), "Distinct puzzle alternatives")
			option_ids[option.id] = option.text
			option_texts[option.text] = true
		check(quest.puzzle.options.size() == 3, "Three authored interpretations")
		check(option_ids.has(quest.puzzle.answer_id) and option_ids.has(quest.puzzle.reject_id), "Puzzle answer/rejection refer to options")
		check(quest.puzzle.answer_id != quest.puzzle.reject_id, "Correct and false answers differ")
		check(option_ids[quest.puzzle.answer_id] == quest.investigation.supported_interpretation, "Solution matches supported interpretation")
		check(option_ids[quest.puzzle.reject_id] == quest.investigation.misleading_claim, "Wrong solution matches overreach")
		check(quest.artifact_id in quest.puzzle.evidence_required, "Artifact required for deduction")
		check(quest.puzzle.on_failure.length() > 20, "Wrong answer can be revisited")
		check(quest.language.required and blocks.has(quest.language.block), "Mandatory ordered Spanish block")
		check(quest.language.new_target in blocks[quest.language.block].focus, "New grammar belongs to current block")
		check(quest.language.stages == ["model", "supported_production", "independent_production", "delayed_recall"], "Practice and consolidation stages")
		check("independent_reformulation" in quest.language.completion_requires, "Choice click alone cannot complete language task")
		check(quest.language.prompt.length() > 15 and quest.language.recall_task.length() > 20, "Authored production and recall")
		check(not quest.completion.truth_from_battle, "Battle result does not prove truth")
		check("peaceful_access" in quest.completion.custody_any, "Combat not a hard quest gate")
		if quest.has("access_puzzle"):
			check("access_puzzle_solved" in quest.completion.all, "Access cipher required for completion")
			var clue: String = quest.access_puzzle.clue
			var words: PackedStringArray = clue.split("». ")[1].trim_suffix(".").split(" / ")
			var decoded := ""
			for word: String in words:
				decoded += word.left(1).to_upper()
			check(decoded == quest.access_puzzle.answer, "Acrostic solution follows supplied rule")
			check(not quest.access_puzzle.requires_external_knowledge, "Cipher self-contained")
	for artifact: Dictionary in data.artifacts:
		check(quests.has(artifact.found_in), "Artifact source exists")
		check(quests[artifact.found_in].artifact_id == artifact.id, "Artifact back-reference matches")
		check(not artifact.consumable and artifact.quest_critical, "Evidence is not consumed")
		check(artifact.supports != artifact.does_not_prove, "Evidence limits explicit")
	for battle: Dictionary in data.battles:
		check(quests.has(battle.quest_id) and quests[battle.quest_id].encounter_id == battle.id, "Encounter back-reference")
		check(battle.enemy_stacks.size() >= 1 and battle.enemy_stacks.size() <= 4, "Battle stack cap")
		check(battle.commands == ["ATTACK", "DEFEND", "ABILITY", "RETREAT"], "MVP commands only")
		for stack: Dictionary in battle.enemy_stacks:
			check(units.has(stack.unit) and stack.count > 0 and stack.count == floor(stack.count), "Valid enemy stack")
		check(battle.victory.truth_effect == null, "Victory cannot decide evidence")
		check(battle.retreat.retry and battle.retreat.retain_evidence and not battle.retreat.quest_failure, "Retreat cannot softlock investigation")
		check(battle.peaceful_route.always_available_after_requirements, "Peaceful access supported")
		for artifact_id: String in battle.peaceful_route.required_artifacts:
			check(artifacts.has(artifact_id) and artifacts[artifact_id].found_in in quests[battle.quest_id].requires, "Peaceful access never requires its own reward")
		check(battle.balance_status == "authored_unplaytested", "Balance status honest")
	for unit: Dictionary in data.units:
		check(unit.hp_per_unit > 0 and unit.damage_min > 0 and unit.damage_max >= unit.damage_min, "Valid unit values")
		check(data.abilities.has(unit.ability), "Unit ability defined in catalog")
	# Simulate topological completion using either custody route; no scene/state mutation.
	var completed := {}
	for pass_index in data.quests.size():
		for quest: Dictionary in data.quests:
			if completed.has(quest.id):
				continue
			var ready := true
			for dependency: String in quest.requires:
				if not completed.has(dependency):
					ready = false
			if ready:
				completed[quest.id] = true
	check(completed.size() == 108, "All quests reachable without cycles")
	for branch: Dictionary in data.branches:
		check(branch.quest_ids.size() == 9, "Nine quests per branch")
		check(quests[branch.entry_quest].requires.is_empty(), "Independent branch entry")
		check(branch.final_quest == branch.quest_ids.back(), "Final quest identified")
		check(quests[branch.final_quest].final_choice.size() == 2, "Two explicit local outcomes")
		for quest_id: String in branch.quest_ids:
			check(quests[quest_id].branch_id == branch.id, "Branch membership consistent")
		check(branch.related_link_optional, "Cross-case link does not block branch")
	check(data.cross_branch_links.size() == 12, "Twelve cross-case comparisons")
	for link: Dictionary in data.cross_branch_links:
		check(branches.has(link.from) and branches.has(link.to), "Cross-case endpoints exist")
		check(link.optional and not link.changes_main_ending, "Links preserve main plot")
		for quest_id: String in link.required_quests:
			check(quests.has(quest_id), "Cross-case requirements valid")
	print("Side catalog checks: %d, failures: %d; 108 quests / 108 battles / 108 artifacts / 12 branches" % [checks, failures])
	get_tree().quit(1 if failures else 0)
