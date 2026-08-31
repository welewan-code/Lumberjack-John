extends "res://company_ui.gd"

const PARKSAJT_TOOL_ID: String = "parksajt_saw"
const PARKSAJT_SAW_TIME: float = 12.0

func _populate_slot_tools(main: Node, tools: OptionButton, slot_index: int) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	tools.add_item("Bez nástroje")
	tools.set_item_metadata(tools.item_count - 1, "")
	var tool_ids: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw", PARKSAJT_TOOL_ID]
	for tool_id: String in tool_ids:
		var owned: int = _owned_tool_count(tool_id)
		var used_total: int = _assigned_tool_count(slots, tool_id)
		var free_total: int = maxi(0, owned - used_total)
		if tool_id == current_tool:
			tools.add_item("%s • přiřazeno zde • vlastníš %d" % [_tool_menu_name(tool_id), owned])
			tools.set_item_metadata(tools.item_count - 1, tool_id)
		elif free_total > 0:
			tools.add_item("%s • volné %d/%d" % [_tool_menu_name(tool_id), free_total, owned])
			tools.set_item_metadata(tools.item_count - 1, tool_id)

func _is_known_tool(tool_id: String) -> bool:
	if tool_id == PARKSAJT_TOOL_ID:
		return true
	return super._is_known_tool(tool_id)

func _tool_role(tool_id: String) -> String:
	if tool_id == PARKSAJT_TOOL_ID:
		return "sawyer"
	return super._tool_role(tool_id)

func _tool_name(tool_id: String) -> String:
	if tool_id == PARKSAJT_TOOL_ID:
		return "Motorová pila Parksajt"
	return super._tool_name(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == PARKSAJT_TOOL_ID:
		return PARKSAJT_SAW_TIME
	return super._tool_cycle_time(tool_id)
