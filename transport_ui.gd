extends Node

const TRANSPORT_AMOUNT_M3: float = 0.1
const TRANSPORT_WAGE: float = 5.0
const WHEELBARROW_TIME: float = 5.0

var transport_running: bool = false
var transport_elapsed: float = 0.0
var transport_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	if str(main.get("current_tab")) == "FIRMA":
		_ensure_transport_slot(main)
	_process_transport(main, delta)

func _ensure_transport_slot(main: Node) -> void:
	var scene: Control = _company_scene(main)
	if scene == null:
		return
	var existing: Node = scene.get_node_or_null("TransportSlot")
	if existing != null:
		if existing is Button:
			transport_button = existing as Button
		return

	var state: Dictionary = _state(main)
	var tool: String = str(state.get("transport_tool", ""))
	var button: Button = Button.new()
	button.name = "TransportSlot"
	button.position = Vector2(360, 105)
	button.size = Vector2(180, 105)
	button.z_index = 8
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(main, "#171411cc", "#9b7447", 10, 2))
	button.add_theme_stylebox_override("hover", _style(main, "#241c15e8", "#d09b57", 10, 2))

	if tool == "wheelbarrow" and _owned_transport("wheelbarrow") > 0:
		button.text = "KOLEČKO\n0,1 m³ • 5 s\nKLIKNI PRO ODVOZ"
		var asset_path: String = "res://assets/tools/wheelbarrow.png"
		if ResourceLoader.exists(asset_path):
			var resource: Resource = ResourceLoader.load(asset_path)
			if resource is Texture2D:
				button.icon = resource as Texture2D
				button.expand_icon = true
		button.pressed.connect(_start_transport)
	else:
		button.text = "+\nDOPRAVA\nVYBRAT PROSTŘEDEK"
		button.pressed.connect(_show_transport_panel)

	scene.add_child(button)
	transport_button = button

func _show_transport_panel() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Doprava – nastavení"
	dialog.ok_button_text = "ZAVŘÍT"
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 180)
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
	_select_tool(tools, str(state.get("transport_tool", "")))
	tools.item_selected.connect(_on_transport_selected.bind(tools, dialog))
	box.add_child(tools)
	box.add_child(_label(main, "Odvoz stojí 5 Kč a veze 0,1 m³ štípaného dřeva.", 13))
	main.add_child(dialog)
	dialog.popup_centered(Vector2i(450, 240))

func _on_transport_selected(index: int, tools: OptionButton, dialog: AcceptDialog) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	state["transport_tool"] = str(tools.get_item_metadata(index))
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	_remove_slot(main)

func _start_transport() -> void:
	if transport_running:
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	if str(state.get("transport_tool", "")) != "wheelbarrow" or _owned_transport("wheelbarrow") <= 0:
		_remove_slot(main)
		return
	if float(state.get("split_m3", 0.0)) + 0.0001 < TRANSPORT_AMOUNT_M3:
		_set_button_message("NEMÁŠ 0,1 m³\nŠTÍPANÉHO DŘEVA")
		return
	if float(state.get("money", 0.0)) < TRANSPORT_WAGE:
		_set_button_message("CHYBÍ 5 Kč\nNA ODVOZ")
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
		transport_button.text = "ODVÁŽÍM...\n%.1f s" % maxf(0.0, WHEELBARROW_TIME - transport_elapsed)
	if transport_elapsed < WHEELBARROW_TIME:
		return

	transport_running = false
	transport_elapsed = 0.0
	var state: Dictionary = _state(main)
	if float(state.get("split_m3", 0.0)) + 0.0001 >= TRANSPORT_AMOUNT_M3 and float(state.get("money", 0.0)) >= TRANSPORT_WAGE:
		state["split_m3"] = maxf(0.0, float(state.get("split_m3", 0.0)) - TRANSPORT_AMOUNT_M3)
		state["money"] = float(state.get("money", 0.0)) - TRANSPORT_WAGE
		state["delivered_m3"] = float(state.get("delivered_m3", 0.0)) + TRANSPORT_AMOUNT_M3
		main.set("state", state)
		if main.has_method("update_hud"):
			main.call("update_hud")
		if main.has_method("save_game"):
			main.call("save_game")
		_set_button_message("ODVEZENO 0,1 m³\nKLIKNI PRO DALŠÍ")
	else:
		_set_button_message("ODVOZ SE NEPOVEDL")
	if is_instance_valid(transport_button):
		transport_button.disabled = false

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
