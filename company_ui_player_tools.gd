extends "res://company_ui_splitter.gd"

const PLAYER_TOOL_ITEMS: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw", PARKSAJT_TOOL_ID, CHECHT_950_TOOL_ID, OJELO_MAG_TOOL_ID]
const PLAYER_TRANSPORT_ITEMS: Array[String] = ["wheelbarrow", "handcart", "small_trailer"]

func _player_item_from_equipped(state: Dictionary) -> String:
	var equipped_tool: String = str(state.get("equipped_player_tool", ""))
	if equipped_tool != "":
		return equipped_tool
	match str(state.get("equipped_axe", "wooden")):
		"sharpened": return "sharpened_axe"
		"checht": return "checht_axe"
		"fickars": return "fickars_axe"
		_: return "wooden_axe"

func _equipped_from_player_item(item_id: String) -> String:
	match item_id:
		"sharpened_axe": return "sharpened"
		"checht_axe": return "checht"
		"fickars_axe": return "fickars"
		_: return "wooden"

func _player_reserves_tool(tool_id: String) -> bool:
	var main: Node = get_tree().current_scene
	if main == null:
		return false
	return _player_item_from_equipped(_state(main)) == tool_id

func validate_work_slots(main: Node, save_changes: bool = true) -> bool:
	var changed: bool = super.validate_work_slots(main, false)
	if main == null:
		return changed
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var player_tool: String = _player_item_from_equipped(state)
	var allowed_for_employees: int = maxi(0, _owned_tool_count(player_tool) - 1)
	var used: int = 0
	for slot_index in range(slots.size()):
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee" or str(slot.get("tool", "")) != player_tool:
			continue
		used += 1
		if used > allowed_for_employees:
			slot["tool"] = ""
			slot["active"] = false
			slots[slot_index] = slot
			changed = true
	state["work_slots"] = slots
	main.set("state", state)
	if changed and save_changes and main.has_method("save_game"):
		main.call("save_game")
	return changed

func _slot_assignment_valid(slots: Array, slot_index: int, tool_id: String) -> bool:
	if not _is_known_tool(tool_id):
		return false
	var owned: int = _owned_tool_count(tool_id)
	if _player_reserves_tool(tool_id):
		owned -= 1
	if owned <= 0:
		return false
	var used_before_or_here: int = 0
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] as Dictionary
		if str(slot.get("mode", "player")) == "employee" and str(slot.get("tool", "")) == tool_id:
			used_before_or_here += 1
			if index == slot_index:
				return used_before_or_here <= owned
	return false

func _populate_worker_tools(tools: OptionButton, slots: Array, slot_index: int, role: String) -> void:
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	tools.add_item("Vyber nástroj")
	tools.set_item_metadata(tools.item_count - 1, "")
	var tool_ids: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw", PARKSAJT_TOOL_ID, CHECHT_950_TOOL_ID, OJELO_MAG_TOOL_ID, CHECHT_SPLITTER_TOOL_ID]
	for tool_id: String in tool_ids:
		if _tool_role(tool_id) != role:
			continue
		var owned: int = _owned_tool_count(tool_id)
		if _player_reserves_tool(tool_id):
			owned -= 1
		var used_total: int = _assigned_tool_count(slots, tool_id)
		var free_total: int = maxi(0, owned - used_total)
		if tool_id == current_tool and owned > 0:
			tools.add_item(_tool_name(tool_id))
			tools.set_item_metadata(tools.item_count - 1, tool_id)
		elif free_total > 0:
			tools.add_item(_tool_name(tool_id))
			tools.set_item_metadata(tools.item_count - 1, tool_id)

func _build_left(main: Node) -> PanelContainer:
	var panel: PanelContainer = super._build_left(main)
	if panel.get_child_count() == 0:
		return panel
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return panel
	var box: VBoxContainer = margin.get_child(0) as VBoxContainer
	if box == null:
		return panel

	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_item: String = _player_item_from_equipped(state)

	var player_panel: PanelContainer = PanelContainer.new()
	player_panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#5f4027", 6, 1))
	var pm: MarginContainer = MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 10)
	pm.add_theme_constant_override("margin_right", 10)
	pm.add_theme_constant_override("margin_top", 8)
	pm.add_theme_constant_override("margin_bottom", 8)
	player_panel.add_child(pm)
	var pv: VBoxContainer = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 5)
	pm.add_child(pv)
	var title: Label = _label(main, "TVŮJ NÁSTROJ", 13)
	title.add_theme_color_override("font_color", Color("#ffca42"))
	pv.add_child(title)
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size.y = 34
	selector.add_theme_font_size_override("font_size", 12)
	for item_id: String in PLAYER_TOOL_ITEMS:
		var owned: int = _owned_tool_count(item_id)
		var assigned: int = _assigned_tool_count(slots, item_id)
		if item_id != current_item and owned - assigned <= 0:
			continue
		selector.add_item(_tool_name(item_id))
		selector.set_item_metadata(selector.item_count - 1, item_id)
		if item_id == current_item:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_player_tool_selected.bind(main, selector))
	pv.add_child(selector)

	var transport_panel: PanelContainer = PanelContainer.new()
	transport_panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#5f4027", 6, 1))
	var tm: MarginContainer = MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 10)
	tm.add_theme_constant_override("margin_right", 10)
	tm.add_theme_constant_override("margin_top", 8)
	tm.add_theme_constant_override("margin_bottom", 8)
	transport_panel.add_child(tm)
	var tv: VBoxContainer = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 5)
	tm.add_child(tv)
	var transport_title: Label = _label(main, "TVŮJ VOZÍK", 13)
	transport_title.add_theme_color_override("font_color", Color("#ffca42"))
	tv.add_child(transport_title)
	var transport_selector: OptionButton = OptionButton.new()
	transport_selector.custom_minimum_size.y = 34
	transport_selector.add_theme_font_size_override("font_size", 12)
	transport_selector.add_item("Bez prostředku")
	transport_selector.set_item_metadata(transport_selector.item_count - 1, "")
	var current_transport: String = _selected_transport(main)
	if current_transport == "":
		transport_selector.select(0)
	for transport_id: String in PLAYER_TRANSPORT_ITEMS:
		if _owned_transport(transport_id) <= 0 and transport_id != current_transport:
			continue
		transport_selector.add_item(_transport_name(transport_id))
		transport_selector.set_item_metadata(transport_selector.item_count - 1, transport_id)
		if transport_id == current_transport:
			transport_selector.select(transport_selector.item_count - 1)
	transport_selector.item_selected.connect(_on_transport_selected.bind(main, transport_selector))
	tv.add_child(transport_selector)

	var insert_index: int = maxi(0, box.get_child_count() - 2)
	box.add_child(player_panel)
	box.move_child(player_panel, insert_index)
	box.add_child(transport_panel)
	box.move_child(transport_panel, insert_index)
	return panel

func _on_player_tool_selected(index: int, main: Node, selector: OptionButton) -> void:
	if main == null or not is_instance_valid(selector):
		return
	var item_id: String = str(selector.get_item_metadata(index))
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	if _owned_tool_count(item_id) - _assigned_tool_count(slots, item_id) <= 0 and item_id != _player_item_from_equipped(state):
		return
	state["equipped_player_tool"] = item_id
	if item_id in ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe"]:
		state["equipped_axe"] = _equipped_from_player_item(item_id)
	main.set("state", state)
	validate_work_slots(main, false)
	if main.has_method("save_game"):
		main.call("save_game")
	call_deferred("_render_company", main)

func _selected_transport(main: Node) -> String:
	var transport: Node = get_node_or_null("/root/TransportUI")
	if transport != null and transport.has_method("get_selected_transport_tool"):
		return str(transport.call("get_selected_transport_tool", main))
	return str(_state(main).get("transport_tool", ""))

func _owned_transport(item_id: String) -> int:
	var shop: Node = get_node_or_null("/root/ShopUI")
	if shop == null:
		return 0
	var inventory_value: Variant = shop.get("inventory")
	if inventory_value is Dictionary:
		return int((inventory_value as Dictionary).get(item_id, 0))
	return 0

func _transport_name(item_id: String) -> String:
	match item_id:
		"wheelbarrow": return "Kolečko – 0,1 m³"
		"handcart": return "Trakař – 0,2 m³"
		"small_trailer": return "Malý vozík za auto – 0,5 m³"
		_: return "Doprava"

func _on_transport_selected(index: int, main: Node, selector: OptionButton) -> void:
	if main == null or not is_instance_valid(selector):
		return
	var transport_id: String = str(selector.get_item_metadata(index))
	if transport_id != "" and _owned_transport(transport_id) <= 0:
		return
	var state: Dictionary = _state(main)
	state["transport_tool"] = transport_id
	main.set("state", state)
	var transport: Node = get_node_or_null("/root/TransportUI")
	if transport != null:
		transport.set("saved_transport_tool", transport_id)
		if transport.has_method("_save_transport_state"):
			transport.call("_save_transport_state")
	if main.has_method("save_game"):
		main.call("save_game")
