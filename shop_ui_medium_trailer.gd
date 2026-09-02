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
