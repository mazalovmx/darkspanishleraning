extends SceneTree
const Grammar = preload("res://src/spanish/grammar_checks.gd")
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
func run() -> void:
	for sentence in ["Yo tiene dos panes.", "Nosotros quiero comprar pan.", "Usted tienes una prueba.",
		"Una cuaderno contiene pruebas.", "La documento cambia la situación legal.",
		"Dos pan cuestan cuatro monedas.", "Quiero compro dos panes.", "Yo no lo tienes."]:
		check(not Grammar.missing(sentence).is_empty(), "Reject known agreement/verb error: " + sentence)
	for sentence in ["Quiero comprar dos panes, por favor.", "Yo tengo una prueba.", "Ustedes tienen razón.",
		"El documento cambia la situación legal.", "Las hipótesis son distintas.", "El agua está limpia.",
		"El cura tiene una cura.", "Los recuerdo.", "La firma.", "El archivo contiene pruebas.",
		"La documento hoy.", "Tu compra cuesta dos monedas.", "Yo sé lo que dice.", "Quiero que usted compre pan.",
		"El testigo escribió «yo tiene», pero yo tengo otra versión.", "Yo, según el testigo, tengo razón.",
		"Yo puedo comprar pan.", "Usted quiere examinar la pieza."]:
		check(Grammar.missing(sentence).is_empty(), "Accept legitimate construction: " + sentence)
	check(Grammar.missing("Yo tiene una cuaderno y dos pan.").size() == 2, "Feedback capped at two errors")
	var world := World.new("province_160x120_v1")
	# Authored content is the compatibility corpus, including more advanced clauses.
	for node: Dictionary in world.campaign.definitions.values():
		for answer: String in node.answers + node.get("variants", []):
			check(Grammar.missing(answer).is_empty(), "Authored campaign Spanish: " + answer)
	var trade = world.trade
	var malformed := "Yo quiere comprar 2 panes."
	check(not trade.missing("bread", 2, malformed, "request").is_empty(), "Market refuses malformed free request")
	# Use a sentence the previous content-key check accepted, to prove migration compatibility.
	malformed = "Yo tiene hambre y quiero comprar 2 panes."
	check(trade.missing("bread", 2, malformed, "request", "basic", false).is_empty(), "Old receipt validation remains lenient")
	check(not trade.missing("bread", 2, malformed, "request").is_empty(), "New requests check the extra malformed clause")
	var card: Dictionary = world.campaign.definitions.sealed_order
	var answer := "La documento cambia la situación legal de los cuadernos."
	check(world.campaign.missing(world, card, answer, false).is_empty(), "Old campaign answer keeps its accepted proof")
	check(not world.campaign.missing(world, card, answer).is_empty(), "New campaign conclusion catches article agreement")
	var shop := World.new()
	check(shop.move_to(Vector2i(6, 11), true), "Reach shop for real transaction checks")
	var before: Dictionary = shop.trade.snapshot()
	var gold: int = shop.resources.gold
	check(not shop.trade.submit(shop, "bread", 2, malformed).ok, "Malformed request cannot start an order")
	check(shop.trade.pending.is_empty() and shop.trade.snapshot() == before and shop.resources.gold == gold, "Rejected request leaves stock, money and inventory untouched")
	check(shop.trade.submit(shop, "bread", 2, "Quiero comprar dos panes, por favor.").ok, "Corrected request starts the order")
	check(shop.trade.submit(shop, "bread", 2, "Son cuatro monedas.").ok, "Price understood")
	check(not shop.trade.submit(shop, "bread", 2, "Yo tiene hambre y confirmo la compra de dos panes por cuatro monedas.").ok, "Malformed confirmation cannot commit")
	check(shop.trade.phase == "confirm" and shop.trade.snapshot() == before and shop.resources.gold == gold, "Rejected confirmation retains order without spending")
	check(shop.trade.submit(shop, "bread", 2, "Confirmo la compra de dos panes por cuatro monedas.").get("committed", false), "Corrected confirmation completes the same order")
	var saved: Dictionary = shop.trade.snapshot()
	saved.receipts[0].request = malformed
	var restored = load("res://src/economy/trade_state.gd").new()
	check(restored.restore(saved, shop.day), "Actual older receipt with now-rejected grammar still restores")
	print("Grammar checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
