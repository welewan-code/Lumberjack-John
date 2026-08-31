extends "res://shop_ui_parksajt.gd"

const CHECHT_SPLITTER_ITEM_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_ITEM: Dictionary = {
	"category": "ŠTÍPAČKY",
	"name": "Štípačka CHECHT – 4 klín",
	"price": 11990,
	"asset": "res://assets/tools/checht_splitter.png",
	"desc": "Cyklus 3,5 s • 0,040 m³ špalků → 0,080 m³ štípaného • 4 klín."
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

func _load_shop_texture(asset_path: String) -> Texture2D:
	if asset_path == "res://assets/tools/checht_splitter.png":
		var image: Image = Image.load_from_file(asset_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return super._load_shop_texture(asset_path)
