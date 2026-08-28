extends Control

# Overlay visuals were removed. Shop item images are rendered only inside shop cards.
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
