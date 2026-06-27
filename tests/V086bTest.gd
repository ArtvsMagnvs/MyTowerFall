extends Node
## V086bTest — Escenarios "encima/debajo con plataforma horizontal en medio" (reporte del
## usuario), que la detección por VELOCIDAD no cubría (oscilación con velocidad alta pero
## desplazamiento neto ~0):
##  E) Troll bajo un jugador elevado con plataforma entre medias → no se queda clavado
##     oscilando: el anti-stuck (progreso+LoS) lo hace patrullar y moverse.
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
func _troll_under_elevated() -> bool:
	var plat := _make_wall(Vector2(160, 100), Vector2(90, 6))   # x[115,205] y[97,103]
	var troll := await _spawn("res://scenes/monsters/StoneTroll.tscn", Vector2(160, 164)) as MonsterBase
	var pl := await _frozen_player(Vector2(160, 75))            # encima de la plataforma
	var saw_lock := false
	var minx := 999.0
	var maxx := -999.0
	for i in 220:
		await get_tree().physics_frame
		if not is_instance_valid(troll): break
		if troll._patrol_lock > 0.0: saw_lock = true
		minx = minf(minx, troll.global_position.x)
		maxx = maxf(maxx, troll.global_position.x)
	var ok := saw_lock and (maxx - minx) > 15.0 and is_instance_valid(troll) and not troll.is_dead
	if is_instance_valid(troll): troll.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(plat): plat.queue_free()
	await get_tree().physics_frame
	return ok

## Bat y jugador en lados opuestos de una plataforma horizontal ancha. Verifica que el Bat
## NUNCA carga el dash sin LoS limpia ni con el camino del dash bloqueado, y que se desbloquea.
func _bat_platform_between(bat_pos: Vector2, player_pos: Vector2) -> bool:
	var plat := _make_wall(Vector2(160, 100), Vector2(120, 6))   # plataforma ancha x[100,220]
	var bat := await _spawn("res://scenes/monsters/ShadowBat.tscn", bat_pos) as ShadowBat
	var pl := await _frozen_player(player_pos)
	var bad_charge := false   # cargar/preparar dash sin LoS al jugador
	var bad_path := false     # preparar dash con el camino snappeado bloqueado
	var saw_unstuck := false
	for i in 200:
		await get_tree().physics_frame
		if not is_instance_valid(bat): break
		if bat._state == ShadowBat.BState.TRACKING:
			bat._cooldown = 0.0   # forzar intento de dash en cada frame: solo lo frena el LoS/camino
		if bat._unstuck_timer > 0.0:
			saw_unstuck = true
		if bat._state == ShadowBat.BState.PREPARING_DASH:
			if not bat.has_clear_los(pl):
				bad_charge = true
			if bat.path_blocked(bat._dash_dir, ShadowBat.DASH_DISTANCE + 4.0):
				bad_path = true
	var ok := (not bad_charge) and (not bad_path) and saw_unstuck
	if is_instance_valid(bat): bat.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(plat): plat.queue_free()
	await get_tree().physics_frame
	return ok
