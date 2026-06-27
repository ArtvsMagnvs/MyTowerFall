extends Node
## SmokeTest — Verificación de runtime headless (temporal).
## Monta un nivel + jugador y comprueba gravedad/colisión y kill por proyectil.

func _ready() -> void:
	await _run()

func _run() -> void:
	var ok_gravity := false
	var ok_kill := false
	var err := ""

	var level := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(level)
	var player := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as ArcherPlayer
	player.player_id = 1
	level.add_child(player)
	player.global_position = Vector2(60, 60)  # cae al suelo

	for i in 120:
		await get_tree().physics_frame
	ok_gravity = player.is_on_floor() and absf(player.velocity.y) < 5.0
	if not ok_gravity:
		err += " gravity(floor=%s vy=%.1f y=%.1f)" % [player.is_on_floor(), player.velocity.y, player.global_position.y]

	# Kill por proyectil: goblin enfrente, flecha horizontal.
	var goblin := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as Slime
	level.add_child(goblin)
	goblin.global_position = player.global_position + Vector2(28, 0)
	await get_tree().physics_frame
	player.spawn_projectile(Vector2.RIGHT, 320.0, "arrow")
	for i in 30:
		await get_tree().physics_frame
	ok_kill = not is_instance_valid(goblin) or goblin.is_dead
	if not ok_kill:
		err += " kill(goblin alive at %.1f)" % goblin.global_position.x

	print("=== SMOKE TEST RESULT ===")
	print("gravity_and_collision: ", "PASS" if ok_gravity else "FAIL")
	print("projectile_kill: ", "PASS" if ok_kill else "FAIL")
	print("details:", err if err != "" else " all good")
	print("=========================")
	get_tree().quit(0 if (ok_gravity and ok_kill) else 1)
