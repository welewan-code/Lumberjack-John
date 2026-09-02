extends "res://shop_ui_no_equip.gd"

const MEDIUM_TRAILER_ITEM_ID: String = "medium_trailer"
const MEDIUM_TRAILER_ITEM: Dictionary = {
	"category": "DOPRAVNÍ PROSTŘEDKY",
	"name": "Střední vozík za auto",
	"price": 13900,
	"asset": "res://Střední vozík za auto.png",
	"desc": "Odveze 1,0 m³. Náklady na velké objednávky 3 Kč/km."
}

func _ready() -> void:
	if not inventory.has(MEDIUM_TRAILER_ITEM_ID):
		inventory[MEDIUM_TRAILER_ITEM_ID] = 0
	super._ready()

func _render_category(main: Node, host: VBoxContainer) -> void:
	super._render_category(main, host)
	if current_category != "DOPRAVNÍ PROSTŘEDKY":
		return
	var grid: GridContainer = null
	for child: Node in host.get_children():
		if child is GridContainer:
			grid = child as GridContainer
			break
	if grid != null:
		_add_item_card(main, grid, MEDIUM_TRAILER_ITEM_ID, MEDIUM_TRAILER_ITEM)

func _add_item_card(main: Node, grid: GridContainer, item_id: String, item: Dictionary) -> void:
	if item_id == "checht_axe":
		var checht_item: Dictionary = item.duplicate(true)
		checht_item["asset"] = "res://checht sekera 2.png"
		super._add_item_card(main, grid, item_id, checht_item)
		return
	super._add_item_card(main, grid, item_id, item)

func _add_checht_preview(row: HBoxContainer, asset_path: String) -> void:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(120, 120)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var loaded_tex: Texture2D = _load_shop_texture(asset_path)
	if loaded_tex != null:
		tex.texture = loaded_tex
	row.add_child(tex)

func _buy_item(item_id: String) -> void:
	if item_id != MEDIUM_TRAILER_ITEM_ID:
		super._buy_item(item_id)
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var price: int = int(MEDIUM_TRAILER_ITEM["price"])
	var state: Dictionary = _main_state(main)
	if float(state.get("money", 0.0)) < float(price):
		return
	state["money"] = float(state.get("money", 0.0)) - float(price)
	inventory[MEDIUM_TRAILER_ITEM_ID] = int(inventory.get(MEDIUM_TRAILER_ITEM_ID, 0)) + 1
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	save_inventory()
	_refresh_category()
