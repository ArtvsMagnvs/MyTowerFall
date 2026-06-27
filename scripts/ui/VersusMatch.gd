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
	_p1.respawn(spawns[0])
	_p2.respawn(spawns[1 % spawns.size()])
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
	var target: Vector2 = _level.safe_respawn_pos(p.last_death_pos)
	var start := _hud.life_anchor(pid)
	var ball := ColorRect.new()
	ball.color = p.body_color
	ball.size = Vector2(6, 6)
	ball.position = start - Vector2(3, 3)
	_level.add_child(ball)
	var mid := (start + target) * 0.5 + Vector2(0, -28)
	var tw := ball.create_tween()
	tw.tween_property(ball, "position", mid - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ball, "position", target - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		ball.queue_free()
		if is_instance_valid(p):
			p.respawn(target))

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
