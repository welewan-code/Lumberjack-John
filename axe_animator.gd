extends Node

# Drží právě vybavenou sekeru přímo v rukou pracovníka.
# WorkRewards vytváří node EquippedAxe a přepíná snímky postavy;
# tenhle skript každý frame přesně zarovná sekeru na ruce podle aktuálního snímku.

const WOODEN_AXE_PATH: String = "res://assets/tools/wooden_axe.png"
const SHARPENED_AXE_PATH: String = "res://assets/tools/sharpened_axe.png"
const CHECHT_AXE_PATH: String = "res://assets/tools/checht_axe.png"
const FICKARS_AXE_PATH: String = "res://assets/tools/fickars_axe.png"

var last_equipped: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return

	var player := _find_player(main)
	var axe := _find_axe(main)
	if player == null or axe == null:
		return

	_update_texture(main, axe)
	_apply_hand_pose(player, axe)

func _find_player(root: Node) -> TextureRect:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TextureRect:
			var rect := node as TextureRect
			if rect.texture != null:
				var path: String = rect.texture.resource_path
				if path.contains("player_wood_") or path.contains("player_sharp_"):
					return rect
		for child in node.get_children():
			stack.append(child)
	return null

func _find_axe(root: Node) -> TextureRect:
	var found := root.find_child("EquippedAxe", true, false)
	if found is TextureRect:
		return found as TextureRect
	return null

func _load_png_direct(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _update_texture(main: Node, axe: TextureRect) -> void:
	var equipped: String = "wooden"
	var state_value = main.get("state")
	if state_value is Dictionary:
		equipped = str((state_value as Dictionary).get("equipped_axe", "wooden"))

	if equipped == last_equipped and axe.texture != null:
		return
	last_equipped = equipped

	var path: String = WOODEN_AXE_PATH
	match equipped:
		"sharpened":
			path = SHARPENED_AXE_PATH
		"checht":
			path = CHECHT_AXE_PATH
		"fickars":
			path = FICKARS_AXE_PATH

	var direct_texture: Texture2D = _load_png_direct(path)
	if direct_texture != null:
		axe.texture = direct_texture
		return
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			axe.texture = resource as Texture2D

func _apply_hand_pose(player: TextureRect, axe: TextureRect) -> void:
	# Samostatná sekera je větší než dřív a otáčí se kolem konce topůrka,
	# tedy přesně kolem místa, kde ji pracovník svírá.
	axe.size = Vector2(118.0, 118.0)
	axe.pivot_offset = Vector2(12.0, 106.0)
	axe.z_index = player.z_index + 8
	axe.scale = Vector2.ONE

	var frame: int = _frame_number(player)
	var hand: Vector2
	var angle_deg: float

	match frame:
		2:
			# Nápřah – ruce nad hlavou.
			hand = Vector2(111.0, 62.0)
			angle_deg = -22.0
		3:
			# Dopad – topůrko vede z rukou přímo ke špalku.
			hand = Vector2(128.0, 126.0)
			angle_deg = 96.0
		4:
			# Dojezd po seku.
			hand = Vector2(131.0, 135.0)
			angle_deg = 72.0
		_:
			# Klidová pozice – sekera leží přirozeně v obou rukách.
			hand = Vector2(121.0, 134.0)
			angle_deg = 62.0

	axe.position = player.position + hand - axe.pivot_offset
	axe.rotation = deg_to_rad(angle_deg)

func _frame_number(player: TextureRect) -> int:
	if player.texture == null:
		return 1
	var path: String = player.texture.resource_path
	for i in range(1, 5):
		if path.ends_with("_%d.png" % i):
			return i
	return 1
