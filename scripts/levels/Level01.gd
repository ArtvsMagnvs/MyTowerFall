extends LevelBase
## Nivel 1 — Bosque Antiguo (rediseño V0.4 p.12). Área de juego 240×180 (x∈[40,280]).
## Suelo sólido con wrapping horizontal a ras de suelo (sales por un lado, entras
## por el otro). Paredes laterales superiores para wall jump. 3 capas de plataformas.
## Enemigos: Slime y Troll. Introductorio.
## Autor: Claude Code · Versión: 0.7.0

func level_title() -> String: return "Bosque Antiguo"
func bg_color() -> Color: return Color(0.07, 0.13, 0.09)

func solids() -> Array:
	return [
		Rect2(40, 0, 240, 10),    # techo
		Rect2(40, 170, 240, 10),  # suelo (con wrapping horizontal a sus lados)
		Rect2(40, 10, 16, 140),   # pared izq superior (y10-150)
		Rect2(264, 10, 16, 140),  # pared der superior
	]

func platforms() -> Array:
	return [
		Rect2(80, 150, 160, 6),   # plataforma media principal (≈20px sobre el suelo)
		Rect2(60, 126, 46, 6),    # media-alta izq
		Rect2(214, 126, 46, 6),   # media-alta der
		Rect2(132, 102, 56, 6),   # alta central
	]

func player_spawns() -> Array:
	return [Vector2(110, 160), Vector2(210, 160)]

func monster_spawns() -> Array:
	return [Vector2(160, 160), Vector2(80, 118), Vector2(240, 118), Vector2(160, 94), Vector2(70, 160)]

func wrap_zones() -> Array:
	return [{"axis": "horizontal", "lo": 150.0, "hi": 180.0}]

# V0.8.2 F-2: oleadas en mini-oleadas. Mini-oleada = [t, [ [tipo, spawn_num, delay], ... ] ].
func waves() -> Array:
	return [
		[  # Oleada 1
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0]]],
			[3.0, [["Troll", 3, 0.0]]],
		],
		[  # Oleada 2
			[0.0, [["Slime", 1, 0.0], ["Slime", 2, 0.0], ["Slime", 4, 0.0]]],
			[2.5, [["Troll", 3, 0.0], ["Bat", 5, 0.0]]],
		],
		[  # Oleada 3
			[0.0, [["Slime", 1, 0.0], ["Bat", 2, 0.0]]],
			[3.0, [["Troll", 3, 0.0], ["Slime", 4, 0.0]]],
			[6.0, [["Specter", 5, 0.0]]],
		],
	]
