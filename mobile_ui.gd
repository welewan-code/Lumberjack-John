extends Node

const MOBILE_UI_SCALE: float = 1.10
const TOUCH_MIN_HEIGHT: float = 56.0
const NAV_MIN_HEIGHT: float = 68.0
const DIALOG_MIN_SIZE: Vector2i = Vector2i(560, 420)
const NAV_TABS: Array[String] = ["FIRMA", "PRÁCE", "OBCHOD", "SKLAD", "STATISTIKY", "ÚSPĚCHY", "NASTAVENÍ"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_existing_tree")
	if OS.has_feature("mobile"):
		get_tree().root.content_scale_factor = MOBILE_UI_SCALE
	if OS.has_feature("mobile") and DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _on_node_added(node: Node) -> void:
	if node is AcceptDialog:
		call_deferred("_apply_dialog", node)
	elif node is Control:
		call_deferred("_apply_control", node)

func _apply_existing_tree() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AcceptDialog:
			_apply_dialog(node as AcceptDialog)
		elif node is Control:
			_apply_control(node as Control)
		for child: Node in node.get_children():
			stack.append(child)

func _apply_dialog(dialog: AcceptDialog) -> void:
	if not is_instance_valid(dialog):
		return
	dialog.min_size = DIALOG_MIN_SIZE
	var ok_button: Button = dialog.get_ok_button()
	if is_instance_valid(ok_button):
		_apply_button(ok_button)

func _apply_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if control is Button:
		_apply_button(control as Button)
	elif control is SpinBox:
		var spin: SpinBox = control as SpinBox
		spin.custom_minimum_size.y = maxf(spin.custom_minimum_size.y, TOUCH_MIN_HEIGHT)
	elif control is LineEdit:
		var line: LineEdit = control as LineEdit
		line.custom_minimum_size.y = maxf(line.custom_minimum_size.y, TOUCH_MIN_HEIGHT)

func _apply_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var target_height: float = NAV_MIN_HEIGHT if button.text in NAV_TABS else TOUCH_MIN_HEIGHT
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, target_height)
	if button.text in NAV_TABS:
		button.add_theme_font_size_override("font_size", 16)
