extends Node
## InputManager — Autoload
## Dueño único del InputMap. Define acciones de P1 y P2 en código,
## soporta remapeo dinámico, selección de dispositivo por jugador y
## persistencia en user://input_config.cfg.
## Autor: Claude Code · Versión: 0.4.0

const CONFIG_PATH := "user://input_config.cfg"

# Acciones lógicas por jugador (sin prefijo). El nombre real es "p{n}_{action}".
const ACTIONS := ["left", "right", "up", "down", "jump", "dash", "attack1", "attack2"]

# Etiquetas humanas para la UI de opciones.
const ACTION_LABELS := {
	"left": "Mover izquierda", "right": "Mover derecha",
	"up": "Apuntar arriba", "down": "Apuntar abajo",
	"jump": "Saltar", "dash": "Dash",
	"attack1": "Ataque 1", "attack2": "Ataque 2",
}

# Dispositivos: "keyboard", "pad1", "pad2"
var device := {1: "keyboard", 2: "keyboard"}

# Defaults de teclado por jugador (physical keycodes).
const KB_DEFAULTS := {
	1: {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"jump": KEY_SPACE, "dash": KEY_SHIFT, "attack1": KEY_Q, "attack2": KEY_E},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"jump": KEY_ENTER, "dash": KEY_SLASH, "attack1": KEY_K, "attack2": KEY_L},
}

# Defaults de gamepad (compartidos; el device index se aplica al construir).
const PAD_DEFAULTS := {
	"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B,
	"attack1": JOY_BUTTON_X, "attack2": JOY_BUTTON_Y,
	"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
}

# Mapa runtime: action_name -> physical_keycode (para teclado). Persistido.
var _keymap := {}

signal on_config_changed

func _ready() -> void:
	_load_or_default()

func action_name(player: int, action: String) -> String:
	return "p%d_%s" % [player, action]

func _load_or_default() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		device[1] = cfg.get_value("devices", "p1", "keyboard")
		device[2] = cfg.get_value("devices", "p2", "keyboard")
		for p in [1, 2]:
			for action in ACTIONS:
				var key: int = cfg.get_value("p%d" % p, action, KB_DEFAULTS[p][action])
				_keymap[action_name(p, action)] = key
	else:
		_reset_keymap_to_defaults()
	rebuild_input_map()

func _reset_keymap_to_defaults() -> void:
	for p in [1, 2]:
		for action in ACTIONS:
			_keymap[action_name(p, action)] = KB_DEFAULTS[p][action]

func reset_player_defaults(player: int) -> void:
	for action in ACTIONS:
		_keymap[action_name(player, action)] = KB_DEFAULTS[player][action]
	device[player] = "keyboard"
	rebuild_input_map()
	save_config()

## Reconstruye todas las acciones en el InputMap según _keymap y device.
func rebuild_input_map() -> void:
	for p in [1, 2]:
		for action in ACTIONS:
			var name := action_name(p, action)
			if InputMap.has_action(name):
				InputMap.action_erase_events(name)
			else:
				InputMap.add_action(name)
			# Evento de teclado
			var ev := InputEventKey.new()
			ev.physical_keycode = _keymap.get(name, KB_DEFAULTS[p][action])
			InputMap.action_add_event(name, ev)
			# Evento de gamepad si procede
			if device[p] != "keyboard":
				var dev_idx := 0 if device[p] == "pad1" else 1
				_add_pad_event(name, action, dev_idx)
	on_config_changed.emit()

func _add_pad_event(name: String, action: String, dev_idx: int) -> void:
	var btn := InputEventJoypadButton.new()
	btn.device = dev_idx
	btn.button_index = PAD_DEFAULTS[action]
	InputMap.action_add_event(name, btn)
	# También mapear el stick izquierdo a las direcciones de movimiento/apuntado.
	var axis_map := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	if axis_map.has(action):
		var m: Array = axis_map[action]
		var mo := InputEventJoypadMotion.new()
		mo.device = dev_idx
		mo.axis = m[0]
		mo.axis_value = m[1]
		InputMap.action_add_event(name, mo)

## Aplica un nuevo evento a una acción (usado por el remapeador).
func remap_action(player: int, action: String, event: InputEvent) -> void:
	if event is InputEventKey:
		_keymap[action_name(player, action)] = event.physical_keycode
		rebuild_input_map()
		save_config()

func get_binding(player: int, action: String) -> int:
	return _keymap.get(action_name(player, action), KB_DEFAULTS[player][action])

func set_binding(player: int, action: String, keycode: int) -> void:
	_keymap[action_name(player, action)] = keycode
	rebuild_input_map()
	save_config()

func set_device(player: int, dev: String) -> void:
	device[player] = dev
	rebuild_input_map()
	save_config()

func save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("devices", "p1", device[1])
	cfg.set_value("devices", "p2", device[2])
	for p in [1, 2]:
		for action in ACTIONS:
			cfg.set_value("p%d" % p, action, _keymap[action_name(p, action)])
	cfg.save(CONFIG_PATH)

## Devuelve el nombre legible de la tecla asignada (para la UI).
func get_binding_label(player: int, action: String) -> String:
	var key: int = _keymap.get(action_name(player, action), KB_DEFAULTS[player][action])
	var s := OS.get_keycode_string(key)
	return s if s != "" else "?"

func is_key_used_by(player: int, keycode: int) -> String:
	for action in ACTIONS:
		if _keymap.get(action_name(player, action), -1) == keycode:
			return action
	return ""
