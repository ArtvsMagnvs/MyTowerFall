extends Node2D
## VersusMatch — Controlador de partida PvP local (§6.2 + Actualización V0.2 punto 11).
## Carga la arena, genera P1 y P2, gestiona 4 vidas por jugador con respawn animado
## (bola de energía + onda expansiva) y rondas al mejor de 5.
## Autor: Claude Code · Versión: 0.5.0

var _level: LevelBase
var _hud: HUD
var _p1: PlayerBase
var _p2: PlayerBase
var _round_active := false

func _ready() -> void:
	var arena_path: String = GameManager.ARENAS[GameManager.selected_arena_index]
	_level = (load(arena_path) as PackedScene).instantiate() as LevelBase
	add_child(_level)
	_hud = HUD.new()
	add_child(_hud)
	AudioManager.play_music("versus")
	_spawn_players()
	_start_round()
	# V0.8.2 E-3: cuenta atrás 3, 2, 1, ¡YA! con ambos jugadores bloqueados.
	await _run_countdown()
	if is_instance_valid(_p1):
		_p1.frozen = false
	if is_instance_valid(_p2):
		_p2.frozen = false

func _spawn_players() -> void:
	_p1 = GameManager.class_scene(GameManager.p1_class).instantiate() as PlayerBase
	_p1.player_id = 1
	_p1.frozen = true   # V0.8.2 E-3: bloqueado hasta el fin de la cuenta atrás
	_level.add_child(_p1)
	_p1.on_died.connect(_on_player_died)
	_p2 = GameManager.class_scene(GameManager.p2_class).instantiate() as PlayerBase
	_p2.player_id = 2
	_p2.frozen = true   # V0.8.2 E-3
	_level.add_child(_p2)
	_p2.on_died.connect(_on_player_died)

func _start_round() -> void:
	var spawns := _level.player_spawns()
	_p1.lives = PlayerBase.LIVES_MAX
	_p2.lives = PlayerBase.LIVES_MAX
	# V0.8.7.4.1: al inicio de cada ronda ambos jugadores arrancan con AMMO_INITIAL (3).
	# Si mueren durante la ronda y se reviven con gema, obtienen solo AMMO_START (1)
	# vía _respawn_player → player.respawn() sin override.
	_p1.respawn(spawns[0], PlayerBase.AMMO_INITIAL)
	_p2.respawn(spawns[1 % spawns.size()], PlayerBase.AMMO_INITIAL)
	_hud.set_versus(GameManager.p1_wins, GameManager.p2_wins, GameManager.rounds_to_win)
	_update_lives_hud()
	_hud.show_banner("¡LISTOS!", 1.0)
	_round_active = true

func _update_lives_hud() -> void:
	_hud.set_lives(_p1.lives, _p2.lives, _p1.body_color, _p2.body_color)

func _on_player_died(loser_id: int) -> void:
	if not _round_active:
		return
	var p := _p1 if loser_id == 1 else _p2
	p.lives -= 1
	_update_lives_hud()
	if p.lives > 0:
		_respawn_player(p, loser_id)
	else:
		_end_round(2 if loser_id == 1 else 1)

func _respawn_player(p: PlayerBase, pid: int) -> void:
	# V0.3 punto 13: el cristal viaja a la posición del cadáver (no al spawn fijo),
	# salvo que esa posición esté en el vacío. Viaje 50% más lento (0.9s).
	var corpse_pos: Vector2 = p.last_death_pos
	if p._last_corpse != null and is_instance_valid(p._last_corpse):
		corpse_pos = (p._last_corpse as Node2D).global_position
	var target: Vector2 = _level.safe_respawn_pos(corpse_pos)
	var start := _hud.life_anchor(pid)
	# V0.8.7.4: la gema viaja al CUERPO. Al llegar se ejecuta la nueva secuencia
	# visual (elevación del cadáver, aura de la gema) y finalmente el respawn
	# (onda expansiva + blink) en `target`.
	# V0.8.7.4.2: la "mini-carga con rayos eléctricos" eliminada — tapaba la onda.
	var ball := _make_gem(start, p.body_color)
	_level.add_child(ball)
	var corpse_node: Node2D = p._last_corpse if is_instance_valid(p._last_corpse) else null
	_play_respawn_sequence(ball, corpse_pos, target, corpse_node, p)
	# Cuando termine la secuencia, _play_respawn_sequence llamará a p.respawn(target).

## V0.8.7.4: secuencia visual de respawn (idéntica a StoryMatch).
## 1. Gema viaja al cuerpo (0.9s, misma curva que antes).
## 2. Al llegar: cuerpo se eleva + se ilumina (0.3s), gema crece con aura (1s total).
## 3. Gema desaparece y el jugador aparece con la onda expansiva + blink.
##    (V0.8.7.4 original tenía una "mini-carga con rayos eléctricos" de 0.5s
##     entre el paso 2 y el 3; eliminada en V0.8.7.4.2 porque tapaba la onda.)
func _play_respawn_sequence(ball: ColorRect, corpse_pos: Vector2, target: Vector2,
		corpse_node: Node2D, player: PlayerBase) -> void:
	var start := ball.global_position
	var mid := (start + corpse_pos) * 0.5 + Vector2(0, -28)
	var tw := ball.create_tween()
	tw.tween_property(ball, "position", mid - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ball, "position", corpse_pos - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_on_gem_arrived(ball, corpse_node, target, player))

func _on_gem_arrived(ball: ColorRect, corpse_node: Node2D, target: Vector2,
		player: PlayerBase) -> void:
	# Paso 2a: cuerpo se eleva ligeramente y se ilumina (animación placeholder).
	# TODO pixel art: sprite/animación única de "cuerpo flotando".
	if corpse_node != null and is_instance_valid(corpse_node):
		var tw_rise := corpse_node.create_tween()
		tw_rise.set_parallel(true)
		tw_rise.tween_property(corpse_node, "position:y",
				corpse_node.global_position.y - 5.0, 0.3).set_trans(Tween.TRANS_SINE)
		tw_rise.tween_property(corpse_node, "modulate",
				Color(1.7, 1.7, 1.7, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	# Paso 2b: aura dorada alrededor de la gema + gema crece (1s total).
	# TODO pixel art: el aura debería ser un sprite único de "carga de gema".
	var aura := Polygon2D.new()
	var r := 8.0
	aura.polygon = PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	aura.color = Color(1.0, 0.9, 0.5, 0.0)
	aura.global_position = ball.global_position + Vector2(3, 3)
	_level.add_child(aura)
	var tw_aura := aura.create_tween()
	tw_aura.set_parallel(true)
	tw_aura.tween_property(aura, "scale", Vector2(1.8, 1.8), 1.0).set_trans(Tween.TRANS_SINE)
	tw_aura.tween_property(aura, "modulate:a", 1.0, 0.4)
	tw_aura.chain().tween_property(aura, "modulate:a", 0.0, 0.6)
	# La gema crece y se desvanece al final del segundo 1.
	var tw_ball := ball.create_tween()
	tw_ball.set_parallel(true)
	tw_ball.tween_property(ball, "scale", Vector2(1.7, 1.7), 1.0).set_trans(Tween.TRANS_SINE)
	tw_ball.tween_property(ball, "modulate:a", 0.0, 0.4).set_delay(0.6)
	# V0.8.7.4.2: sin mini-carga intermedia — el "remolino de rayos" V0.8.7.4 era
	# ruido creativo que tapaba la propia onda expansiva. Eliminado.
	tw_ball.chain().tween_callback(func() -> void:
		ball.queue_free()
		if is_instance_valid(aura): aura.queue_free()
		player.respawn(target))

## V0.8.7.4: crea una "gema" como ColorRect cuadrado con el color del cuerpo del jugador.
func _make_gem(start_pos: Vector2, color: Color) -> ColorRect:
	var g := ColorRect.new()
	g.color = color
	g.size = Vector2(6, 6)
	g.position = start_pos - Vector2(3, 3)
	g.z_index = 50
	return g

func _end_round(winner: int) -> void:
	_round_active = false
	GameManager.register_round_win(winner)
	_hud.set_versus(GameManager.p1_wins, GameManager.p2_wins, GameManager.rounds_to_win)
	_hud.show_banner("¡JUGADOR %d GANA LA RONDA!" % winner)
	await get_tree().create_timer(2.0).timeout
	if GameManager.versus_match_over():
		_end_match()
	else:
		_hud.hide_banner()
		_start_round()

func _end_match() -> void:
	_hud.show_banner("¡JUGADOR %d GANA LA PARTIDA!" % GameManager.versus_winner())
	await get_tree().create_timer(3.0).timeout
	SceneManager.goto_main_menu()

## V0.8.2 E-3: muestra 3, 2, 1, ¡YA! centrado en pantalla con outline.
func _run_countdown() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 80
	add_child(cl)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	cl.add_child(lbl)
	var steps := [["3", 1.0], ["2", 1.0], ["1", 1.0], ["¡YA!", 0.5]]
	for s in steps:
		lbl.text = s[0]
		await get_tree().create_timer(s[1]).timeout
	cl.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.goto_main_menu()
