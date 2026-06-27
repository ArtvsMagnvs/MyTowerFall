extends Node
## V086Test — Verifica la Actualización V0.8.6 en condiciones NO lineales:
##  A) Anti-stuck terrestre (Slime, Troll): bloqueados contra una pared con el jugador
##     detrás → activan el bloqueo de patrulla (_patrol_lock) y se mueven (no se congelan).
##  B) Anti-stuck volador (Bat, Specter): atascados contra geometría → desbloqueo
##     perpendicular (_unstuck_timer) y se mueven.
##  C) Sin falso positivo: persecución con camino libre NO dispara el anti-stuck.
##  D) Bat LoS: pared entre Bat y jugador → NO hace dash; sin pared → SÍ hace dash.

var _lvl: LevelBase

func _ready() -> void:
	await _run()

func _make_wall(center: Vector2, size: Vector2) -> StaticBody2D:
	var w := StaticBody2D.new()
	w.add_to_group("world")
	w.collision_layer = 1
	w.collision_mask = 0
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = size
	c.shape = s
	w.add_child(c)
	_lvl.add_child(w)
	w.global_position = center
	return w

func _spawn(path: String, pos: Vector2) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_lvl.add_child(n)
	await get_tree().physics_frame
	n.global_position = pos
	return n

func _frozen_player(pos: Vector2) -> PlayerBase:
	var pl := (load("res://scenes/characters/Warrior.tscn") as PackedScene).instantiate() as PlayerBase
	pl.player_id = 1
	_lvl.add_child(pl)
	await get_tree().physics_frame
	pl.global_position = pos
	pl.set_physics_process(false)   # estático: no cae, no actúa, pero get_nearest_player lo ve
	return pl

func _run() -> void:
	_lvl = (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(_lvl)
	await get_tree().physics_frame

	# === A: anti-stuck terrestre ===
	# El jugador se coloca lo bastante lejos para que el monstruo persiga (y se atasque contra
	# el muro) en vez de atacar: el Troll puñetea a <40px, así que su jugador va más lejos.
	var slime_res := await _ground_stuck("res://scenes/monsters/Slime.tscn", 178.0)
	var troll_res := await _ground_stuck("res://scenes/monsters/StoneTroll.tscn", 205.0)

	# === B: anti-stuck volador ===
	var bat_stuck := await _fly_stuck("res://scenes/monsters/ShadowBat.tscn", 190.0)
	var spec_stuck := await _fly_stuck("res://scenes/monsters/SpecterArcher.tscn", 210.0)

	# === C: sin falso positivo (Slime con camino libre) ===
	var no_false := await _no_false_stuck()

	# === D: Bat LoS ===
	var los_blocked := await _bat_los(true)    # pared entre medias → NO dash
	var los_clear := await _bat_los(false)     # sin pared → SÍ dash

	print("=== V086 TEST RESULT ===")
	print("slime_antistuck (A): ", "PASS" if (slime_res.saw_lock and slime_res.moved and slime_res.alive) else "FAIL", " ", slime_res)
	print("troll_antistuck (A): ", "PASS" if (troll_res.saw_lock and troll_res.moved and troll_res.alive) else "FAIL", " ", troll_res)
	print("bat_antistuck (B): ", "PASS" if bat_stuck else "FAIL")
	print("specter_antistuck (B): ", "PASS" if spec_stuck else "FAIL")
	print("no_false_positive (C): ", "PASS" if no_false else "FAIL")
	print("bat_los_blocked_no_dash (D): ", "PASS" if los_blocked else "FAIL")
	print("bat_los_clear_dashes (D): ", "PASS" if los_clear else "FAIL")
	print("========================")
	var ok: bool = bool(slime_res.saw_lock) and bool(slime_res.moved) and bool(slime_res.alive) \
		and bool(troll_res.saw_lock) and bool(troll_res.moved) and bool(troll_res.alive) \
		and bat_stuck and spec_stuck and no_false and los_blocked and los_clear
	get_tree().quit(0 if ok else 1)

## Monstruo terrestre bloqueado contra una pared con el jugador al otro lado.
func _ground_stuck(path: String, player_x: float) -> Dictionary:
	var wall := _make_wall(Vector2(155, 145), Vector2(10, 50))   # x[150,160] y[120,170] (sobre el suelo)
	var mon := await _spawn(path, Vector2(140, 164)) as MonsterBase
	var pl := await _frozen_player(Vector2(player_x, 164))
	var saw_lock := false
	var minx := 999.0
	var maxx := -999.0
	for i in 200:   # ~3.3s
		await get_tree().physics_frame
		if not is_instance_valid(mon):
			break
		if mon.get("_patrol_lock") != null and mon._patrol_lock > 0.0:
			saw_lock = true
		minx = minf(minx, mon.global_position.x)
		maxx = maxf(maxx, mon.global_position.x)
	var res := {
		"saw_lock": saw_lock,
		"moved": (maxx - minx) > 10.0,
		"alive": is_instance_valid(mon) and not mon.is_dead,
	}
	if is_instance_valid(mon): mon.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(wall): wall.queue_free()
	await get_tree().physics_frame
	return res

## Monstruo volador empujando contra una pared para alcanzar al jugador detrás.
func _fly_stuck(path: String, player_x: float) -> bool:
	var wall := _make_wall(Vector2(155, 80), Vector2(10, 80))   # x[150,160] y[40,120]
	var mon := await _spawn(path, Vector2(140, 80)) as MonsterBase
	var pl := await _frozen_player(Vector2(player_x, 80))
	var saw_unstuck := false
	for i in 120:   # ~2s
		await get_tree().physics_frame
		if not is_instance_valid(mon):
			break
		if mon.get("_unstuck_timer") != null and mon._unstuck_timer > 0.0:
			saw_unstuck = true
	if is_instance_valid(mon): mon.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if is_instance_valid(wall): wall.queue_free()
	await get_tree().physics_frame
	return saw_unstuck

## Persecución con camino libre: el anti-stuck NO debe activarse.
func _no_false_stuck() -> bool:
	var mon := await _spawn("res://scenes/monsters/Slime.tscn", Vector2(100, 164)) as MonsterBase
	var pl := await _frozen_player(Vector2(170, 164))
	var triggered := false
	for i in 60:   # ~1s de persecución limpia (antes de alcanzarlo)
		await get_tree().physics_frame
		if not is_instance_valid(mon):
			break
		if mon.get("_patrol_lock") != null and mon._patrol_lock > 0.0:
			triggered = true
	if is_instance_valid(mon): mon.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	await get_tree().physics_frame
	return not triggered

## Bat con o sin pared entre él y el jugador. Devuelve si el comportamiento es el esperado.
func _bat_los(blocked: bool) -> bool:
	var wall: StaticBody2D = null
	if blocked:
		wall = _make_wall(Vector2(165, 80), Vector2(10, 80))   # x[160,170] y[40,120], entre medias
	var bat := await _spawn("res://scenes/monsters/ShadowBat.tscn", Vector2(150, 80)) as ShadowBat
	var px := 190.0 if blocked else 185.0
	var pl := await _frozen_player(Vector2(px, 80))
	# Esperar a que entre en TRACKING y forzar el cooldown a 0 para que intente el dash ya.
	var saw_dash := false
	for i in 200:   # ~3.3s
		await get_tree().physics_frame
		if not is_instance_valid(bat):
			break
		if bat._state == ShadowBat.BState.TRACKING:
			bat._cooldown = 0.0
		if bat._state == ShadowBat.BState.DASHING or bat._state == ShadowBat.BState.PREPARING_DASH:
			saw_dash = true
	if is_instance_valid(bat): bat.queue_free()
	if is_instance_valid(pl): pl.queue_free()
	if wall != null and is_instance_valid(wall): wall.queue_free()
	await get_tree().physics_frame
	# blocked → esperamos NO dash; clear → esperamos SÍ dash.
	return (not saw_dash) if blocked else saw_dash
