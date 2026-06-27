extends Node2D
class_name AmmoCounter
## AmmoCounter — Contador visual de munición sobre el personaje.
## Dibuja hasta 5 iconos pixel art del proyectil de la clase (no números).
## DOCUMENTO_MAESTRO.md §5b. Parpadea cuando el stock está vacío.
## Autor: Claude Code · Versión: 0.4.0

var player: PlayerBase
const ICON_W := 4
const ICON_H := 5
const GAP := 1
var _blink := 0.0
var _pop_scale := 1.0

func _ready() -> void:
	z_index = 10

func pop() -> void:
	_pop_scale = 1.6

func _process(delta: float) -> void:
	_blink += delta
	_pop_scale = lerpf(_pop_scale, 1.0, 0.2)
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var color: Color = player.projectile_color
	var total_w := PlayerBase.AMMO_MAX * (ICON_W + GAP)
	var start_x := -total_w * 0.5
	for i in PlayerBase.AMMO_MAX:
		var x := start_x + i * (ICON_W + GAP)
		var r := Rect2(Vector2(x, -ICON_H), Vector2(ICON_W, ICON_H))
		if i < player.ammo:
			var c := color
			if i == player.ammo - 1:
				r.size *= _pop_scale
			draw_rect(r, c)
			draw_rect(r, Color.BLACK, false, 1.0)
		else:
			# Slot vacío: parpadea si no queda munición
			var a := 0.15
			if player.ammo == 0 and fmod(_blink, 0.4) < 0.2:
				a = 0.5
			draw_rect(r, Color(color.r, color.g, color.b, a), false, 1.0)
