extends Node

const OFFLINE_PATH := "user://drevo_tycoon_offline.json"
const HEARTBEAT_SECONDS := 5.0

var heartbeat := 0.0

func _ready() -> void:
    call_deferred("_apply_offline_progress")

func _process(delta: float) -> void:
    heartbeat += delta
    if heartbeat >= HEARTBEAT_SECONDS:
        heartbeat = 0.0
        _write_last_seen()

func _exit_tree() -> void:
    _write_last_seen()

func _apply_offline_progress() -> void:
    var game = get_parent()
    if game == null:
        return

    var now := int(Time.get_unix_time_from_system())
    var last_seen := _read_last_seen()
    if last_seen <= 0:
        _write_last_seen()
        return

    var elapsed := max(0, now - last_seen)
    if elapsed < 2:
        _write_last_seen()
        return

    var splitter_tool: String = str(game.state.get("splitter_tool", ""))
    var sawyer_tool: String = str(game.state.get("sawyer_tool", ""))

    var split_cycle := 0.0
    if splitter_tool == "sharpened":
        split_cycle = 1.6
    elif splitter_tool == "wooden":
        split_cycle = 1.8

    var saw_cycle := 0.0
    if sawyer_tool == "frameSaw":
        saw_cycle = float(game.FRAME_SAW_CYCLE)

    if split_cycle <= 0.0 and saw_cycle <= 0.0:
        _write_last_seen()
        return

    var next_split := split_cycle if split_cycle > 0.0 else INF
    var next_saw := saw_cycle if saw_cycle > 0.0 else INF
    var split_count := 0
    var saw_count := 0
    var safety := 0

    while safety < 20000:
        safety += 1
        var next_event: float = min(next_split, next_saw)
        if next_event > float(elapsed):
            break

        if next_saw <= next_split:
            if game.do_sawyer_cycle():
                saw_count += 1
                next_saw += saw_cycle
            else:
                next_saw = INF
        else:
            if game.do_splitter_cycle():
                split_count += 1
                next_split += split_cycle
            else:
                next_split = INF

        if is_inf(next_split) and is_inf(next_saw):
            break

    if saw_count > 0 or split_count > 0:
        game.save_game()
        game.show_tab(game.current_tab)
        game.say("Zatímco byla hra zavřená: pilař %d cyklů, štípač %d seků. (%d s)" % [saw_count, split_count, elapsed])

    _write_last_seen()

func _read_last_seen() -> int:
    if not FileAccess.file_exists(OFFLINE_PATH):
        return 0
    var file := FileAccess.open(OFFLINE_PATH, FileAccess.READ)
    if file == null:
        return 0
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return int(parsed.get("last_seen", 0))
    return 0

func _write_last_seen() -> void:
    var file := FileAccess.open(OFFLINE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"last_seen": int(Time.get_unix_time_from_system())}))
