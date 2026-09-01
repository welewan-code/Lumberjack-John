extends "res://company_ui.gd"

const PARKSAJT_TOOL_ID: String = "parksajt_saw"
const CHECHT_950_TOOL_ID: String = "checht_950_saw"
const OJELO_MAG_TOOL_ID: String = "ojelo_mag_gs400_saw"
const PARKSAJT_SAW_TIME: float = 12.0
const CHECHT_950_SAW_TIME: float = 10.0
const OJELO_MAG_SAW_TIME: float = 8.0
const OJELO_MAG_SAW_IN_M3: float = 0.027
const OJELO_MAG_SAW_OUT_M3: float = 0.036
const EMPLOYEE_AXE_HANDLING_TIME: float = 2.0

func _populate_slot_tools(main: Node, tools: OptionButton, slot_index: int) -> void:
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	tools.add_item("Bez nástroje")
	tools.set_item_metadata(tools.item_count - 1, "")
	var tool_ids: Array[String] = ["wooden_axe", "sharpened_axe", "checht_axe", "fickars_axe", "frame_saw", "aku_saw", PARKSAJT_TOOL_ID, CHECHT_950_TOOL_ID, OJELO_MAG_TOOL_ID]
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
	if tool_id == PARKSAJT_TOOL_ID or tool_id == CHECHT_950_TOOL_ID or tool_id == OJELO_MAG_TOOL_ID:
		return true
	return super._is_known_tool(tool_id)

func _tool_role(tool_id: String) -> String:
	if tool_id == PARKSAJT_TOOL_ID or tool_id == CHECHT_950_TOOL_ID or tool_id == OJELO_MAG_TOOL_ID:
		return "sawyer"
	return super._tool_role(tool_id)

func _tool_name(tool_id: String) -> String:
	if tool_id == PARKSAJT_TOOL_ID:
		return "Motorová pila Parksajt"
	if tool_id == CHECHT_950_TOOL_ID:
		return "Motorová pila CHECHT 950"
	if tool_id == OJELO_MAG_TOOL_ID:
		return "Motorová pila Ojelo Mag GS400"
	return super._tool_name(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == PARKSAJT_TOOL_ID:
		return PARKSAJT_SAW_TIME
	if tool_id == CHECHT_950_TOOL_ID:
		return CHECHT_950_SAW_TIME
	if tool_id == OJELO_MAG_TOOL_ID:
		return OJELO_MAG_SAW_TIME
	var base_time: float = super._tool_cycle_time(tool_id)
	if super._tool_role(tool_id) == "splitter":
		return base_time + EMPLOYEE_AXE_HANDLING_TIME
	return base_time

func _do_saw_cycle(state: Dictionary, tool_id: String) -> bool:
	if tool_id != OJELO_MAG_TOOL_ID:
		return super._do_saw_cycle(state, tool_id)
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return false
	if float(state.get("logs_m3", 0.0)) + 0.0001 < OJELO_MAG_SAW_IN_M3:
		return false
	var net_growth: float = OJELO_MAG_SAW_OUT_M3 - OJELO_MAG_SAW_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["logs_m3"] = maxf(0.0, float(state.get("logs_m3", 0.0)) - OJELO_MAG_SAW_IN_M3)
	state["roundwood_m3"] = float(state.get("roundwood_m3", 0.0)) + OJELO_MAG_SAW_OUT_M3
	return true