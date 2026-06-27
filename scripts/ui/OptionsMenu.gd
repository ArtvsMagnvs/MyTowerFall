extends Control
## OptionsMenu — Audio + Controles (§6.4).
## Pestaña Audio: volumen música/SFX. Pestaña Controles: remapeo por jugador,
## resolución de conflictos y selector de dispositivo. Persiste vía InputManager.
## Autor: Claude Code · Versión: 0.4.0

var _remapper: ControlsRemapper
var _pending_player := 0
var _pending_action := ""
var _binding_buttons := {}  # "p{n}_{action}" -> Button
var _prompt: Label

func _ready() -> void:
	theme = UITheme.build()                 # V0.5.1 CAMBIO-8
	add_child(UIInputBridge.new())          # V0.5.1 CAMBIO-9
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_remapper = ControlsRemapper.new()
	add_child(_remapper)
	_remapper.captured.connect(_on_captured)
	_remapper.cancelled.connect(_on_capture_cancelled)

	var tabs := TabContainer.new()
	tabs.position = Vector2(6, 6)
	tabs.size = Vector2(308, 150)
	tabs.add_theme_font_size_override("font_size", 4)   # V0.8.2 E-2: 9 ×0.4
	add_child(tabs)
	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_controls_tab())

	_prompt = Label.new()
	_prompt.position = Vector2(6, 158)
	_prompt.size = Vector2(220, 14)
	_prompt.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 8 ×0.4
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	add_child(_prompt)

	var back := Button.new()
	back.text = "VOLVER (Esc)"
	back.position = Vector2(236, 158)
	back.size = Vector2(78, 6)   # V0.8.2 E-2: alto 14 ×0.4
	back.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 8 ×0.4
	back.pressed.connect(func(): SceneManager.goto_main_menu())
	add_child(back)

func _build_audio_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "AUDIO"
	v.add_theme_constant_override("separation", 3)   # V0.8.2 E-2: 8 ×0.4
	_add_slider(v, "Música", AudioManager.music_volume, func(val): AudioManager.set_music_volume(val))
	_add_slider(v, "Efectos (SFX)", AudioManager.sfx_volume, func(val): AudioManager.set_sfx_volume(val))
	return v

func _add_slider(parent: Node, label: String, value: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)   # V0.8.2 E-2: 8 ×0.4
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_font_size_override("font_size", 4)   # V0.8.2 E-2: 9 ×0.4
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(160, 5)   # V0.8.2 E-2: alto 12 ×0.4
	s.value_changed.connect(func(val): cb.call(val))
	h.add_child(s)
	parent.add_child(h)

func _build_controls_tab() -> Control:
	# V0.2 punto 7: las columnas van dentro de un ScrollContainer (altura visible
	# acotada) para que todos los bindings sean accesibles. El botón Atrás vive
	# fuera del TabContainer, anclado abajo, sin solaparse nunca.
	var scroll := ScrollContainer.new()
	scroll.name = "CONTROLES"
	scroll.custom_minimum_size = Vector2(296, 118)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 4)   # V0.8.2 E-2: 10 ×0.4
	root.add_child(_player_column(1))
	root.add_child(_player_column(2))
	scroll.add_child(root)
	return scroll

func _player_column(player: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var title := Label.new()
	title.text = "JUGADOR %d" % player
	title.add_theme_font_size_override("font_size", 4)   # V0.8.2 E-2: 9 ×0.4
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0) if player == 1 else Color(1.0, 0.6, 0.4))
	v.add_child(title)
	for action in InputManager.ACTIONS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)   # V0.8.2 E-2: 4 ×0.4
		var l := Label.new()
		l.text = InputManager.ACTION_LABELS[action]
		l.custom_minimum_size = Vector2(78, 0)
		l.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 7 ×0.4
		h.add_child(l)
		var b := Button.new()
		b.text = InputManager.get_binding_label(player, action)
		b.custom_minimum_size = Vector2(48, 4)   # V0.8.2 E-2: alto 11 ×0.4
		b.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 7 ×0.4
		var pl := player
		var ac: String = action
		b.pressed.connect(func(): _begin_remap(pl, ac))
		_binding_buttons["p%d_%s" % [player, action]] = b
		h.add_child(b)
		v.add_child(h)
	# Selector de dispositivo
	var dev := OptionButton.new()
	dev.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 7 ×0.4
	dev.add_item("Teclado")
	dev.add_item("Gamepad 1")
	dev.add_item("Gamepad 2")
	dev.selected = ["keyboard", "pad1", "pad2"].find(InputManager.device[player])
	dev.item_selected.connect(func(i): InputManager.set_device(player, ["keyboard", "pad1", "pad2"][i]))
	v.add_child(dev)
	# Restablecer
	var reset := Button.new()
	reset.text = "Restablecer P%d" % player
	reset.add_theme_font_size_override("font_size", 3)   # V0.8.2 E-2: 7 ×0.4
	reset.pressed.connect(func():
		InputManager.reset_player_defaults(player)
		_refresh_bindings())
	v.add_child(reset)
	return v

func _begin_remap(player: int, action: String) -> void:
	if _remapper.is_capturing():
		return
	_pending_player = player
	_pending_action = action
	_prompt.text = "P%d · %s: pulsa una tecla (Esc cancela)" % [player, InputManager.ACTION_LABELS[action]]
	_remapper.start_capture()

func _on_captured(event: InputEvent) -> void:
	if event is InputEventKey:
		var newkey: int = event.physical_keycode
		# Conflicto con otra acción del mismo jugador → intercambio.
		var conflict := InputManager.is_key_used_by(_pending_player, newkey)
		if conflict != "" and conflict != _pending_action:
			var oldkey := InputManager.get_binding(_pending_player, _pending_action)
			InputManager.set_binding(_pending_player, conflict, oldkey)
		# Aviso si la usa el otro jugador.
		var other := 2 if _pending_player == 1 else 1
		if InputManager.is_key_used_by(other, newkey) != "":
			_prompt.text = "Aviso: esa tecla también la usa el Jugador %d" % other
		else:
			_prompt.text = ""
		InputManager.set_binding(_pending_player, _pending_action, newkey)
		_refresh_bindings()
	else:
		_prompt.text = "El remapeo de gamepad usa la disposición por defecto."
	_pending_action = ""

func _on_capture_cancelled() -> void:
	_prompt.text = "Remapeo cancelado."
	_pending_action = ""

func _refresh_bindings() -> void:
	for player in [1, 2]:
		for action in InputManager.ACTIONS:
			var key := "p%d_%s" % [player, action]
			if _binding_buttons.has(key):
				_binding_buttons[key].text = InputManager.get_binding_label(player, action)

## V0.8.2 E-1: consume WASD/flechas para que no las procese la navegación por defecto.
## EXCEPCIÓN: durante el remapeo NO se consumen, para poder asignar esas teclas.
func _input(event: InputEvent) -> void:
	if _remapper != null and _remapper.is_capturing():
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode in \
			[KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _remapper.is_capturing():
		SceneManager.goto_main_menu()
