extends RefCounted
class_name UITheme
## UITheme — Tema de UI común para los menús (V0.5.1 CAMBIO-8).
## Fuente del motor (sans, no pixel) a tamaños legibles + botones con estilo.
## Con stretch_mode = canvas_items, el texto se renderiza nítido a la resolución real.
## Autor: Claude Code · Versión: 0.5.1

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 11
	t.set_font_size("font_size", "Button", 12)
	t.set_color("font_color", "Button", Color(0.92, 0.92, 0.96))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", _box(Color(0.14, 0.15, 0.22, 0.92)))
	t.set_stylebox("hover", "Button", _box(Color(0.24, 0.26, 0.36, 0.96)))
	t.set_stylebox("pressed", "Button", _box(Color(0.10, 0.11, 0.16, 0.96)))
	t.set_stylebox("focus", "Button", _box(Color(0.30, 0.42, 0.60, 0.5)))
	return t

static func _box(col: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(2)
	b.set_content_margin_all(4.0)
	b.set_border_width_all(1)
	b.border_color = Color(0, 0, 0, 0.5)
	return b
