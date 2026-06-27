extends LevelBase
## Nivel 2 — Ruinas Voladoras (rediseño V0.4 p.12). Plataformas flotantes en el vacío.
## Wrapping total (horizontal toda la altura + vertical todo el ancho): el arena es
## un toroide, nunca se cae fuera. Pequeños salientes laterales para wall jump.
## Enemigos: Slime, Espectro, Murciélago. Dificultad media.
## Autor: Claude Code · Versión: 0.7.0

func level_title() -> String: return "Ruinas Voladoras"
func bg_color() -> Color: return Color(0.07, 0.09, 0.17)

func solids() -> Array:
	return [
		# Salientes laterales (superficies de wall jump), no paredes completas.
		Rect2(40, 30, 14, 22),
		Rect2(266, 30, 14, 22),
		Rect2(40, 128, 14, 22),
		Rect2(266, 128, 14, 22),
	]

func platforms() -> Array:
	return [
		Rect2(70, 44, 44, 6),     # alta izq
		Rect2(206, 44, 44, 6),    # alta der
		Rect2(64, 92, 52, 6),     # media izq
		Rect2(204, 92, 52, 6),    # media der
		Rect2(96, 134, 40, 6),    # baja izq
		Rect2(184, 134, 40, 6),   # baja der
	]

func player_spawns() -> Array:
	return [Vector2(90, 84), Vector2(230, 84)]

func monster_spawns() -> Array:
	return [Vector2(92, 36), Vector2(228, 36), Vector2(116, 126), Vector2(204, 126), Vector2(160, 60)]

func wrap_zones() -> Array:
	return [
		{"axis": "horizontal", "lo": 0.0, "hi": 180.0},
		{"axis": "vertical", "lo": 40.0, "hi": 280.0},
	]

# V0.8.2 F-2: oleadas en mini-oleadas. Mini-oleada = [t, [ [tipo, spawn_num, delay], ... ] ].
func waves() -> Array:
	return [
		[  # Oleada 1
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0]]],
			[2.5, [["Specter", 5, 0.0]]],
			[5.0, [["Troll", 3, 0.0]]],
		],
		[  # Oleada 2
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0], ["Slime", 4, 0.0]]],
			[2.0, [["Bat", 3, 0.0], ["Bat", 5, 0.0]]],
			[5.0, [["Troll", 2, 0.0], ["Specter", 4, 0.0]]],
		],
		[  # Oleada 3
			[0.0, [["Slime", 1, 0.0], ["Bat", 3, 0.0]]],
			[2.5, [["Specter", 5, 0.0], ["Troll", 2, 0.0]]],
			[5.5, [["Bat", 4, 0.0], ["Bat", 1, 0.0]]],
			[8.0, [["Troll", 3, 0.0]]],
		],
	]
