extends Node

const SMELINAR_PRICE_PER_M3: float = 900.0
const STORAGE_CAPACITY: float = 10.0
const CHOP_IN_M3: float = 0.010
const CHOP_OUT_M3: float = 0.015
const SPLITTER_WAGE_PER_10_MIN: float = 150.0
const SAWYER_WAGE_PER_10_MIN: float = 200.0
const WAGE_PERIOD_SECONDS: float = 600.0
const SAW_IN_M3: float = 0.025
const SAW_OUT_M3: float = 0.033
const SPLITTER_TIME_WOODEN: float = 1.8
const SPLITTER_TIME_SHARPENED: float = 1.6
const SPLITTER_TIME_CHECHT: float = 1.5
const SPLITTER_TIME_FICKARS: float = 1.3
const FICKARS_BONUS_CHANCE: float = 0.05
const FICKARS_BONUS_IN_M3: float = 0.020
const FICKARS_BONUS_OUT_M3: float = 0.030
const SAWYER_TIME_FRAME: float = 20.0
const SAWYER_TIME_AKU: float = 14.0
const SLOT_COUNT: int = 3
const TOOL_IDS: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw"]

var last_tab: String = ""
var smelinar_amount: SpinBox = null
var smelinar_stock_label: Label = null
var smelinar_value_label: Label = null
var smelinar_sell_button: Button = null
var storage_label: Label = null
var chop_button: Button = null
var chop_progress: ProgressBar = null
var chop_timer: Label = null
var chop_running: bool = false
var chop_elapsed: float = 0.0
var chop_duration: float = 1.8
var slot_elapsed: Array[float] = [0.0, 0.0, 0.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_validate_current_scene_slots")

func _validate_current_scene_slots() -> void:
	var main: Node = get_tree().current_scene
	if main != null:
		validate_work_slots(main, true)

func _process(delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "FIRMA" and last_tab != "FIRMA":
		validate_work_slots(main, true)
		call_deferred("_render_company", main)
	elif tab == "SKLAD" and last_tab != "SKLAD":
		call_deferred("_render_storage", main)
	if tab == "FIRMA":
		_refresh_smelinar(main)
		_refresh_storage_label(main)
		_process_chop(main, delta)
	_process_workers(main, delta)
	last_tab = tab

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

	var heading: Label = _label(main, "PRACOVNÍ SLOTY", 19)
	heading.position = Vector2(300, 145)
	heading.size = Vector2(300, 35)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("#ffca42"))
	heading.z_index = 5
	scene.add_child(heading)

	var slot_positions: Array[Vector2] = [Vector2(25, 190), Vector2(325, 190), Vector2(625, 190)]
	for slot_index in range(SLOT_COUNT):
		_add_work_slot(main, scene, slot_index, slot_positions[slot_index], Vector2(235, 300))

	chop_button = Button.new()
	chop_button.position = Vector2(350, 515)
	chop_button.size = Vector2(190, 75)
	chop_button.add_theme_font_size_override("font_size", 17)
	chop_button.add_theme_stylebox_override("normal", _style(main, "#75451f", "#a06a35", 14, 2))
	chop_button.add_theme_stylebox_override("hover", _style(main, "#895226", "#c18444", 14, 2))
	chop_button.pressed.connect(_start_chop)
	chop_button.z_index = 6
	scene.add_child(chop_button)

	var state: Dictionary = _state(main)
	if _has_player_slot(state):
		chop_button.text = "ŠPALEK\nŠTÍPAT SÁM"
		chop_button.disabled = false
	else:
		chop_button.text = "NENÍ SLOT\nPRACOVAT SÁM"
		chop_button.disabled = true

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
	chop_timer = _label(main, "Klikni na štípání" if _has_player_slot(state) else "Všechny sloty obsluhují zaměstnanci", 14)
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

func _add_work_slot(main: Node, scene: Control, slot_index: int, pos: Vector2, field_size: Vector2) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var slot: Dictionary = slots[slot_index] as Dictionary
	var mode: String = str(slot.get("mode", "player"))
	var tool_id: String = str(slot.get("tool", ""))
	var active: bool = bool(slot.get("active", false))

	var field: Button = Button.new()
	field.position = pos
	field.size = field_size
	field.z_index = 4
	field.add_theme_stylebox_override("normal", _style(main, "#17141166", "#9b7447", 10, 2))
	field.add_theme_stylebox_override("hover", _style(main, "#241c15aa", "#d09b57", 10, 2))
	field.pressed.connect(_show_slot_panel.bind(slot_index))
	scene.add_child(field)

	var texture: Texture2D = _slot_texture(main, mode, tool_id)
	if texture != null:
		var sprite: TextureRect = TextureRect.new()
		sprite.position = Vector2(15, 8)
		sprite.size = Vector2(field_size.x - 30.0, field_size.y - 82.0)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.texture = texture
		field.add_child(sprite)

	var status: Label = _label(main, _slot_field_text(slot_index, mode, tool_id, active), 12)
	status.anchor_left = 0.0
	status.anchor_right = 1.0
	status.anchor_top = 1.0
	status.anchor_bottom = 1.0
	status.offset_left = 4.0
	status.offset_right = -4.0
	status.offset_top = -72.0
	status.offset_bottom = -4.0
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(status)

func _slot_field_text(slot_index: int, mode: String, tool_id: String, active: bool) -> String:
	if mode == "player":
		return "SLOT %d\nPRACOVAT SÁM\nbez automatiky" % (slot_index + 1)
	if tool_id == "":
		return "SLOT %d\nZAMĚSTNANEC\nBEZ NÁSTROJE" % (slot_index + 1)
	var status: String = "PRACUJE" if active else "STOP"
	return "SLOT %d • %s\n%s\n%s" % [slot_index + 1, status, _tool_role_name(tool_id), _tool_name(tool_id)]

func _slot_texture(main: Node, mode: String, tool_id: String) -> Texture2D:
	if mode == "player":
		if main.has_method("load_player_texture"):
			var player_value: Variant = main.call("load_player_texture")
			if player_value is Texture2D:
				return player_value as Texture2D
		return null
	var path: String = ""
	var role: String = _tool_role(tool_id)
	if role == "sawyer":
		path = "res://assets/characters/sawyer_1.png"
	elif role == "splitter":
		path = "res://assets/characters/splitter_wood_1.png"
	if path != "" and ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return null

func _show_slot_panel(slot_index: int) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	validate_work_slots(main, true)
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var slot: Dictionary = slots[slot_index] as Dictionary
	var mode: String = str(slot.get("mode", "player"))
	var tool_id: String = str(slot.get("tool", ""))
	var active: bool = bool(slot.get("active", false))

	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Pracovní slot %d" % (slot_index + 1)
	dialog.ok_button_text = "ZAVŘÍT"
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 350)
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)

	var mode_label: Label = _label(main, "REŽIM SLOTU", 15)
	mode_label.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(mode_label)
	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	box.add_child(mode_row)
	var self_button: Button = Button.new()
	self_button.text = "PRACOVAT SÁM"
	self_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self_button.custom_minimum_size.y = 40
	self_button.disabled = mode == "player"
	self_button.pressed.connect(_set_slot_mode.bind(slot_index, "player", dialog))
	mode_row.add_child(self_button)
	var hire_button: Button = Button.new()
	hire_button.text = "NAJMOUT ZAMĚSTNANCE"
	hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire_button.custom_minimum_size.y = 40
	hire_button.disabled = mode == "employee"
	hire_button.pressed.connect(_set_slot_mode.bind(slot_index, "employee", dialog))
	mode_row.add_child(hire_button)

	if mode == "player":
		box.add_child(_label(main, "Tento slot představuje hráče. Automatická výroba je vypnutá.", 14))
	else:
		var tool_label: Label = _label(main, "NÁSTROJ", 15)
		tool_label.add_theme_color_override("font_color", Color("#ffca42"))
		box.add_child(tool_label)
		var tools: OptionButton = OptionButton.new()
		tools.custom_minimum_size.y = 40
		_populate_slot_tools(main, tools, slot_index)
		_select_option_metadata(tools, tool_id)
		tools.item_selected.connect(_on_slot_tool_selected.bind(slot_index, tools, dialog))
		box.add_child(tools)

		box.add_child(_label(main, "Činnost: %s" % _tool_role_name(tool_id), 15))
		if tool_id != "":
			box.add_child(_label(main, "Cyklus: %.1f s  •  Mzda: %.0f Kč / 10 min" % [_tool_cycle_time(tool_id), _tool_wage(tool_id)], 13))

		var toggle: Button = Button.new()
		toggle.text = "ZASTAVIT PRÁCI" if active else "SPUSTIT PRÁCI"
		toggle.custom_minimum_size.y = 42
		toggle.disabled = tool_id == ""
		if tool_id == "":
			toggle.tooltip_text = "Nejdřív vyber nástroj."
		toggle.pressed.connect(_toggle_slot.bind(slot_index, dialog))
		box.add_child(toggle)

	main.add_child(dialog)
	dialog.popup_centered(Vector2i(540, 430))

func _set_slot_mode(slot_index: int, mode: String, dialog: AcceptDialog) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	if mode == "employee":
		slots[slot_index] = {"mode":"employee", "tool":"", "active":false}
	else:
		slots[slot_index] = {"mode":"player", "tool":"", "active":false}
	slot_elapsed[slot_index] = 0.0
	state["work_slots"] = slots
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	call_deferred("_render_company", main)

func _populate_slot_tools(main: Node, tools: OptionButton, slot_index: int) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	tools.add_item("Bez nástroje")
	tools.set_item_metadata(tools.item_count - 1, "")
	for tool_id: String in TOOL_IDS:
		var owned: int = _owned_tool_count(tool_id)
		var used_total: int = _assigned_tool_count(slots, tool_id)
		var free_total: int = maxi(0, owned - used_total)
		if tool_id == current_tool:
			tools.add_item("%s • přiřazeno zde • vlastníš %d" % [_tool_menu_name(tool_id), owned])
			tools.set_item_metadata(tools.item_count - 1, tool_id)
		elif free_total > 0:
			tools.add_item("%s • volné %d/%d" % [_tool_menu_name(tool_id), free_total, owned])
			tools.set_item_metadata(tools.item_count - 1, tool_id)

func _select_option_metadata(tools: OptionButton, tool_id: String) -> void:
	for index: int in range(tools.item_count):
		if str(tools.get_item_metadata(index)) == tool_id:
			tools.select(index)
			return
	tools.select(0)

func _on_slot_tool_selected(index: int, slot_index: int, tools: OptionButton, dialog: AcceptDialog) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var slot: Dictionary = slots[slot_index] as Dictionary
	if str(slot.get("mode", "player")) != "employee":
		return
	var old_tool: String = str(slot.get("tool", ""))
	var tool_id: String = str(tools.get_item_metadata(index))
	if tool_id != "" and tool_id != old_tool:
		var used_total: int = _assigned_tool_count(slots, tool_id)
		if used_total >= _owned_tool_count(tool_id):
			return
	slot["tool"] = tool_id
	if tool_id == "":
		slot["active"] = false
	slots[slot_index] = slot
	slot_elapsed[slot_index] = 0.0
	state["work_slots"] = slots
	main.set("state", state)
	validate_work_slots(main, false)
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	call_deferred("_render_company", main)

func _toggle_slot(slot_index: int, dialog: AcceptDialog) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	validate_work_slots(main, true)
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var slot: Dictionary = slots[slot_index] as Dictionary
	if str(slot.get("mode", "player")) != "employee":
		return
	var tool_id: String = str(slot.get("tool", ""))
	if tool_id == "" or not _slot_assignment_valid(slots, slot_index, tool_id):
		return
	slot["active"] = not bool(slot.get("active", false))
	slots[slot_index] = slot
	slot_elapsed[slot_index] = 0.0
	state["work_slots"] = slots
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	if is_instance_valid(dialog):
		dialog.queue_free()
	call_deferred("_render_company", main)

func validate_work_slots(main: Node, save_changes: bool = true) -> bool:
	if main == null:
		return false
	var state: Dictionary = _state(main)
	var original: Variant = state.get("work_slots", [])
	var slots: Array = _work_slots(state)
	var changed: bool = true
	if original is Array:
		var original_array: Array = original as Array
		changed = original_array != slots

	var assigned: Dictionary = {}
	for slot_index in range(SLOT_COUNT):
		var slot: Dictionary = slots[slot_index] as Dictionary
		var mode: String = str(slot.get("mode", "player"))
		var tool_id: String = str(slot.get("tool", ""))
		var active: bool = bool(slot.get("active", false))
		if mode != "employee":
			if tool_id != "" or active:
				changed = true
			slot = {"mode":"player", "tool":"", "active":false}
			slots[slot_index] = slot
			continue
		if tool_id == "":
			if active:
				changed = true
				slot["active"] = false
			slots[slot_index] = slot
			continue
		if not _is_known_tool(tool_id):
			changed = true
			slots[slot_index] = {"mode":"employee", "tool":"", "active":false}
			continue
		var already_assigned: int = int(assigned.get(tool_id, 0))
		var owned: int = _owned_tool_count(tool_id)
		if already_assigned >= owned:
			changed = true
			slots[slot_index] = {"mode":"employee", "tool":"", "active":false}
			continue
		assigned[tool_id] = already_assigned + 1

	state["work_slots"] = slots
	main.set("state", state)
	if changed and save_changes and main.has_method("save_game"):
		main.call("save_game")
	return changed

func _work_slots(state: Dictionary) -> Array:
	var result: Array = []
	var raw_value: Variant = state.get("work_slots", [])
	var raw: Array = []
	if raw_value is Array:
		raw = raw_value as Array
	for slot_index in range(SLOT_COUNT):
		var mode: String = "player"
		var tool_id: String = ""
		var active: bool = false
		if slot_index < raw.size() and raw[slot_index] is Dictionary:
			var source: Dictionary = raw[slot_index] as Dictionary
			mode = "employee" if str(source.get("mode", "player")) == "employee" else "player"
			if mode == "employee":
				tool_id = str(source.get("tool", ""))
				active = bool(source.get("active", false))
		result.append({"mode":mode, "tool":tool_id, "active":active})
	return result

func _has_player_slot(state: Dictionary) -> bool:
	var slots: Array = _work_slots(state)
	for slot_value: Variant in slots:
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("mode", "player")) == "player":
			return true
	return false

func _owned_tool_count(tool_id: String) -> int:
	if tool_id == "wooden_axe":
		return 1
	var shop: Node = get_node_or_null("/root/ShopUI")
	if shop == null:
		return 0
	if shop.has_method("get_owned_item_count"):
		return maxi(0, int(shop.call("get_owned_item_count", tool_id)))
	var inventory_value: Variant = shop.get("inventory")
	if inventory_value is Dictionary:
		return maxi(0, int((inventory_value as Dictionary).get(tool_id, 0)))
	return 0

func _assigned_tool_count(slots: Array, tool_id: String) -> int:
	var count: int = 0
	for slot_value: Variant in slots:
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("mode", "player")) == "employee" and str(slot.get("tool", "")) == tool_id:
			count += 1
	return count

func _slot_assignment_valid(slots: Array, slot_index: int, tool_id: String) -> bool:
	if not _is_known_tool(tool_id):
		return false
	var owned: int = _owned_tool_count(tool_id)
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

func _is_known_tool(tool_id: String) -> bool:
	return TOOL_IDS.has(tool_id)

func _tool_role(tool_id: String) -> String:
	match tool_id:
		"frame_saw", "aku_saw": return "sawyer"
		"wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe": return "splitter"
		_: return ""

func _tool_role_name(tool_id: String) -> String:
	match _tool_role(tool_id):
		"sawyer": return "ŘEZAČ"
		"splitter": return "ŠTÍPAČ"
		_: return "BEZ ČINNOSTI"

func _tool_name(tool_id: String) -> String:
	match tool_id:
		"frame_saw": return "Rámová pila"
		"aku_saw": return "Aku pila"
		"wooden_axe": return "Tupá sekera"
		"sharpened_axe": return "Nabroušená sekera"
		"checht_axe": return "Štípací sekera CHECHT"
		"fickars_axe": return "Štípací sekera Fickars"
		_: return "Bez nástroje"

func _tool_menu_name(tool_id: String) -> String:
	var cycle: float = _tool_cycle_time(tool_id)
	var unit: String = "řez" if _tool_role(tool_id) == "sawyer" else "špalek"
	return "%s – %.1f s / %s" % [_tool_name(tool_id), cycle, unit]

func _tool_cycle_time(tool_id: String) -> float:
	match tool_id:
		"frame_saw": return SAWYER_TIME_FRAME
		"aku_saw": return SAWYER_TIME_AKU
		"wooden_axe": return SPLITTER_TIME_WOODEN
		"sharpened_axe": return SPLITTER_TIME_SHARPENED
		"checht_axe": return SPLITTER_TIME_CHECHT
		"fickars_axe": return SPLITTER_TIME_FICKARS
		_: return 0.0

func _tool_wage(tool_id: String) -> float:
	return SAWYER_WAGE_PER_10_MIN if _tool_role(tool_id) == "sawyer" else SPLITTER_WAGE_PER_10_MIN

func _tool_cycle_wage(tool_id: String) -> float:
	return _tool_wage(tool_id) * _tool_cycle_time(tool_id) / WAGE_PERIOD_SECONDS

func _process_workers(main: Node, delta: float) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var changed: bool = false
	for slot_index in range(SLOT_COUNT):
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

func _perform_tool_cycle(state: Dictionary, tool_id: String) -> bool:
	if _tool_role(tool_id) == "sawyer":
		return _do_saw_cycle(state, tool_id)
	if _tool_role(tool_id) == "splitter":
		return _do_split_cycle(state, tool_id)
	return false

func _do_saw_cycle(state: Dictionary, tool_id: String) -> bool:
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return false
	if float(state.get("logs_m3", 0.0)) + 0.0001 < SAW_IN_M3:
		return false
	var net_growth: float = SAW_OUT_M3 - SAW_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["logs_m3"] = maxf(0.0, float(state.get("logs_m3", 0.0)) - SAW_IN_M3)
	state["roundwood_m3"] = float(state.get("roundwood_m3", 0.0)) + SAW_OUT_M3
	return true

func _do_split_cycle(state: Dictionary, tool_id: String) -> bool:
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return false
	var available: float = float(state.get("roundwood_m3", 0.0))
	if available + 0.0001 < CHOP_IN_M3:
		return false
	var input_amount: float = CHOP_IN_M3
	var output_amount: float = CHOP_OUT_M3
	if tool_id == "fickars_axe" and randf() < FICKARS_BONUS_CHANCE:
		var bonus_growth: float = FICKARS_BONUS_OUT_M3 - FICKARS_BONUS_IN_M3
		if available + 0.0001 >= FICKARS_BONUS_IN_M3 and _storage_used(state) + bonus_growth <= STORAGE_CAPACITY + 0.0001:
			input_amount = FICKARS_BONUS_IN_M3
			output_amount = FICKARS_BONUS_OUT_M3
	var net_growth: float = output_amount - input_amount
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["roundwood_m3"] = maxf(0.0, available - input_amount)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + output_amount
	return true

func _build_left(main: Node) -> PanelContainer:
	var panel: PanelContainer = _side_panel(main, 250)
	var box: VBoxContainer = _side_box(panel)
	var title: Label = _label(main, "FIRMA", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	var sh: Label = _label(main, "SKLAD", 17)
	sh.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(sh)
	storage_label = _label(main, "0.000 / 10.0 m³", 15)
	box.add_child(storage_label)
	box.add_child(_label(main, "Jeden společný sklad pro klády, špalky i štípané dřevo.", 13))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label(main, "Ruční štípání", 17))
	box.add_child(_label(main, "0,010 m³ špalků → 0,015 m³ štípaného", 13))
	return panel

func _build_jobs(main: Node) -> PanelContainer:
	var panel: PanelContainer = _side_panel(main, 270)
	var box: VBoxContainer = _side_box(panel)
	var title: Label = _label(main, "ZAKÁZKY", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var dealer: PanelContainer = PanelContainer.new()
	dealer.add_theme_stylebox_override("panel", _style(main, "#171411", "#79512e", 7, 1))
	box.add_child(dealer)
	var dm: MarginContainer = MarginContainer.new()
	dm.add_theme_constant_override("margin_left", 12)
	dm.add_theme_constant_override("margin_right", 12)
	dm.add_theme_constant_override("margin_top", 10)
	dm.add_theme_constant_override("margin_bottom", 10)
	dealer.add_child(dm)
	var dv: VBoxContainer = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 7)
	dm.add_child(dv)
	var dt: Label = _label(main, "ŠMELINÁŘ", 18)
	dt.add_theme_color_override("font_color", Color("#ffca42"))
	dv.add_child(dt)
	dv.add_child(_label(main, "Štípané dřevo • 900 Kč / m³", 14))
	smelinar_stock_label = _label(main, "Štípané: 0.0 m³", 13)
	dv.add_child(smelinar_stock_label)
	var amount_row: HBoxContainer = HBoxContainer.new()
	dv.add_child(amount_row)
	amount_row.add_child(_label(main, "Prodat:", 13))
	smelinar_amount = SpinBox.new()
	smelinar_amount.min_value = 0.1
	smelinar_amount.max_value = 0.1
	smelinar_amount.step = 0.1
	smelinar_amount.value = 0.1
	smelinar_amount.suffix = " m³"
	smelinar_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smelinar_amount.value_changed.connect(_on_smelinar_amount_changed)
	amount_row.add_child(smelinar_amount)
	smelinar_value_label = _label(main, "Dostaneš: 90 Kč", 14)
	dv.add_child(smelinar_value_label)
	smelinar_sell_button = Button.new()
	smelinar_sell_button.text = "PRODAT"
	smelinar_sell_button.custom_minimum_size.y = 36
	smelinar_sell_button.pressed.connect(_sell_to_smelinar)
	dv.add_child(smelinar_sell_button)
	return panel

func _start_chop() -> void:
	if chop_running:
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _state(main)
	if not _has_player_slot(state):
		if is_instance_valid(chop_timer):
			chop_timer.text = "Nejdřív nastav některý slot na PRACOVAT SÁM"
		return
	if float(state.get("roundwood_m3", 0.0)) + 0.0001 < CHOP_IN_M3:
		if is_instance_valid(chop_timer):
			chop_timer.text = "Nemáš špalky"
		return
	var net_growth: float = CHOP_OUT_M3 - CHOP_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		if is_instance_valid(chop_timer):
			chop_timer.text = "Sklad je plný"
		return
	chop_running = true
	chop_elapsed = 0.0
	chop_duration = float(main.call("axe_time")) if main.has_method("axe_time") else 1.8
	if is_instance_valid(chop_progress):
		chop_progress.max_value = chop_duration
		chop_progress.value = 0.0
	if is_instance_valid(chop_button):
		chop_button.disabled = true

func _process_chop(main: Node, delta: float) -> void:
	if not chop_running:
		return
	chop_elapsed += delta
	if is_instance_valid(chop_progress):
		chop_progress.value = chop_elapsed
	if is_instance_valid(chop_timer):
		chop_timer.text = "Štípám... %.1f s" % maxf(0.0, chop_duration - chop_elapsed)
	if chop_elapsed < chop_duration:
		return
	chop_running = false
	var state: Dictionary = _state(main)
	var available: float = float(state.get("roundwood_m3", 0.0))
	var input_amount: float = CHOP_IN_M3
	var output_amount: float = CHOP_OUT_M3
	var bonus: bool = false
	if str(state.get("equipped_axe", "wooden")) == "fickars" and randf() < FICKARS_BONUS_CHANCE:
		var bonus_growth: float = FICKARS_BONUS_OUT_M3 - FICKARS_BONUS_IN_M3
		if available + 0.0001 >= FICKARS_BONUS_IN_M3 and _storage_used(state) + bonus_growth <= STORAGE_CAPACITY + 0.0001:
			input_amount = FICKARS_BONUS_IN_M3
			output_amount = FICKARS_BONUS_OUT_M3
			bonus = true
	var net_growth: float = output_amount - input_amount
	if available + 0.0001 >= input_amount and _storage_used(state) + net_growth <= STORAGE_CAPACITY + 0.0001:
		state["roundwood_m3"] = maxf(0.0, available - input_amount)
		state["split_m3"] = float(state.get("split_m3", 0.0)) + output_amount
		main.set("state", state)
		if main.has_method("update_hud"):
			main.call("update_hud")
		if main.has_method("save_game"):
			main.call("save_game")
		if is_instance_valid(chop_timer):
			chop_timer.text = "+0,030 m³ štípaného • BONUS" if bonus else "+0,015 m³ štípaného"
	if is_instance_valid(chop_progress):
		chop_progress.value = 0.0
	if is_instance_valid(chop_button):
		chop_button.disabled = not _has_player_slot(_state(main))
	_refresh_storage_label(main)
	_refresh_smelinar(main)

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
	var used: float = _storage_used(state)
	var total: Label = _label(main, "Celkem: %.3f / 10.0 m³" % used, 20)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = STORAGE_CAPACITY
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

func _add_storage_card(main: Node, grid: GridContainer, title_text: String, amount: float) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(main, "#171411", "#79512e", 7, 1))
	grid.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	margin.add_child(box)
	var t: Label = _label(main, title_text, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(t)
	var a: Label = _label(main, "%.3f m³" % amount, 24)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(a)

func _sell_to_smelinar() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not is_instance_valid(smelinar_amount):
		return
	var state: Dictionary = _state(main)
	var available: float = float(state.get("split_m3", 0.0))
	var amount: float = snappedf(float(smelinar_amount.value), 0.1)
	if amount < 0.1 or amount > available + 0.0001:
		return
	state["split_m3"] = maxf(0.0, available - amount)
	state["money"] = float(state.get("money", 0.0)) + amount * SMELINAR_PRICE_PER_M3
	state["xp"] = int(state.get("xp", 0)) + int(round(amount * 10.0))
	main.set("state", state)
	if main.has_method("update_hud"):
		main.call("update_hud")
	if main.has_method("save_game"):
		main.call("save_game")
	_refresh_smelinar(main)
	_refresh_storage_label(main)

func _on_smelinar_amount_changed(_value: float) -> void:
	_update_smelinar_value()

func _refresh_smelinar(main: Node) -> void:
	if not is_instance_valid(smelinar_amount):
		return
	var available: float = maxf(0.0, float(_state(main).get("split_m3", 0.0)))
	var sellable: float = floor(available * 10.0 + 0.0001) / 10.0
	if is_instance_valid(smelinar_stock_label):
		smelinar_stock_label.text = "Štípané: %.1f m³" % available
	smelinar_amount.max_value = maxf(0.1, sellable)
	if smelinar_amount.value > smelinar_amount.max_value:
		smelinar_amount.value = smelinar_amount.max_value
	if is_instance_valid(smelinar_sell_button):
		smelinar_sell_button.disabled = sellable < 0.1
	_update_smelinar_value()

func _update_smelinar_value() -> void:
	if not is_instance_valid(smelinar_amount) or not is_instance_valid(smelinar_value_label):
		return
	smelinar_value_label.text = "Dostaneš: %.0f Kč" % (float(smelinar_amount.value) * SMELINAR_PRICE_PER_M3)

func _refresh_storage_label(main: Node) -> void:
	if is_instance_valid(storage_label):
		storage_label.text = "%.3f / 10.0 m³" % _storage_used(_state(main))

func _storage_used(state: Dictionary) -> float:
	return float(state.get("logs_m3", 0.0)) + float(state.get("roundwood_m3", 0.0)) + float(state.get("split_m3", 0.0))

func _host(main: Node) -> MarginContainer:
	var value: Variant = main.get("content_host")
	if value is MarginContainer:
		return value as MarginContainer
	return null

func _state(main: Node) -> Dictionary:
	var value: Variant = main.get("state")
	if value is Dictionary:
		return value as Dictionary
	return {}

func _clear(host: MarginContainer) -> void:
	for child: Node in host.get_children():
		child.queue_free()

func _side_panel(main: Node, width: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(main, "#1b1713", "#5f4027", 7, 1))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return panel

func _side_box(panel: PanelContainer) -> VBoxContainer:
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	return margin.get_child(0) as VBoxContainer

func _load_company_background() -> Texture2D:
	var candidates: Array[String] = ["res://assets/backgrounds/company_yard.png", "res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png"]
	for candidate: String in candidates:
		if ResourceLoader.exists(candidate):
			var resource: Resource = ResourceLoader.load(candidate)
			if resource is Texture2D:
				return resource as Texture2D
	return null

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
