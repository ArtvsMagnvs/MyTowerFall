extends Node
## GameManager — Autoload
## Estado global del juego: modo activo, clases elegidas, puntuaciones Versus
## y progreso del modo Historia.
## Autor: Claude Code · Versión: 0.4.0

enum Mode { NONE, VERSUS, STORY }

# Clases disponibles
const CLASS_ARCHER := "archer"
const CLASS_WARRIOR := "warrior"

const ARENAS := [
	"res://scenes/levels/Level_01_Forest.tscn",
	"res://scenes/levels/Level_02_Ruins.tscn",
	"res://scenes/levels/Level_03_Tower.tscn",
]

const STORY_LEVELS := [
	"res://scenes/levels/Level_01_Forest.tscn",
	"res://scenes/levels/Level_02_Ruins.tscn",
	"res://scenes/levels/Level_03_Tower.tscn",
]

var mode: Mode = Mode.NONE

# Selección de personajes
var p1_class := CLASS_ARCHER
var p2_class := CLASS_WARRIOR
var story_class := CLASS_ARCHER

# Versus
var rounds_to_win := 3        # Mejor de 5
var p1_wins := 0
var p2_wins := 0
var selected_arena_index := 0

# Historia
var story_level_index := 0

func reset_versus() -> void:
	p1_wins = 0
	p2_wins = 0

func register_round_win(player: int) -> void:
	if player == 1:
		p1_wins += 1
	else:
		p2_wins += 1

func versus_match_over() -> bool:
	return p1_wins >= rounds_to_win or p2_wins >= rounds_to_win

func versus_winner() -> int:
	if p1_wins >= rounds_to_win:
		return 1
	if p2_wins >= rounds_to_win:
		return 2
	return 0

func reset_story() -> void:
	story_level_index = 0

func class_scene(cls: String) -> PackedScene:
	if cls == CLASS_WARRIOR:
		return load("res://scenes/characters/Warrior.tscn")
	return load("res://scenes/characters/Archer.tscn")
