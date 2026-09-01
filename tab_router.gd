extends Node

var connected_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var employed: bool = _is_employed(main)
	_update_role(main, employed)
	for node in _all_nodes(main):
		if node is Button:
			var button := node as Button
			if button.text == "PRÁCE" and not employed:
				button.text = "PODNIKATEL"
			if button.text in ["FIRMA", "PRÁCE", "PODNIKATEL", "OBCHOD", "SKLAD", "STATISTIKY", "ÚSPĚCHY", "NASTAVENÍ"]:
				button.mouse_filter = Control.MOUSE_FILTER_STOP
				button.z_index = 100
				_connect_once(button, "tab")
			elif button.text == "ODEJÍT Z PRÁCE":
				_connect_once(button, "quit")

func _connect_once(button: Button, kind: String) -> void:
	var key: String = "%s:%s" % [button.get_instance_id(), kind]
	if connected_buttons.has(key):
		return
	connected_buttons[key] = true
	if kind == "quit":
		button.pressed.connect(_quit_job)
	else:
		button.pressed.connect(_open_button_tab.bind(button))

func _open_button_tab(button: Button) -> void:
	var tab_name: String = button.text
	var main := get_tree().current_scene
	if main == null:
		return
	if tab_name == "PODNIKATEL":
		if main.has_method("show_tab"):
			main.call("show_tab", "PODNIKATEL")
		return
	if main.has_method("show_tab"):
		main.call("show_tab", tab_name)

func _quit_job() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var state_value: Variant = main.get("state")
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value as Dictionary
	state["employed"] = false
	state["current_job"] = "entrepreneur"
	main.set("state", state)
	if main.has_method("save_game"):
		main.call("save_game")
	if main.has_method("update_hud"):
		main.call("update_hud")
	_update_role(main, false)
	if main.has_method("show_tab"):
		main.call("show_tab", "PODNIKATEL")

func _is_employed(main: Node) -> bool:
	var state_value: Variant = main.get("state")
	if state_value is Dictionary:
		return bool((state_value as Dictionary).get("employed", true))
	return true

func _update_role(main: Node, employed: bool) -> void:
	var role_value: Variant = main.get("role_label")
	if role_value is Label and is_instance_valid(role_value):
		var role := role_value as Label
		role.text = "Pomocník ve dřevárně" if employed else "Podnikatel"

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result