extends Node

const SMELINAR_PRICE_PER_M3: float = 900.0
const SMELINAR_MIN_M3: float = 0.1
const STORAGE_CAPACITY: float = 10.0
const CHOP_IN_M3: float = 0.010
const CHOP_OUT_M3: float = 0.015

var last_tab: String = ""
var smelinar_amount: SpinBox = null
var smelinar_stock_label: Label = null
var smelinar_value_label: Label = null
var smelinar_sell_button: Button = null
var storage_label: Label = null
var company_chop_button: Button = null
var company_chop_progress: ProgressBar = null
var company_chop_timer: Label = null
var company_chop_running: bool = false
var company_chop_elapsed: float = 0.0
var company_chop_duration: float = 1.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "FIRMA" and last_tab != "FIRMA":
		call_deferred("_render_company", main)
	elif tab == "SKLAD" and last_tab != "SKLAD":
		call_deferred("_render_storage", main)

	if tab == "FIRMA":
		_refresh_smelinar(main)
		_refresh_company_storage(main)
		_process_company_chop(main, delta)
	last_tab = tab

func _render_company(main: Node) -> void:
	var host := _content_host(main)
	if host == null:
		return
	_clear_host(host)
	await get_tree().process_frame
	if not is_instance_valid(host):
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	host.add_child(row)

	var left := _build_company_left(main, 250)
	row.add_child(left)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(main, "#17120f", "#6b4628", 7, 1))
	row.add_child(center_panel)

	var scene := Control.new()
	scene.clip_contents = true
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scene)

	var image := TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _load_company_background()
	scene.add_child(image)

	var player := TextureRect.new()
	player.position = Vector2(110, 245)
	player.size = Vector2(190, 230)
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.texture = _load_player_texture(main)
	player.z_index = 5
	scene.add_child(player)

	company_chop_button = Button.new()
	company_chop_button.position = Vector2(285, 390)
	company_chop_button.size = Vector2(145, 82)
	company_chop_button.text = "ŠPALEK\nŠTÍPAT"
	company_chop_button.add_theme_font_size_override("font_size", 18)
	company_chop_button.add_theme_stylebox_override("normal", _panel_style(main, "#75451f", "#a06a35", 14, 2))
	company_chop_button.add_theme_stylebox_override("hover", _panel_style(main, "#895226", "#c18444", 14, 2))
	company_chop_button.pressed.connect(_start_company_chop)
	company_chop_button.z_index = 6
	scene.add_child(company_chop_button)

	var action_panel := PanelContainer.new()
	action_panel.position = Vector2(145, 485)
	action_panel.size = Vector2(430, 70)
	action_panel.add_theme_stylebox_override("panel", _panel_style(main, "#171411cc", "#5b422c", 6, 1))
	action_panel.z_index = 7
	scene.add_child(action_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10); margin.add_theme_constant_override("margin_right", 10); margin.add_theme_constant_override("margin_top", 7); margin.add_theme_constant_override("margin_bottom", 7)
	action_panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); margin.add_child(box)
	company_chop_timer = _make_label(main, "Klikni na špalek", 14)
	company_chop_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(company_chop_timer)
	company_chop_progress = ProgressBar.new(); company_chop_progress.show_percentage = false; company_chop_progress.min_value = 0.0; company_chop_progress.max_value = 1.8; company_chop_progress.value = 0.0; company_chop_progress.custom_minimum_size.y = 12; box.add_child(company_chop_progress)

	var right := _build_jobs_panel(main, 270)
	row.add_child(right)
	_refresh_smelinar(main)
	_refresh_company_storage(main)

func _build_company_left(main: Node, width: float) -> PanelContainer:
	var panel := _base_side_panel(main, width)
	var box := _panel_box(panel)
	var title := _make_label(main, "FIRMA", 22); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_color_override("font_color", Color("#ffca42")); box.add_child(title)
	var storage_title := _make_label(main, "SKLAD", 17); storage_title.add_theme_color_override("font_color", Color("#ffca42")); box.add_child(storage_title)
	storage_label = _make_label(main, "0.00 / 10.00 m³", 15); box.add_child(storage_label)
	box.add_child(_make_label(main, "Společná kapacita pro všechny materiály.", 13))
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(spacer)
	box.add_child(_make_label(main, "Ruční štípání", 17))
	box.add_child(_make_label(main, "1 sek: 0,010 m³ špalků → 0,015 m³ štípaného dřeva", 13))
	return panel

func _start_company_chop() -> void:
	if company_chop_running:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var state := _state(main)
	var used := _storage_used(state)
	if float(state.get("roundwood_m3", 0.0)) + 0.0001 < CHOP_IN_M3:
		if is_instance_valid(company_chop_timer): company_chop_timer.text = "Nemáš žádné špalky"
		return
	var net_growth := CHOP_OUT_M3 - CHOP_IN_M3
	if used + net_growth > STORAGE_CAPACITY + 0.0001:
		if is_instance_valid(company_chop_timer): company_chop_timer.text = "Sklad je plný"
		return
	company_chop_running = true
	company_chop_elapsed = 0.0
	company_chop_duration = float(main.call("axe_time")) if main.has_method("axe_time") else 1.8
	if is_instance_valid(company_chop_progress):
		company_chop_progress.max_value = company_chop_duration
		company_chop_progress.value = 0.0
	if is_instance_valid(company_chop_button): company_chop_button.disabled = true

func _process_company_chop(main: Node, delta: float) -> void:
	if not company_chop_running:
		return
	company_chop_elapsed += delta
	if is_instance_valid(company_chop_progress): company_chop_progress.value = company_chop_elapsed
	if is_instance_valid(company_chop_timer): company_chop_timer.text = "Štípám... %.1f s" % maxf(0.0, company_chop_duration - company_chop_elapsed)
	if company_chop_elapsed < company_chop_duration:
		return
	company_chop_running = false
	var state := _state(main)
	var available := float(state.get("roundwood_m3", 0.0))
	var used := _storage_used(state)
	if available + 0.0001 >= CHOP_IN_M3 and used + (CHOP_OUT_M3 - CHOP_IN_M3) <= STORAGE_CAPACITY + 0.0001:
		state["roundwood_m3"] = maxf(0.0, available - CHOP_IN_M3)
		state["split_m3"] = float(state.get("split_m3", 0.0)) + CHOP_OUT_M3
		main.set("state", state)
		if main.has_method("update_hud"): main.call("update_hud")
		if main.has_method("save_game"): main.call("save_game")
		if is_instance_valid(company_chop_timer): company_chop_timer.text = "+0,015 m³ štípaného dřeva"
	else:
		if is_instance_valid(company_chop_timer): company_chop_timer.text = "Nelze štípat"
	if is_instance_valid(company_chop_progress): company_chop_progress.value = 0.0
	if is_instance_valid(company_chop_button): company_chop_button.disabled = false
	_refresh_company_storage(main)
	_refresh_smelinar(main)

func _render_storage(main: Node) -> void:
	var host := _content_host(main)
	if host == null:
		return
	_clear_host(host)
	await get_tree().process_frame
	if not is_instance_valid(host): return
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#5f4027", 7, 1)); host.add_child(panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_top", 24); margin.add_theme_constant_override("margin_bottom", 24); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 16); margin.add_child(box)
	var title := _make_label(main, "SKLAD", 28); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_color_override("font_color", Color("#ffca42")); box.add_child(title)
	var state := _state(main); var used := _storage_used(state)
	var total := _make_label(main, "Celkem: %.3f / %.1f m³" % [used, STORAGE_CAPACITY], 20); total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(total)
	var bar := ProgressBar.new(); bar.min_value = 0.0; bar.max_value = STORAGE_CAPACITY; bar.value = used; bar.show_percentage = false; bar.custom_minimum_size.y = 20; box.add_child(bar)
	var grid := GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation", 12); box.add_child(grid)
	_add_storage_card(main, grid, "KLÁDY", float(state.get("logs_m3", 0.0)))
	_add_storage_card(main, grid, "ŠPALKY", float(state.get("roundwood_m3", 0.0)))
	_add_storage_card(main, grid, "ŠTÍPANÉ DŘEVO", float(state.get("split_m3", 0.0)))
	var note := _make_label(main, "Všechny materiály sdílí jeden sklad. Kapacita je zatím 10 m³.", 15); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(note)

func _add_storage_card(main: Node, grid: GridContainer, title_text: String, amount: float) -> void:
	var card := PanelContainer.new(); card.custom_minimum_size = Vector2(250, 150); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel", _panel_style(main, "#171411", "#79512e", 7, 1)); grid.add_child(card)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 14); margin.add_theme_constant_override("margin_right", 14); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14); card.add_child(margin)
	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER; margin.add_child(box)
	var t := _make_label(main, title_text, 18); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_color_override("font_color", Color("#ffca42")); box.add_child(t)
	var a := _make_label(main, "%.3f m³" % amount, 24); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(a)

func _refresh_company_storage(main: Node) -> void:
	if storage_label == null or not is_instance_valid(storage_label): return
	var state := _state(main); var used := _storage_used(state)
	storage_label.text = "%.3f / %.1f m³" % [used, STORAGE_CAPACITY]
	storage_label.add_theme_color_override("font_color", Color("#ff7a55") if used >= STORAGE_CAPACITY - 0.001 else Color("#f2e9da"))

func _build_jobs_panel(main: Node, width: float) -> PanelContainer:
	var panel := _base_side_panel(main, width)
	var box := _panel_box(panel)
	var title := _make_label(main, "ZAKÁZKY", 22); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_color_override("font_color", Color("#ffca42")); box.add_child(title)
	var jobs_space := Control.new(); jobs_space.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(jobs_space)
	var dealer := PanelContainer.new(); dealer.add_theme_stylebox_override("panel", _panel_style(main, "#171411", "#79512e", 7, 1)); box.add_child(dealer)
	var dm := MarginContainer.new(); dm.add_theme_constant_override("margin_left", 12); dm.add_theme_constant_override("margin_right", 12); dm.add_theme_constant_override("margin_top", 10); dm.add_theme_constant_override("margin_bottom", 10); dealer.add_child(dm)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 7); dm.add_child(dv)
	var dealer_title := _make_label(main, "ŠMELINÁŘ", 18); dealer_title.add_theme_color_override("font_color", Color("#ffca42")); dv.add_child(dealer_title)
	dv.add_child(_make_label(main, "Bere štípané dřevo hned.\n900 Kč / m³", 14))
	smelinar_stock_label = _make_label(main, "Sklad: 0.0 m³", 13); dv.add_child(smelinar_stock_label)
	var amount_row := HBoxContainer.new(); amount_row.add_theme_constant_override("separation", 6); dv.add_child(amount_row); amount_row.add_child(_make_label(main, "Prodat:", 13))
	smelinar_amount = SpinBox.new(); smelinar_amount.min_value = SMELINAR_MIN_M3; smelinar_amount.max_value = SMELINAR_MIN_M3; smelinar_amount.step = 0.1; smelinar_amount.value = SMELINAR_MIN_M3; smelinar_amount.suffix = " m³"; smelinar_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL; smelinar_amount.value_changed.connect(_on_smelinar_amount_changed); amount_row.add_child(smelinar_amount)
	smelinar_value_label = _make_label(main, "Dostaneš: 90 Kč", 14); dv.add_child(smelinar_value_label)
	smelinar_sell_button = Button.new(); smelinar_sell_button.text = "PRODAT"; smelinar_sell_button.custom_minimum_size.y = 36; smelinar_sell_button.add_theme_stylebox_override("normal", _panel_style(main, "#597f0d", "#7ca620", 4, 1)); smelinar_sell_button.pressed.connect(_sell_to_smelinar); dv.add_child(smelinar_sell_button)
	return panel

func _on_smelinar_amount_changed(_value: float) -> void: _update_smelinar_value_text()

func _sell_to_smelinar() -> void:
	var main := get_tree().current_scene
	if main == null or smelinar_amount == null or not is_instance_valid(smelinar_amount): return
	var state := _state(main); var available: float = float(state.get("split_m3", 0.0)); var amount: float = snappedf(float(smelinar_amount.value), 0.1)
	if amount < SMELINAR_MIN_M3 or amount > available + 0.0001: return
	state["split_m3"] = maxf(0.0, available - amount); state["money"] = float(state.get("money", 0.0)) + amount * SMELINAR_PRICE_PER_M3
	main.set("state", state); if main.has_method("update_hud"): main.call("update_hud"); if main.has_method("save_game"): main.call("save_game")
	_refresh_smelinar(main); _refresh_company_storage(main)

func _refresh_smelinar(main: Node) -> void:
	if smelinar_amount == null or not is_instance_valid(smelinar_amount): return
	var state := _state(main); var available: float = maxf(0.0, float(state.get("split_m3", 0.0))); var sellable_max: float = floor(available * 10.0 + 0.0001) / 10.0
	if is_instance_valid(smelinar_stock_label): smelinar_stock_label.text = "Štípané: %.1f m³" % available
	smelinar_amount.max_value = maxf(SMELINAR_MIN_M3, sellable_max)
	if smelinar_amount.value > smelinar_amount.max_value: smelinar_amount.value = smelinar_amount.max_value
	if smelinar_amount.value < SMELINAR_MIN_M3: smelinar_amount.value = SMELINAR_MIN_M3
	if is_instance_valid(smelinar_sell_button): smelinar_sell_button.disabled = sellable_max < SMELINAR_MIN_M3
	_update_smelinar_value_text()

func _update_smelinar_value_text() -> void:
	if smelinar_amount == null or not is_instance_valid(smelinar_amount) or smelinar_value_label == null or not is_instance_valid(smelinar_value_label): return
	var amount: float = snappedf(float(smelinar_amount.value), 0.1); smelinar_value_label.text = "Dostaneš: %.0f Kč" % (amount * SMELINAR_PRICE_PER_M3)

func _storage_used(state: Dictionary) -> float:
	return float(state.get("logs_m3", 0.0)) + float(state.get("roundwood_m3", 0.0)) + float(state.get("split_m3", 0.0))

func _state(main: Node) -> Dictionary:
	var value = main.get("state")
	return value as Dictionary if value is Dictionary else {}

func _content_host(main: Node) -> MarginContainer:
	var value = main.get("content_host")
	return value as MarginContainer if value is MarginContainer else null

func _clear_host(host: MarginContainer) -> void:
	for child in host.get_children(): child.queue_free()

func _base_side_panel(main: Node, width: float) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size.x = width; panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#5f4027", 7, 1))
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 14); margin.add_theme_constant_override("margin_right", 14); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); margin.add_child(box)
	return panel

func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := panel.get_child(0) as MarginContainer
	return margin.get_child(0) as VBoxContainer

func _load_player_texture(main: Node) -> Texture2D:
	var state := _state(main); var equipped := str(state.get("equipped_axe", "wooden")); var path := "res://assets/characters/player_sharp_1.png" if equipped == "sharpened" else "res://assets/characters/player_wood_1.png"
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D: return res as Texture2D
	return null

func _load_company_background() -> Texture2D:
	var candidates: Array[String] = ["res://assets/backgrounds/company_yard.png", "res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png", "res://assets/sluncem_zalitý_dvůr_venkovské_chalupy.png"]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res := ResourceLoader.load(path)
			if res is Texture2D: return res as Texture2D
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir != null:
		dir.list_dir_begin(); var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
				var path := "res://assets/backgrounds/" + file_name
				if ResourceLoader.exists(path):
					var res := ResourceLoader.load(path)
					if res is Texture2D: return res as Texture2D
			file_name = dir.get_next()
		dir.list_dir_end()
	return null

func _make_label(main: Node, text_value: String, size: int) -> Label:
	var value = main.call("make_label", text_value, size)
	if value is Label: return value as Label
	var label := Label.new(); label.text = text_value; return label

func _panel_style(main: Node, bg: String, border: String, radius: int, width: int) -> StyleBoxFlat:
	var value = main.call("panel_style", bg, border, radius, width)
	if value is StyleBoxFlat: return value as StyleBoxFlat
	return StyleBoxFlat.new()
