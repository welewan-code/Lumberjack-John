extends "res://company_ui_parksajt.gd"

const CHECHT_SPLITTER_TOOL_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_TIME: float = 3.5
const CHECHT_SPLITTER_IN_M3: float = 0.040
const CHECHT_SPLITTER_OUT_M3: float = 0.080

func _populate_slot_tools(main: Node, tools: OptionButton, slot_index: int) -> void:
	super._populate_slot_tools(main, tools, slot_index)
	var state: Dictionary = _state(main)
	var slots: Array = _work_slots(state)
	var current_tool: String = str((slots[slot_index] as Dictionary).get("tool", ""))
	var owned: int = _owned_tool_count(CHECHT_SPLITTER_TOOL_ID)
	var used_total: int = _assigned_tool_count(slots, CHECHT_SPLITTER_TOOL_ID)
	var free_total: int = maxi(0, owned - used_total)
	if CHECHT_SPLITTER_TOOL_ID == current_tool:
		tools.add_item("%s • přiřazeno zde • vlastníš %d" % [_tool_menu_name(CHECHT_SPLITTER_TOOL_ID), owned])
		tools.set_item_metadata(tools.item_count - 1, CHECHT_SPLITTER_TOOL_ID)
	elif free_total > 0:
		tools.add_item("%s • volné %d/%d" % [_tool_menu_name(CHECHT_SPLITTER_TOOL_ID), free_total, owned])
		tools.set_item_metadata(tools.item_count - 1, CHECHT_SPLITTER_TOOL_ID)

func _is_known_tool(tool_id: String) -> bool:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return true
	return super._is_known_tool(tool_id)

func _tool_role(tool_id: String) -> String:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return "splitter"
	return super._tool_role(tool_id)

func _tool_name(tool_id: String) -> String:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return "Štípačka CHECHT – 4 klín"
	return super._tool_name(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return CHECHT_SPLITTER_TIME
	return super._tool_cycle_time(tool_id)

func _do_split_cycle(state: Dictionary, tool_id: String) -> bool:
	if tool_id != CHECHT_SPLITTER_TOOL_ID:
		return super._do_split_cycle(state, tool_id)
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return false
	var available: float = float(state.get("roundwood_m3", 0.0))
	if available + 0.0001 < CHECHT_SPLITTER_IN_M3:
		return false
	var net_growth: float = CHECHT_SPLITTER_OUT_M3 - CHECHT_SPLITTER_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return false
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["roundwood_m3"] = maxf(0.0, available - CHECHT_SPLITTER_IN_M3)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + CHECHT_SPLITTER_OUT_M3
	return true
