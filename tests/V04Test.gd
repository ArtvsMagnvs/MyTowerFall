extends Node
## V04Test — Verifica el screen wrapping (Actualización V0.4 punto 11):
##  A) jugador que cruza el borde derecho aparece por la izquierda (Nivel 1, horizontal)
##  B) proyectil hace wrapping horizontal y sigue su trayectoria (Nivel 1)
##  C) jugador que cae por el hueco lateral aparece desde arriba (Nivel 3, vertical)

func _ready() -> void:
	await _run()

func _run() -> void:
	# --- A y B: Nivel 1 (wrap horizontal a ras de suelo) ---
	var l1 := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(l1)
	await get_tree().physics_frame
	var pa := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	l1.add_child(pa)
	await get_tree().physics_frame
	pa.global_position = Vector2(283, 162)   # justo pasado el borde derecho, a ras de suelo
	for i in 4:
		await get_tree().physics_frame
	var a_ok := pa.global_position.x < 90.0   # debe haber aparecido por la izquierda
	var a_x := pa.global_position.x
	pa.queue_free()
	await get_tree().physics_frame

	var proj := ProjectileBase.new()
	proj.kind = "arrow"
	proj.proj_color = Color(0.9, 0.8, 0.3)
	l1.add_child(proj)
	proj.setup(Vector2(272, 158), Vector2.RIGHT, 300.0)
	for i in 10:
		await get_tree().physics_frame
	var b_ok := is_instance_valid(proj) and proj.global_position.x < 160.0
	var b_x := proj.global_position.x if is_instance_valid(proj) else -999.0
	l1.queue_free()
	await get_tree().physics_frame

	# --- C: Nivel 3 (wrap vertical por hueco lateral del suelo) ---
	var l3 := (load("res://scenes/levels/Level_03_Tower.tscn") as PackedScene).instantiate() as LevelBase
	add_child(l3)
	await get_tree().physics_frame
	var pc := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pc.player_id = 1
	l3.add_child(pc)
	await get_tree().physics_frame
	pc.global_position = Vector2(68, 176)     # hueco lateral izq, cerca del borde inferior
	for i in 8:
		await get_tree().physics_frame
	var c_ok := pc.global_position.y < 90.0    # debe haber aparecido desde arriba

	print("=== V04 TEST RESULT ===")
	print("player_h_wrap (p11): ", "PASS" if a_ok else "FAIL", " (x=%.1f)" % a_x)
	print("proj_h_wrap (p11): ", "PASS" if b_ok else "FAIL", " (x=%.1f)" % b_x)
	print("player_v_wrap (p11): ", "PASS" if c_ok else "FAIL", " (y=%.1f)" % pc.global_position.y)
	print("=======================")
	get_tree().quit(0 if (a_ok and b_ok and c_ok) else 1)
