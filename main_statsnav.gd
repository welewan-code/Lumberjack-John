extends "res://main_stats_live.gd"

func show_tab(tab: String) -> void:
	if tab == "STATISTIKY":
		achievements_section = "STATISTIKY"
		super.show_tab("ÚSPĚCHY")
		return
	super.show_tab(tab)
