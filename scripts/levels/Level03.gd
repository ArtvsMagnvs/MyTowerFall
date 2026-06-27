extends LevelBase
## Nivel 3 — Torre del Caos (rediseño V0.4 p.12). Diseño vertical en cascada.
## Wrapping vertical en los dos huecos del suelo a los lados (caes por ahí y apareces
## desde el techo). Paredes finas en los bordes para no salir en horizontal.
## Enemigos: todos. Alta dificultad.
## Autor: Claude Code · Versión: 0.7.0

func level_title() -> String: return "Torre del Caos"
func bg_color() -> Color: return Color(0.15, 0.05, 0.08)

func solids() -> Array:
	return [
		Rect2(40, 0, 8, 180),     # borde izq fino (evita salir en horizontal)
		Rect2(272, 0, 8, 180),    # borde der fino
		Rect2(90, 0, 140, 10),    # techo central (huecos a los lados)
		Rect2(90, 170, 140, 10),  # suelo central (huecos de wrapping a los lados)
	]

func platforms() -> Array:
	return [
		Rect2(70, 150, 50, 6),    # baja izq
		Rect2(200, 150, 50, 6),   # baja der
		Rect2(110, 120, 100, 6),  # media central ancha
		Rect2(60, 96, 46, 6),     # media-alta izq
		Rect2(214, 96, 46, 6),    # media-alta der
		Rect2(120, 66, 80, 6),    # alta central
	]

func player_spawns() -> Array:
	return [Vector2(130, 160), Vector2(190, 160)]

func monster_spawns() -> Array:
	return [Vector2(160, 160), Vector2(95, 142), Vector2(225, 142), Vector2(160, 112), Vector2(160, 58)]

func wrap_zones() -> Array:
	return [
		{"axis": "vertical", "lo": 48.0, "hi": 90.0},
		{"axis": "vertical", "lo": 230.0, "hi": 272.0},
	]

# V0.8.2 F-2: oleadas en mini-oleadas. Mini-oleada = [t, [ [tipo, spawn_num, delay], ... ] ].
func waves() -> Array:
	return [
		[  # Oleada 1
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0], ["Specter", 5, 0.0]]],
			[2.5, [["Troll", 3, 0.0], ["Bat", 4, 0.0]]],
			[5.5, [["Bat", 1, 0.0], ["Bat", 2, 0.0]]],
		],
		[  # Oleada 2
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0], ["Slime", 3, 0.0]]],
			[2.0, [["Bat", 4, 0.0], ["Bat", 5, 0.0], ["Specter", 2, 0.0]]],
			[4.5, [["Troll", 1, 0.0], ["Troll", 3, 0.0]]],
			[8.0, [["Bat", 4, 0.0], ["Bat", 5, 0.0], ["Specter", 3, 0.0]]],
		],
		[  # Oleada 3 — final
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0], ["Bat", 4, 0.0], ["Bat", 5, 0.0]]],
			[2.0, [["Specter", 3, 0.0], ["Specter", 4, 0.0]]],
			[4.5, [["Troll", 1, 0.0], ["Troll", 2, 0.0]]],
			[7.5, [["Troll", 3, 0.0], ["Bat", 4, 0.0], ["Bat", 5, 0.0], ["Specter", 2, 0.0]]],
		],
	]
