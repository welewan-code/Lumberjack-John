extends Node

var connected_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	for node in _all_nodes(main):
		if node is Button:
			var button := node as Button
			if button.text in ["FIRMA", "PRÁCE", "OBCHOD", "SKLAD", "STATISTIKY", "ÚSPĚCHY", "NASTAVENÍ"]:
				button.mouse_filter = Control.MOUSE_FILTER_STOP
				button.z_index = 10000
				var key := button.get_instance_id()
				if not connected_buttons.has(key):
					connected_buttons[key] = true
					button.pressed.connect(_open_tab.bind(button.text))

func _open_tab(tab_name: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if main.has_method("show_tab"):
		main.call("show_tab", tab_name)

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result
