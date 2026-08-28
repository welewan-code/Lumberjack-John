extends Node

var last_tab: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var tab: String = str(main.get("current_tab"))
	if tab == "FIRMA" and last_tab != "FIRMA":
		call_deferred("_render_company", main)
	last_tab = tab

func _render_company(main: Node) -> void:
	var host_value = main.get("content_host")
	if not (host_value is MarginContainer):
		return
	var host := host_value as MarginContainer
	for child in host.get_children():
		child.queue_free()
	await get_tree().process_frame
	if not is_instance_valid(host):
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	host.add_child(row)

	var left := _side_panel(main, "FIRMA", 250)
	row.add_child(left)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(main, "#17120f", "#6b4628", 7, 1))
	row.add_child(center_panel)

	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _load_company_background()
	center_panel.add_child(image)

	var right := _side_panel(main, "PŘEHLED", 270)
	row.add_child(right)

func _side_panel(main: Node, title_text: String, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(main, "#1b1713", "#5f4027", 7, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := _make_label(main, title_text, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffca42"))
	box.add_child(title)
	var hint := _make_label(main, "", 14)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(hint)
	return panel

func _load_company_background() -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/backgrounds/company_yard.png",
		"res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png",
		"res://assets/sluncem_zalitý_dvůr_venkovské_chalupy.png"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res := ResourceLoader.load(path)
			if res is Texture2D:
				return res as Texture2D
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
				var path := "res://assets/backgrounds/" + file_name
				if ResourceLoader.exists(path):
					var res := ResourceLoader.load(path)
					if res is Texture2D:
						return res as Texture2D
			file_name = dir.get_next()
		dir.list_dir_end()
	return null

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
