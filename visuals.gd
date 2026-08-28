extends Control

const SHOP_CATEGORY_LABELS: Array[String] = ["SEKERY", "PILY", "DOPRAVNÍ PROSTŘEDKY"]
const COMPANY_BG_CANDIDATES: Array[String] = [
	"res://assets/backgrounds/company_yard.png",
	"res://assets/backgrounds/sluncem_zalitý_dvůr_venkovské_chalupy.png",
	"res://assets/backgrounds/sluncem_zality_dvur_venkovske_chalupy.png",
	"res://assets/sluncem_zalitý_dvůr_venkovské_chalupy.png"
]

var game: Node
var company_background: TextureRect

func _ready() -> void:
	game = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_company_background()
	set_process(true)

func _build_company_background() -> void:
	company_background = TextureRect.new()
	company_background.name = "CompanyYardBackground"
	company_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	company_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	company_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	company_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	company_background.offset_top = 84.0
	company_background.offset_bottom = -58.0
	company_background.z_index = 10
	company_background.visible = false
	add_child(company_background)

	var texture := _load_company_background_texture()
	if texture != null:
		company_background.texture = texture

func _load_company_background_texture() -> Texture2D:
	for path in COMPANY_BG_CANDIDATES:
		if ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path)
			if resource is Texture2D:
				return resource as Texture2D

	# Fallback: vezmi první obrázek ze složky backgrounds, i když má jiný název.
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var lower := file_name.to_lower()
				if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
					var path := "res://assets/backgrounds/" + file_name
					if ResourceLoader.exists(path):
						var resource := ResourceLoader.load(path)
						if resource is Texture2D:
							dir.list_dir_end()
							return resource as Texture2D
			file_name = dir.get_next()
		dir.list_dir_end()
	return null

func _process(_delta: float) -> void:
	if game == null:
		return

	var tab: String = ""
	if "current_tab" in game:
		tab = str(game.current_tab)

	if is_instance_valid(company_background):
		# Když obrázek Godot naimportuje až po startu editoru, zkus ho znovu načíst.
		if tab == "FIRMA" and company_background.texture == null:
			var texture := _load_company_background_texture()
			if texture != null:
				company_background.texture = texture
		company_background.visible = tab == "FIRMA" and company_background.texture != null

	if tab != "OBCHOD":
		return

	# In the shop, category names belong only on the category buttons.
	# Hide duplicate standalone headers such as the permanent "SEKERY" label.
	for node in _all_nodes(game):
		if node is Label:
			var label := node as Label
			if label.text in SHOP_CATEGORY_LABELS:
				label.visible = false

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result
