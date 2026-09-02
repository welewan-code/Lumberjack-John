extends "res://shop_ui_splitter.gd"

func _add_item_card(main: Node, grid: GridContainer, item_id: String, item: Dictionary) -> void:
	super._add_item_card(main, grid, item_id, item)
	if grid.get_child_count() == 0:
		return
	var card: Node = grid.get_child(grid.get_child_count() - 1)
	for node: Node in _all_nodes(card):
		if node is Button and (node as Button).text == "VYBAVIT":
			(node as Button).queue_free()

func _add_checht_preview(row: HBoxContainer, _asset_path: String) -> void:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(120, 120)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var image: Image = Image.load_from_file("res://assets/tools/checht_axe.png")
	if image != null and not image.is_empty():
		tex.texture = ImageTexture.create_from_image(image)
	row.add_child(tex)
