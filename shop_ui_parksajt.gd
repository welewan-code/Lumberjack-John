extends "res://shop_ui.gd"

const PARKSAJT_ITEM_ID: String = "parksajt_saw"
const CHECHT_950_ITEM_ID: String = "checht_950_saw"

const PARKSAJT_ITEM: Dictionary = {
	"category": "PILY",
	"name": "Motorová pila Parksajt",
	"price": 1200,
	"asset": "res://assets/tools/parksajt_chainsaw.png",
	"desc": "Motorová pila Parksajt • 30 cm lišta • řezání 12 s."
}

const CHECHT_950_ITEM: Dictionary = {
	"category": "PILY",
	"name": "Motorová pila CHECHT 950",
	"price": 2600,
	"asset": "res://motorová pila Checht 950.png",
	"desc": "Motorová pila CHECHT 950 • 30 cm lišta • řezání 10 s."
}

func _ready() -> void:
	if not inventory.has(PARKSAJT_ITEM_ID):
		inventory[PARKSAJT_ITEM_ID] = 0
	if not inventory.has(CHECHT_950_ITEM_ID):
		inventory[CHECHT_950_ITEM_ID] = 0
	super._ready()

func _render_category(main: Node, host: VBoxContainer) -> void:
	super._render_category(main, host)
	if current_category != "PILY":
		return
	var grid: GridContainer = null
	for child: Node in host.get_children():
		if child is GridContainer:
			grid = child as GridContainer
			break
	if grid != null:
		_add_item_card(main, grid, PARKSAJT_ITEM_ID, PARKSAJT_ITEM)
		_add_item_card(main, grid, CHECHT_950_ITEM_ID, CHECHT_950_ITEM)

func _load_shop_texture(asset_path: String) -> Texture2D:
	if asset_path == "res://motorová pila Checht 950.png":
		var image: Image = Image.load_from_file(asset_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return super._load_shop_texture(asset_path)

func _buy_item(item_id: String) -> void:
	if item_id != PARKSAJT_ITEM_ID and item_id != CHECHT_950_ITEM_ID:
		super._buy_item(item_id)
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var item: Dictionary = PARKSAJT_ITEM if item_id == PARKSAJT_ITEM_ID else CHECHT_950_ITEM
	var price: int = int(item["price"])
	var state: Dictionary = _main_state(main)
	if float(state.get("money", 0.0)) < float(price):
		return
	state["money"] = float(state.get("money", 0.0)) - float(price)
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	save_inventory()
	_refresh_category()
