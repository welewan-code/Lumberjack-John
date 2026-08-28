extends Node

func _ready() -> void:
    if not OS.has_environment("DREVO_TEST_SESSION"):
        return
    if OS.get_environment("DREVO_TEST_SESSION") != "1":
        return
    call_deferred("_inject_test_state")

func _inject_test_state() -> void:
    var game = get_parent()
    if game == null:
        return

    game.state["money"] = max(float(game.state.get("money", 0.0)), 5000.0)
    game.state["logs_m3"] = max(float(game.state.get("logs_m3", 0.0)), 2.0)
    game.state["roundwood_m3"] = max(float(game.state.get("roundwood_m3", 0.0)), 2.0)
    game.state["wooden_axe_qty"] = max(int(game.state.get("wooden_axe_qty", 0)), 2)
    game.state["sharpened_axe_qty"] = max(int(game.state.get("sharpened_axe_qty", 0)), 1)
    game.state["frame_saw_qty"] = max(int(game.state.get("frame_saw_qty", 0)), 1)
    game.state["wheelbarrow_qty"] = max(int(game.state.get("wheelbarrow_qty", 0)), 1)

    game.save_game()
    game.show_tab("FIRMA")
    game.say("TEST REŽIM: 5 000 Kč, materiál a nářadí připravené pro rychlé testování.")
