extends Node
func _ready() -> void:
	await _run()
func _run() -> void:
	var level := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(level)
	var p2 := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	p2.player_id = 2
	level.add_child(p2)
	await get_tree().physics_frame
	# Columna x=70: libre de plataformas entre el punto de caída y el suelo.
	p2.global_position = Vector2(70, 164)
	var p1 := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	p1.player_id = 1
	level.add_child(p1)
	await get_tree().physics_frame
	p1.global_position = Vector2(70, 150)
	p1.velocity = Vector2(0, 140)
	var p1_bounced := false
	for i in 120:
		await get_tree().physics_frame
		if p1.velocity.y < -20.0:
			p1_bounced = true
	print("=== STOMP TEST RESULT ===")
	var ok = p2.is_dead
	print("pvp_stomp_kills: ", "PASS" if ok else "FAIL", " (p2.is_dead=%s, p1_bounced=%s)" % [p2.is_dead, p1_bounced])
	print("=========================")
	get_tree().quit(0 if ok else 1)
