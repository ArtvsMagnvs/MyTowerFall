extends Node
## V084uiTest — Verifica el fix del freeze/crash de UI con WASD y flechas:
##  U1) MainMenu: pulsar abajo mueve el foco EXACTAMENTE un paso (sin crash, sin doble salto).
##  U2) MainMenu: WASD (tecla S) también navega un paso.
##  U3) CharacterSelect y OptionsMenu: pulsar flechas/WASD no cuelga ni crashea.
## Si el bridge volviera a usar parse_input_event, el motor se colgaría aquí (timeout).

func _ready() -> void:
	await _run()

func _key(kc: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = kc
	e.keycode = kc
	e.pressed = pressed
	Input.parse_input_event(e)

func _tap(kc: int) -> void:
	_key(kc, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(kc, false)
	await get_tree().process_frame

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()

func _run() -> void:
	# --- U1 + U2: navegación de MainMenu ---
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i in 10:
		await get_tree().process_frame
	var f0 := _focus()
	var u1_ok := false
	var u2_ok := false
	if f0 != null:
		var expected_down := f0.find_next_valid_focus()
		await _tap(KEY_DOWN)
		var f1 := _focus()
		u1_ok = (f1 != null and f1 == expected_down and f1 != f0)   # un solo paso, sin doble
		var expected_s := f1.find_next_valid_focus() if f1 != null else null
		await _tap(KEY_S)   # WASD
		var f2 := _focus()
		u2_ok = (f2 != null and f2 == expected_s and f2 != f1)
	menu.queue_free()
	await get_tree().process_frame

	# --- U3: CharacterSelect y OptionsMenu no cuelgan con flechas/WASD ---
	GameManager.mode = GameManager.Mode.STORY
	var cs := (load("res://scenes/ui/CharacterSelect.tscn") as PackedScene).instantiate()
	add_child(cs)
	for i in 8:
		await get_tree().process_frame
	for kc in [KEY_RIGHT, KEY_LEFT, KEY_D, KEY_A, KEY_DOWN, KEY_UP]:
		await _tap(kc)
	cs.queue_free()
	await get_tree().process_frame

	var om := (load("res://scenes/ui/OptionsMenu.tscn") as PackedScene).instantiate()
	add_child(om)
	for i in 8:
		await get_tree().process_frame
	for kc in [KEY_DOWN, KEY_UP, KEY_S, KEY_W, KEY_LEFT, KEY_RIGHT]:
		await _tap(kc)
	om.queue_free()
	await get_tree().process_frame
	var u3_ok := true   # llegar hasta aquí = no hubo cuelgue/crash

	print("=== V084UI TEST RESULT ===")
	print("mainmenu_arrow_single_step (U1): ", "PASS" if u1_ok else "FAIL")
	print("mainmenu_wasd_single_step (U2): ", "PASS" if u2_ok else "FAIL")
	print("submenus_no_freeze (U3): ", "PASS" if u3_ok else "FAIL")
	print("==========================")
	get_tree().quit(0 if (u1_ok and u2_ok and u3_ok) else 1)
