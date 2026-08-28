extends Node

const SHOP_SAVE_PATH := "user://shop_inventory.json"
const CATEGORIES: Array[String] = ["SEKERY", "PILY", "DOPRAVNÍ PROSTŘEDKY"]

const ITEMS: Dictionary = {
	"wooden_axe": {"category":"SEKERY", "name":"Tupá sekera", "price":0, "asset":"res://assets/tools/wooden_axe.png", "desc":"Základní pracovní sekera."},
	"sharpened_axe": {"category":"SEKERY", "name":"Nabroušená sekera", "price":120, "asset":"res://assets/tools/sharpened_axe.png", "desc":"Rychlejší sekání než se základní sekerou."},
	"frame_saw": {"category":"PILY", "name":"Rámová pila", "price":400, "asset":"res://assets/tools/frame_saw.png", "desc":"Ruční pila pro další pracovní činnosti."},
	"aku_saw": {"category":"PILY", "name":"Aku pila", "price":1800, "asset":"res://assets/tools/aku_saw.png", "desc":"Rychlejší elektrická pila."},
	"wheelbarrow": {"category":"DOPRAVNÍ PROSTŘEDKY", "name":"Kolečko", "price":900, "asset":"res://assets/tools/wheelbarrow.png", "desc":"Základní přesun materiálu."},
	"handcart": {"category":"DOPRAVNÍ PROSTŘEDKY", "name":"Ruční vozík", "price":2200, "asset":"", "desc":"Větší kapacita než kolečko."}
}

var watched_shop_button: Button = null
var current_category: String = "SEKERY"
var inventory: Dictionary = {
	"sharpened_axe": 0,
	"frame_saw": 0,
	"aku_saw": 0,
	"wheelbarrow": 0,
	"handcart": 0
}

func _ready() -> void:
	load_inventory()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	for node in _all_nodes(main):
		if node is Button and (node as Button).text == "OBCHOD":
			var button := node as Button
			if button != watched_shop_button:
				watched_shop_button = button
				if not button.pressed.is_connected(_on_shop_pressed):
					button.pressed.connect(_on_shop_pressed)
			return

func _on_shop_pressed() -> void:
	call_deferred("_render_shop")

func _render_shop() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var host_value = main.get("content_host")
	if not (host_value is MarginContainer):
		return
	var host := host_value as MarginContainer
	for child in host.get_children():
		child.queue_free()
	await get_tree().process_frame
	if not is_instance_valid(host):
		return

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	host.add_child(root)

	var title := _make_label(main, "OBCHOD", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	for category in CATEGORIES:
		var b := Button.new()
		b.text = category
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 42
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_switch_category.bind(category))
		tabs.add_child(b)

	var category_host := VBoxContainer.new()
	category_host.name = "ShopCategoryHost"
	category_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_host.add_theme_constant_override("separation", 10)
	root.add_child(category_host)
	_render_category(main, category_host)

func _switch_category(category: String) -> void:
	current_category = category
	var main := get_tree().current_scene
	if main == null:
		return
	var host := _find_named_node(main, "ShopCategoryHost")
	if host is VBoxContainer:
		for child in host.get_children():
			child.queue_free()
		await get_tree().process_frame
		if is_instance_valid(host):
			_render_category(main, host as VBoxContainer)

func _render_category(main: Node, host: VBoxContainer) -> void:
	var header := _make_label(main, current_category, 21)
	header.add_theme_color_override("font_color", Color("#ffca42"))
	host.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	host.add_child(grid)

	for item_id in ITEMS.keys():
		var item: Dictionary = ITEMS[item_id]
		if str(item["category"]) == current_category:
			_add_item_card(main, grid, str(item_id), item)

func _add_item_card(main: Node, grid: GridContainer, item_id: String, item: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#6b4628", 7, 1))
	grid.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var asset_path: String = str(item.get("asset", ""))
	if asset_path != "" and ResourceLoader.exists(asset_path):
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(120, 120)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var res := ResourceLoader.load(asset_path)
		if res is Texture2D:
			tex.texture = res as Texture2D
		row.add_child(tex)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)

	var name_label := _make_label(main, str(item["name"]), 20)
	name_label.add_theme_color_override("font_color", Color("#ffca42"))
	info.add_child(name_label)
	info.add_child(_make_label(main, str(item["desc"]), 14))

	var price: int = int(item["price"])
	var owned: int = _owned_count(main, item_id)
	var price_text := "Startovní výbava" if price <= 0 else "%d Kč" % price
	info.add_child(_make_label(main, "Cena: %s  •  Vlastníš: %d" % [price_text, owned], 14))

	var action := Button.new()
	action.custom_minimum_size.y = 36
	if item_id == "wooden_axe":
		action.text = "VYBAVIT"
		action.disabled = false
		action.pressed.connect(_equip_axe.bind("wooden"))
	elif item_id == "sharpened_axe" and owned > 0:
		action.text = "VYBAVIT"
		action.pressed.connect(_equip_axe.bind("sharpened"))
	else:
		action.text = "KOUPIT ZA %d Kč" % price
		action.disabled = float(_main_state(main).get("money", 0.0)) < float(price)
		action.pressed.connect(_buy_item.bind(item_id))
	info.add_child(action)

func _buy_item(item_id: String) -> void:
	if not ITEMS.has(item_id):
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var item: Dictionary = ITEMS[item_id]
	var price: int = int(item["price"])
	var state := _main_state(main)
	if float(state.get("money", 0.0)) < float(price):
		return
	state["money"] = float(state.get("money", 0.0)) - float(price)
	if item_id == "sharpened_axe":
		state["sharpened_axe_qty"] = int(state.get("sharpened_axe_qty", 0)) + 1
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	else:
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	save_inventory()
	_refresh_category()

func _equip_axe(axe_id: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var state := _main_state(main)
	if axe_id == "sharpened" and int(state.get("sharpened_axe_qty", 0)) <= 0 and int(inventory.get("sharpened_axe", 0)) <= 0:
		return
	state["equipped_axe"] = axe_id
	main.set("state", state)
	main.call("save_game")
	_refresh_category()

func _refresh_category() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var host := _find_named_node(main, "ShopCategoryHost")
	if host is VBoxContainer:
		for child in host.get_children():
			child.queue_free()
		await get_tree().process_frame
		if is_instance_valid(host):
			_render_category(main, host as VBoxContainer)

func _owned_count(main: Node, item_id: String) -> int:
	var state := _main_state(main)
	if item_id == "wooden_axe":
		return maxi(1, int(state.get("wooden_axe_qty", 1)))
	if item_id == "sharpened_axe":
		return maxi(int(state.get("sharpened_axe_qty", 0)), int(inventory.get(item_id, 0)))
	return int(inventory.get(item_id, 0))

func _main_state(main: Node) -> Dictionary:
	var value = main.get("state")
	if value is Dictionary:
		return value as Dictionary
	return {}

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

func _find_named_node(root: Node, node_name: String) -> Node:
	for node in _all_nodes(root):
		if node.name == node_name:
			return node
	return null

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result

func save_inventory() -> void:
	var f := FileAccess.open(SHOP_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(inventory))

func load_inventory() -> void:
	if not FileAccess.file_exists(SHOP_SAVE_PATH):
		return
	var f := FileAccess.open(SHOP_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in inventory.keys():
			if parsed.has(key):
				inventory[key] = int(parsed[key])
