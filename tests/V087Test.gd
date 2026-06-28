extends Node
## V087Test — Verifica la separación AMMO_INITIAL (3 al spawnear) vs AMMO_START (1 al
## revivir tras muerte+gema). Caso de regresión V0.8.7.4.1: ambos bugs surgieron al
## confundir "inicio de partida" con "respawn tras muerte".

var _lvl: LevelBase

func _ready() -> void:
	await _run()

func _run() -> void:
	_lvl = (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_lvl)
	await get_tree().physics_frame

	var ok_initial := await _initial_spawn_has_three_arrows()
	var ok_respawn := await _respawn_after_death_gives_one_arrow()
	var ok_explicit_initial := await _respawn_with_initial_ammo_override()

	print("=== V087 TEST RESULT ===")
	print("initial_spawn_has_three_arrows: ", "PASS" if ok_initial else "FAIL")
	print("respawn_after_death_gives_one_arrow: ", "PASS" if ok_respawn else "FAIL")
	print("respawn_with_initial_override_works: ", "PASS" if ok_explicit_initial else "FAIL")
	print("=========================")
	get_tree().quit(0 if (ok_initial and ok_respawn and ok_explicit_initial) else 1)

## Al instanciar un PlayerBase sin llamar a respawn() (caso StoryMatch: el player se
## coloca en posición manualmente), ammo debe ser AMMO_INITIAL = 3.
func _initial_spawn_has_three_arrows() -> bool:
	var pa := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	_lvl.add_child(pa)
	await get_tree().physics_frame
	pa.global_position = Vector2(100, 100)
	await get_tree().physics_frame
	var ok := pa.ammo == PlayerBase.AMMO_INITIAL and PlayerBase.AMMO_INITIAL == 3
	if is_instance_valid(pa): pa.queue_free()
	await get_tree().physics_frame
	return ok

## Llamar a respawn() sin override → debe poner ammo = AMMO_START = 1
## (esto simula el caso "el jugador murió y la gema lo revive").
func _respawn_after_death_gives_one_arrow() -> bool:
	var pa := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	_lvl.add_child(pa)
	await get_tree().physics_frame
	# Gastamos toda la munición manualmente para asegurarnos de que respawn() la repone.
	pa.ammo = 0
	pa.respawn(Vector2(100, 100))   # sin override → AMMO_START = 1
	await get_tree().physics_frame
	var ok := pa.ammo == PlayerBase.AMMO_START and PlayerBase.AMMO_START == 1
	if is_instance_valid(pa): pa.queue_free()
	await get_tree().physics_frame
	return ok

## Llamar a respawn(at, AMMO_INITIAL) → debe poner ammo = 3 (caso VersusMatch al
## inicio de cada ronda).
func _respawn_with_initial_ammo_override() -> bool:
	var pa := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	_lvl.add_child(pa)
	await get_tree().physics_frame
	pa.ammo = 0
	pa.respawn(Vector2(100, 100), PlayerBase.AMMO_INITIAL)
	await get_tree().physics_frame
	var ok := pa.ammo == PlayerBase.AMMO_INITIAL and pa.ammo == 3
	if is_instance_valid(pa): pa.queue_free()
	await get_tree().physics_frame
	return ok