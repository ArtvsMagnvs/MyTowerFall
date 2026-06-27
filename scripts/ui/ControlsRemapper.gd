extends Node
class_name ControlsRemapper
## ControlsRemapper — Captura interactiva de input para el remapeo (§6.4).
## Espera el siguiente evento de teclado/gamepad y lo emite. ESC cancela.
## Autor: Claude Code · Versión: 0.4.0

signal captured(event: InputEvent)
signal cancelled

var _capturing := false

func start_capture() -> void:
	_capturing = true

func is_capturing() -> bool:
	return _capturing

func _input(event: InputEvent) -> void:
	if not _capturing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_capturing = false
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			cancelled.emit()
		else:
			captured.emit(event)
	elif event is InputEventJoypadButton and event.pressed:
		_capturing = false
		get_viewport().set_input_as_handled()
		captured.emit(event)
