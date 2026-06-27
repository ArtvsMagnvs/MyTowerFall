extends Node
## V083Test — Verifica la Actualización V0.8.3:
##  P1) Durante el DASH el jugador ATRAVIESA un monstruo sólido (Slime).
##  P2) El wall slide se corta al acabar la pared de una plataforma fina (cae libre).
##  P3) Caer sobre el Troll lo mata (stomp con rayo de 6px).
##  P4) Al morir con impulso, _last_corpse queda guardado y se desplaza del punto de muerte.

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame

	# --- P1: dash atraviesa un Slime sólido ---
	var slime := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(slime)
	var pa := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	lvl.add_child(pa)
	await get_tree().physics_frame
	pa.global_position = Vector2(70, 168)
	slime.global_position = Vector2(95, 168)
	slime.set_physics_process(false)
	Input.action_press("p1_right")
	Input.action_press("p1_dash")
	await get_tree().physics_frame   # se dispara el dash (just_pressed)
	Input.action_release("p1_dash")
	for i in 12:
		await get_tree().physics_frame
	Input.action_release("p1_right")
	# Con P1, el dash cruza al Slime → x del jugador supera la del Slime.
	var p1_ok := is_instance_valid(pa) and not pa.is_dead \
			and pa.global_position.x > slime.global_position.x
	var p1_x := pa.global_position.x if is_instance_valid(pa) else -999.0
	if is_instance_valid(pa): pa.queue_free()
	if is_instance_valid(slime): slime.queue_free()
	await get_tree().physics_frame

	# --- P2: wall slide se corta al acabar una plataforma fina ---
	var plat := StaticBody2D.new()
	plat.add_to_group("world")
	plat.collision_layer = 1
	plat.collision_mask = 0
	var pcol := CollisionShape2D.new()
	var pshape := RectangleShape2D.new()
	# Pared corta (≈2 tiles, y∈[80,104]): hay zona de wall slide bajo el borde superior
	# (sin que se dispare el ledge grab), y la pared ACABA en y=104.
	pshape.size = Vector2(10, 24)
	pcol.shape = pshape
	plat.add_child(pcol)
	lvl.add_child(plat)
	# Columna x≈200 en la parte alta: por debajo (hasta y≈150) está libre de geometría del nivel.
	plat.global_position = Vector2(200, 46)   # pared y∈[34,58]
	var pw := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pw.player_id = 1
	lvl.add_child(pw)
	await get_tree().physics_frame
	pw.global_position = Vector2(191, 49)   # pegado a la cara izq, por debajo del borde superior
	pw.velocity = Vector2(0, 5)
	Input.action_press("p1_right")          # empuja contra la pared
	var max_vy := 0.0
	var saw_wall_slide := false
	for i in 50:
		await get_tree().physics_frame
		if not is_instance_valid(pw):
			break
		if pw.state == PlayerBase.State.WALL_SLIDE:
			saw_wall_slide = true
		max_vy = maxf(max_vy, pw.velocity.y)
	Input.action_release("p1_right")
	# Si el slide quedara "pegado" sin pared, vy nunca superaría wall_slide_speed (60).
	# Con el fix, al pasar el borde inferior cae libre y vy supera ese tope.
	var p2_ok := saw_wall_slide and max_vy > 90.0
	if is_instance_valid(pw): pw.queue_free()
	if is_instance_valid(plat): plat.queue_free()
	await get_tree().physics_frame

	# --- P3: caer sobre el Troll lo mata ---
	var troll := (load("res://scenes/monsters/StoneTroll.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(troll)
	var pt := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pt.player_id = 1
	lvl.add_child(pt)
	await get_tree().physics_frame
	troll.global_position = Vector2(70, 164)
	troll.set_physics_process(false)
	pt.global_position = Vector2(70, 150)
	pt.velocity = Vector2(0, 140)
	for i in 30:
		await get_tree().physics_frame
	var p3_ok := (not is_instance_valid(troll)) or troll.is_dead
	if is_instance_valid(pt): pt.queue_free()
	if is_instance_valid(troll): troll.queue_free()
	await get_tree().physics_frame

	# --- P4: _last_corpse guardado y desplazado por el impulso del proyectil ---
	var pd := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pd.player_id = 1
	lvl.add_child(pd)
	await get_tree().physics_frame
	pd.global_position = Vector2(160, 80)
	var proj := ProjectileBase.new()
	proj.kind = "arrow"
	proj.owner_node = null
	lvl.add_child(proj)                       # _ready() fija death_impulse=110
	proj.setup(Vector2(120, 80), Vector2(1, 0), 300.0)
	pd.die(proj)
	if is_instance_valid(proj): proj.queue_free()
	var death_pos: Vector2 = pd.last_death_pos
	for i in 25:
		await get_tree().physics_frame
	var corpse = pd._last_corpse
	var p4_ok := corpse != null and is_instance_valid(corpse) \
			and (corpse as Node2D).global_position.x > death_pos.x + 2.0
	var corpse_dx := ((corpse as Node2D).global_position.x - death_pos.x) if (corpse != null and is_instance_valid(corpse)) else -999.0

	print("=== V083 TEST RESULT ===")
	print("dash_through_slime (P1): ", "PASS" if p1_ok else "FAIL", " (px=", p1_x, " slime.x=95)")
	print("wall_slide_stops (P2): ", "PASS" if p2_ok else "FAIL", " (saw_slide=", saw_wall_slide, " max_vy=", max_vy, ")")
	print("stomp_kills_troll (P3): ", "PASS" if p3_ok else "FAIL")
	print("corpse_ref_displaced (P4): ", "PASS" if p4_ok else "FAIL", " (corpse_dx=", corpse_dx, ")")
	print("========================")
	get_tree().quit(0 if (p1_ok and p2_ok and p3_ok and p4_ok) else 1)
