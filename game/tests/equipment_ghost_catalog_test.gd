extends Node
var checks := 0
var failures := 0
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func read_json(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		push_error("Invalid catalog: " + path)
		get_tree().quit(1)
		return {}
	return parser.data
func indexed(rows: Array) -> Dictionary:
	var out := {}
	for row: Dictionary in rows:
		check(not out.has(row.id), "Unique catalog ID")
		out[row.id] = row
	return out
func valid_slot(item: Dictionary, types: Dictionary, data: Dictionary) -> bool:
	var group: String = types[item.type].slot_group
	return item.default_slot in data.rules.slot_groups[group] if data.rules.slot_groups.has(group) else item.default_slot == group
func run() -> void:
	var equipment := read_json("res://content/scenario/equipment.json")
	var ghosts := read_json("res://content/scenario/ghost_knights.json")
	var side := read_json("res://content/scenario/side_investigations.json")
	if equipment.is_empty() or ghosts.is_empty() or side.is_empty():
		return
	var types := indexed(equipment.types)
	var items := indexed(equipment.items)
	var sets := indexed(equipment.sets)
	var rarities := indexed(equipment.rarities)
	var knights := indexed(ghosts.knights)
	var quests := indexed(side.quests)
	var branches := indexed(side.branches)
	var units := indexed(side.units)
	check(types.size() == 30 and items.size() == 180, "30 equipment types and 180 authored items")
	check(sets.size() == 6 and knights.size() == 8, "Six souls and eight knight behaviors")
	check(equipment.slots.size() == 14, "Fourteen body/accessory slots")
	check(equipment.status == "runtime_integrated_partial_acquisition" and ghosts.status == "authored_not_integrated", "Runtime status honest")
	check("gate_i" in equipment.activation_requires and "gate_i" in ghosts.activation_requires, "Integration gates preserved")
	var rank := 0
	for rarity: Dictionary in equipment.rarities:
		check(rarity.rank > rank, "Rarity order strictly increasing")
		rank = int(rarity.rank)
	check(equipment.rarities.back().id == "soul", "Soul assembly is highest tier")
	for type: Dictionary in equipment.types:
		var ordinary_rarities := {}
		for item: Dictionary in equipment.items:
			if item.type == type.id and not item.unique:
				ordinary_rarities[item.rarity] = true
		check(ordinary_rarities.size() == 5, "Every type spans five ordinary tiers")
	for item: Dictionary in equipment.items:
		check(types.has(item.type) and rarities.has(item.rarity), "Item type and rarity exist")
		check(valid_slot(item, types, equipment), "Item uses a compatible slot")
		check(not item.effects.is_empty(), "Item has a concrete bonus")
		for bonus: Dictionary in item.effects:
			check(equipment.effects.has(bonus.effect), "Known stat")
			check(bonus.amount > 0 and bonus.amount <= equipment.effects[bonus.effect].cap, "Positive bounded stat")
		if item.source.kind == "merchant":
			check(item.source.requires_spanish and item.price_gold > 0, "Purchase requires Spanish and defined price")
		if item.unique:
			check(item.price_gold == null, "Unique components and souls cannot be bought as a shortcut")
		if item.rarity == "soul":
			check(sets.has(item.id) and item.source.kind == "soul_assembly", "Highest rank requires a soul recipe")
	var bound := {}
	for reward: Dictionary in equipment.reward_bindings:
		check(quests.has(reward.quest_id) and items.has(reward.item_id), "Reward overlay has existing quest and item")
		check(not bound.has(reward.item_id), "Unique part has one reward source")
		bound[reward.item_id] = reward.quest_id
		check(reward.once_per_campaign and reward.does_not_replace_evidence, "No farming or consumption of evidence")
		check(reward.custody_routes == ["battle_victory", "peaceful_access"], "Peaceful route retains equipment rewards")
	check(bound.size() == 24, "Twenty-four unique parts")
	for set: Dictionary in equipment.sets:
		check(set.components.size() == 4, "Four components per set")
		var occupied := {}
		var component_ids := {}
		for part: Dictionary in set.components:
			check(items.has(part.item_id) and bound.has(part.item_id), "Recipe part obtainable")
			check(items[part.item_id].set_id == set.id, "Part belongs to exactly this set")
			check(items[part.item_id].default_slot == part.slot, "Recipe slot agrees with item")
			check(not occupied.has(part.slot) and not component_ids.has(part.item_id), "No self-conflicting recipe")
			occupied[part.slot] = true
			component_ids[part.item_id] = true
			check(quests[bound[part.item_id]].language.block <= set.ritual.required_block, "Parts obtainable without later grammar")
		check(occupied.keys() == set.reserved_slots, "Combined artifact reserves all component slots")
		check(items[set.combined_item].reserved_slots == set.reserved_slots, "Combined item and recipe agree")
		var memories := indexed(set.soul.memories)
		for memory: Dictionary in set.soul.memories:
			check(component_ids.has(memory.source_component), "Memory belongs to a required part")
		for memory_id: String in set.ritual.required_memories:
			check(memories.has(memory_id), "Persuasion evidence exists")
		check(set.soul.accepted_argument != set.soul.rejected_argument, "Argument has a meaningful competing interpretation")
		check(set.ritual.required_block >= 2 and set.ritual.required_block <= 7, "Soul follows ordered curriculum")
		check(set.ritual.spanish_prompts.size() == 3, "Three distinct production stages")
		check("independent_argument" in set.ritual.stages and "delayed_recall" in set.ritual.stages, "No click-only assembly")
		check("curriculum_prerequisites_consolidated" in set.ritual.canonical_checks, "No rarity-based grammar jump")
		check(knights.has(set.special.target_knight) and not set.special.automatic_truth, "Soul power has target without granting truth")
	var rules: Dictionary = equipment.rules
	check(rules.assembly.requires_soul_consent and rules.assembly.requires_spanish_production, "Soul and Spanish gates mandatory")
	check(rules.assembly.all_components_equipped and rules.assembly.all_reserved_slots_required, "No free slots from combination")
	check(not rules.assembly.consumes_component_instances and rules.assembly.atomic, "Assembly preserves component instances atomically")
	check(rules.disassembly.returns_exact_component_instances and rules.disassembly.preserves_consent, "Reversible assembly without duplicate rewards")
	check(not rules.backpack_grants_bonuses and rules.assembly.model_cannot_commit, "Only equipped stats and local commit")
	check(rules.transfer.new_hero_requires_own_spanish_consent, "Consent cannot be transferred as a shortcut")
	check(rules.soul_consent.delayed_recall_min_world_turns >= 1, "Recall not the same immediate copied answer")
	var policies := {}
	var effects_used := {}
	for knight: Dictionary in ghosts.knights:
		check(not policies.has(knight.orders.target_policy), "Distinct opponent target policy")
		policies[knight.orders.target_policy] = true
		check(not effects_used.has(knight.orders.effect_id), "Distinct story intervention")
		effects_used[knight.orders.effect_id] = true
		check(ghosts.effects.has(knight.orders.effect_id), "Effect defined")
		var effect: Dictionary = ghosts.effects[knight.orders.effect_id]
		check(effect.reversible and effect.max_turns <= ghosts.turn_contract.budget.max_effect_duration_turns, "Local change expires within budget")
		check(knight.orders.cooldown_turns >= ghosts.turn_contract.budget.repeat_target_cooldown_turns, "No repeated target lock")
		for branch_id: String in knight.spawn.branch_ids:
			check(branches.has(branch_id), "Knight tied to an existing branch")
		check(knight.minimum_curriculum_block == knight.counter.required_block, "Encounter and language gate agree")
		check(knight.counter.requires_typed_spanish and knight.counter.requires_supported_evidence, "Counter combines evidence and Spanish")
		check(knight.counter.soul_optional and "wait_for_expiry" in knight.counter.alternative_routes, "No soul-set softlock")
		check(not knight.intervention.can_change_evidence and not knight.intervention.can_change_main_ending, "Bounded story authority")
		check(knight.intervention.trace_always_recorded and knight.intervention.expiry_returns_access, "Visible trace and recovery")
		if knight.counter.soul_set != null:
			check(sets.has(knight.counter.soul_set), "Soul counter exists")
		if knight.orders.effect_id == "fragment_escrow":
			check(knight.intervention.unclaimed_items_only, "Knight never steals owned equipment")
		for stack: Dictionary in knight.battle.enemy_stacks:
			check(units.has(stack.unit) and stack.count > 0, "Uses defined battle units")
		check(knight.battle.enemy_stacks.size() <= 4, "Stack limit respected")
		check(knight.battle.commands == ["ATTACK", "DEFEND", "ABILITY", "RETREAT"], "Existing command vocabulary")
		for stage in ["first_round", "second_round", "later_rounds"]:
			check(knight.battle.script[stage] in knight.battle.commands, "Tactics use valid commands")
		check(knight.battle.balance_status == "authored_unplaytested", "No false battle validation")
	var turn: Dictionary = ghosts.turn_contract
	check(turn.mode == "simultaneous_plan_then_resolve", "Simultaneous strategic orders")
	check(turn.snapshot_rules.ai_orders_frozen_before_player_commit, "AI cannot react to uncommitted player orders")
	check(not turn.snapshot_rules.npc_uses_player_current_order, "AI does not peek at player choice")
	check(turn.atomic_resolution and not turn.reload_rerolls, "Save/reload preserves resolution")
	check(turn.budget.max_active_knights <= 3 and turn.budget.max_interventions_per_turn <= 2, "Bounded pressure")
	for invariant: String in ghosts.invariants:
		check(ghosts.invariants[invariant], "Canonical and recovery invariant enabled")
	print("Equipment/ghost catalog checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
