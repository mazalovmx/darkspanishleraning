extends SceneTree
## Survival dialogues of master spec 30: every exchange can be typed offline with the
## authored replies, short exchanges follow the previous line, and a finished exchange
## is remembered, saved and listed on the progress tab.
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

## Types each line at the inn and returns the replies.
func talk(dialogue, lines: Array) -> Array:
	var replies: Array = []
	for line: String in lines:
		dialogue.submit(line)
		replies.append(str(dialogue.histories.LOC11.back().reply))
	return replies

## The same exchange outside the map: offline branches chained through the history.
func script(dialogue, id: String, lines: Array) -> Array:
	dialogue.histories[id] = []
	var replies: Array = []
	for line: String in lines:
		var branch: Dictionary = dialogue.branch_for(id, line)
		replies.append(str(branch.get("reply", dialogue.conversations[id].fallback)))
		dialogue.histories[id].append({"player": line, "reply": replies.back(), "branch": str(branch.get("id", "")), "survival": str(branch.get("survival", ""))})
	return replies

func run() -> void:
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.selected = true
	check(map.state.move_to(Vector2i(6, 11), true), "Reach the inn")
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	await process_frame
	var dialogue = map.dialogue
	dialogue.client.config.dev_flags.offline_mode = true
	var state = map.state
	check(state.survival_done().is_empty(), "Nothing practised yet")
	check(talk(dialogue, ["Buenas tardes. ¿Tiene pan?", "Deme dos, por favor."]) == ["Sí. Dos monedas.", "Aquí tiene: dos panes, cuatro monedas. Se los cobro en el mostrador."], "Food: price, then the total for the amount asked")
	check(talk(dialogue, ["¿Hay agua potable?"]) == ["Sí, detrás del establo."], "Water")
	var inn: Array = talk(dialogue, ["Necesito una habitación para esta noche.", "¿Incluye comida?"])
	check(inn[0] == "Cinco monedas." and inn[1].begins_with("Incluye la cena"), "Inn: price, then what the room includes")
	check(talk(dialogue, ["¿Cómo llego al monasterio?"])[0].contains("gire a la izquierda en el cruce"), "Directions")
	check(talk(dialogue, ["¿Es seguro el camino del norte?"])[0].begins_with("Seguro, no. Abierto, sí."), "Road safety")
	var stable: Array = talk(dialogue, ["Necesito comida para el caballo.", "Para dos días."])
	check(stable[0] == "¿Cuánto quiere?" and stable[1].begins_with("Para dos días, dos raciones de pienso: seis monedas."), "Stable: amount, then days and price")
	var complaint: Array = talk(dialogue, ["Pedí aceite, no vino.", "No. Le pedí aceite para la lámpara."])
	check(complaint[0] == "Eso fue lo que me pidió." and complaint[1].contains("me equivoqué"), "Complaint: denial, then the innkeeper admits the mistake")
	# A follow-up line means nothing without the line it follows.
	check(not dialogue.reply_for("LOC11", "Para dos días.").contains("raciones"), "Amount of days alone is not a stable order")
	check(dialogue.reply_for("LOC11", "¿Incluye comida?") == dialogue.conversations.LOC11.fallback, "A room question alone gets the fallback")
	check(not talk(dialogue, ["¿Tiene pan?", "¿Hay agua potable?", "Tres."])[2].contains("panes"), "Another topic breaks the exchange")
	var done: Array = state.survival_done()
	check(done.size() == 7 and "permission" not in done and "medicine" not in done, "Seven exchanges carried through at the inn")
	var topics: Array = state.npc_memory.innkeeper_prototype.topics
	check("survival:food" in topics and "survival:complaint" in topics and int(state.npc_memory.innkeeper_prototype.count) == 14, "Exchanges kept as topics; each line counts once as a talk")
	# Medicine at the hospital and permission at the archive.
	var medicine: Array = script(dialogue, "LOC15", ["Necesito vendas.", "Tres. ¿Cuánto cuestan?"])
	check(medicine == ["¿Cuántas?", "Cinco monedas cada una: tres vendas, quince monedas. Se las doy en el mostrador del hospital."], "Medicine: how many, then the price")
	check(dialogue.histories.LOC15.back().survival == "medicine", "Medicine exchange finished on the second line")
	check(script(dialogue, "LOC15", ["Necesito vendas.", "¿Cuánto cuestan?", "Una."])[2].contains("una venda, cinco monedas"), "A price question keeps the exchange open")
	check(script(dialogue, "LOC15", ["¿Cómo llego al monasterio?"])[0].contains("Después del puente"), "Directions from Miralba cross the bridge")
	var permission: Array = script(dialogue, "LOC14_CUESTA", ["Necesito entrar.", "Tengo una orden del tribunal."])
	check(permission[0].begins_with("No puede pasar.") and permission[1].begins_with("Déjeme verla."), "Permission: refusal, then the order is checked")
	check(dialogue.histories.LOC14_CUESTA.back().survival == "permission", "Permission exchange finished on the order")
	check(not script(dialogue, "LOC14_CUESTA", ["Tengo una orden del tribunal."])[0].begins_with("Déjeme verla"), "The order without asking to enter is just the order")
	check(dialogue.grounding.intent_for("Necesito entrar.") == "ask_permission", "Asking to enter is the topic the sealed order card needs")
	# Each exchange of section 30 is marked by exactly one finishing branch kind.
	var kinds := {}
	for id: String in dialogue.conversations:
		for branch: Dictionary in dialogue.conversations[id].branches:
			if branch.has("survival"):
				check(state.SURVIVAL.has(branch.survival), "Known survival exchange: " + str(branch.survival))
				kinds[branch.survival] = true
			if branch.has("follows"):
				var led := false
				for other: Dictionary in dialogue.conversations[id].branches:
					led = led or other.get("id", "") == branch.follows
				check(led, "A follow-up has the line it follows: " + id)
	check(kinds.size() == state.SURVIVAL.size(), "All nine exchanges of section 30 exist")
	map._close_poi()
	map.queue_free()
	await process_frame
	# Saved with the conversation memory; unknown survival topics are refused.
	var world := World.new("province_160x120_v1")
	world.remember("leonor_valera", "unknown", 1)
	world.note_survival("leonor_valera", "medicine")
	world.note_survival("leonor_valera", "invented")
	world.note_survival("simon_vale", "water")
	check(world.npc_memory.leonor_valera.topics == ["survival:medicine"] and not world.npc_memory.has("simon_vale"), "Only known exchanges with characters already met")
	var loaded: Dictionary = Save.decode(Save.snapshot(world))
	check(loaded.has("state") and loaded.state.survival_done() == ["medicine"], "Survival exchanges survive a save")
	var forged: Dictionary = Save.snapshot(world)
	forged.npc_memory.leonor_valera.topics = ["survival:invented"]
	check(Save.decode(forged).has("error"), "An invented survival topic is refused")
	var panel = load("res://src/spanish/curriculum_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open_course(world)
	panel.progress_tab.pressed.emit()
	check(panel.report.text.contains("DIÁLOGOS DE SUPERVIVENCIA: 1 de 9") and panel.report.text.contains("✓ Medicina"), "Progress lists finished exchanges")
	check(panel.report.text.contains("· Permiso: «Necesito entrar.» · con Fermín Cuesta"), "Progress says where to practise the rest")
	panel.queue_free()
	await process_frame
	print("Survival dialogue checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
