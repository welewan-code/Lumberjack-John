extends "res://company_ui_parksajt.gd"

const CHECHT_SPLITTER_TOOL_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_TIME: float = 8.0
const CHECHT_SPLITTER_IN_M3: float = 0.040
const CHECHT_SPLITTER_OUT_M3: float = 0.060
const FIRST_PROPERTY_BACKGROUND: String = "res://Firemní zázemí 1.png"
const FIRST_PROPERTY_STORAGE_CAPACITY: float = 40.0
const FIRST_PROPERTY_STORAGE_BONUS: float = 30.0
const HOME_EMPLOYEE_SLOTS: int = 3
const PROPERTY_EMPLOYEE_SLOTS: int = 5
const EMPLOYEE_TOTAL_SLOTS: int = 5

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

func _active_employee_capacity(state: Dictionary) -> int:
	if _property_rented(state) and str(state.get("company_location", "home")) == "first_property":
		return PROPERTY_EMPLOYEE_SLOTS
	return HOME_EMPLOYEE_SLOTS

func _employee_role_name(role: String) -> String:
	return "ŘEZAČ" if role == "sawyer" else "ŠTÍPAČ"

func _employee_wage_for_role(role: String) -> float:
	return SAWYER_WAGE_PER_10_MIN * 6.0 if role == "sawyer" else SPLITTER_WAGE_PER_10_MIN * 6.0

func _work_slots(state: Dictionary) -> Array:
	var result: Array = []
	var raw_value: Variant = state.get("work_slots", [])
	var raw: Array = raw_value as Array if raw_value is Array else []
	for slot_index in range(EMPLOYEE_TOTAL_SLOTS):
		var mode: String = "player"
		var tool_id: String = ""
		var active: bool = false
		var employee_role: String = ""
		if slot_index < raw.size() and raw[slot_index] is Dictionary:
			var source: Dictionary = raw[slot_index] as Dictionary
			mode = "employee" if str(source.get("mode", "player")) == "employee" else "player"
			if mode == "employee":
				tool_id = str(source.get("tool", ""))
				employee_role = str(source.get("employee_role", ""))
				if employee_role == "" and tool_id != "":
					employee_role = _tool_role(tool_id)
				active = tool_id != ""
		result.append({"mode":mode, "tool":tool_id, "active":active, "employee_role":employee_role})
	return result

func validate_work_slots(main: Node, save_changes: bool = true) -> bool:
	if main == null:
		return false
	var state: Dictionary = _state(main)
	var original: Variant = state.get("work_slots", [])
	var slots: Array = _work_slots(state)
	var changed: bool = not (original is Array and (original as Array) == slots)
	var assigned: Dictionary = {}
	for slot_index in range(EMPLOYEE_TOTAL_SLOTS):
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee":
			slots[slot_index] = {"mode":"player", "tool":"", "active":false, "employee_role":""}
			continue
		var role: String = str(slot.get("employee_role", ""))
		var tool_id: String = str(slot.get("tool", ""))
		if role != "splitter" and role != "sawyer":
			role = _tool_role(tool_id)
		if role != "splitter" and role != "sawyer":
			role = "splitter"
		if tool_id != "" and (not _is_known_tool(tool_id) or _tool_role(tool_id) != role):
			tool_id = ""
		if tool_id != "":
			var already_assigned: int = int(assigned.get(tool_id, 0))
			var owned: int = _owned_tool_count(tool_id)
			if already_assigned >= owned:
				tool_id = ""
			else:
				assigned[tool_id] = already_assigned + 1
		slots[slot_index] = {"mode":"employee", "tool":tool_id, "active":tool_id != "", "employee_role":role}
	state["work_slots"] = slots
	main.set("state", state)
	if changed and save_changes and main.has_method("save_game"):
		main.call("save_game")
	return changed

func _has_player_slot(_state_value: Dictionary) -> bool:
	return true

func _ensure_worker_elapsed_size() -> void:
	while slot_elapsed.size() < EMPLOYEE_TOTAL_SLOTS:
		slot_elapsed.append(0.0)

func _process_workers(main: Node, delta: float) -> void:
	_ensure_worker_elapsed_size()
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var capacity: int = _active_employee_capacity(state)
	var changed: bool = false
	for slot_index in range(EMPLOYEE_TOTAL_SLOTS):
		if slot_index >= capacity:
			slot_elapsed[slot_index] = 0.0
			continue
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee" or not bool(slot.get("active", false)):
			slot_elapsed[slot_index] = 0.0
			continue
		var tool_id: String = str(slot.get("tool", ""))
		if not _slot_assignment_valid(slots, slot_index, tool_id):
			slot_elapsed[slot_index] = 0.0
			continue
		var cycle_time: float = _tool_cycle_time(tool_id)
		if cycle_time <= 0.0:
			slot_elapsed[slot_index] = 0.0
			continue
		slot_elapsed[slot_index] += delta
		if slot_elapsed[slot_index] >= cycle_time:
			slot_elapsed[slot_index] = 0.0
			if _perform_tool_cycle(state, tool_id):
				changed = true
	if changed:
		main.set("state", state)
		if main.has_method("update_hud"):
			main.call("update_hud")
		if main.has_method("save_game"):
			main.call("save_game")

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

func _render_company(main: Node) -> void:
	var host: MarginContainer = _host(main)
	if host == null:
		return
	validate_work_slots(main, true)
	_clear(host)
	await get_tree().process_frame
	if not is_instance_valid(host):
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	host.add_child(row)
	row.add_child(_build_left(main))

	var center: PanelContainer = PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_stylebox_override("panel", _style(main, "#17120f", "#6b4628", 7, 1))
	row.add_child(center)
	var scene: Control = Control.new()
	center.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.clip_contents = true
	var bg: TextureRect = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _load_company_background()
	scene.add_child(bg)

	chop_button = Button.new()
	chop_button.position = Vector2(350, 515)
	chop_button.size = Vector2(190, 75)
	chop_button.add_theme_font_size_override("font_size", 17)
	chop_button.add_theme_stylebox_override("normal", _style(main, "#75451f", "#a06a35", 14, 2))
	chop_button.add_theme_stylebox_override("hover", _style(main, "#895226", "#c18444", 14, 2))
	chop_button.pressed.connect(_start_chop)
	chop_button.z_index = 6
	scene.add_child(chop_button)
	chop_button.text = "PRACOVAT"
	chop_button.disabled = false

	var action: PanelContainer = PanelContainer.new()
	action.position = Vector2(240, 610)
	action.size = Vector2(410, 70)
	action.add_theme_stylebox_override("panel", _style(main, "#171411", "#5b422c", 6, 1))
	action.z_index = 7
	scene.add_child(action)
	var am: MarginContainer = MarginContainer.new()
	am.add_theme_constant_override("margin_left", 10)
	am.add_theme_constant_override("margin_right", 10)
	am.add_theme_constant_override("margin_top", 7)
	am.add_theme_constant_override("margin_bottom", 7)
	action.add_child(am)
	var av: VBoxContainer = VBoxContainer.new()
	am.add_child(av)
	chop_timer = _label(main, "Klikni na PRACOVAT", 14)
	chop_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(chop_timer)
	chop_progress = ProgressBar.new()
	chop_progress.show_percentage = false
	chop_progress.max_value = float(main.call("axe_time")) if main.has_method("axe_time") else 1.8
	chop_progress.custom_minimum_size.y = 12
	av.add_child(chop_progress)
	row.add_child(_build_jobs(main))
	_refresh_storage_label(main)
	_refresh_smelinar(main)

func _build_left(main: Node) -> PanelContainer:
	var panel: PanelContainer = _side_panel(main, 370)
	var box: VBoxContainer = _side_box(panel)
	box.add_theme_constant_override("separation", 9)
	var state: Dictionary = _state(main)
	var rented: bool = _property_rented(state)
	if rented and not bool(state.get("first_property_rented", false)):
		state["first_property_rented"] = true
		main.set("state", state)
		if main.has_method("save_game"):
			main.call("save_game")

	storage_label = _label(main, "SKLAD - %.3f/%.1f m³" % [_actual_storage_used(state), _effective_storage_capacity(state)], 17)
	storage_label.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(storage_label)

	var employees_title: Label = _label(main, "ZAMĚSTNANCI", 17)
	employees_title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(employees_title)

	var headers: HBoxContainer = HBoxContainer.new()
	headers.add_theme_constant_override("separation", 6)
	box.add_child(headers)
	var employee_header: Label = _label(main, "Zaměstnanec", 11)
	employee_header.custom_minimum_size.x = 112
	headers.add_child(employee_header)
	var tool_header: Label = _label(main, "Nástroj", 11)
	tool_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headers.add_child(tool_header)
	var wage_header: Label = _label(main, "Mzda", 11)
	wage_header.custom_minimum_size.x = 72
	wage_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	headers.add_child(wage_header)

	var slots: Array = _work_slots(state)
	var capacity: int = _active_employee_capacity(state)
	var employee_count: int = 0
	for slot_index in range(capacity):
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee":
			continue
		_add_employee_row(main, box, slots, slot_index)
		employee_count += 1

	if employee_count < capacity:
		var add_row: HBoxContainer = HBoxContainer.new()
		add_row.add_theme_constant_override("separation", 8)
		box.add_child(add_row)
		var add_button: Button = Button.new()
		add_button.text = "+"
		add_button.custom_minimum_size = Vector2(34, 30)
		add_button.add_theme_font_size_override("font_size", 18)
		add_button.tooltip_text = "Přidat zaměstnance"
		add_button.pressed.connect(_show_employee_picker.bind(main, employee_count))
		add_row.add_child(add_button)
		add_row.add_child(_label(main, "Přidat zaměstnance", 12))

	var wage_spacer: Control = Control.new()
	wage_spacer.custom_minimum_size.y = 12
	box.add_child(wage_spacer)
	var total_hourly: float = 0.0
	var active_count: int = 0
	for slot_index in range(capacity):
		var slot: Dictionary = slots[slot_index] as Dictionary
		if str(slot.get("mode", "player")) != "employee":
			continue
		if str(slot.get("tool", "")) == "":
			continue
		total_hourly += _employee_wage_for_role(str(slot.get("employee_role", "splitter")))
		active_count += 1
	var wage_panel: PanelContainer = PanelContainer.new()
	wage_panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#5f4027", 6, 1))
	box.add_child(wage_panel)
	var wm: MarginContainer = MarginContainer.new()
	wm.add_theme_constant_override("margin_left", 10)
	wm.add_theme_constant_override("margin_right", 10)
	wm.add_theme_constant_override("margin_top", 8)
	wm.add_theme_constant_override("margin_bottom", 8)
	wage_panel.add_child(wm)
	var wage_summary: Label = _label(main, "MZDY CELKEM\n%d aktivní • %.0f Kč/h" % [active_count, total_hourly], 13)
	wage_summary.add_theme_color_override("font_color", Color("#ffca42"))
	wm.add_child(wage_summary)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label(main, "Ruční štípání", 17))
	box.add_child(_label(main, "0,010 m³ špalků → 0,015 m³ štípaného", 13))
	return panel

func _add_employee_row(main: Node, box: VBoxContainer, slots: Array, slot_index: int) -> void:
	var slot: Dictionary = slots[slot_index] as Dictionary
	var role: String = str(slot.get("employee_role", "splitter"))
	var tool_id: String = str(slot.get("tool", ""))
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#5f4027", 5, 1))
	box.add_child(row_panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row_panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var fire_button: Button = Button.new()
	fire_button.text = "✕  %s" % _employee_role_name(role)
	fire_button.custom_minimum_size = Vector2(112, 34)
	fire_button.add_theme_font_size_override("font_size", 11)
	fire_button.tooltip_text = "Propustit zaměstnance"
	fire_button.pressed.connect(_fire_employee.bind(main, slot_index))
	row.add_child(fire_button)

	var tools: OptionButton = OptionButton.new()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.custom_minimum_size.y = 34
	tools.add_theme_font_size_override("font_size", 11)
	_populate_worker_tools(tools, slots, slot_index, role)
	_select_option_metadata(tools, tool_id)
	tools.item_selected.connect(_on_worker_tool_selected.bind(main, slot_index, tools))
	row.add_child(tools)

	var wage: Label = _label(main, "%.0f Kč/h" % _employee_wage_for_role(role), 11)
	wage.custom_minimum_size.x = 72
	wage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(wage)

func _populate_worker_tools(tools: OptionButton, slots: Array, slot_index: int, role: String) -> void:
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	tools.add_item("Vyber nástroj")
	tools.set_item_metadata(tools.item_count - 1, "")
	var tool_ids: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw", PARKSAJT_TOOL_ID, CHECHT_950_TOOL_ID, OJELO_MAG_TOOL_ID, CHECHT_SPLITTER_TOOL_ID]
	for tool_id: String in tool_ids:
		if _tool_role(tool_id) != role:
			continue
		var owned: int = _owned_tool_count(tool_id)
		var used_total: int = _assigned_tool_count(slots, tool_id)
		var free_total: int = maxi(0, owned - used_total)
		if tool_id == current_tool:
			tools.add_item(_tool_name(tool_id))
			tools.set_item_metadata(tools.item_count - 1, tool_id)
		elif free_total > 0:
			tools.add_item(_tool_name(tool_id))
			tools.set_item_metadata(tools.item_count - 1, tool_id)

func _show_employee_picker(main: Node, slot_index: int) -> void:
	if main == null:
		return
	var state: Dictionary = _state(main)
	if slot_index >= _active_employee_capacity(state):
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Vybrat zaměstnance"
	dialog.ok_button_text = "ZRUŠIT"
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(360, 150)
	content.add_theme_constant_override("separation", 10)
	dialog.add_child(content)
	var splitter: Button = Button.new()
	splitter.text = "ŠTÍPAČ  •  900 Kč/h"
	splitter.custom_minimum_size.y = 46
	splitter.pressed.connect(_hire_employee.bind(main, slot_index, "splitter", dialog))
	content.add_child(splitter)
	var sawyer: Button = Button.new()
	sawyer.text = "ŘEZAČ  •  1 200 Kč/h"
	sawyer.custom_minimum_size.y = 46
	sawyer.pressed.connect(_hire_employee.bind(main, slot_index, "sawyer", dialog))
	content.add_child(sawyer)
	main.add_child(dialog)
	dialog.popup_centered(Vector2i(400, 220))

func _hire_employee(main: Node, slot_index: int, role: String, dialog: AcceptDialog) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var compacted: Array = []
	for slot_value: Variant in slots:
		var current: Dictionary = slot_value as Dictionary
		if str(current.get("mode", "player")) == "employee":
			compacted.append(current)
	if compacted.size() >= _active_employee_capacity(state):
		if is_instance_valid(dialog):
			dialog.queue_free()
		return
	compacted.append({"mode":"employee", "tool":"", "active":false, "employee_role":role})
	while compacted.size() < EMPLOYEE_TOTAL_SLOTS:
		compacted.append({"mode":"player", "tool":"", "active":false, "employee_role":""})
	state["work_slots"] = compacted
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	call_deferred("_render_company", main)

func _fire_employee(main: Node, slot_index: int) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var compacted: Array = []
	for index in range(slots.size()):
		if index == slot_index:
			continue
		var current: Dictionary = slots[index] as Dictionary
		if str(current.get("mode", "player")) == "employee":
			compacted.append(current)
	while compacted.size() < EMPLOYEE_TOTAL_SLOTS:
		compacted.append({"mode":"player", "tool":"", "active":false, "employee_role":""})
	state["work_slots"] = compacted
	main.set("state", state)
	_ensure_worker_elapsed_size()
	for i in range(slot_elapsed.size()):
		slot_elapsed[i] = 0.0
	if main.has_method("save_game"):
		main.call("save_game")
	call_deferred("_render_company", main)

func _on_worker_tool_selected(index: int, main: Node, slot_index: int, tools: OptionButton) -> void:
	if main == null or not is_instance_valid(tools):
		return
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot: Dictionary = slots[slot_index] as Dictionary
	if str(slot.get("mode", "player")) != "employee":
		return
	var old_tool: String = str(slot.get("tool", ""))
	var tool_id: String = str(tools.get_item_metadata(index))
	var role: String = str(slot.get("employee_role", "splitter"))
	if tool_id != "" and _tool_role(tool_id) != role:
		_select_option_metadata(tools, old_tool)
		return
	if tool_id != "" and tool_id != old_tool:
		if _assigned_tool_count(slots, tool_id) >= _owned_tool_count(tool_id):
			_select_option_metadata(tools, old_tool)
			return
	slot["tool"] = tool_id
	slot["active"] = tool_id != ""
	slots[slot_index] = slot
	state["work_slots"] = slots
	main.set("state", state)
	_ensure_worker_elapsed_size()
	slot_elapsed[slot_index] = 0.0
	if main.has_method("save_game"):
		main.call("save_game")
	call_deferred("_render_company", main)

func _refresh_storage_label(main: Node) -> void:
	if not is_instance_valid(storage_label):
		return
	var state: Dictionary = _state(main)
	storage_label.text = "SKLAD - %.3f/%.1f m³" % [_actual_storage_used(state), _effective_storage_capacity(state)]

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
	_add_self_pickup_reserve_control(main, box, state, capacity)

func _add_self_pickup_reserve_control(main: Node, box: VBoxContainer, state: Dictionary, capacity: float) -> void:
	var reserve_panel: PanelContainer = PanelContainer.new()
	reserve_panel.add_theme_stylebox_override("panel", _style(main, "#171411", "#79512e", 7, 1))
	box.add_child(reserve_panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	reserve_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title: Label = _label(main, "REZERVA PRO VLASTNÍ OBJEDNÁVKY", 17)
	title.add_theme_color_override("font_color", Color("#ffca42"))
	content.add_child(title)
	content.add_child(_label(main, "Sousedské samoodběry nesmí prodat štípané dřevo pod tuto hranici.", 13))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var reserve_input: SpinBox = SpinBox.new()
	reserve_input.min_value = 0.0
	reserve_input.max_value = capacity
	reserve_input.step = 0.1
	reserve_input.value = clampf(float(state.get("self_pickup_reserve_m3", 0.0)), 0.0, capacity)
	reserve_input.suffix = " m³"
	reserve_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reserve_input)
	var save_button: Button = Button.new()
	save_button.text = "PONECHAT NA SKLADĚ"
	save_button.custom_minimum_size = Vector2(220, 40)
	save_button.pressed.connect(_save_self_pickup_reserve.bind(main, reserve_input))
	row.add_child(save_button)
	var current: Label = _label(main, "Aktuálně rezervováno: %.1f m³" % float(state.get("self_pickup_reserve_m3", 0.0)), 13)
	current.name = "SelfPickupReserveCurrent"
	content.add_child(current)

func _save_self_pickup_reserve(main: Node, reserve_input: SpinBox) -> void:
	if main == null or not is_instance_valid(reserve_input):
		return
	var state: Dictionary = _state(main)
	var capacity: float = _effective_storage_capacity(state)
	var reserve: float = clampf(snappedf(float(reserve_input.value), 0.1), 0.0, capacity)
	state["self_pickup_reserve_m3"] = reserve
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	call_deferred("_render_storage", main)

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
