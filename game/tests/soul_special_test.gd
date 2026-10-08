extends SceneTree
## Each soul set's own special (equipment.json): restored copy (SA02), rumour source
## (SA03), one-source route (SA04), missing premise (SA05), reward ward (SA06). The ward
## of SA01 is covered with a real ritual in ghost_persistence_test.
const World = preload("res://src/world/world_state.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
## An assembled set whose soul consented, owned by the active hero (fixture).
func grant(world: RefCounted, set_id: String) -> void:
	world.equipment.assemblies[set_id] = {"owner": world.party.active_id, "creator": world.party.active_id, "parts": [], "day": 1}
	var stages := {}
	for stage: String in world.equipment.STAGES:
		stages[stage] = {"day": 1}
	if not world.equipment.rituals.has(world.party.active_id):
		world.equipment.rituals[world.party.active_id] = {}
	world.equipment.rituals[world.party.active_id][set_id] = stages
func run() -> void:
	var world := World.new("province_160x120_v1")
	var ghosts = world.ghosts
	var quest: String = world.side_cases.branches.SB01.quest_ids[0]
	var branch := "SB01"
	check(ghosts.soul_set_for(world, "NK06") == "SA02" and ghosts.soul_set_for(world, "NK03") == "", "Sets answer their knights")
	check(not ghosts.use_special(world, "NK06", quest).ok, "No set, no special")
	for set_id in ["SA02", "SA03", "SA04", "SA05", "SA06"]:
		grant(world, set_id)
	# SA02: lifts NK06's redaction, only while it is active.
	check(not ghosts.use_special(world, "NK06", quest).ok and int(world.equipment.special_used.get("SA02", 0)) == 0, "SA02 refuses without an active redaction and keeps its daily use")
	ghosts.effects[branch] = {"knight": "NK06", "target": quest, "start": 1, "expiry": world.day + 3}
	var restored: Dictionary = ghosts.use_special(world, "NK06", quest)
	check(restored.ok and not ghosts.effects.has(branch) and restored.message.contains("copia pública"), "SA02 restores the public copy")
	check(not ghosts.use_special(world, "NK06", quest).ok, "Once per day")
	# SA03: names the shared source of NK04's rumour.
	ghosts.effects[branch] = {"knight": "NK04", "target": quest, "start": 1, "expiry": world.day + 3}
	check(not ghosts.use_special(world, "NK04", quest).ok, "SA03 needs an inspected source")
	world.side_cases.records[quest] = {"progress": {"access": {"day": 1}, "inspect": {"day": 1}}, "reward": ""}
	var source: Dictionary = ghosts.use_special(world, "NK04", quest)
	var artifact: String = world.side_cases.artifacts[world.side_cases.quests[quest].artifact_id].name
	check(source.ok and source.message.contains(artifact) and source.message.contains("no certifica"), "SA03 names the source without certifying the claim")
	check(ghosts.effects.has(branch), "SA03 leaves the intervention in place")
	ghosts.effects.erase(branch)
	# SA04: a one-source route for two world turns.
	check(ghosts.use_special(world, "NK02", quest).ok and ghosts.wards[branch] == {"knight": "NK02", "set": "SA04", "kind": "route", "expiry": world.day + 2}, "SA04 opens the duplicate-receipt route")
	# SA05: the missing premise, not the answer.
	var premise: Dictionary = ghosts.use_special(world, "NK08", quest)
	check(premise.ok and premise.message.contains(str(world.side_cases.quests[quest].investigation.verification_action)), "SA05 shows the missing premise")
	# SA06: a ward against NK05 on another case.
	var other: String = world.side_cases.branches.SB02.quest_ids[0]
	check(ghosts.use_special(world, "NK05", other).ok and ghosts.wards.SB02.kind == "ward" and ghosts.wards.SB02.knight == "NK05", "SA06 protects the reward for a turn")
	print("Soul special checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
