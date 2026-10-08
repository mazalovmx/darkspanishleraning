extends RefCounted
const Curriculum = preload("res://src/spanish/curriculum.gd")
## Bounded authored practice; no free-language grading or truth from a battle.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/side_investigations.json"))
static var practice: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/side_practice.json"))
var quests: Dictionary = {}
var battles: Dictionary = {}
var artifacts: Dictionary = {}
var branches: Dictionary = {}
var records: Dictionary = {}
## Answered comparisons between concluded cases: link id -> {day, hero, answer}.
var comparisons: Dictionary = {}
## Words that name each case, for comparison answers.
const TOPICS := {"SB01": ["censo", "limosnas", "familias", "deudas", "raspado", "folio"], "SB02": ["reloj", "campana", "campanas", "horas", "hora"],
	"SB03": ["agua", "atlas", "plano", "canal", "sed", "leyenda"], "SB04": ["vecinos", "nombres", "identidad", "identidades", "desplazados"],
	"SB05": ["animales", "bestiario", "margen", "simbolos", "plagio", "lista"], "SB06": ["instrumento", "lente", "lentes", "optica", "luz"],
	"SB07": ["pesas", "balanza", "pesos", "puerto", "peso"], "SB08": ["sanos", "cifras", "hospital", "pacientes", "denominador"],
	"SB09": ["vara", "medida", "medidas", "gremio", "patron"], "SB10": ["correo", "cartas", "carta", "ausentes"],
	"SB11": ["aire", "ventilacion", "letania", "protocolo", "mina"], "SB12": ["grano", "glosario", "hambre", "reservas", "trigo"]}
## Words that compare or contrast (the connectors of the vocabulary practice).
const COMPARE := ["pero", "mientras", "en cambio", "sin embargo", "no obstante", "aunque", "a diferencia", "por el contrario",
	"tambien", "igual que", "como", "ambos", "ambas", "los dos", "las dos", "en los dos"]
const STAGES := ["access","inspect","puzzle","supported","independent","recall"]

func _init() -> void:
	for entry: Dictionary in catalog.quests:
		quests[entry.id] = entry
	for entry: Dictionary in catalog.battles:
		battles[entry.id] = entry
	for entry: Dictionary in catalog.artifacts:
		artifacts[entry.id] = entry
	for entry: Dictionary in catalog.branches:
		branches[entry.id] = entry

func stages(id: String) -> Array:
	return STAGES + (["choice"] if not quests[id].final_choice.is_empty() else [])

func complete(id: String, ledger: Dictionary) -> bool:
	return quests.has(id) and ledger.has(id) and ledger[id].progress.size() == stages(id).size()

func stage(id: String) -> String:
	var count: int = records.get(id,{}).get("progress",{}).size()
	return "complete" if count >= stages(id).size() else str(stages(id)[count])

func completed_day(id: String, ledger: Dictionary) -> int:
	return int(ledger[id].progress[stages(id).back()].day) if complete(id,ledger) else 0

func language_ready(world: RefCounted,id: String,day: int) -> bool:
	var node: Dictionary = quests[id]
	var grammar: Array = [node.language.new_target]
	if int(node.language.block) == 6:
		grammar.append("ir_a_future")
	return world.campaign.language_ready(world,{"min_block":int(node.language.block)-1,"grammar":grammar},day)

func prerequisites(id: String,ledger: Dictionary,day: int) -> bool:
	for required: String in quests[id].requires:
		var completed := completed_day(required,ledger)
		if completed < 1 or completed > day:
			return false
	return true

func reason(world: RefCounted,id: String) -> String:
	if not quests.has(id) or world.map_id != "province_160x120_v1":
		return "Este expediente pertenece a la provincia."
	if world.planning_active() or world.active_battle != null or not world.trade.pending.is_empty() or not world.economy.pending.is_empty():
		return "Resuelve las órdenes preparadas o termina la acción actual."
	if world.location_at(world.hero_cell).get("id","") != quests[id].location_id:
		return "Visita el lugar de la investigación."
	if not prerequisites(id,records,world.day):
		return "Resuelve primero los expedientes que aportan las pruebas necesarias."
	if not language_ready(world,id,world.day):
		return "Consolida los bloques anteriores y practica las formas de este expediente."
	var knight: String = world.ghosts.blocked(world,id)
	if not knight.is_empty():
		return "Una intervención impide este paso. Abre «Caballeros y pruebas» para refutarla en español, o espera a que termine."
	if stage(id) == "complete":
		return "El expediente ya está resuelto."
	return ""

func available(world: RefCounted) -> Array:
	var result := []
	for id: String in quests:
		if prerequisites(id,records,world.day):
			result.append(id)
	return result

func models(id: String) -> Dictionary:
	var index: int = (int(id.trim_prefix("SX"))-1) % 9
	var name: String = artifacts[quests[id].artifact_id].name
	var card: Dictionary = practice[index]
	return {"access":"Quiero examinar la pieza «%s» con un testigo, por favor." % name,
		"supported":card.supported % name,"independent":card.independent[0] % name,
		"alternative":card.independent[1] % name,"recall":card.recall % name}

func choice_model(choice: String) -> String:
	return "Propondría publicar el expediente." if choice.ends_with("_public") else "Propondría proteger los datos personales."

func reward_item(world: RefCounted,id: String) -> String:
	for binding: Dictionary in world.equipment.catalog.reward_bindings:
		if binding.quest_id == id:
			return binding.item_id
	return ""

func encounter_definition(id: String) -> Dictionary:
	if not battles.has(id):
		return {}
	var definition: Dictionary = battles[id]
	var enemies: Array = []
	for stack: Dictionary in definition.enemy_stacks:
		enemies.append({"type":str(stack.unit),"count":int(stack.count)})
	return {"id":id,"name":definition.title,"location_id":definition.location_id,
		"requires":"","enemies":enemies,"reward":{}}

func can_battle(world: RefCounted,id: String) -> bool:
	return battles.has(id) and reason(world,battles[id].quest_id).is_empty() and stage(battles[id].quest_id) == "access" and world.encounters.get(id,{}).get("outcome","") != "victory"

const ACCESS_KEYS := [{"need":"una petición (quiero, necesito, pido…)","any":["quiero","necesito","pido","puedo","solicito","querria","me gustaria"]},
	{"need":"examinar, revisar o ver","any":["examinar","revisar","ver","inspeccionar","estudiar","consultar","mirar","comparar"]}]
const CHOICE_KEYS := {"public":{"need":"publicar el expediente","any":["publicar","publicaria","publicacion","publico","hacer publico"]},
	"private":{"need":"proteger los datos personales","any":["proteger","protegeria","proteccion","ocultar","ocultaria","reservar"]}}
const CONDITIONAL := {"need":"un condicional (propondría…)","match":" \\w+(ria|rias|riamos|rian) "}

func template(id: String) -> Dictionary:
	return practice[(int(id.trim_prefix("SX"))-1) % 9]

## Sentences the panel shows for this case; reproducing one whole is copying, not production.
func shown(id: String) -> Array:
	var node: Dictionary = quests[id]
	return [node.hook,node.investigation.observation,node.investigation.supported_interpretation,
		node.investigation.misleading_claim,node.language.model_frame,models(id).supported]

func _needs(keys: Array,text: String) -> Array[String]:
	var result: Array[String] = []
	for group: Dictionary in keys:
		var found := false
		if group.has("match"):
			found = RegEx.create_from_string(str(group.match)).search(text) != null
		else:
			found = group.any.any(func(form: String) -> bool: return text.contains(" %s " % form))
		if not found:
			result.append(str(group.need))
	return result

## What a free answer still lacks, by step. Authored model sentences always pass.
func missing(world: RefCounted,id: String,step: String,answer: String,choice := "") -> Array[String]:
	var course = world.learner.curriculum
	var phrases := models(id)
	var result: Array[String] = []
	var text: String = course.words(answer)
	match step:
		"access":
			if _same(world,answer,phrases.access):
				return result
			result = _needs(ACCESS_KEYS,text)
			var piece: String = course.words(artifacts[quests[id].artifact_id].name)
			if not text.contains(piece) and not [" pieza "," prueba "," objeto "].any(func(word: String) -> bool: return text.contains(word)):
				result.append("la pieza")
			return result
		"choice":
			if choice in quests[id].final_choice and _same(world,answer,choice_model(choice)):
				return result
			return _needs([CONDITIONAL,CHOICE_KEYS["public" if choice.ends_with("_public") else "private"]],text)
	var accepted: Array = [phrases.supported] if step == "supported" else [phrases.independent,phrases.alternative]
	if step == "recall":
		accepted = [phrases.recall,phrases.supported,phrases.independent,phrases.alternative]
	for phrase: String in accepted:
		if _same(world,answer,phrase):
			return result
	result = _needs(template(id).keys,text)
	if text.split(" ",false).size() < 4:
		result.append("una frase completa")
	# Relevance: one content word of five letters or more from this case.
	var node: Dictionary = quests[id]
	var case_words := {}
	for sentence: String in [node.hook,node.investigation.observation,node.investigation.supported_interpretation,node.language.prompt,artifacts[node.artifact_id].name]:
		for word in course.words(sentence).split(" ",false):
			if word.length() >= 5:
				case_words[word] = true
	if not Array(text.split(" ",false)).any(func(word: String) -> bool: return case_words.has(word)):
		result.append("algo concreto de este caso")
	if step == "independent":
		var copied := false
		for shown_text: String in shown(id):
			for sentence in RegEx.create_from_string("[.?!…;]").sub(shown_text,"|",true).split("|",false):
				var shown_words: String = course.words(sentence)
				copied = copied or (shown_words.split(" ",false).size() >= 3 and text.contains(shown_words))
		if copied:
			result.append("tus propias palabras, no una frase ya mostrada")
	return result

func _same(world: RefCounted,a: String,b: String) -> bool:
	return world.learner.curriculum.normalized(a) == world.learner.curriculum.normalized(b)

func _valid(world: RefCounted,id: String,step: String,payload: Dictionary,ledger: Dictionary) -> bool:
	var node: Dictionary = quests[id]
	var day: int = int(payload.day)
	var proof: Dictionary = ledger.get(id,{}).get("progress",{})
	if step != "access" and (not payload.route.is_empty() or not payload.cipher.is_empty()):
		return false
	if step not in ["puzzle","choice"] and (not payload.choice.is_empty() or not payload.rejected.is_empty()):
		return false
	var phrases := models(id)
	match step:
		"access":
			if payload.route not in ["peaceful","battle"] or not missing(world,id,"access",payload.answer).is_empty():
				return false
			if node.has("access_puzzle"):
				if not _same(world,payload.cipher,node.access_puzzle.answer):
					return false
			elif not payload.cipher.is_empty():
				return false
			var encounter: Dictionary = battles[node.encounter_id]
			if payload.route == "battle":
				var victory: Dictionary = world.encounters.get(node.encounter_id,{})
				if victory.get("outcome","") != "victory" or int(victory.get("day",0)) > day:
					return false
			else:
				for artifact_id: String in encounter.peaceful_route.required_artifacts:
					var source: String = artifacts[artifact_id].found_in
					var inspection: Dictionary = ledger.get(source,{}).get("progress",{}).get("inspect",{})
					if inspection.is_empty() or int(inspection.day) > day:
						return false
		"inspect":
			return payload.answer.is_empty()
		"puzzle":
			return payload.answer.is_empty() and payload.choice == node.puzzle.answer_id and payload.rejected == node.puzzle.reject_id
		"supported","independent":
			return missing(world,id,step,payload.answer).is_empty()
		"recall":
			return day > int(proof.get("independent",{}).get("day",day)) and missing(world,id,step,payload.answer).is_empty()
		"choice":
			return payload.rejected.is_empty() and payload.choice in node.final_choice and missing(world,id,step,payload.answer,payload.choice).is_empty()
	return true

func submit(world: RefCounted,id: String,answer := "",choice := "",rejected := "",route := "",cipher := "") -> Dictionary:
	var denied := reason(world,id)
	if not denied.is_empty():
		return {"ok":false,"message":denied}
	if answer.length() > 300 or cipher.length() > 40:
		return {"ok":false,"message":"Revisa la extensión de la respuesta."}
	var step := stage(id)
	var payload := {"day":world.day,"hero":world.party.active_id,"answer":answer.strip_edges(),"choice":choice,"rejected":rejected,"route":route,"cipher":cipher.strip_edges()}
	if step in ["access","supported","independent","recall","choice"]:
		var gaps := missing(world,id,step,payload.answer,choice)
		if not gaps.is_empty():
			return {"ok":false,"message":"Tu frase necesita: " + "; ".join(gaps) + "."}
		if world.learner.curriculum.is_last_block(int(quests[id].language.block) - 1):
			var authored: Array = models(id).values() + [choice_model(choice),quests[id].language.model_frame,quests[id].language.prompt]
			var spelling: PackedStringArray = world.learner.curriculum.orthography_errors(payload.answer,authored)
			if not spelling.is_empty():
				return {"ok":false,"message":"En este nivel cuentan las tildes: " + ", ".join(spelling) + "."}
	if not _valid(world,id,step,payload,records):
		return {"ok":false,"message":"Revisa la prueba, la comparación y la forma de la frase. El recuerdo requiere un día posterior."}
	var final: bool = step == stages(id).back()
	var reward := reward_item(world,id)
	if final and not reward.is_empty() and not world.equipment.can_grant(reward,world.party.active_id):
		return {"ok":false,"message":"No hay espacio para recibir el componente. Conservas tu progreso."}
	if not records.has(id):
		records[id] = {"progress":{},"reward":""}
	records[id].progress[step] = payload
	if final and not reward.is_empty():
		records[id].reward = world.equipment.grant(reward,world.party.active_id)
	return {"ok":true,"completed":final,"message":"Expediente resuelto; la prueba permanece en el archivo." if final else "Paso registrado. La investigación continúa."}

## The authored outcome the player chose at a branch's final quest, or {}.
func outcome(branch: String) -> Dictionary:
	var final: String = branches[branch].final_quest
	if not complete(final, records):
		return {}
	var chosen: String = str(records[final].progress.choice.choice)
	for entry: Dictionary in branches[branch].get("outcomes", []):
		if entry.id == chosen:
			return entry
	return {}

## Flags of the chosen outcomes (publication or protected copy), for the dialogue context.
func outcome_flags() -> Dictionary:
	var flags := {}
	for branch: String in branches:
		var chosen := outcome(branch)
		if not chosen.is_empty():
			flags[str(chosen.flag)] = "confirmed"
	return flags

## Local consequences shown at a place: one line per concluded case located there.
func local_consequences(location_id: String) -> Array[String]:
	var lines: Array[String] = []
	for branch: String in branches:
		var chosen := outcome(branch)
		if not chosen.is_empty() and branches[branch].location_id == location_id:
			lines.append("%s · %s: %s" % [branches[branch].title, chosen.label, chosen.effect])
	return lines

## Branches with at least one concluded quest, in catalog order.
func started_branches() -> Array:
	return branches.keys().filter(func(branch: String) -> bool:
		return branches[branch].quest_ids.any(func(id: String) -> bool: return complete(id, records)))

## Notebook text for a branch: premise, the supported conclusion of every concluded
## quest, and the chosen outcome once the case is closed.
func case_summary(branch: String) -> String:
	var data: Dictionary = branches[branch]
	var lines: Array[String] = [str(data.title).to_upper(), str(data.premise), "", "CONCLUSIONES APOYADAS"]
	for id: String in data.quest_ids:
		if complete(id, records):
			lines.append("• %s: %s" % [quests[id].title, quests[id].rewards.journal_entry])
	var done: int = data.quest_ids.filter(func(id: String) -> bool: return complete(id, records)).size()
	lines.append("")
	var chosen := outcome(branch)
	if chosen.is_empty():
		lines.append("Expediente abierto: %d de %d pasos concluidos." % [done, data.quest_ids.size()])
	else:
		lines.append("RESOLUCIÓN: " + str(data.canonical_resolution))
		lines.append("DECISIÓN: %s. %s" % [chosen.label, chosen.effect])
	lines.append("Lo que está en juego: " + str(data.stakes))
	return "\n".join(lines)

## Optional comparisons between cases (cross-branch links) whose quests are concluded.
func open_links() -> Array:
	return catalog.cross_branch_links.filter(func(link: Dictionary) -> bool:
		return link.required_quests.all(func(id: String) -> bool: return complete(id, records)))

## What a comparison answer still lacks: a word for each case and a comparing word.
func comparison_missing(link: Dictionary, answer: String) -> Array[String]:
	var result: Array[String] = []
	var text := " " + " ".join(Curriculum.fold(answer.to_lower()).replace(",", " ").replace(".", " ").replace(";", " ").split(" ", false)) + " "
	if answer.length() > 300:
		result.append("una frase más breve")
		return result
	for branch: String in [link.from, link.to]:
		if not TOPICS[branch].any(func(word: String) -> bool: return text.contains(" %s " % word)):
			result.append("algo del caso «%s»" % branches[branch].title)
	if not COMPARE.any(func(word: String) -> bool: return text.contains(" %s " % word)):
		result.append("una palabra que compare o contraste (pero, en cambio, mientras, igual que…)")
	if text.split(" ", false).size() < 8:
		result.append("una frase completa (al menos ocho palabras)")
	return result

## Records the player's comparison of two concluded cases.
func answer_comparison(world: RefCounted, link_id: String, answer: String) -> Dictionary:
	var link: Dictionary = {}
	for entry: Dictionary in open_links():
		if entry.id == link_id:
			link = entry
	if link.is_empty():
		return {"ok": false, "message": "Esta comparación todavía no está abierta."}
	var gaps := comparison_missing(link, answer)
	if not gaps.is_empty():
		return {"ok": false, "message": "Tu comparación necesita: " + "; ".join(gaps) + "."}
	comparisons[link_id] = {"day": world.day, "hero": world.party.active_id, "answer": answer.strip_edges()}
	return {"ok": true, "message": "Comparación anotada en el cuaderno."}

func snapshot() -> Dictionary:
	var result := records.duplicate(true)
	if not comparisons.is_empty():
		result["comparisons"] = comparisons.duplicate(true)
	return result

## Saved comparisons checked against a case ledger: each link open (both quests
## concluded), dated after that, and its answer still meeting the keys. Null if invalid.
func valid_comparisons(saved: Dictionary, ledger: Dictionary, world: RefCounted) -> Variant:
	var validated := {}
	for link: Dictionary in catalog.cross_branch_links:
		if not saved.has(link.id):
			continue
		var entry: Variant = saved[link.id]
		var opened := 0
		for quest: String in link.required_quests:
			if not complete(quest, ledger):
				return null
			opened = maxi(opened, completed_day(quest, ledger))
		if not entry is Dictionary or entry.size() != 3 or not entry.get("answer") is String or not entry.get("hero") is String or not _integer(entry.get("day"), maxi(1, opened), world.day) or not comparison_missing(link, entry.answer).is_empty():
			return null
		validated[link.id] = {"day": int(entry.day), "hero": str(entry.hero), "answer": str(entry.answer)}
	return validated if validated.size() == saved.size() else null

func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant,world: RefCounted) -> bool:
	# Answered comparisons travel under their own key (absent from older saves).
	var saved_comparisons: Variant = {}
	if data is Dictionary and data.has("comparisons"):
		data = data.duplicate(true)
		saved_comparisons = data.comparisons
		data.erase("comparisons")
	if not saved_comparisons is Dictionary or saved_comparisons.size() > catalog.cross_branch_links.size():
		return false
	if not data is Dictionary or data.size() > quests.size() or (world.map_id != "province_160x120_v1" and not data.is_empty()):
		return false
	# Validate shape before following cross-case references.
	for id in data:
		if not quests.has(id) or not data[id] is Dictionary or data[id].size() != 2:
			return false
		if not data[id].get("progress") is Dictionary or not data[id].get("reward") is String:
			return false
		var proof: Dictionary = data[id].progress
		if proof.is_empty() or proof.size() > stages(id).size():
			return false
		var previous := 0
		for index in proof.size():
			var step: String = stages(id)[index]
			var payload: Variant = proof.get(step)
			if not payload is Dictionary or payload.size() != 7 or not _integer(payload.get("day"),1,world.day):
				return false
			if payload.day < previous or payload.get("hero") not in world.party.heroes:
				return false
			if not world.party.heroes[payload.hero].unlocked:
				return false
			for field in ["answer","choice","rejected","route","cipher"]:
				if not payload.get(field) is String or payload[field].length() > (40 if field == "cipher" else 300):
					return false
			previous = int(payload.day)
	var rewards := {}
	for id: String in data:
		var record: Dictionary = data[id]
		var first_day: int = int(record.progress.access.day)
		if not prerequisites(id,data,first_day):
			return false
		for step: String in record.progress:
			var payload: Dictionary = record.progress[step]
			if not language_ready(world,id,int(payload.day)) or not _valid(world,id,step,payload,data):
				return false
		var item := reward_item(world,id)
		if complete(id,data) and not item.is_empty():
			if record.reward.is_empty() or rewards.has(record.reward) or not world.equipment.instances.has(record.reward):
				return false
			if world.equipment.instances[record.reward].item != item:
				return false
			rewards[record.reward] = true
		elif not record.reward.is_empty():
			return false
	var validated: Variant = valid_comparisons(saved_comparisons, data, world)
	if validated == null:
		return false
	records = data.duplicate(true)
	comparisons = validated
	return true
