extends "res://contract_manager.gd"

const PICKUP_SAVE_PATH: String = "user://neighbor_pickup.json"

var neighbor_self_pickup_enabled: bool = false

func _ready() -> void:
	_load_pickup_setting()
	super._ready()

func _offer_volumes_for_tool(tool_id: String) -> Array[float]:
	var source: Array[float] = super._offer_volumes_for_tool(tool_id)
	var limited: Array[float] = []
	for volume: float in source:
		if volume <= 1.0 + 0.0001:
			limited.append(volume)
	return limited

func _ensure_ui(main: Node, now: int) -> void:
	super._ensure_ui(main, now)
	var box: VBoxContainer = _jobs_box(main)
	if box == null:
		return
	var panel: Node = box.get_node_or_null("NeighborContractsPanel")
	if panel == null:
		return
	var existing: Node = panel.find_child("NeighborSelfPickupButton", true, false)
	if existing is Button:
		_update_pickup_button(existing as Button)
		return
	var content: VBoxContainer = _neighbor_content(panel)
	if content == null:
		return
	var separator: HSeparator = HSeparator.new()
	separator.name = "NeighborSelfPickupSeparator"
	content.add_child(separator)
	var hint: Label = _label(main, "Sousedé si mohou hotové dřevo vyzvednout sami.", 11)
	hint.name = "NeighborSelfPickupHint"
	content.add_child(hint)
	var button: Button = Button.new()
	button.name = "NeighborSelfPickupButton"
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_toggle_neighbor_self_pickup.bind(button))
	content.add_child(button)
	_update_pickup_button(button)

func _neighbor_content(panel: Node) -> VBoxContainer:
	if panel.get_child_count() == 0:
		return null
	var margin: Node = panel.get_child(0)
	if not (margin is MarginContainer) or margin.get_child_count() == 0:
		return null
	var content: Node = margin.get_child(0)
	if content is VBoxContainer:
		return content as VBoxContainer
	return null

func _toggle_neighbor_self_pickup(button: Button) -> void:
	neighbor_self_pickup_enabled = not neighbor_self_pickup_enabled
	_save_pickup_setting()
	_update_pickup_button(button)

func _update_pickup_button(button: Button) -> void:
	if neighbor_self_pickup_enabled:
		button.text = "VLASTNÍ ODBĚR SOUSEDŮ: POVOLEN"
		button.tooltip_text = "Kliknutím vlastní odběr sousedům zakážeš."
	else:
		button.text = "POVOLIT SOUSEDŮM VLASTNÍ ODBĚR DŘEVA"
		button.tooltip_text = "Kliknutím povolíš sousedům vlastní odběr dřeva."

func _save_pickup_setting() -> void:
	var file: FileAccess = FileAccess.open(PICKUP_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"enabled": neighbor_self_pickup_enabled}))

func _load_pickup_setting() -> void:
	if not FileAccess.file_exists(PICKUP_SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(PICKUP_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		neighbor_self_pickup_enabled = bool((parsed as Dictionary).get("enabled", false))

func is_neighbor_self_pickup_enabled() -> bool:
	return neighbor_self_pickup_enabled
