extends "res://shop_ui_splitter.gd"

func _add_item_card(main: Node, grid: GridContainer, item_id: String, item: Dictionary) -> void:
	var display_item: Dictionary = item.duplicate(true)
	if item_id == "checht_axe":
		display_item["asset"] = "res://assets/tools/checht_axe.png"
	super._add_item_card(main, grid, item_id, display_item)
	if grid.get_child_count() == 0:
		return
	var card: Node = grid.get_child(grid.get_child_count() - 1)
	for node: Node in _all_nodes(card):
		if node is Button and (node as Button).text == "VYBAVIT":
			(node as Button).queue_free()

func _load_png_direct(asset_path: String) -> Texture2D:
	if not FileAccess.file_exists(asset_path):
		return null
	var file: FileAccess = FileAccess.open(asset_path, FileAccess.READ)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _load_shop_texture(asset_path: String) -> Texture2D:
	if asset_path.to_lower().ends_with(".png"):
		var direct_texture: Texture2D = _load_png_direct(asset_path)
		if direct_texture != null:
			return direct_texture
	return super._load_shop_texture(asset_path)

func _add_checht_preview(row: HBoxContainer, asset_path: String) -> void:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(120, 120)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var loaded_tex: Texture2D = _load_shop_texture(asset_path)
	if loaded_tex != null:
		tex.texture = loaded_tex
	row.add_child(tex)
