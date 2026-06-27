extends Node
## V084Test — Verifica que el wall slide NO continúa en el aire al acabar el lateral.
## El jugador se desliza por una pared alta (y∈[40,100]); mientras esté en WALL_SLIDE, su
## pie no debe rebasar el borde inferior de la pared más de ~3px (antes, con el rayo en el
## centro, los pies seguían deslizando ~5px en el aire por debajo de la pared).

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame
	var wall := StaticBody2D.new()
	wall.add_to_group("world")
	wall.collision_layer = 1
	wall.collision_mask = 0
	var c := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 60)   # cara izquierda en x=200, y∈[40,100]
	c.shape = sh
	wall.add_child(c)
	lvl.add_child(wall)
	wall.global_position = Vector2(205, 70)
	var wall_bottom := 100.0
	var p := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	p.player_id = 1
	lvl.add_child(p)
	await get_tree().physics_frame
	p.global_position = Vector2(196, 55)
	p.velocity = Vector2(0, 5)
	Input.action_press("p1_right")
	var half := p.body_size.y * 0.5
	var saw_slide := false
	var saw_fall_after := false
	var max_foot_while_sliding := -999.0
	for i in 70:
		await get_tree().physics_frame
		if not is_instance_valid(p):
			break
		if p.state == PlayerBase.State.WALL_SLIDE:
			saw_slide = true
			max_foot_while_sliding = maxf(max_foot_while_sliding, p.global_position.y + half)
		elif saw_slide and p.state == PlayerBase.State.FALL:
			saw_fall_after = true
	Input.action_release("p1_right")
	# El pie no debe haber deslizado en el aire por debajo del final de la pared.
	var no_air_slide := max_foot_while_sliding <= wall_bottom + 3.0
	var ok := saw_slide and saw_fall_after and no_air_slide

	print("=== V084 TEST RESULT ===")
	print("wall_slide_no_air (foot<=bottom+3): ", "PASS" if ok else "FAIL")
	print("  saw_slide=", saw_slide, " saw_fall_after=", saw_fall_after, " max_foot=", max_foot_while_sliding, " wall_bottom=", wall_bottom)
	print("========================")
	get_tree().quit(0 if ok else 1)
