extends Node
## V03Test — Verifica mecánicas de la Actualización V0.3 (temporal):
##  A) contacto lateral con enemigo pasivo NO mata (punto 8)
##  B) stomp sobre un goblin en el aire SÍ funciona (punto 5)
##  C) la flecha queda clavada en el suelo tras desaparecer el cadáver (punto 4)

func _ready() -> void:
	await _run()

func _run() -> void:
	var level := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(level)
	await get_tree().physics_frame

	# --- A: contacto lateral no letal (Espectro: is_attack_active siempre false) ---
	var pa := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	level.add_child(pa)
	var spec := (load("res://scenes/monsters/SpecterArcher.tscn") as PackedScene).instantiate() as MonsterBase
	level.add_child(spec)
	await get_tree().physics_frame
	pa.global_position = Vector2(90, 150)
	for i in 30:
		spec.global_position = pa.global_position   # solapamiento lateral forzado
		await get_tree().physics_frame
	var a_ok := not pa.is_dead
	spec.queue_free()
	pa.queue_free()

	# --- B: stomp sobre goblin en el aire ---
	var gob := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as Slime
	level.add_child(gob)
	var pb := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pb.player_id = 2
	level.add_child(pb)
	await get_tree().physics_frame
	gob.global_position = Vector2(210, 150)
	gob._state = Slime.G.AIRBORNE
	gob.velocity = Vector2(0, -60)            # subiendo (rising) → no letal, pero stompable
	pb.global_position = Vector2(210, 138)
	pb.velocity = Vector2(0, 120)             # cayendo sobre el goblin
	for i in 50:
		await get_tree().physics_frame
	var b_ok := not is_instance_valid(gob) or gob.is_dead
	if is_instance_valid(pb):
		pb.queue_free()   # aislar C: ningún jugador debe recoger la flecha caída
	await get_tree().physics_frame

	# --- C: flecha cae al suelo tras desaparecer el cadáver ---
	var gob2 := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as Slime
	level.add_child(gob2)
	await get_tree().physics_frame
	gob2.global_position = Vector2(120, 150)
	var arr := ProjectileBase.new()      # flecha simulada (no en árbol)
	arr.kind = "arrow"
	arr.carries_pickup = true
	arr.death_impulse = 200.0
	arr.proj_color = Color(0.9, 0.8, 0.3)
	arr.velocity = Vector2(120, 0)
	gob2.die(arr)
	arr.free()
	for i in 220:                         # > vida del cadáver (2.5s)
		await get_tree().physics_frame
	var c_ok := get_tree().get_nodes_in_group("stuck_projectile").size() >= 1

	print("=== V03 TEST RESULT ===")
	print("lateral_no_kill (p8): ", "PASS" if a_ok else "FAIL")
	print("stomp_airborne (p5): ", "PASS" if b_ok else "FAIL")
	print("arrow_drops_to_floor (p4): ", "PASS" if c_ok else "FAIL")
	print("=======================")
	get_tree().quit(0 if (a_ok and b_ok and c_ok) else 1)
