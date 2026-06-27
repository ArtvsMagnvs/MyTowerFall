extends CanvasLayer
class_name HUD
## HUD — Interfaz de juego (§10 + V0.4 punto 13).
## Paneles laterales de 40px (área de juego central de 240px). Vidas apiladas
## verticalmente en cada panel; rondas Versus / indicador de oleada.
## Autor: Claude Code · Versión: 0.7.0

const PANEL_W := 40.0
const ARENA_RIGHT := 280.0

var _p1: Label
var _p2: Label
var _wave: Label
var _banner: Label
var _lives_root: Control
var _p1_life_nodes: Array[ColorRect] = []
var _p2_life_nodes: Array[ColorRect] = []

func _ready() -> void:
	layer = 50
	_build_panels()
	_p1 = _make_label(Vector2(2, 160), HORIZONTAL_ALIGNMENT_CENTER, Color(0.4, 0.8, 1.0))
	_p1.size = Vector2(38, 12)
	_p2 = _make_label(Vector2(282, 160), HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 0.6, 0.4))
	_p2.size = Vector2(38, 12)
	_wave = _make_label(Vector2(2, 4), HORIZONTAL_ALIGNMENT_CENTER, Color(0.9, 0.85, 0.5))
	_wave.size = Vector2(38, 12)
	_wave.add_theme_font_size_override("font_size", 7)
	_banner = _make_label(Vector2(40, 78), HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	_banner.size = Vector2(240, 24)
	_banner.add_theme_font_size_override("font_size", 14)
	_banner.add_theme_constant_override("outline_size", 5)
	_banner.visible = false

	_lives_root = Control.new()
	_lives_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lives_root)

func _build_panels() -> void:
	var left := ColorRect.new()
	left.color = Color(0.04, 0.04, 0.08, 0.92)
	left.position = Vector2(0, 0)
	left.size = Vector2(PANEL_W, 180)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var right := ColorRect.new()
	right.color = Color(0.04, 0.04, 0.08, 0.92)
	right.position = Vector2(ARENA_RIGHT, 0)
	right.size = Vector2(PANEL_W, 180)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)

## V0.4 punto 13: iconos de vida apilados verticalmente en cada panel lateral.
func set_lives(p1_lives: int, p2_lives: int, col1: Color, col2: Color) -> void:
	for n in _p1_life_nodes:
		n.queue_free()
	for n in _p2_life_nodes:
		n.queue_free()
	_p1_life_nodes.clear()
	_p2_life_nodes.clear()
	for i in p1_lives:
		_p1_life_nodes.append(_make_life_icon(Vector2(16, 8 + i * 9), col1))
	for i in p2_lives:
		_p2_life_nodes.append(_make_life_icon(Vector2(296, 8 + i * 9), col2))

func _make_life_icon(pos: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(8, 8)
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_root.add_child(r)
	return r

func life_anchor(player: int) -> Vector2:
	return Vector2(20, 14) if player == 1 else Vector2(300, 14)

func _make_label(pos: Vector2, align: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(38, 12)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	add_child(l)
	return l

func set_versus(p1_wins: int, p2_wins: int, target: int) -> void:
	_wave.visible = false
	_p1.text = "P1 %s" % _dots(p1_wins, target)
	_p2.text = "P2 %s" % _dots(p2_wins, target)

func _dots(n: int, total: int) -> String:
	var s := ""
	for i in total:
		s += "*" if i < n else "."
	return s

func set_wave(index: int, total: int) -> void:
	_p1.visible = false
	_p2.visible = false
	_wave.text = "OLA\n%d/%d" % [index, total]

func show_banner(text: String, duration: float = 0.0) -> void:
	_banner.text = text
	_banner.visible = true
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		_banner.visible = false

func hide_banner() -> void:
	_banner.visible = false
