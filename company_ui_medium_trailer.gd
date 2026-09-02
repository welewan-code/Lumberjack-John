extends "res://company_ui_player_tools.gd"

const MEDIUM_TRAILER_ID: String = "medium_trailer"

func _build_left(main: Node) -> PanelContainer:
	var panel: PanelContainer = super._build_left(main)
	var selector: OptionButton = _find_transport_selector(panel)
	if selector == null:
		return panel
	var current_transport: String = _selected_transport(main)
	if _owned_transport(MEDIUM_TRAILER_ID) <= 0 and current_transport != MEDIUM_TRAILER_ID:
		return panel
	for index: int in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == MEDIUM_TRAILER_ID:
			return panel
	selector.add_item(_transport_name(MEDIUM_TRAILER_ID))
	selector.set_item_metadata(selector.item_count - 1, MEDIUM_TRAILER_ID)
	if current_transport == MEDIUM_TRAILER_ID:
		selector.select(selector.item_count - 1)
	return panel

func _find_transport_selector(root: Node) -> OptionButton:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is OptionButton:
			var option: OptionButton = node as OptionButton
			for index: int in range(option.item_count):
				if str(option.get_item_metadata(index)) == "small_trailer":
					return option
		for child: Node in node.get_children():
			stack.append(child)
	return null

func _transport_name(item_id: String) -> String:
	if item_id == MEDIUM_TRAILER_ID:
		return "Střední vozík za auto – 1,0 m³"
	return super._transport_name(item_id)
