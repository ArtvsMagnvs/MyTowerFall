extends Node
## ScreenWrapper — Autoload (Actualización V0.4 punto 11).
## Define el área de juego (240×180, x∈[40,280]) y las zonas de wrapping del nivel
## actual. Calcula el reposicionamiento continuo y el offset del "ghost" para el
## efecto medio-cuerpo-en-cada-lado, estilo TowerFall/Pac-Man.
## Autor: Claude Code · Versión: 0.7.0

const ARENA_LEFT := 40.0
const ARENA_RIGHT := 280.0
const ARENA_TOP := 0.0
const ARENA_BOTTOM := 180.0
const ARENA_W := 240.0
const ARENA_H := 180.0

# Cada zona: {axis: "horizontal"|"vertical", lo: float, hi: float}
# Para horizontal, lo/hi son el rango Y del hueco; para vertical, el rango X.
var zones: Array = []

func clear_zones() -> void:
	zones.clear()

func add_zone(axis: String, lo: float, hi: float) -> void:
	zones.append({"axis": axis, "lo": lo, "hi": hi})

## Desplazamiento a aplicar cuando el CENTRO cruza un borde con hueco (si no, ZERO).
func wrap_delta(pos: Vector2) -> Vector2:
	for z in zones:
		if z.axis == "horizontal":
			if pos.y < z.lo or pos.y > z.hi:
				continue
			if pos.x > ARENA_RIGHT:
				return Vector2(-ARENA_W, 0)
			elif pos.x < ARENA_LEFT:
				return Vector2(ARENA_W, 0)
		else:
			if pos.x < z.lo or pos.x > z.hi:
				continue
			if pos.y > ARENA_BOTTOM:
				return Vector2(0, -ARENA_H)
			elif pos.y < ARENA_TOP:
				return Vector2(0, ARENA_H)
	return Vector2.ZERO

## Offset donde dibujar el ghost (mitad asomando por el lado opuesto), o ZERO.
func ghost_offset(pos: Vector2, half: Vector2) -> Vector2:
	for z in zones:
		if z.axis == "horizontal":
			if pos.y < z.lo or pos.y > z.hi:
				continue
			if ARENA_RIGHT - pos.x < half.x:
				return Vector2(-ARENA_W, 0)
			elif pos.x - ARENA_LEFT < half.x:
				return Vector2(ARENA_W, 0)
		else:
			if pos.x < z.lo or pos.x > z.hi:
				continue
			if ARENA_BOTTOM - pos.y < half.y:
				return Vector2(0, -ARENA_H)
			elif pos.y - ARENA_TOP < half.y:
				return Vector2(0, ARENA_H)
	return Vector2.ZERO
