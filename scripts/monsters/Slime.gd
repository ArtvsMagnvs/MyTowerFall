extends MonsterBase
class_name Slime
## Slime (antes "Goblin Saltarín"; §7.1 + V0.3/0.4).
## Camina para desplazarse y solo salta para atacar. Puede caer de plataformas
## persiguiendo al jugador (V0.4 p.2). El salto es el ataque: letal solo al caer.
## Stomp posible siempre. ★☆☆
## V0.8.6: anti-stuck (bloqueo de patrulla cuando se atasca en CHASE).
## Autor: Claude Code · Versión: 0.8.7

enum G { PATROL, CHASE, WINDUP, AIRBORNE, LAND }

const PATROL_SPEED := 15.0   # V0.5 punto 4 (÷2)
const CHASE_SPEED := 30.0    # V0.5 punto 4 (÷2)
const DETECT := 80.0
const JUMP_VY := -50.0       # V0.8.2 A-4: impulso ÷2 (salto más alto y flotante con g=112)
const JUMP_VX := 30.0        # V0.8.2 A-3: igualado a CHASE_SPEED (sin "acelerón" al saltar)
const SLIME_GRAVITY := 112.0 # V0.8.2 A-4: gravedad propia reducida para altura ×2
const WINDUP_T := 0.2
const LAND_T := 0.4

# V0.8.6.1 anti-stuck por PROGRESO real (no por velocidad: detecta también la oscilación en
# el sitio bajo un jugador inalcanzable) + gate de LoS (solo circula si hay geometría en medio).
const STUCK_WINDOW := 0.6
const STUCK_MIN_PROGRESS := 10.0
const STUCK_PATROL_T := 1.5

var _state: G = G.PATROL
var _dir := 1
var _timer := 0.0
var _patrol_lock := 0.0

func _ready() -> void:
	body_size = Vector2(10, 12)
	body_color = Color(0.45, 0.72, 0.32)
	flying = false
	stompable = true
	monster_name = "Slime"
	add_to_group("slimes")
	super._ready()
	gravity = SLIME_GRAVITY   # V0.8.2 A-4: override tras super (MonsterBase usa self.gravity)

func _ai(delta: float) -> void:
	_patrol_lock = maxf(_patrol_lock - delta, 0.0)
	match _state:
		G.PATROL: _patrol()
		G.CHASE: _chase(delta)
		G.WINDUP: _windup(delta)
		G.AIRBORNE: _airborne()
		G.LAND: _land(delta)

func _patrol() -> void:
	is_attack_active = false
	reset_stuck()   # patrullando no se acumula atasco
	if is_on_wall():
		_dir = -_dir
	velocity.x = _dir * PATROL_SPEED
	# Durante el bloqueo anti-stuck NO se re-persigue: patrulla para alejarse y circular.
	if _patrol_lock > 0.0:
		return
	var p := get_nearest_player()
	if p != null and absf(p.global_position.x - global_position.x) < DETECT:
		_state = G.CHASE
		reset_stuck()   # ventana fresca al empezar a perseguir

func _chase(delta: float) -> void:
	is_attack_active = false
	var p := get_nearest_player()
	if p == null:
		_state = G.PATROL
		return
	# Anti-stuck (V0.8.6.1): por progreso real + LoS. Si no avanza Y hay geometría entre el
	# Slime y el jugador (no puede alcanzarlo) → patrulla forzada para circular.
	if is_stuck_no_los(delta, p, STUCK_WINDOW, STUCK_MIN_PROGRESS):
		_patrol_lock = STUCK_PATROL_T
		_dir = -_dir
		velocity.x = _dir * PATROL_SPEED
		_state = G.PATROL
		return
	var dx := p.global_position.x - global_position.x
	var dy := p.global_position.y - global_position.y
	_dir = 1 if dx >= 0.0 else -1
	# V0.4 p.2: sin miedo al borde; camina hacia el jugador aunque pueda caer.
	velocity.x = _dir * CHASE_SPEED
	var same_platform := absf(dy) < 16.0
	if is_on_floor() and ((not same_platform) or absf(dx) < 20.0):
		_state = G.WINDUP
		_timer = WINDUP_T
		velocity.x = 0.0
		reset_stuck()   # va a saltar/atacar: no es atasco
	elif absf(dx) > DETECT * 1.5:
		_state = G.PATROL

func _windup(delta: float) -> void:
	is_attack_active = false
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_jump_attack()

func _jump_attack() -> void:
	var p := get_nearest_player()
	if p != null:
		_dir = 1 if (p.global_position.x - global_position.x) >= 0.0 else -1
	velocity.y = JUMP_VY
	velocity.x = _dir * JUMP_VX
	_state = G.AIRBORNE
	AudioManager.play_sfx("jump")

func _airborne() -> void:
	# Letal solo en la fase de caída (no al subir).
	is_attack_active = velocity.y > 0.0
	if is_on_floor():
		_state = G.LAND
		_timer = LAND_T
		is_attack_active = false

func _land(delta: float) -> void:
	is_attack_active = false
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		var p := get_nearest_player()
		if p != null and absf(p.global_position.x - global_position.x) < DETECT:
			_state = G.CHASE
		else:
			_state = G.PATROL
