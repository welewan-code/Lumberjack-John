extends Node

const TRANSPORT_SAVE_PATH: String = "user://transport_state.json"
const TRANSPORT_AMOUNT_M3: float = 0.1
const TRANSPORT_WAGE: float = 5.0
const WHEELBARROW_TIME: float = 5.0
const UI_REFRESH_INTERVAL: float = 0.25

var transport_running: bool = false
var transport_elapsed: float = 0.0
var transport_button: Button = null
var ui_refresh_elapsed: float = 0.0
var saved_transport_tool: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_transport_state()

func _process(delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	_restore_saved_tool(main)
	_process_transport(main, delta)

	ui_refresh_elapsed += delta
	if ui_refresh_elapsed < UI_REFRESH_INTERVAL:
		return
	ui_refresh_elapsed = 0.0

	if str(main.get("current_tab")) == "FIRMA":
		_ensure_transport_slot(main)
	if not transport_running:
		_try_auto_start(main)

func get_selected_transport_tool(main: Node = null) -> String:
	if main != null:
		var state: Dictionary = _state(main)
		var state_tool: String = str(state.get("transport_tool", ""))
		if state_tool != "":
			return state_tool
	return saved_transport_tool

func _restore_saved_tool(main: Node) -> void:
	if saved_transport_tool == "":
		return
	var state: Dictionary = _state(main)
	if str(state.get("transport_tool", "")) == saved_transport_tool:
		return
	state["transport_tool"] = saved_transport_tool
	main.set("state", state)

func _ensure_transport_slot(main: Node) -> void:
	var scene: Control = _company_scene(main)
	if scene == null:
		return
	var existing: Node = scene.get_node_or_null("TransportSlot")
	if existing != null:
		if existing is Button:
			transport_button = existing as Button
			_refresh_transport_button(main)
		return

	var button: Button = Button.new()
	button.name = "TransportSlot"
	button.position = Vector2(360, 105)
	button.size = Vector2(180, 105)
	button.z_index = 8
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(main, "#171411cc", "#9b7447", 10, 2))
	button.add_theme_stylebox_override("hover", _style(main, "#241c15e8", "#d09b57", 10, 2))
	button.pressed.connect(_show_transport_panel)
	scene.add_child(button)
	transport_button = button
	_refresh_transport_button(main)

func _refresh_transport_button(main: Node) -> void:
	if not is_instance_valid(transport_button) or transport_running:
		return
	var state: Dictionary = _state(main)
	var tool: String = get_selected_transport_tool(main)
	if tool == "wheelbarrow" and _owned_transport("wheelbarrow") > 0:
		var has_contract: bool = _contract_bool("has_active_contract")
		if has_contract:
			if float(state.get("split_m3", 0.0)) + 0.0001 < TRANSPORT_AMOUNT_M3:
				transport_button.text = "KOLEČKO\nČEKÁ NA DŘEVO\n0,1 m³ / odvoz"
			elif float(state.get("money", 0.0)) < TRANSPORT_WAGE:
				transport_button.text = "KOLEČKO\nČEKÁ NA 5 Kč\nZA ODVOZ"
			else:
				transport_button.text = "KOLEČKO\nAUTOMATICKÝ ODVOZ\n0,1 m³ • 5 s"
		else:
			transport_button.text = "KOLEČKO\nČEKÁ NA ZAKÁZKU\n0,1 m³ • 5 s"
		if transport_button.icon == null:
			var asset_path: String = "res://assets/tools/wheelbarrow.png"
			if ResourceLoader.exists(asset_path):
				var resource: Resource = ResourceLoader.load(asset_path)
				if resource is Texture2D:
					transport_button.icon = resource as Texture2D
					transport_button.expand_icon = true
	else:
		transport_button.icon = null
		transport_button.text = "+\nDOPRAVA\nVYBRAT PROSTŘEDEK"

func _show_transport_panel() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Doprava – nastavení"
	dialog.ok_button_text = "ZAVŘÍT"
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 190)
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)
	box.add_child(_label(main, "DOPRAVNÍ PROSTŘEDEK", 15))

	var tools: OptionButton = OptionButton.new()
	tools.custom_minimum_size.y = 40
	tools.add_item("Bez prostředku")
	tools.set_item_metadata(tools.item_count - 1, "")
	if _owned_transport("wheelbarrow") > 0:
		tools.add_item("Kolečko – 0,1 m³ / 5 s")
		tools.set_item_metadata(tools.item_count - 1, "wheelbarrow")
	else:
		box.add_child(_label(main, "Kolečko nejdřív kup v obchodě.", 13))
	_select_tool(tools, get_selected_transport_tool(main))
	tools.item_selected.connect(_on_transport_selected.bind(tools, dialog))
	box.add_child(tools)
	box.add_child(_label(main, "Po přijetí zakázky vozí samo. Každý odvoz stojí 5 Kč.", 13))
	main.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 250))

func _on_transport_selected(index: int, tools: OptionButton, dialog: AcceptDialog) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	saved_transport_tool = str(tools.get_item_metadata(index))
	state["transport_tool"] = saved_transport_tool
	main.set("state", state)
	_save_transport_state()
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	_remove_slot(main)

func _try_auto_start(main: Node) -> void:
	var state: Dictionary = _state(main)
	if get_selected_transport_tool(main) != "wheelbarrow":
		return
	if _owned_transport("wheelbarrow") <= 0:
		return
	if not _contract_bool("can_accept_delivery", [TRANSPORT_AMOUNT_M3]):
		return
	if float(state.get("split_m3", 0.0)) + 0.0001 < TRANSPORT_AMOUNT_M3:
		return
	if float(state.get("money", 0.0)) < TRANSPORT_WAGE:
		return
	transport_running = true
	transport_elapsed = 0.0
	if is_instance_valid(transport_button):
		transport_button.disabled = true

func _process_transport(main: Node, delta: float) -> void:
	if not transport_running:
		return
	transport_elapsed += delta
	if is_instance_valid(transport_button):
		transport_button.text = "ODVÁŽÍM NA ZAKÁZKU...\n%.1f s" % maxf(0.0, WHEELBARROW_TIME - transport_elapsed)
	if transport_elapsed < WHEELBARROW_TIME:
		return

	transport_running = false
	transport_elapsed = 0.0
	var state: Dictionary = _state(main)
	var can_deliver: bool = _contract_bool("can_accept_delivery", [TRANSPORT_AMOUNT_M3])
	if can_deliver and float(state.get("split_m3", 0.0)) + 0.0001 >= TRANSPORT_AMOUNT_M3 and float(state.get("money", 0.0)) >= TRANSPORT_WAGE:
		state["split_m3"] = maxf(0.0, float(state.get("split_m3", 0.0)) - TRANSPORT_AMOUNT_M3)
		state["money"] = float(state.get("money", 0.0)) - TRANSPORT_WAGE
		main.set("state", state)
		var result: Dictionary = _register_delivery(main, TRANSPORT_AMOUNT_M3)
		if main.has_method("update_hud"):
			main.call("update_hud")
		if main.has_method("save_game"):
			main.call("save_game")
		if bool(result.get("completed", false)):
			_set_button_message("ZAKÁZKA HOTOVÁ\n+%.0f Kč" % float(result.get("payout", 0.0)))
		else:
			_set_button_message("ODVEZENO 0,1 m³\nPOKRAČUJU AUTOMATICKY")
	else:
		_set_button_message("ODVOZ ČEKÁ")
	if is_instance_valid(transport_button):
		transport_button.disabled = false

func _contract_bool(method_name: String, args: Array = []) -> bool:
	var contracts: Node = get_node_or_null("/root/ContractManager")
	if contracts == null or not contracts.has_method(method_name):
		return false
	var value: Variant
	if args.is_empty():
		value = contracts.call(method_name)
	else:
		value = contracts.callv(method_name, args)
	if value is bool:
		return value as bool
	return false

func _register_delivery(main: Node, amount: float) -> Dictionary:
	var contracts: Node = get_node_or_null("/root/ContractManager")
	if contracts == null or not contracts.has_method("register_delivery"):
		return {"ok": false, "completed": false, "payout": 0.0}
	var value: Variant = contracts.call("register_delivery", main, amount)
	if value is Dictionary:
		return value as Dictionary
	return {"ok": false, "completed": false, "payout": 0.0}

func _set_button_message(value: String) -> void:
	if is_instance_valid(transport_button):
		transport_button.text = value

func _remove_slot(main: Node) -> void:
	var scene: Control = _company_scene(main)
	if scene == null:
		return
	var existing: Node = scene.get_node_or_null("TransportSlot")
	if existing != null:
		existing.queue_free()
	transport_button = null

func _company_scene(main: Node) -> Control:
	var host_value: Variant = main.get("content_host")
	if not (host_value is MarginContainer):
		return null
	var host: MarginContainer = host_value as MarginContainer
	if host.get_child_count() == 0:
		return null
	var row: Node = host.get_child(0)
	if not (row is HBoxContainer) or row.get_child_count() < 2:
		return null
	var center: Node = row.get_child(1)
	if not (center is PanelContainer) or center.get_child_count() == 0:
		return null
	var scene: Node = center.get_child(0)
	if scene is Control:
		return scene as Control
	return null

func _select_tool(tools: OptionButton, tool_id: String) -> void:
	for index: int in range(tools.item_count):
		if str(tools.get_item_metadata(index)) == tool_id:
			tools.select(index)
			return
	tools.select(0)

func _owned_transport(item_id: String) -> int:
	var shop: Node = get_node_or_null("/root/ShopUI")
	if shop == null:
		return 0
	var value: Variant = shop.get("inventory")
	if value is Dictionary:
		return int((value as Dictionary).get(item_id, 0))
	return 0

func _state(main: Node) -> Dictionary:
	var value: Variant = main.get("state")
	if value is Dictionary:
		return value as Dictionary
	return {}

func _save_transport_state() -> void:
	var file: FileAccess = FileAccess.open(TRANSPORT_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"transport_tool": saved_transport_tool}))

func _load_transport_state() -> void:
	if not FileAccess.file_exists(TRANSPORT_SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(TRANSPORT_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		saved_transport_tool = str((parsed as Dictionary).get("transport_tool", ""))

func _label(main: Node, text_value: String, size: int) -> Label:
	var value: Variant = main.call("make_label", text_value, size)
	if value is Label:
		return value as Label
	var label: Label = Label.new()
	label.text = text_value
	return label

func _style(main: Node, bg: String, border: String, radius: int, width: int) -> StyleBoxFlat:
	var value: Variant = main.call("panel_style", bg, border, radius, width)
	if value is StyleBoxFlat:
		return value as StyleBoxFlat
	return StyleBoxFlat.new()
