extends Control

const SHOP_CATEGORY_LABELS: Array[String] = ["SEKERY", "PILY", "DOPRAVNÍ PROSTŘEDKY"]

var game: Node

func _ready() -> void:
	game = get_parent()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	if game == null:
		return
	var tab: String = ""
	if "current_tab" in game:
		tab = str(game.current_tab)
	if tab != "OBCHOD":
		return

	# In the shop, category names belong only on the category buttons.
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
