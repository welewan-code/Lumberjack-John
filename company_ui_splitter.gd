extends "res://company_ui_parksajt.gd"

const CHECHT_SPLITTER_TOOL_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_TIME: float = 8.0
const CHECHT_SPLITTER_IN_M3: float = 0.040
const CHECHT_SPLITTER_OUT_M3: float = 0.060
const FIRST_PROPERTY_BACKGROUND: String = "res://Firemní zázemí 1.png"

func _populate_slot_tools(main: Node, tools: OptionButton, slot_index: int) -> void:
	super._populate_slot_tools(main, tools, slot_index)
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	var owned: int = _owned_tool_count(CHECHT_SPLITTER_TOOL_ID)
	var used_total: int = _assigned_tool_count(slots, CHECHT_SPLITTER_TOOL_ID)
	var free_total: int = maxi(0, owned - used_total)
	if CHECHT_SPLITTER_TOOL_ID == current_tool:
		tools.add_item("%s • přiřazeno zde • vlastníš %d" % [_tool_menu_name(CHECHT_SPLITTER_TOOL_ID), owned])
		tools.set_item_metadata(tools.item_count - 1, CHECHT_SPLITTER_TOOL_ID)
	elif free_total > 0:
		tools.add_item("%s • volné %d/%d" % [_tool_menu_name(CHECHT_SPLITTER_TOOL_ID), free_total, owned])
		tools.set_item_metadata(tools.item_count - 1, CHECHT_SPLITTER_TOOL_ID)

func _is_known_tool(tool_id: String) -> bool:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return true
	return super._is_known_tool(tool_id)

func _tool_role(tool_id: String) -> String:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return "splitter"
	return super._tool_role(tool_id)

func _tool_name(tool_id: String) -> String:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return "Štípačka CHECHT – 4 klín"
	return super._tool_name(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return CHECHT_SPLITTER_TIME
	return super._tool_cycle_time(tool_id)

func _do_split_cycle(state: Dictionary, tool_id: String) -> bool:
	if tool_id != CHECHT_SPLITTER_TOOL_ID:
		return super._do_split_cycle(state, tool_id)
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return false
	var available: float = float(state.get("roundwood_m3", 0.0))
	if available + 0.0001 < CHECHT_SPLITTER_IN_M3:
		return false
	var net_growth: float = CHECHT_SPLITTER_OUT_M3 - CHECHT_SPLITTER_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["roundwood_m3"] = maxf(0.0, available - CHECHT_SPLITTER_IN_M3)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + CHECHT_SPLITTER_OUT_M3
	return true

func _build_left(main: Node) -> PanelContainer:
	var panel: PanelContainer = super._build_left(main)
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return panel
	var box: VBoxContainer = margin.get_child(0) as VBoxContainer
	if box == null:
		return panel
	var location_title: Label = _label(main, "PRACOVNÍ MÍSTO", 15)
	location_title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(location_title)
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size.y = 36
	selector.add_theme_font_size_override("font_size", 13)
	var state: Dictionary = _state(main)
	var current_location: String = str(state.get("company_location", "home"))
	var rented: bool = bool(state.get("first_property_rented", false)) or current_location == "first_property"
	if rented and not bool(state.get("first_property_rented", false)):
		state["first_property_rented"] = true
		main.set("state", state)
		if main.has_method("save_game"):
			main.call("save_game")
	selector.add_item("Domov")
	selector.set_item_metadata(0, "home")
	if rented:
		selector.add_item("Firemní zázemí – malý dřevosklad")
		selector.set_item_metadata(1, "first_property")
		selector.select(1 if current_location == "first_property" else 0)
	else:
		selector.select(0)
	selector.item_selected.connect(_on_company_location_selected.bind(main, selector))
	box.add_child(selector)
	return panel

func _on_company_location_selected(index: int, main: Node, selector: OptionButton) -> void:
	if main == null or not is_instance_valid(selector):
		return
	var location: String = str(selector.get_item_metadata(index))
	var state: Dictionary = _state(main)
	if location == "first_property" and not bool(state.get("first_property_rented", false)):
		selector.select(0)
		return
	state["company_location"] = location
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	call_deferred("_render_company", main)

func _load_company_background() -> Texture2D:
	var main: Node = get_tree().current_scene
	if main != null:
		var state: Dictionary = _state(main)
		if str(state.get("company_location", "home")) == "first_property" and ResourceLoader.exists(FIRST_PROPERTY_BACKGROUND):
			var resource: Resource = ResourceLoader.load(FIRST_PROPERTY_BACKGROUND)
			if resource is Texture2D:
				return resource as Texture2D
	return super._load_company_background()
