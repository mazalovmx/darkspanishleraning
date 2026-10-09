extends FileDialog
## Native Godot file chooser, scoped to named checkpoints; autosave stays separate.
signal chosen(path: String, saving: bool)
const Log = preload("res://src/common/play_log.gd")
var saving := true
var directory := "user://saves"
var autosave_path := ""
var name_seed := ""
var automatic_name := Button.new()
var load_autosave := Button.new()
var help := Label.new()

func _ready() -> void:
	access = FileDialog.ACCESS_USERDATA
	display_mode = FileDialog.DISPLAY_LIST
	get_cancel_button().text = "Cancelar"
	filters = PackedStringArray(["*.save.json ; Partidas guardadas"])
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 16
	min_size = Vector2i(680, 440)
	get_vbox().add_child(help)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	automatic_name.text = "Usar nombre automático"
	automatic_name.pressed.connect(func(): current_file = fresh_name())
	get_vbox().add_child(automatic_name)
	load_autosave.text = "Cargar autoguardado"
	load_autosave.pressed.connect(func():
		hide()
		chosen.emit(autosave_path, false))
	get_vbox().add_child(load_autosave)
	file_selected.connect(func(path: String):
		hide()
		chosen.emit(path, saving))
	canceled.connect(func(): Log.write("save_picker_cancelled", {"saving":saving}))

func open(world: RefCounted, autosave: String, folder: String, for_save: bool) -> void:
	saving = for_save
	directory = folder
	autosave_path = autosave
	DirAccess.make_dir_recursive_absolute(directory)
	root_subfolder = directory
	current_dir = directory
	file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	title = "Guardar partida" if saving else "Cargar partida"
	get_ok_button().text = "Guardar" if saving else "Cargar"
	automatic_name.visible = saving
	load_autosave.visible = not saving
	load_autosave.disabled = not FileAccess.file_exists(autosave_path)
	help.text = "Puedes conservar el nombre propuesto o escribir el tuyo. El autoguardado se mantiene aparte." if saving else "Elige una partida de la lista o carga el autoguardado."
	name_seed = "Dia_%03d_%s" % [world.day, str(world.party.active().definition.short_name).validate_filename()]
	current_file = fresh_name() if saving else ""
	Log.write("save_picker_open", {"saving":saving})
	popup_centered(Vector2i(780, 520))

func fresh_name() -> String:
	var stem := name_seed + "_" + Time.get_datetime_string_from_system().replace(":", "-")
	var filename := stem + ".save.json"
	var index := 2
	while FileAccess.file_exists(directory.path_join(filename)):
		filename = stem + "_%d.save.json" % index
		index += 1
	return filename

func accepts(path: String) -> bool:
	return path.get_base_dir().simplify_path() == directory.simplify_path() and path.ends_with(".save.json")
