extends Control
## CharacterSelect — Selección de personaje (§10).
## Versus: P1 → P2 → arena. Historia: una sola clase. Pixel art placeholder.
## Autor: Claude Code · Versión: 0.4.0

var _phase := 0  # 0:P1/clase  1:P2  2:arena
var _title: Label
var _row: HBoxContainer

const CLASS_DESC := {
	"archer": "ARQUERO\nÁgil. Flechas\nparabólicas.",
	"warrior": "GUERRERO\nPesado. Espada\ny carga.",
}
const ARENA_NAMES := ["Bosque Antiguo", "Ruinas Voladoras", "Torre del Caos"]

func _ready() -> void:
	theme = UITheme.build()                 # V0.5.1 CAMBIO-8
	add_child(UIInputBridge.new())          # V0.5.1 CAMBIO-9
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_title = Label.new()
	_title.position = Vector2(0, 24)
	_title.size = Vector2(320, 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 5)   # V0.8.2 E-2: 12 ×0.4
	_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	add_child(_title)

	_row = HBoxContainer.new()
	_row.position = Vector2(40, 70)
	_row.custom_minimum_size = Vector2(240, 70)
	_row.add_theme_constant_override("separation", 6)   # V0.8.2 E-2: 16 ×0.4
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)

	var back := Button.new()
	back.text = "VOLVER (Esc)"
	back.position = Vector2(8, 160)
	back.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 8 ×0.4
	back.pressed.connect(func(): SceneManager.goto_main_menu())
	add_child(back)

	_build_phase()

## V0.8.2 E-1: consume WASD/flechas (la navegación la aporta UIInputBridge).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode in \
			[KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()

func _build_phase() -> void:
	for c in _row.get_children():
		c.queue_free()
	if GameManager.mode == GameManager.Mode.STORY:
		_title.text = "MODO HISTORIA — ELIGE TU HÉROE"
		_class_buttons(func(cls):
			GameManager.story_class = cls
			SceneManager.change_scene("res://scenes/ui/StoryMatch.tscn"))
		return
	match _phase:
		0:
			_title.text = "JUGADOR 1 — ELIGE TU CLASE"
			_class_buttons(func(cls):
				GameManager.p1_class = cls
				_phase = 1
				_build_phase())
		1:
			_title.text = "JUGADOR 2 — ELIGE TU CLASE"
			_class_buttons(func(cls):
				GameManager.p2_class = cls
				_phase = 2
				_build_phase())
		2:
			_title.text = "ELIGE LA ARENA"
			_arena_buttons()

func _class_buttons(cb: Callable) -> void:
	for cls in ["archer", "warrior"]:
		var b := Button.new()
		b.text = CLASS_DESC[cls]
		b.custom_minimum_size = Vector2(100, 26)   # V0.8.2 E-2: alto 64 ×0.4
		b.add_theme_font_size_override("font_size", 4)   # V0.8.2 E-2: 9 ×0.4
		var col := Color(0.27, 0.55, 0.29) if cls == "archer" else Color(0.72, 0.21, 0.18)
		b.add_theme_color_override("font_color", col.lightened(0.4))
		b.pressed.connect(func(): cb.call(cls))
		_row.add_child(b)
	await get_tree().process_frame
	if _row.get_child_count() > 0:
		(_row.get_child(0) as Button).grab_focus()

func _arena_buttons() -> void:
	for i in 3:
		var b := Button.new()
		b.text = ARENA_NAMES[i]
		b.custom_minimum_size = Vector2(72, 26)   # V0.8.2 E-2: alto 64 ×0.4
		b.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 8 ×0.4
		var idx := i
		b.pressed.connect(func():
			GameManager.selected_arena_index = idx
			SceneManager.change_scene("res://scenes/ui/VersusMatch.tscn"))
		_row.add_child(b)
	await get_tree().process_frame
	if _row.get_child_count() > 0:
		(_row.get_child(0) as Button).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameManager.mode == GameManager.Mode.VERSUS and _phase > 0:
			_phase -= 1
			_build_phase()
		else:
			SceneManager.goto_main_menu()
