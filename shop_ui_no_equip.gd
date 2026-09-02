extends "res://shop_ui_splitter.gd"

func _add_item_card(main: Node, grid: GridContainer, item_id: String, item: Dictionary) -> void:
	super._add_item_card(main, grid, item_id, item)
	if grid.get_child_count() == 0:
		return
	var card: Node = grid.get_child(grid.get_child_count() - 1)
	for node: Node in _all_nodes(card):
		if node is Button and (node as Button).text == "VYBAVIT":
			(node as Button).queue_free()
