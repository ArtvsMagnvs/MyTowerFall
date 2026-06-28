extends Node
## V086bTest — Escenarios "encima/debajo con plataforma horizontal en medio" (reporte del
## usuario), que la detección por VELOCIDAD no cubría (oscilación con velocidad alta pero
## desplazamiento neto ~0):
##  E) Troll bajo un jugador elevado con plataforma entre medias → no se queda clavado
##     oscilando. V0.8.7.3: con el gate de plataforma, el Troll directamente NO entra en
##     CHASE (|dy| >= 14 px) — patrulla y olvida. Validamos que se mueve Y no rebota.
##  F) Bat DEBAJO de una plataforma, jugador encima → NUNCA carga el dash sin LoS, y se
##     desbloquea (el camino del dash snappeado también se comprueba).
##  G) Bat ENCIMA de una plataforma, jugador debajo → idem.

var _lvl: LevelBase

func _ready() -> void:
	await _run()

func _make_wall(center: Vector2, size: Vector2) -> StaticBody2D:
	var w := StaticBody2D.new()
	w.add_to_group("world"); w.collision_layer = 1; w.collision_mask = 0
	var c := CollisionShape2D.new(); var s := RectangleShape2D.new(); s.size = size; c.shape = s
	w.add_child(c); _lvl.add_child(w); w.global_position = center
	return w

func _spawn(path: String, pos: Vector2) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_lvl.add_child(n); await get_tree().physics_frame
	n.global_position = pos
	return n

func _frozen_player(pos: Vector2) -> PlayerBase:
	var pl := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pl.player_id = 1; _lvl.add_child(pl); await get_tree().physics_frame
	pl.global_position = pos; pl.set_physics_process(false)
	return pl

func _run() -> void:
	_lvl = (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_lvl); await get_tree().physics_frame

	var e := await _troll_under_elevated()
	var f := await _bat_platform_between(Vector2(160, 125), Vector2(160, 68))   # bat debajo, jugador arriba
	var g := await _bat_platform_between(Vector2(160, 72), Vector2(160, 132))   # bat arriba, jugador debajo

	print("=== V086B TEST RESULT ===")
	print("troll_under_elevated_circula (E): ", "PASS" if e else "FAIL")
	print("bat_below_no_charge_no_los (F): ", "PASS" if f else "FAIL")
	print("bat_above_no_charge_no_los (G): ", "PASS" if g else "FAIL")
	print("=========================")
	get_tree().quit(0 if (e and f and g) else 1)

## Troll en el suelo, jugador elevado con plataforma horizontal entre medias.
## V0.8.7.3: con el gate de plataforma (|dy| >= 14 px), el Troll directamente NO entra en
## CHASE — patrulla y se olvida. La aserción antigua esperaba `saw_lock=true` (el Troll se
## quedaba stuck bajo la plataforma y el anti-stuck le forzaba a circular). Con la nueva
## semántica, el Troll nunca llega a CHASE, así que `patrol_lock` puede quedarse en 0.
## Validamos: (a) el Troll NO está clavado (se mueve >15 px), (b) sigue vivo, (c) no
## rebota entre estados (medimos cambios de dirección como proxy de oscilación en CHASE).
func _troll_under_elevated() -> bool:
	var plat := _make_wall(Vector2(160, 100), Vector2(90, 6))   # x[115,205] y[97,103]
	var troll := await _spawn("res://scenes/monsters/StoneTroll.tscn", Vector2(160, 164)) as MonsterBase
	var pl := await _frozen_player(Vector2(160, 75))            # encima de la plataforma
	var minx := 999.0
	var maxx := -999.0
	var prev_dir_sign := 0.0
	var sign_changes := 0
	for i in 220:
		await get_tree().physics_frame
		if not is_instance_valid(troll): break
		minx = minf(minx, troll.global_position.x)
		maxx = maxf(maxx, troll.global_position.x)
		# Contamos cambios de signo de velocidad horizontal (proxy de oscilación chase↔patrol).
		var vx := troll.velocity.x
		var sign := 0.0
		if vx > 1.0: sign = 1.0
		elif vx < -1.0: sign = -1.0
		if sign != 0.0 and prev_dir_sign != 0.0 and sign != prev_dir_sign:
			sign_changes += 1
		if sign != 0.0: prev_dir_sign = sign
	# V0.8.7.3: "no clavado-cíclico" = se mueve Y no rebota mucho. PATROL cambia al chocar
	# con pared (gira), eso es 1-2 cambios. CHASE↔PATROL ping-pong serían >=5.
	var ok := (maxx - minx) > 15.0 and is_instance_valid(troll) and not troll.is_dead and sign_changes <= 4
	if is_instance_valid(troll): troll.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(plat): plat.queue_free()
	await get_tree().physics_frame
	return ok

## Bat y jugador en lados opuestos de una plataforma horizontal ancha. Verifica que el Bat
## NUNCA carga el dash sin LoS limpia ni con el camino del dash bloqueado, y que responde al
## anti-stuck (ya sea con unstuck perpendicular o volviendo a FLYING, ambos son válidos en V0.8.7.2).
func _bat_platform_between(bat_pos: Vector2, player_pos: Vector2) -> bool:
	var plat := _make_wall(Vector2(160, 100), Vector2(120, 6))   # plataforma ancha x[100,220]
	var bat := await _spawn("res://scenes/monsters/ShadowBat.tscn", bat_pos) as ShadowBat
	var pl := await _frozen_player(player_pos)
	var bad_charge := false   # cargar/preparar dash sin LoS al jugador
	var bad_path := false     # preparar dash con el camino snappeado bloqueado
	# V0.8.7.2: el anti-stuck del Bat puede ser unstuck perpendicular O vuelta a FLYING
	# (gate de LoS). Aceptamos cualquiera de los dos como respuesta válida.
	var saw_anti_stuck := false
	for i in 200:
		await get_tree().physics_frame
		if not is_instance_valid(bat): break
		# V0.8.7.2: si el Bat está en FLYING (porque el gate de LoS de V0.8.7.2 bloqueó
		# la entrada a TRACKING), forzarlo a TRACKING para probar también el gate interno.
		if bat._state == ShadowBat.BState.FLYING:
			bat._state = ShadowBat.BState.TRACKING
		if bat._state == ShadowBat.BState.TRACKING:
			bat._cooldown = 0.0   # forzar intento de dash en cada frame: solo lo frena el LoS/camino
		if bat._unstuck_timer > 0.0 or bat._state == ShadowBat.BState.FLYING:
			saw_anti_stuck = true
		if bat._state == ShadowBat.BState.PREPARING_DASH:
			if not bat.has_clear_los(pl):
				bad_charge = true
			if bat.path_blocked(bat._dash_dir, ShadowBat.DASH_DISTANCE + 4.0):
				bad_path = true
	var ok := (not bad_charge) and (not bad_path) and saw_anti_stuck
	if is_instance_valid(bat): bat.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(plat): plat.queue_free()
	await get_tree().physics_frame
	return ok
