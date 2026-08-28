extends Node

var watched_button: Button = null
var reward_pending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var button = main.get("chop_button")
	if button is Button and button != watched_button:
		watched_button = button as Button
		if not watched_button.pressed.is_connected(_on_work_pressed):
			watched_button.pressed.connect(_on_work_pressed)

func _on_work_pressed() -> void:
	if reward_pending:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	if bool(main.get("action_running")):
		return
	reward_pending = true
	var duration: float = float(main.call("axe_time"))
	await get_tree().create_timer(duration + 0.05).timeout
	main = get_tree().current_scene
	if main != null:
		var state_value = main.get("state")
		if state_value is Dictionary:
			var state: Dictionary = state_value
			var pay: int = randi_range(1, 3)
			var xp_gain: int = randi_range(1, 5)
			state["money"] = float(state.get("money", 0.0)) + pay
			state["xp"] = int(state.get("xp", 0)) + xp_gain
			state["work_clicks"] = int(state.get("work_clicks", 0)) + 1
			main.set("state", state)
			main.call("update_hud")
			main.call("save_game")
	reward_pending = false
