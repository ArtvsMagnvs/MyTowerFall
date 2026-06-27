extends Node
## MonsterTest — Ejercita la IA de los 4 monstruos sin que el motor falle (temporal).

func _ready() -> void:
	await _run()

func _run() -> void:
	var level := (load("res://scenes/levels/Level_03_Tower.tscn") as PackedScene).instantiate() as LevelBase
	add_child(level)
	var player := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	player.player_id = 1
	level.add_child(player)
	player.global_position = Vector2(160, 150)

	var paths := [
		"res://scenes/monsters/Slime.tscn",
		"res://scenes/monsters/SpecterArcher.tscn",
		"res://scenes/monsters/StoneTroll.tscn",
		"res://scenes/monsters/ShadowBat.tscn",
	]
	var spawns := [Vector2(80, 60), Vector2(160, 40), Vector2(120, 150), Vector2(220, 60)]
	for i in paths.size():
		var m := (load(paths[i]) as PackedScene).instantiate() as MonsterBase
		level.add_child(m)
		m.global_position = spawns[i]

	for i in 240:
		await get_tree().physics_frame

	print("=== MONSTER TEST RESULT ===")
	print("monsters_ran_without_crash: PASS (alive=%d, projectiles=%d)" % [
		get_tree().get_nodes_in_group("monster").size(),
		get_tree().get_nodes_in_group("projectile").size()])
	print("===========================")
	get_tree().quit(0)
