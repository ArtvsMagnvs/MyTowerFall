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
	var ball := ColorRect.new()
	ball.color = _player.body_color
	ball.size = Vector2(6, 6)
	ball.position = start - Vector2(3, 3)
	_level.add_child(ball)
	var mid := (start + target) * 0.5 + Vector2(0, -28)
	var tw := ball.create_tween()
	tw.tween_property(ball, "position", mid - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ball, "position", target - Vector2(3, 3), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		ball.queue_free()
		if is_instance_valid(_player):
			_player.respawn(target))

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
