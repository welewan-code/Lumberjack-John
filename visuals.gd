extends Control

const CHARACTER_BASE := "res://assets/characters/"
const TOOL_BASE := "res://assets/tools/"

var game: Node
var player_sprite: TextureRect
var splitter_sprite: TextureRect
var sawyer_sprite: TextureRect
var tool_strip: HBoxContainer
var frame_time: float = 0.0
var frame_index: int = 0

func _ready() -> void:
    game = get_parent()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    _build_visuals()
    set_process(true)

func _build_visuals() -> void:
    player_sprite = _make_actor(Vector2(70, 235), Vector2(235, 235))
    splitter_sprite = _make_actor(Vector2(475, 300), Vector2(170, 170))
    sawyer_sprite = _make_actor(Vector2(765, 225), Vector2(190, 190))

    tool_strip = HBoxContainer.new()
    tool_strip.position = Vector2(340, 92)
    tool_strip.add_theme_constant_override("separation", 14)
    tool_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tool_strip)

    for item in [
        ["wooden_axe.png", "Tupá sekera"],
        ["sharpened_axe.png", "Nabroušená sekera"],
        ["frame_saw.png", "Rámovka"],
        ["aku_saw.png", "Aku pila"],
        ["wheelbarrow.png", "Kolečko"]
    ]:
        var box := VBoxContainer.new()
        box.custom_minimum_size = Vector2(92, 90)
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var tex := TextureRect.new()
        tex.custom_minimum_size = Vector2(72, 58)
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var path: String = TOOL_BASE + String(item[0])
        if ResourceLoader.exists(path):
            tex.texture = load(path)
        var label := Label.new()
        label.text = String(item[1])
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 11)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        box.add_child(tex)
        box.add_child(label)
        tool_strip.add_child(box)

func _make_actor(pos: Vector2, size: Vector2) -> TextureRect:
    var tex := TextureRect.new()
    tex.position = pos
    tex.size = size
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tex)
    return tex

func _process(delta: float) -> void:
    if game == null:
        return
    var tab := ""
    if "current_tab" in game:
        tab = str(game.current_tab)

    visible = tab == "FIRMA" or tab == "OBCHOD" or tab == "SKLAD"
    if not visible:
        return

    tool_strip.visible = tab == "OBCHOD" or tab == "SKLAD"
    player_sprite.visible = tab == "FIRMA"
    splitter_sprite.visible = tab == "FIRMA"
    sawyer_sprite.visible = tab == "FIRMA"

    frame_time += delta
    if frame_time >= 0.22:
        frame_time = 0.0
        frame_index = (frame_index + 1) % 4

    _refresh_firma_sprites()

func _refresh_firma_sprites() -> void:
    if not ("state" in game):
        return
    var state: Dictionary = game.state

    var equipped := str(state.get("equipped_axe", "wooden"))
    var player_prefix := "player_sharp" if equipped == "sharpened" else "player_wood"
    _set_frame(player_sprite, player_prefix, frame_index)

    var splitter_tool := str(state.get("splitter_tool", ""))
    if splitter_tool == "":
        splitter_sprite.modulate = Color(1, 1, 1, 0.18)
        _set_frame(splitter_sprite, "splitter_wood", 0)
    else:
        splitter_sprite.modulate = Color.WHITE
        var split_prefix := "splitter_sharp" if splitter_tool == "sharpened" else "splitter_wood"
        _set_frame(splitter_sprite, split_prefix, frame_index)

    var sawyer_tool := str(state.get("sawyer_tool", ""))
    if sawyer_tool == "":
        sawyer_sprite.modulate = Color(1, 1, 1, 0.18)
        _set_frame(sawyer_sprite, "sawyer_frame", 0)
    else:
        sawyer_sprite.modulate = Color.WHITE
        var saw_prefix := "sawyer_aku" if sawyer_tool == "akuSaw" else "sawyer_frame"
        _set_frame(sawyer_sprite, saw_prefix, frame_index)

func _set_frame(target: TextureRect, prefix: String, index: int) -> void:
    var path := CHARACTER_BASE + prefix + "_" + str(index + 1) + ".png"
    if ResourceLoader.exists(path):
        target.texture = load(path)
