extends Node2D
## StoryMatch — Controlador del modo Historia (§6.3).
## Intro narrativa → combate por oleadas → victoria → siguiente nivel / ending.
## Muerte: pantalla YOU DIED y reintento del nivel desde el inicio (checkpoint).
## Autor: Claude Code · Versión: 0.4.0

enum Phase { INTRO, PLAY, DEAD, CLEARED, ENDING }

const INTROS := [
	"BOSQUE ANTIGUO\n\nEl bosque susurra secretos.\nLas criaturas guardan las ruinas.\nAbre tu camino.",
	"RUINAS VOLADORAS\n\nFragmentos de una ciudad olvidada\nflotan en el vacío.\nUn paso en falso es el último.",
	"TORRE DEL CAOS\n\nLa torre se desmorona.\nAquí termina —o empieza— todo.",
]

var _phase: Phase = Phase.INTRO
var _level: LevelBase
var _hud: HUD
var _player: PlayerBase
var _overlay: Control
var _overlay_label: Label

func _ready() -> void:
	_hud = HUD.new()
	add_child(_hud)
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.03, 0.03, 0.06, 0.92)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)
	cl.add_child(_overlay)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 11)
	_overlay_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_overlay.add_child(_overlay_label)

	var idx: int = GameManager.story_level_index
	if DebugManager.SKIP_INTROS:
		_begin_level()
	else:
		_phase = Phase.INTRO
		_overlay_label.text = INTROS[idx] + "\n\n[ Pulsa cualquier tecla ]"

func _begin_level() -> void:
	_overlay.visible = false
	var idx: int = GameManager.story_level_index
	_level = (load(GameManager.STORY_LEVELS[idx]) as PackedScene).instantiate() as LevelBase
	add_child(_level)
	move_child(_level, 0)
	AudioManager.play_music("level%d" % (idx + 1))
	_player = GameManager.class_scene(GameManager.story_class).instantiate() as PlayerBase
	_player.player_id = 1
	_level.add_child(_player)
	_player.global_position = _level.player_spawns()[0]
	_player.lives = PlayerBase.LIVES_MAX   # V0.3 punto 13: 4 vidas en Historia
	_player.on_died.connect(_on_player_died)
	_level.on_wave_started.connect(func(i, t): _hud.set_wave(i, t))
	_level.on_level_cleared.connect(_on_level_cleared)
	_update_lives_hud()
	_phase = Phase.PLAY
	# V0.8.2 E-3: cuenta atrás antes de empezar; los monstruos NO spawnan hasta el final.
	_player.frozen = true
	await _run_countdown()
	if not is_instance_valid(_player):
		return
	_player.frozen = false
	_level.start_waves()

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

func _update_lives_hud() -> void:
	_hud.set_lives(_player.lives, 0, _player.body_color, _player.body_color)

func _on_level_cleared() -> void:
	_phase = Phase.CLEARED
	_hud.show_banner("NIVEL COMPLETADO")
	await get_tree().create_timer(3.0).timeout
	GameManager.story_level_index += 1
	if GameManager.story_level_index >= GameManager.STORY_LEVELS.size():
		_show_ending()
	else:
		SceneManager.change_scene("res://scenes/ui/StoryMatch.tscn")

func _show_ending() -> void:
	_phase = Phase.ENDING
	_overlay.visible = true
	_overlay_label.text = "Has restaurado el equilibrio.\n\nFIN\n\n¡Gracias por jugar!\n\n[ Pulsa cualquier tecla ]"

func _on_player_died(_id: int) -> void:
	if _phase != Phase.PLAY:
		return
	_player.lives -= 1
	_update_lives_hud()
	if _player.lives > 0:
		_respawn_player()
	else:
		_game_over()

func _respawn_player() -> void:
	# V0.8.2 D-1: esperar a que el cadáver se detenga, luego leer su posición FINAL.
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(_player):
		return
	var corpse_pos: Vector2 = _player.last_death_pos
	if _player._last_corpse != null and is_instance_valid(_player._last_corpse):
		corpse_pos = (_player._last_corpse as Node2D).global_position
	# safe_respawn_pos() ajusta el destino para no reaparecer dentro de geometría/vacío.
	var target: Vector2 = _level.safe_respawn_pos(corpse_pos)
	var start := _hud.life_anchor(1)
	# V0.8.7.4: la gema viaja al CUERPO (no al safe pos). Al llegar se ejecuta la nueva
	# secuencia visual: elevación del cadáver, aura de la gema, y finalmente el
	# respawn (onda expansiva + blink). El respawn ocurre en `target` (safe pos)
	# para evitar spawnear dentro de geometría.
	# V0.8.7.4.2: la "mini-carga con rayos eléctricos" eliminada — tapaba la onda.
	var ball := _make_gem(start, _player.body_color)
	_level.add_child(ball)
	var corpse_node: Node2D = _player._last_corpse if is_instance_valid(_player._last_corpse) else null
	_play_respawn_sequence(ball, corpse_pos, target, corpse_node, _player)
	# Cuando termine la secuencia, _play_respawn_sequence llamará a _player.respawn(target).

## V0.8.7.4: secuencia visual de respawn.
## 1. Gema viaja al cuerpo (0.9s, misma curva que antes).
## 2. Al llegar: cuerpo se eleva + se ilumina (0.3s), gema crece con aura (1s total).
## 3. Gema desaparece y el jugador aparece con la onda expansiva + blink.
##    (V0.8.7.4 original incluía una "mini-carga con rayos eléctricos" de 0.5s
##     entre el paso 2 y el 3; eliminada en V0.8.7.4.2 porque tapaba la onda.)
## 4. Player respawn (onda expansiva existente + blink de invuln 1.5s existente).
## Los rayos son puramente decorativos (sin hitbox) — la onda expansiva sigue siendo
## el momento letal. Las animaciones de "cuerpo flotando" y "durante la onda" son
## placeholders geométricos hasta que llegue el pixel art.
func _play_respawn_sequence(ball: ColorRect, corpse_pos: Vector2, target: Vector2,
		corpse_node: Node2D, player: PlayerBase) -> void:
	# Paso 1: gema viaja al cuerpo (arc de dos tramos, 0.45s + 0.45s = 0.9s)
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
	aura.color = Color(1.0, 0.9, 0.5, 0.0)   # arranca transparente
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
	# Paso 3 (V0.8.7.4.2): sin mini-carga intermedia — la gema se desvanece y el
	# jugador aparece directamente con la onda expansiva + blink de su respawn()
	# estándar. El "remolino de rayos" de V0.8.7.4 era ruido creativo que tapaba la
	# propia onda; eliminado en StoryMatch y VersusMatch.
	tw_ball.chain().tween_callback(func() -> void:
		ball.queue_free()
		if is_instance_valid(aura): aura.queue_free()
		if is_instance_valid(player):
			player.respawn(target))

## V0.8.7.4: crea una "gema" como ColorRect cuadrado con el color del cuerpo del jugador.
## Reutilizable por StoryMatch y VersusMatch.
func _make_gem(start_pos: Vector2, color: Color) -> ColorRect:
	var g := ColorRect.new()
	g.color = color
	g.size = Vector2(6, 6)
	g.position = start_pos - Vector2(3, 3)
	g.z_index = 50
	return g

func _game_over() -> void:
	_phase = Phase.DEAD
	_overlay.visible = true
	_overlay_label.text = "HAS CAÍDO\n\n[ Pulsa cualquier tecla\npara reiniciar el nivel ]"

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	match _phase:
		Phase.INTRO:
			_begin_level()
		Phase.DEAD:
			SceneManager.change_scene("res://scenes/ui/StoryMatch.tscn")
		Phase.ENDING:
			GameManager.reset_story()
			SceneManager.goto_main_menu()
	if event.is_action_pressed("ui_cancel") and _phase == Phase.PLAY:
		SceneManager.goto_main_menu()
