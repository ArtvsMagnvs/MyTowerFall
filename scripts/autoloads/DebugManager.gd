extends Node
## DebugManager — Autoload
## Overlay de desarrollo (F1), flags de debug y dibujo de hitboxes.
## Autor: Claude Code · Versión: 0.4.0

# --- Flags de debug ---
var GODMODE: bool = false        # El jugador no muere
var SHOW_HITBOXES: bool = false  # Visualiza hitboxes / colisiones
var SKIP_INTROS: bool = false    # Salta pantallas de intro de nivel
var INFINITE_DASH: bool = false  # Sin cooldown de dash

var _overlay_visible: bool = false
var _layer: CanvasLayer
var _label: Label
var _version_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	_label = Label.new()
	_label.position = Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	_layer.add_child(_label)

	# Versión siempre visible en la esquina inferior derecha
	_version_label = Label.new()
	_version_label.add_theme_font_size_override("font_size", 8)
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_version_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_version_label.add_theme_constant_override("outline_size", 2)
	_version_label.text = VersionManager.get_version_string()
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.position = Vector2(-44, -14)
	_layer.add_child(_version_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_toggle_overlay()
			KEY_F2:
				SHOW_HITBOXES = not SHOW_HITBOXES
				_refresh_hitbox_draw()
			KEY_F3:
				GODMODE = not GODMODE
			KEY_F4:
				INFINITE_DASH = not INFINITE_DASH

func _toggle_overlay() -> void:
	_overlay_visible = not _overlay_visible
	_label.visible = _overlay_visible

func _refresh_hitbox_draw() -> void:
	for node in get_tree().get_nodes_in_group("debuggable"):
		if node.has_method("queue_redraw"):
			node.queue_redraw()

func _process(_delta: float) -> void:
	if not _overlay_visible:
		return
	var txt: String = "FPS: %d\n" % Engine.get_frames_per_second()
	txt += "FLAGS: god=%s hitbox=%s inf_dash=%s skip=%s\n" % [GODMODE, SHOW_HITBOXES, INFINITE_DASH, SKIP_INTROS]
	txt += "[F1 overlay] [F2 hitbox] [F3 god] [F4 dash]\n"
	for node in get_tree().get_nodes_in_group("debuggable"):
		if node.has_method("get_debug_info"):
			txt += node.get_debug_info() + "\n"
	_label.text = txt
