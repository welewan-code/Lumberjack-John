extends Node

const SMELINAR_PRICE_PER_M3: float = 900.0
const SMELINAR_MIN_M3: float = 0.1

var last_tab: String = ""
var smelinar_amount: SpinBox = null
var smelinar_stock_label: Label = null
var smelinar_value_label: Label = null
var smelinar_sell_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "FIRMA" and last_tab != "FIRMA":
		call_deferred("_render_company", main)
	if tab == "FIRMA":
		_refresh_smelinar(main)
	last_tab = tab

func _render_company(main: Node) -> void:
	var host_value = main.get("content_host")
	if not (host_value is MarginContainer):
		return
	var host := host_value as MarginContainer
	for child in host.get_children():
		child.queue_free()
	await get_tree().process_frame
	if not is_instance_valid(host):
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	host.add_child(row)

	var left := _side_panel(main, "FIRMA", 250)
	row.add_child(left)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(main, "#17120f", "#6b4628", 7, 1))
	row.add_child(center_panel)

	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _load_company_background()
	center_panel.add_child(image)

	var right := _build_jobs_panel(main, 270)
	row.add_child(right)
	_refresh_smelinar(main)

func _side_panel(main: Node, title_text: String, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#5f4027", 7, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := _make_label(main, title_text, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	var hint := _make_label(main, "", 14)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(hint)
	return panel

func _build_jobs_panel(main: Node, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#5f4027", 7, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := _make_label(main, "ZAKÁZKY", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)

	# Volné místo pro běžné zakázky, které sem budeme doplňovat.
	var jobs_space := Control.new()
	jobs_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(jobs_space)

	var dealer := PanelContainer.new()
	dealer.add_theme_stylebox_override("panel", _panel_style(main, "#171411", "#79512e", 7, 1))
	box.add_child(dealer)

	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_left", 12)
	dm.add_theme_constant_override("margin_right", 12)
	dm.add_theme_constant_override("margin_top", 10)
	dm.add_theme_constant_override("margin_bottom", 10)
	dealer.add_child(dm)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 7)
	dm.add_child(dv)

	var dealer_title := _make_label(main, "ŠMELINÁŘ", 18)
	dealer_title.add_theme_color_override("font_color", Color("#ffca42"))
	dv.add_child(dealer_title)
	dv.add_child(_make_label(main, "Bere štípané dřevo hned.\n900 Kč / m³", 14))

	smelinar_stock_label = _make_label(main, "Sklad: 0.0 m³", 13)
	dv.add_child(smelinar_stock_label)

	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 6)
	dv.add_child(amount_row)
	amount_row.add_child(_make_label(main, "Prodat:", 13))

	smelinar_amount = SpinBox.new()
	smelinar_amount.min_value = SMELINAR_MIN_M3
	smelinar_amount.max_value = SMELINAR_MIN_M3
	smelinar_amount.step = 0.1
	smelinar_amount.value = SMELINAR_MIN_M3
	smelinar_amount.suffix = " m³"
	smelinar_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smelinar_amount.value_changed.connect(_on_smelinar_amount_changed)
	amount_row.add_child(smelinar_amount)

	smelinar_value_label = _make_label(main, "Dostaneš: 90 Kč", 14)
	dv.add_child(smelinar_value_label)

	smelinar_sell_button = Button.new()
	smelinar_sell_button.text = "PRODAT"
	smelinar_sell_button.custom_minimum_size.y = 36
	smelinar_sell_button.add_theme_stylebox_override("normal", _panel_style(main, "#597f0d", "#7ca620", 4, 1))
	smelinar_sell_button.pressed.connect(_sell_to_smelinar)
	dv.add_child(smelinar_sell_button)

	return panel

func _on_smelinar_amount_changed(_value: float) -> void:
	_update_smelinar_value_text()

func _sell_to_smelinar() -> void:
	var main := get_tree().current_scene
	if main == null or smelinar_amount == null or not is_instance_valid(smelinar_amount):
		return
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var available: float = float(state.get("split_m3", 0.0))
	var amount: float = snappedf(float(smelinar_amount.value), 0.1)
	if amount < SMELINAR_MIN_M3 or amount > available + 0.0001:
		return

	state["split_m3"] = maxf(0.0, available - amount)
	state["money"] = float(state.get("money", 0.0)) + amount * SMELINAR_PRICE_PER_M3
	main.set("state", state)
	if main.has_method("update_hud"):
		main.call("update_hud")
	if main.has_method("save_game"):
		main.call("save_game")
	_refresh_smelinar(main)

func _refresh_smelinar(main: Node) -> void:
	if smelinar_amount == null or not is_instance_valid(smelinar_amount):
		return
	var state_value = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value
	var available: float = maxf(0.0, float(state.get("split_m3", 0.0)))
	var sellable_max: float = floor(available * 10.0 + 0.0001) / 10.0

	if is_instance_valid(smelinar_stock_label):
		smelinar_stock_label.text = "Sklad: %.1f m³" % available

	smelinar_amount.max_value = maxf(SMELINAR_MIN_M3, sellable_max)
	if smelinar_amount.value > smelinar_amount.max_value:
		smelinar_amount.value = smelinar_amount.max_value
	if smelinar_amount.value < SMELINAR_MIN_M3:
		smelinar_amount.value = SMELINAR_MIN_M3

	if is_instance_valid(smelinar_sell_button):
		smelinar_sell_button.disabled = sellable_max < SMELINAR_MIN_M3
	_update_smelinar_value_text()

func _update_smelinar_value_text() -> void:
	if smelinar_amount == null or not is_instance_valid(smelinar_amount):
		return
	if smelinar_value_label == null or not is_instance_valid(smelinar_value_label):
		return
	var amount: float = snappedf(float(smelinar_amount.value), 0.1)
	var value: float = amount * SMELINAR_PRICE_PER_M3
	smelinar_value_label.text = "Dostaneš: %.0f Kč" % value

func _load_company_background() -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/backgrounds/company_yard.png",
		"res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png",
		"res://assets/sluncem_zalitý_dvůr_venkovské_chalupy.png"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res := ResourceLoader.load(path)
			if res is Texture2D:
				return res as Texture2D
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
				var path := "res://assets/backgrounds/" + file_name
				if ResourceLoader.exists(path):
					var res := ResourceLoader.load(path)
					if res is Texture2D:
						return res as Texture2D
			file_name = dir.get_next()
		dir.list_dir_end()
	return null

func _make_label(main: Node, text_value: String, size: int) -> Label:
	var value = main.call("make_label", text_value, size)
	if value is Label:
		return value as Label
	var label := Label.new()
	label.text = text_value
	return label

func _panel_style(main: Node, bg: String, border: String, radius: int, width: int) -> StyleBoxFlat:
	var value = main.call("panel_style", bg, border, radius, width)
	if value is StyleBoxFlat:
		return value as StyleBoxFlat
	return StyleBoxFlat.new()
