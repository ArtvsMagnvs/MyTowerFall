extends Node
## V082Test — Verifica las correcciones de física de la Actualización V0.8.2:
##  B-1) El jugador choca contra un Slime SÓLIDO (no lo atraviesa).
##  B-1) El jugador atraviesa al Espectro (no sólido) sin bloqueo.
##  B-2) Un Troll debajo de una plataforma NO muere cuando el jugador aterriza encima.
## Usa la columna x=70 del Nivel 1 (libre de plataformas hasta el suelo) salvo donde
## se construye una plataforma de prueba propia.

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame

	# --- B-1a: el jugador choca contra un Slime sólido y no lo atraviesa ---
	var slime := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(slime)
	var pa := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	lvl.add_child(pa)
	await get_tree().physics_frame
	# Ambos en el suelo (y≈170), separados en horizontal; el Slime a la derecha.
	pa.global_position = Vector2(70, 168)
	slime.global_position = Vector2(95, 168)
	slime.set_physics_process(false)   # IA congelada: el Slime es un muro estático
	Input.action_press("p1_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("p1_right")
	# Con B-1, el jugador queda a la izquierda del Slime (bloqueado). Sin B-1 lo cruzaría.
	var b1a_ok := is_instance_valid(pa) and not pa.is_dead \
			and pa.global_position.x < slime.global_position.x - 2.0
	var b1a_x := pa.global_position.x if is_instance_valid(pa) else -999.0
	if is_instance_valid(pa): pa.queue_free()
	if is_instance_valid(slime): slime.queue_free()
	await get_tree().physics_frame

	# --- B-1b: el jugador atraviesa al Espectro (no sólido) ---
	var spec := (load("res://scenes/monsters/SpecterArcher.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(spec)
	var pb := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pb.player_id = 1
	lvl.add_child(pb)
	await get_tree().physics_frame
	pb.global_position = Vector2(70, 168)
	spec.global_position = Vector2(95, 168)
	spec.set_physics_process(false)
	Input.action_press("p1_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("p1_right")
	# El jugador debe poder rebasar la x del Espectro (sin bloqueo físico).
	var b1b_ok := is_instance_valid(pb) and not pb.is_dead \
			and pb.global_position.x > spec.global_position.x - 1.0
	var b1b_x := pb.global_position.x if is_instance_valid(pb) else -999.0
	if is_instance_valid(pb): pb.queue_free()
	if is_instance_valid(spec): spec.queue_free()
	await get_tree().physics_frame

	# --- B-2: Troll bajo una plataforma; el jugador aterriza encima y el Troll NO muere ---
	var plat := StaticBody2D.new()
	plat.add_to_group("world")
	plat.collision_layer = 1   # L_WORLD
	plat.collision_mask = 0
	var pcol := CollisionShape2D.new()
	var pshape := RectangleShape2D.new()
	pshape.size = Vector2(40, 8)
	pcol.shape = pshape
	plat.add_child(pcol)
	lvl.add_child(plat)
	plat.global_position = Vector2(70, 120)
	var troll := (load("res://scenes/monsters/StoneTroll.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(troll)
	var pc := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pc.player_id = 1
	lvl.add_child(pc)
	await get_tree().physics_frame
	# Troll justo debajo de la plataforma (su parte superior casi tocando el borde inferior).
	troll.global_position = Vector2(70, 132)
	troll.set_physics_process(false)
	# Jugador cae sobre la plataforma desde arriba.
	pc.global_position = Vector2(70, 100)
	pc.velocity = Vector2(0, 120)
	for i in 40:
		await get_tree().physics_frame
	var b2_ok := is_instance_valid(troll) and not troll.is_dead
	var b2_py := pc.global_position.y if is_instance_valid(pc) else -999.0

	print("=== V082 TEST RESULT ===")
	print("solid_slime_blocks (B-1): ", "PASS" if b1a_ok else "FAIL", " (px=", b1a_x, " slime.x=", 95.0, ")")
	print("specter_passthrough (B-1): ", "PASS" if b1b_ok else "FAIL", " (px=", b1b_x, ")")
	print("stomp_not_through_platform (B-2): ", "PASS" if b2_ok else "FAIL", " (player_y=", b2_py, ")")
	print("========================")
	get_tree().quit(0 if (b1a_ok and b1b_ok and b2_ok) else 1)
