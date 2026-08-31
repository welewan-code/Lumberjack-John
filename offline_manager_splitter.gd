extends "res://offline_manager_parksajt.gd"

const CHECHT_SPLITTER_TOOL_ID: String = "checht_splitter_4way"
const CHECHT_SPLITTER_TIME: float = 3.5
const CHECHT_SPLITTER_IN_M3: float = 0.040
const CHECHT_SPLITTER_OUT_M3: float = 0.080

func _tool_role(tool_id: String) -> String:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return "splitter"
	return super._tool_role(tool_id)

func _tool_cycle_time(tool_id: String) -> float:
	if tool_id == CHECHT_SPLITTER_TOOL_ID:
		return CHECHT_SPLITTER_TIME
	return super._tool_cycle_time(tool_id)

func _try_split_cycle(state: Dictionary, tool_id: String) -> int:
	if tool_id != CHECHT_SPLITTER_TOOL_ID:
		return super._try_split_cycle(state, tool_id)
	var cycle_wage: float = _tool_cycle_wage(tool_id)
	if float(state.get("money", 0.0)) + 0.0001 < cycle_wage:
		return CYCLE_NO_MONEY
	var available: float = float(state.get("roundwood_m3", 0.0))
	if available + 0.0001 < CHECHT_SPLITTER_IN_M3:
		return CYCLE_NO_INPUT
	var net_growth: float = CHECHT_SPLITTER_OUT_M3 - CHECHT_SPLITTER_IN_M3
	if _storage_used(state) + net_growth > STORAGE_CAPACITY + 0.0001:
		return CYCLE_STORAGE_FULL
	state["money"] = maxf(0.0, float(state.get("money", 0.0)) - cycle_wage)
	state["roundwood_m3"] = maxf(0.0, available - CHECHT_SPLITTER_IN_M3)
	state["split_m3"] = float(state.get("split_m3", 0.0)) + CHECHT_SPLITTER_OUT_M3
	return CYCLE_SUCCESS
