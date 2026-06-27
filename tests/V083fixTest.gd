extends Node
## V083fixTest — Verifica las correcciones reforzadas del stomp y el wall slide:
##  S1) Stomp DESCENTRADO sobre un Slime (cae a +3px) → muere (antes el cuerpo sólido
##      desviaba al jugador y el rayo central fallaba).
##  S2) Stomp descentrado a -3px sobre un Slime → muere.
##  S3) Stomp descentrado sobre un Troll (+5px) → muere.
##  S4) Stomp sobre un Slime con IA ACTIVA (no congelado) → muere.
##  W1) Soltar el input a mitad de wall slide → cae libre de inmediato (sin slide fantasma).

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame

	var s1 := await _stomp_case("res://scenes/monsters/Slime.tscn", Vector2(70, 164), Vector2(73, 150), true)
	var s2 := await _stomp_case("res://scenes/monsters/Slime.tscn", Vector2(70, 164), Vector2(67, 150), true)
	var s3 := await _stomp_case("res://scenes/monsters/StoneTroll.tscn", Vector2(70, 164), Vector2(75, 150), true)
	var s4 := await _stomp_case("res://scenes/monsters/Slime.tscn", Vector2(70, 164), Vector2(70, 152), false)

	# --- W1: soltar el input a mitad de wall slide → cae libre ---
	var pw := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pw.player_id = 1
	lvl.add_child(pw)
	await get_tree().physics_frame
	pw.global_position = Vector2(60, 80)   # pegado a la cara der de la pared izq del nivel (x≈56)
	pw.velocity = Vector2(0, 5)
	Input.action_press("p1_left")          # empuja contra la pared izquierda
	var press_max := 0.0
	for i in 12:
		await get_tree().physics_frame
		press_max = maxf(press_max, pw.velocity.y)
	Input.action_release("p1_left")        # SUELTA: ya no debe deslizar
	var release_max := 0.0
	for i in 12:
		await get_tree().physics_frame
		release_max = maxf(release_max, pw.velocity.y)
	# Mientras pulsa: capado a wall_slide_speed (60). Tras soltar: cae libre (>100).
	var w1_ok := press_max < 75.0 and release_max > 100.0
	if is_instance_valid(pw): pw.queue_free()

	print("=== V083FIX TEST RESULT ===")
	print("stomp_offset_pos_slime (S1): ", "PASS" if s1 else "FAIL")
	print("stomp_offset_neg_slime (S2): ", "PASS" if s2 else "FAIL")
	print("stomp_offset_troll (S3): ", "PASS" if s3 else "FAIL")
	print("stomp_moving_slime (S4): ", "PASS" if s4 else "FAIL")
	print("wall_slide_release (W1): ", "PASS" if w1_ok else "FAIL", " (press_max=", press_max, " release_max=", release_max, ")")
	print("===========================")
	var ok := s1 and s2 and s3 and s4 and w1_ok
	get_tree().quit(0 if ok else 1)

## Deja caer a un Warrior sobre un monstruo y devuelve true si el monstruo muere.
func _stomp_case(monster_path: String, mon_pos: Vector2, player_pos: Vector2, freeze: bool) -> bool:
	var lvl := get_node_or_null(".") as Node
	var parent := get_child(0)   # el LevelBase
	var mon := (load(monster_path) as PackedScene).instantiate() as MonsterBase
	parent.add_child(mon)
	var p := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	p.player_id = 1
	parent.add_child(p)
	await get_tree().physics_frame
	mon.global_position = mon_pos
	if freeze:
		mon.set_physics_process(false)
	p.global_position = player_pos
	p.velocity = Vector2(0, 150)
	var dead := false
	for i in 30:
		await get_tree().physics_frame
		if not is_instance_valid(mon) or mon.is_dead:
			dead = true
			break
	if is_instance_valid(p): p.queue_free()
	if is_instance_valid(mon): mon.queue_free()
	await get_tree().physics_frame
	return dead
