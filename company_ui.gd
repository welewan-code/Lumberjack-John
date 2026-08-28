extends Node

const SMELINAR_PRICE_PER_M3: float = 900.0
const STORAGE_CAPACITY: float = 10.0
const CHOP_IN_M3: float = 0.010
const CHOP_OUT_M3: float = 0.015

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "FIRMA" and last_tab != "FIRMA":
		call_deferred("_render_company", main)
	elif tab == "SKLAD" and last_tab != "SKLAD":
		call_deferred("_render_storage", main)
	if tab == "FIRMA":
		_refresh_smelinar(main)
		_refresh_storage_label(main)
		_process_chop(main, delta)
	last_tab = tab

func _render_company(main: Node) -> void:
	var host: MarginContainer = _host(main)
	if host == null:
		return
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

	var player: TextureRect = TextureRect.new()
	player.position = Vector2(105, 245)
	player.size = Vector2(190, 230)
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.texture = _load_player_texture(main)
	player.z_index = 5
	scene.add_child(player)

	chop_button = Button.new()
	chop_button.position = Vector2(285, 390)
	chop_button.size = Vector2(145, 82)
	chop_button.text = "ŠPALEK\nŠTÍPAT"
	chop_button.add_theme_font_size_override("font_size", 18)
	chop_button.add_theme_stylebox_override("normal", _style(main, "#75451f", "#a06a35", 14, 2))
	chop_button.add_theme_stylebox_override("hover", _style(main, "#895226", "#c18444", 14, 2))
	chop_button.pressed.connect(_start_chop)
	chop_button.z_index = 6
	scene.add_child(chop_button)

	var action: PanelContainer = PanelContainer.new()
	action.position = Vector2(145, 485)
	action.size = Vector2(430, 70)
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
	chop_timer = _label(main, "Klikni na špalek", 14)
	chop_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(chop_timer)
	chop_progress = ProgressBar.new()
	chop_progress.show_percentage = false
	chop_progress.max_value = 1.8
	chop_progress.custom_minimum_size.y = 12
	av.add_child(chop_progress)

	row.add_child(_build_jobs(main))
	_refresh_storage_label(main)
	_refresh_smelinar(main)

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
	if main.has_method("axe_time"):
		chop_duration = float(main.call("axe_time"))
	else:
		chop_duration = 1.8
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
	var net_growth: float = CHOP_OUT_M3 - CHOP_IN_M3
	if available + 0.0001 >= CHOP_IN_M3 and _storage_used(state) + net_growth <= STORAGE_CAPACITY + 0.0001:
		state["roundwood_m3"] = maxf(0.0, available - CHOP_IN_M3)
		state["split_m3"] = float(state.get("split_m3", 0.0)) + CHOP_OUT_M3
		main.set("state", state)
		if main.has_method("update_hud"):
			main.call("update_hud")
		if main.has_method("save_game"):
			main.call("save_game")
		if is_instance_valid(chop_timer):
			chop_timer.text = "+0,015 m³ štípaného"
	if is_instance_valid(chop_progress):
		chop_progress.value = 0.0
	if is_instance_valid(chop_button):
		chop_button.disabled = false
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
	var note: Label = _label(main, "Všechny materiály sdílí maximální kapacitu 10 m³.", 15)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

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
	if not is_instance_valid(storage_label):
		return
	var used: float = _storage_used(_state(main))
	storage_label.text = "%.3f / 10.0 m³" % used

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

func _load_player_texture(main: Node) -> Texture2D:
	var equipped: String = str(_state(main).get("equipped_axe", "wooden"))
	var path: String = "res://assets/characters/player_wood_1.png"
	if equipped == "sharpened":
		path = "res://assets/characters/player_sharp_1.png"
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return null

func _load_company_background() -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/backgrounds/company_yard.png",
		"res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png"
	]
	for candidate: String in candidates:
		if ResourceLoader.exists(candidate):
			var resource: Resource = ResourceLoader.load(candidate)
			if resource is Texture2D:
				return resource as Texture2D
	var dir: DirAccess = DirAccess.open("res://assets/backgrounds")
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
				var image_path: String = "res://assets/backgrounds/" + file_name
				if ResourceLoader.exists(image_path):
					var resource: Resource = ResourceLoader.load(image_path)
					if resource is Texture2D:
						dir.list_dir_end()
						return resource as Texture2D
			file_name = dir.get_next()
		dir.list_dir_end()
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
