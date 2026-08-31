extends "res://shop_ui.gd"

const PARKSAJT_ITEM_ID: String = "parksajt_saw"
const PARKSAJT_ITEM: Dictionary = {
	"category": "PILY",
	"name": "Motorová pila Parksajt",
	"price": 1200,
	"asset": "res://assets/tools/parksajt_chainsaw.png",
	"desc": "Motorová pila Parksajt • 30 cm lišta • řezání 12 s."
}

func _ready() -> void:
	if not inventory.has(PARKSAJT_ITEM_ID):
		inventory[PARKSAJT_ITEM_ID] = 0
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

func _buy_item(item_id: String) -> void:
	if item_id != PARKSAJT_ITEM_ID:
		super._buy_item(item_id)
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var price: int = int(PARKSAJT_ITEM["price"])
	var state: Dictionary = _main_state(main)
	if float(state.get("money", 0.0)) < float(price):
		return
	state["money"] = float(state.get("money", 0.0)) - float(price)
	inventory[PARKSAJT_ITEM_ID] = int(inventory.get(PARKSAJT_ITEM_ID, 0)) + 1
	main.set("state", state)
	main.call("update_hud")
	main.call("save_game")
	save_inventory()
	_refresh_category()
