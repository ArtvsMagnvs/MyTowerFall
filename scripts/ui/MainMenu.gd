extends Control
## MainMenu — Menú principal (DOCUMENTO_MAESTRO.md §10).
## Logo + opciones HISTORIA / VERSUS / OPCIONES / SALIR.
## Autor: Claude Code · Versión: 0.4.0

func _ready() -> void:
	AudioManager.play_music("menu")
	theme = UITheme.build()                 # V0.5.1 CAMBIO-8
	add_child(UIInputBridge.new())          # V0.5.1 CAMBIO-9
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = VersionManager.GAME_TITLE
	title.position = Vector2(0, 18)
	title.size = Vector2(320, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)   # V0.8.2 E-2: 28 ×0.4
	title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.25))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = VersionManager.GAME_SUBTITLE
	subtitle.position = Vector2(0, 46)
	subtitle.size = Vector2(320, 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 5)   # V0.8.2 E-2: 13 ×0.4
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.72, 0.45))
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 1)
	add_child(subtitle)

	var vb := VBoxContainer.new()
	vb.position = Vector2(110, 80)
	vb.custom_minimum_size = Vector2(100, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)   # V0.8.2 E-2: 4 ×0.4
	add_child(vb)

	_add_button(vb, "HISTORIA", _on_story)
	_add_button(vb, "VERSUS", _on_versus)
	_add_button(vb, "OPCIONES", _on_options)
	_add_button(vb, "SALIR", _on_quit)

	await get_tree().process_frame
	if vb.get_child_count() > 0:
		(vb.get_child(0) as Button).grab_focus()

func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 6)   # V0.8.2 E-2: alto 15 ×0.4
	b.add_theme_font_size_override("font_size", 4)   # V0.8.2 E-2: 10 ×0.4
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	parent.add_child(b)

## V0.8.2 E-1: consume las teclas de movimiento (WASD/flechas) para que no las procese
## la navegación de UI por defecto de Godot (evita el freeze/crash). La navegación
## controlada la aporta UIInputBridge (vía InputEventAction, que esto no bloquea).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and _is_movement_key((event as InputEventKey).keycode):
		get_viewport().set_input_as_handled()

func _is_movement_key(kc: int) -> bool:
	return kc in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

func _on_story() -> void:
	GameManager.mode = GameManager.Mode.STORY
	GameManager.reset_story()
	SceneManager.goto_character_select()

func _on_versus() -> void:
	GameManager.mode = GameManager.Mode.VERSUS
	GameManager.reset_versus()
	SceneManager.goto_character_select()

func _on_options() -> void:
	SceneManager.change_scene("res://scenes/ui/OptionsMenu.tscn")

func _on_quit() -> void:
	get_tree().quit()
