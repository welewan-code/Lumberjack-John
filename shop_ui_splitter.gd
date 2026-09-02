extends "res://shop_ui_parksajt.gd"

const CHECHT_SPLITTER_ITEM_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_ITEM: Dictionary = {
	"category": "ŠTÍPAČKY",
	"name": "Štípačka CHECHT – 4 klín",
	"price": 11990,
	"asset": "res://assets/tools/checht_splitter.png",
	"desc": "Cyklus 8 s • 0,040 m³ špalků → 0,060 m³ štípaného • 4 klín."
}

func _ready() -> void:
	if not inventory.has(CHECHT_SPLITTER_ITEM_ID):
		inventory[CHECHT_SPLITTER_ITEM_ID] = 0
	super._ready()

func _render_category(main: Node, host: VBoxContainer) -> void:
	super._render_category(main, host)
	if current_category != "ŠTÍPAČKY":
		return
	var grid: GridContainer = null
	for child: Node in host.get_children():
		if child is GridContainer:
			grid = child as GridContainer
			break
	if grid != null:
		_add_item_card(main, grid, CHECHT_SPLITTER_ITEM_ID, CHECHT_SPLITTER_ITEM)

func _buy_item(item_id: String) -> void:
	if item_id != CHECHT_SPLITTER_ITEM_ID:
		super._buy_item(item_id)
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var price: int = int(CHECHT_SPLITTER_ITEM["price"])
	var state: Dictionary = _main_state(main)
	if float(state.get("money", 0.0)) < float(price):
		return
	state["money"] = float(state.get("money", 0.0)) - float(price)
	inventory[CHECHT_SPLITTER_ITEM_ID] = int(inventory.get(CHECHT_SPLITTER_ITEM_ID, 0)) + 1
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	save_inventory()
	_refresh_category()

func _storage_capacity_for_state(state: Dictionary) -> float:
	var has_first_property: bool = bool(state.get("first_property_rented", false)) or str(state.get("company_location", "home")) == "first_property"
	return 40.0 if has_first_property else 10.0

func _render_wood_buy(main: Node, host: VBoxContainer) -> void:
	var state: Dictionary = _main_state(main)
	var capacity: float = _storage_capacity_for_state(state)
	var used: float = _storage_used(state)
	var free: float = maxf(0.0, capacity - used)
	var storage := _make_label(main, "Sklad: %.2f / %.2f m³  •  Volno: %.2f m³" % [used, capacity, free], 16)
	storage.add_theme_color_override("font_color", Color("#ffca42"))
	host.add_child(storage)
	host.add_child(_make_label(main, "Materiál se nakupuje pouze po celých metrech.", 14))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	host.add_child(grid)
	_add_wood_buy_card(main, grid, "roundwood_m3", "ŠPALKY", BLOCK_PRICE_PER_M3)
	_add_wood_buy_card(main, grid, "logs_m3", "KLÁDY", LOG_PRICE_PER_M3)

func _add_wood_buy_card(main: Node, grid: GridContainer, key: String, title_text: String, price: float) -> void:
	var state: Dictionary = _main_state(main)
	var capacity: float = _storage_capacity_for_state(state)
	var owned: float = float(state.get(key, 0.0))
	var used: float = _storage_used(state)
	var can_fit: bool = used + BUY_STEP_M3 <= capacity + 0.0001
	var can_afford: bool = float(state.get("money", 0.0)) >= price
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#6b4628", 7, 1))
	grid.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := _make_label(main, title_text, 21)
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	box.add_child(_make_label(main, "Ve skladu: %.2f m³" % owned, 15))
	box.add_child(_make_label(main, "Cena: %.0f Kč / m³" % price, 15))
	box.add_child(_make_label(main, "Balení: 1 m³", 14))
	var buy := Button.new()
	buy.text = "KOUPIT 1 m³ ZA %.0f Kč" % price
	buy.custom_minimum_size.y = 42
	buy.disabled = not can_fit or not can_afford
	buy.pressed.connect(_buy_wood.bind(key, price))
	box.add_child(buy)
	if not can_fit:
		box.add_child(_make_label(main, "Ve skladu není místo na další 1 m³.", 13))

func _buy_wood(key: String, price: float) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var state: Dictionary = _main_state(main)
	var capacity: float = _storage_capacity_for_state(state)
	if float(state.get("money", 0.0)) < price or _storage_used(state) + BUY_STEP_M3 > capacity + 0.0001:
		return
	state["money"] = float(state.get("money", 0.0)) - price
	state[key] = float(state.get(key, 0.0)) + BUY_STEP_M3
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	_refresh_category()

func _load_shop_texture(asset_path: String) -> Texture2D:
	if asset_path == "res://assets/tools/checht_splitter.png":
		var image: Image = Image.load_from_file(asset_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return super._load_shop_texture(asset_path)
