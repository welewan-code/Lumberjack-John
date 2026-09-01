extends "res://company_ui_parksajt.gd"

const CHECHT_SPLITTER_TOOL_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_TIME: float = 8.0
const CHECHT_SPLITTER_IN_M3: float = 0.040
const CHECHT_SPLITTER_OUT_M3: float = 0.060
const FIRST_PROPERTY_BACKGROUND: String = "res://Firemní zázemí 1.png"
const FIRST_PROPERTY_STORAGE_CAPACITY: float = 40.0
const FIRST_PROPERTY_STORAGE_BONUS: float = 30.0

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

func _property_rented(state: Dictionary) -> bool:
	return bool(state.get("first_property_rented", false)) or str(state.get("company_location", "home")) == "first_property"

func _actual_storage_used(state: Dictionary) -> float:
	return float(state.get("logs_m3", 0.0)) + float(state.get("roundwood_m3", 0.0)) + float(state.get("split_m3", 0.0))

func _effective_storage_capacity(state: Dictionary) -> float:
	return FIRST_PROPERTY_STORAGE_CAPACITY if _property_rented(state) else STORAGE_CAPACITY

func _storage_used(state: Dictionary) -> float:
	var actual: float = _actual_storage_used(state)
	if _property_rented(state):
		return maxf(0.0, actual - FIRST_PROPERTY_STORAGE_BONUS)
	return actual

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
	var state: Dictionary = _state(main)
	var current_location: String = str(state.get("company_location", "home"))
	var rented: bool = _property_rented(state)
	if rented and not bool(state.get("first_property_rented", false)):
		state["first_property_rented"] = true
		main.set("state", state)
		if main.has_method("save_game"):
			main.call("save_game")
	if is_instance_valid(storage_label):
		storage_label.text = "%.3f / %.1f m³" % [_actual_storage_used(state), _effective_storage_capacity(state)]
	var location_title: Label = _label(main, "PRACOVNÍ MÍSTO", 15)
	location_title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(location_title)
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size.y = 36
	selector.add_theme_font_size_override("font_size", 13)
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

func _refresh_storage_label(main: Node) -> void:
	if not is_instance_valid(storage_label):
		return
	var state: Dictionary = _state(main)
	storage_label.text = "%.3f / %.1f m³" % [_actual_storage_used(state), _effective_storage_capacity(state)]

func _render_storage(main: Node) -> void:
	var host: MarginContainer = _host(main)
	if host == null:
		return
	_clear(host)
	await get_tree().process_frame
	if not is_instance_valid(host):
		return
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(main, "#1b1713", "#5f4027", 7, 1))
	host.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var title: Label = _label(main, "SKLAD", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	var state: Dictionary = _state(main)
	var used: float = _actual_storage_used(state)
	var capacity: float = _effective_storage_capacity(state)
	var total: Label = _label(main, "Celkem: %.3f / %.1f m³" % [used, capacity], 20)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = capacity
	bar.value = used
	bar.show_percentage = false
	bar.custom_minimum_size.y = 20
	box.add_child(bar)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	_add_storage_card(main, grid, "KLÁDY", float(state.get("logs_m3", 0.0)))
	_add_storage_card(main, grid, "ŠPALKY", float(state.get("roundwood_m3", 0.0)))
	_add_storage_card(main, grid, "ŠTÍPANÉ DŘEVO", float(state.get("split_m3", 0.0)))

func _on_company_location_selected(index: int, main: Node, selector: OptionButton) -> void:
	if main == null or not is_instance_valid(selector):
		return
	var location: String = str(selector.get_item_metadata(index))
	var state: Dictionary = _state(main)
	if location == "first_property" and not _property_rented(state):
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
