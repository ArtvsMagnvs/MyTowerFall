extends Node
## SceneManager — Autoload
## Transiciones de escena con fade a negro. Carga/descarga centralizada.
## Autor: Claude Code · Versión: 0.4.0

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const CHARACTER_SELECT := "res://scenes/ui/CharacterSelect.tscn"

var _layer: CanvasLayer
var _fade: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, 0.25)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0, 0.25)
	_busy = false

func change_scene_packed(packed: PackedScene) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, 0.25)
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await _fade_to(0.0, 0.25)
	_busy = false

func goto_main_menu() -> void:
	change_scene(MAIN_MENU)

func goto_character_select() -> void:
	change_scene(CHARACTER_SELECT)

func _fade_to(target_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_alpha, duration)
	await tw.finished
