extends Control
## Title screen: continue, new game, settings and quit (master spec, release readiness).
const Settings = preload("res://src/common/settings.gd")
const ParchmentTheme = preload("res://src/common/parchment_theme.gd")
const MAP_SCENE := "res://src/world/province_map.tscn"
var save_path := "user://province_savegame.json"
var settings_path := Settings.PATH
var continue_button := Button.new()
var new_button := Button.new()
var settings_button := Button.new()
var quit_button := Button.new()
var confirm := ConfirmationDialog.new()
var settings_panel := PanelContainer.new()
var music_toggle := CheckBox.new()
var music_slider := HSlider.new()
var sfx_toggle := CheckBox.new()
var sfx_slider := HSlider.new()
var config: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/game.json"))
	config = parsed if parsed is Dictionary else {}
	# Same font as the map's panels, and the parchment page of the journal.
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 20
	var background := ColorRect.new()
	background.color = Color("#17191d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(520, 0)
	ParchmentTheme.apply(page)
	center.add_child(page)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	page.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "EL ÍNDICE DE CENIZA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Una investigación en español\nInterfaz 2026.10.09 · edificios y partidas"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	for pair in [[continue_button, "Continuar"], [new_button, "Nueva partida"], [settings_button, "Ajustes"], [quit_button, "Salir"]]:
		pair[0].text = pair[1]
		pair[0].add_theme_font_size_override("font_size", 22)
		box.add_child(pair[0])
	continue_button.visible = FileAccess.file_exists(save_path)
	continue_button.pressed.connect(func(): get_tree().change_scene_to_file(MAP_SCENE))
	new_button.pressed.connect(func():
		if FileAccess.file_exists(save_path):
			confirm.popup_centered()
		else:
			start_new())
	settings_button.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)
	quit_button.pressed.connect(func(): get_tree().quit())
	add_child(confirm)
	confirm.title = "Nueva partida"
	confirm.dialog_text = "¿Empezar desde el principio? La partida guardada se reemplaza; se conserva una copia anterior."
	confirm.ok_button_text = "Sí"
	confirm.cancel_button_text = "No"
	confirm.confirmed.connect(start_new)
	_build_settings(box)

func start_new() -> void:
	# The map starts a new game (keeping a .bak of the old save) once it has loaded.
	Engine.set_meta("start_new_game", true)
	get_tree().change_scene_to_file(MAP_SCENE)

func _build_settings(box: VBoxContainer) -> void:
	box.add_child(settings_panel)
	settings_panel.hide()
	var rows := VBoxContainer.new()
	settings_panel.add_child(rows)
	var audio := Settings.audio(config, settings_path)
	for row in [[music_toggle, music_slider, "Música", "music"], [sfx_toggle, sfx_slider, "Sonidos", "sfx"]]:
		row[0].text = row[2]
		row[0].button_pressed = bool(audio.get(row[3], true))
		row[1].min_value = -40.0
		row[1].max_value = 0.0
		row[1].step = 1.0
		row[1].value = float(audio.get(row[3] + "_db", -12.0))
		row[1].custom_minimum_size = Vector2(240, 0)
		row[1].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_child(row[0])
		line.add_child(row[1])
		rows.add_child(line)
		row[0].toggled.connect(func(_on: bool): save())
		row[1].value_changed.connect(func(_v: float): save())

func save() -> bool:
	Settings.apply_effects({"sfx": sfx_toggle.button_pressed, "sfx_db": sfx_slider.value})
	return Settings.save_audio({"music": music_toggle.button_pressed, "music_db": music_slider.value,
		"sfx": sfx_toggle.button_pressed, "sfx_db": sfx_slider.value}, settings_path)
