extends Node

const EXPORT_PATH: String = "user://lumberjack_save_export.json"
const PRE_IMPORT_BACKUP_PATH: String = "user://lumberjack_save_before_import.json"
const FORMAT_NAME: String = "lumberjack-john-save"
const SCHEMA_VERSION: int = 1
const SAVE_FILES: Dictionary = {
	"drevo_tycoon_save.json": "user://drevo_tycoon_save.json",
	"shop_inventory.json": "user://shop_inventory.json",
	"neighbor_contracts.json": "user://neighbor_contracts.json",
	"transport_state.json": "user://transport_state.json",
	"drevo_tycoon_offline.json": "user://drevo_tycoon_offline.json"
}

var last_tab: String = ""
var status_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "NASTAVENÍ" and last_tab != "NASTAVENÍ":
		call_deferred("_render_settings", main)
	last_tab = tab

func _render_settings(main: Node) -> void:
	var host_value: Variant = main.get("content_host")
	if not (host_value is MarginContainer):
		return
	var host: MarginContainer = host_value as MarginContainer
	for child: Node in host.get_children():
		child.queue_free()
	await get_tree().process_frame
	if not is_instance_valid(host) or str(main.get("current_tab")) != "NASTAVENÍ":
		return

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if main.has_method("panel_style"):
		var style_value: Variant = main.call("panel_style", "#1b1713", "#6b4628", 7, 1)
		if style_value is StyleBoxFlat:
			panel.add_theme_stylebox_override("panel", style_value as StyleBoxFlat)
	host.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	var title: Label = _label(main, "NASTAVENÍ", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)

	var mobile_info: Label = _label(main, "Mobilní režim: landscape • responzivní 16:9 základ", 15)
	mobile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(mobile_info)

	var save_title: Label = _label(main, "ZÁLOHA A PŘENOS SAVE", 20)
	save_title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(save_title)

	var help: Label = _label(main, "EXPORT uloží kompletní save balíček a zkopíruje ho do schránky. Pošli si text do druhého zařízení, zkopíruj ho tam a použij IMPORT. Import data nejdřív zkontroluje a před přepsáním vytvoří lokální zálohu.", 14)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.y = 70
	box.add_child(help)

	var export_button: Button = Button.new()
	export_button.text = "EXPORT SAVE • KOPÍROVAT DO SCHRÁNKY"
	export_button.custom_minimum_size.y = 58
	export_button.pressed.connect(_on_export_pressed)
	box.add_child(export_button)

	var import_button: Button = Button.new()
	import_button.text = "IMPORT SAVE ZE SCHRÁNKY"
	import_button.custom_minimum_size.y = 58
	import_button.pressed.connect(_on_import_pressed)
	box.add_child(import_button)

	status_label = _label(main, "", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 52
	box.add_child(status_label)

func _on_export_pressed() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		_set_status("Export se nepodařil: hra není načtená.", true)
		return
	var bundle: Dictionary = _collect_bundle(main)
	if bundle.is_empty():
		_set_status("Export se nepodařil: save data nejsou platná.", true)
		return
	var text: String = JSON.stringify(bundle)
	var file: FileAccess = FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if file == null:
		_set_status("Export se nepodařil: nelze vytvořit záložní soubor.", true)
		return
	file.store_string(text)
	DisplayServer.clipboard_set(text)
	_set_status("Save je zazálohovaný a zkopírovaný do schránky. Teď ho můžeš poslat do PC nebo mobilu.", false)

func _on_import_pressed() -> void:
	var text: String = DisplayServer.clipboard_get().strip_edges()
	if text == "":
		_set_status("Ve schránce není žádný save text.", true)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_set_status("Import odmítnut: schránka neobsahuje platný JSON save.", true)
		return
	var bundle: Dictionary = parsed as Dictionary
	var validation_error: String = _validate_bundle(bundle)
	if validation_error != "":
		_set_status("Import odmítnut: %s" % validation_error, true)
		return

	var current_bundle: Dictionary = _collect_bundle(get_tree().current_scene)
	if not current_bundle.is_empty():
		var backup: FileAccess = FileAccess.open(PRE_IMPORT_BACKUP_PATH, FileAccess.WRITE)
		if backup != null:
			backup.store_string(JSON.stringify(current_bundle))

	var files: Dictionary = bundle.get("files", {}) as Dictionary
	for file_name_value: Variant in files.keys():
		var file_name: String = str(file_name_value)
		var target_path: String = str(SAVE_FILES.get(file_name, ""))
		if target_path == "":
			continue
		var out_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
		if out_file == null:
			_set_status("Import selhal při zápisu %s. Původní save je uložený v předimportní záloze." % file_name, true)
			return
		out_file.store_string(JSON.stringify(files[file_name_value]))

	_set_status("Import hotov. Úplně zavři hru a znovu ji spusť, aby se načetly všechny části save.", false)

func _collect_bundle(main: Node) -> Dictionary:
	if main == null:
		return {}
	if main.has_method("save_game"):
		main.call("save_game")
	var shop: Node = get_node_or_null("/root/ShopUI")
	if shop != null and shop.has_method("save_inventory"):
		shop.call("save_inventory")

	var files: Dictionary = {}
	for file_name_value: Variant in SAVE_FILES.keys():
		var file_name: String = str(file_name_value)
		var path: String = str(SAVE_FILES[file_name_value])
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			return {}
		files[file_name] = parsed

	if not files.has("drevo_tycoon_save.json"):
		return {}
	return {
		"format": FORMAT_NAME,
		"schema": SCHEMA_VERSION,
		"created_at": int(Time.get_unix_time_from_system()),
		"files": files
	}

func _validate_bundle(bundle: Dictionary) -> String:
	if str(bundle.get("format", "")) != FORMAT_NAME:
		return "neznámý formát"
	if int(bundle.get("schema", -1)) != SCHEMA_VERSION:
		return "nepodporovaná verze save balíčku"
	var files_value: Variant = bundle.get("files", null)
	if not (files_value is Dictionary):
		return "chybí seznam save souborů"
	var files: Dictionary = files_value as Dictionary
	if not files.has("drevo_tycoon_save.json"):
		return "chybí hlavní save"

	for file_name_value: Variant in files.keys():
		var file_name: String = str(file_name_value)
		if not SAVE_FILES.has(file_name):
			return "obsahuje nepovolený soubor %s" % file_name
		if not (files[file_name_value] is Dictionary):
			return "%s nemá platnou strukturu" % file_name

	var main_save: Dictionary = files["drevo_tycoon_save.json"] as Dictionary
	for numeric_key: String in ["money", "xp", "level", "logs_m3", "roundwood_m3", "split_m3"]:
		if not main_save.has(numeric_key) or not _is_number(main_save[numeric_key]):
			return "hlavní save má neplatné pole %s" % numeric_key
	if main_save.has("work_slots"):
		var slots_value: Variant = main_save["work_slots"]
		if not (slots_value is Array):
			return "work_slots není seznam"
		var slots: Array = slots_value as Array
		if slots.size() > 3:
			return "work_slots obsahuje příliš mnoho slotů"
		for slot_value: Variant in slots:
			if not (slot_value is Dictionary):
				return "některý pracovní slot není platný"

	if files.has("shop_inventory.json"):
		var inventory: Dictionary = files["shop_inventory.json"] as Dictionary
		for value: Variant in inventory.values():
			if not _is_number(value) or int(value) < 0:
				return "inventář nástrojů obsahuje neplatný počet"

	return ""

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _set_status(message: String, is_error: bool) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#ff7676") if is_error else Color("#9dd67a"))

func _label(main: Node, text_value: String, size: int) -> Label:
	if main != null and main.has_method("make_label"):
		var value: Variant = main.call("make_label", text_value, size)
		if value is Label:
			return value as Label
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	return label
