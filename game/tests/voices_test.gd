extends SceneTree
## Speech by station, dark sides and the comic speakers (bible 38.2 and 13.12).
const Save = preload("res://src/save/save_game.gd")
const Client = preload("res://src/claude/claude_client.gd")
const COMIC := {"juez_bridoya": "LOC02", "panurgo": "LOC05", "fray_juan": "LOC11", "janotus_bragmardo": "LOC03",
	"picrocolo": "LOC07", "ulpiano_sellado": "LOC14", "tia_brigida": "LOC10", "tiburcio_ruedas": "LOC13", "mamerto_remolacha": "LOC06"}
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogue/npc_grounding.json"))
	for id: String in data.npcs:
		var persona: Dictionary = data.npcs[id].persona
		for field in ["station", "speech", "dark_side"]:
			check(str(persona.get(field, "")).length() > 5, "Every speaker has %s: %s" % [field, id])
	check(Client.SYSTEM_PROMPT.contains("persona.dark_side") and Client.SYSTEM_PROMPT.contains("persona.station"), "The model is told how to use station and dark side")
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var dialogue = map.dialogue
	dialogue.client.config.dev_flags.offline_mode = true
	for key: String in dialogue.conversations:
		check(str(dialogue.conversations[key].get("dark_line", "")).length() > 10, "Every conversation has an offline dark line: " + key)
	# The comic speakers: saveable, grounded, in their place, and outside every case.
	for npc_id: String in COMIC:
		var key := ""
		for candidate: String in dialogue.conversations:
			if dialogue.conversations[candidate].npc_id == npc_id:
				key = candidate
		check(not key.is_empty() and dialogue.scene_for(key) == COMIC[npc_id], "Comic speaker placed: " + npc_id)
		check(npc_id in Save.NPC_IDS and dialogue.available(key), "Comic speaker saveable and present from the start: " + npc_id)
		var context: Dictionary = dialogue.grounding.context_for(npc_id, "greeting", {}, [])
		check(not context.is_empty() and str(context.npc.persona.dark_side).length() > 5 and context.eligible_unlock_ids.is_empty(), "Comic speaker grounded, unlocks nothing: " + npc_id)
		for fact: String in data.npcs[npc_id].knowledge:
			var shared: bool = data.npcs.keys().any(func(other: String) -> bool: return other != npc_id and fact in data.npcs[other].knowledge)
			check(not data.clues.has(fact) and not shared, "Comic facts are their own, never clues: " + fact)
		check(ResourceLoader.exists("res://assets/portraits/%s.png" % npc_id), "Comic speaker has a portrait: " + npc_id)
	check(dialogue.reply_for("LOC02_BRIDOYA", "¿Cómo decide con los dados?").contains("dados"), "Bridoya answers about his dice")
	check(dialogue.reply_for("LOC05_PANURGO", "Háblame de las ovejas").contains("carnero"), "Panurgo tells the sheep story")
	check(dialogue.reply_for("LOC14_ULPIANO", "¿Está usted muerto?").contains("documento sellado"), "Ulpiano will not argue with a seal")
	# Offline, the dark side breaks through on a return greeting every third exchange.
	var inn: Dictionary = dialogue.conversations.LOC11
	for count in [1, 2, 3, 5]:
		map.state.npc_memory[inn.npc_id] = {"count": count, "last_day": 1, "topics": []}
		dialogue.histories.erase("LOC11")
		dialogue.histories["LOC11"] = []
		dialogue.location_id = "LOC11"
		dialogue._render_history()
		check(dialogue.transcript.text.contains(str(inn.dark_line)) == (count % 3 == 2), "Dark line only on every third exchange: %d" % count)
	map.state.npc_memory.erase(inn.npc_id)
	dialogue.histories["LOC11"] = []
	dialogue._render_history()
	check(not dialogue.transcript.text.contains(str(inn.dark_line)), "A first visit has no dark line")
	check(Save.decode(Save.snapshot(map.state)).has("state"), "Memory of the new speakers saves")
	map.queue_free()
	await process_frame
	print("Voices checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
