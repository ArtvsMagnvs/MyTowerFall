extends Node
class_name UIInputBridge
## UIInputBridge — Traduce los inputs de juego (P1/P2) a navegación de menús.
## Se añade como hijo de cada menú; vive mientras el menú existe.
## Autor: Claude Code · Versión: 0.8.4
##
## V0.8.4 (fix crítico): ANTES sintetizaba acciones ui_* con `Input.parse_input_event`,
## que RE-ENTRABA en este mismo `_input` mientras `is_action_just_pressed` seguía siendo
## true en el mismo frame → recursión infinita → cuelgue/crash del motor al pulsar
## flechas o WASD. Ahora mueve el foco DIRECTAMENTE con la API de Control (sin sintetizar
## eventos), con detección de flanco en `_process`. La activación (Enter/Espacio/A) la
## gestiona `ui_accept` por defecto de Godot; aquí solo se navega.

const PLAYERS := [1, 2]

func _process(_delta: float) -> void:
	for pid in PLAYERS:
		if _just(pid, "up") or _just(pid, "left"):
			_move_focus(-1)
			return
		if _just(pid, "down") or _just(pid, "right"):
			_move_focus(1)
			return

func _just(pid: int, dir: String) -> bool:
	var a := "p%d_%s" % [pid, dir]
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)

func _move_focus(step: int) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cur := vp.gui_get_focus_owner()
	var nxt: Control = null
	if cur == null:
		nxt = _first_focusable(get_tree().root)
	elif step > 0:
		nxt = cur.find_next_valid_focus()
	else:
		nxt = cur.find_prev_valid_focus()
	if nxt != null and is_instance_valid(nxt):
		nxt.grab_focus()

func _first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).is_visible_in_tree():
			return c
		var r := _first_focusable(c)
		if r != null:
			return r
	return null
