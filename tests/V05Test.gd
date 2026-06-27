extends Node
## V05Test — Verifica el stomp determinista (Actualización V0.5 punto 5):
##  A) jugador cae sobre Slime → Slime muere y el jugador rebota
##  B) jugador en DASH cae sobre Slime → nadie muere (el dash esquiva)
##  C) jugador cae sobre Espectro → el Espectro NO recibe stomp (sobrevive)
## Columna x=70: libre de plataformas entre el punto de caída y el suelo.

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame

	# --- A: stomp normal sobre Slime ---
	var slime := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(slime)
	var pa := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pa.player_id = 1
	lvl.add_child(pa)
	await get_tree().physics_frame
	slime.global_position = Vector2(70, 164)
	slime.set_physics_process(false)   # congelar IA para una caída determinista
	pa.global_position = Vector2(70, 150)
	pa.velocity = Vector2(0, 140)
	var a_bounced := false
	for i in 40:
		await get_tree().physics_frame
		if is_instance_valid(pa) and pa.velocity.y < -40.0:
			a_bounced = true
	var a_ok := (not is_instance_valid(slime) or slime.is_dead) and a_bounced
	if is_instance_valid(pa): pa.queue_free()
	await get_tree().physics_frame

	# --- B: jugador en DASH cae sobre Slime → nadie muere ---
	var slime2 := (load("res://scenes/monsters/Slime.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(slime2)
	var pb := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pb.player_id = 2
	lvl.add_child(pb)
	await get_tree().physics_frame
	slime2.global_position = Vector2(70, 164)
	slime2.set_physics_process(false)
	pb.global_position = Vector2(70, 150)
	pb._dash_dir = Vector2(0, 1)   # caída en dash (solo para el test)
	pb._dash_time = 0.5
	for i in 18:
		await get_tree().physics_frame
	var b_ok := is_instance_valid(slime2) and not slime2.is_dead and not pb.is_dead
	if is_instance_valid(slime2): slime2.queue_free()
	if is_instance_valid(pb): pb.queue_free()
	await get_tree().physics_frame

	# --- C: stomp sobre Espectro → no recibe stomp ---
	var spec := (load("res://scenes/monsters/SpecterArcher.tscn") as PackedScene).instantiate() as MonsterBase
	lvl.add_child(spec)
	var pc := (load("res://scenes/characters/Archer.tscn") as PackedScene).instantiate() as PlayerBase
	pc.player_id = 1
	lvl.add_child(pc)
	await get_tree().physics_frame
	spec.global_position = Vector2(70, 150)
	pc.global_position = Vector2(70, 136)
	pc.velocity = Vector2(0, 140)
	for i in 26:
		await get_tree().physics_frame
	var c_ok := is_instance_valid(spec) and not spec.is_dead

	print("=== V05 TEST RESULT ===")
	print("stomp_kills_slime (p5): ", "PASS" if a_ok else "FAIL")
	print("dash_no_stomp (p5): ", "PASS" if b_ok else "FAIL")
	print("specter_not_stompable (p5): ", "PASS" if c_ok else "FAIL")
	print("=======================")
	get_tree().quit(0 if (a_ok and b_ok and c_ok) else 1)
