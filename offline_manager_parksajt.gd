extends "res://offline_manager.gd"

const PARKSAJT_TOOL_ID: String = "parksajt_saw"
const PARKSAJT_SAW_TIME: float = 12.0

func _tool_role(tool_id: String) -> String:
	if tool_id == PARKSAJT_TOOL_ID:
		return "sawyer"
	return super._tool_role(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == PARKSAJT_TOOL_ID:
		return PARKSAJT_SAW_TIME
	return super._tool_cycle_time(tool_id)
