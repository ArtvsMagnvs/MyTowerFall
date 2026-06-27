extends Node
## V051Test — BUG-1 (no tunneling) y CAMBIO-10 (plataforma sólida desde abajo).

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	await get_tree().physics_frame

	# --- A: flecha muy rápida contra la pared izquierda (x40-56, y10-150) ---
	var arr := ProjectileBase.new()
	arr.kind = "arrow"
	arr.proj_color = Color(0.9, 0.8, 0.3)
	lvl.add_child(arr)
	arr.proj_gravity = 0.0   # trayectoria recta para aislar el test
	arr.setup(Vector2(200, 80), Vector2.LEFT, 600.0)   # 2× de rápido
	for i in 40:
		await get_tree().physics_frame
		if not is_instance_valid(arr):
			break
	var a_ok := is_instance_valid(arr) and arr.is_in_group("stuck_projectile") and arr.global_position.x > 50.0
	var a_x := arr.global_position.x if is_instance_valid(arr) else -999.0
	if is_instance_valid(arr): arr.queue_free()
	await get_tree().physics_frame

	# --- B: plataforma flotante sólida desde abajo (main platform y150, x80-240) ---
	var pl := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pl.player_id = 1
	lvl.add_child(pl)
	await get_tree().physics_frame
	pl.global_position = Vector2(160, 168)   # bajo la plataforma central
	var min_y := 999.0
	for i in 50:
		pl.velocity.y = -300.0               # empujar hacia arriba con fuerza cada frame
		await get_tree().physics_frame
		min_y = minf(min_y, pl.global_position.y)
	# Si la plataforma es sólida, el jugador nunca cruza por encima de su borde (y=150).
	var b_ok := min_y > 150.0

	print("=== V051 TEST RESULT ===")
	print("arrow_no_tunnel (BUG-1): ", "PASS" if a_ok else "FAIL", " (x=%.1f stuck=%s)" % [a_x, arr.is_in_group("stuck_projectile") if is_instance_valid(arr) else false])
	print("platform_solid_below (CAMBIO-10): ", "PASS" if b_ok else "FAIL", " (min_y=%.1f)" % min_y)
	print("========================")
	get_tree().quit(0 if (a_ok and b_ok) else 1)
