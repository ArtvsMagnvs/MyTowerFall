extends MonsterBase
class_name Slime
## Slime (antes "Goblin Saltarín"; §7.1 + V0.3/0.4).
## Camina para desplazarse y solo salta para atacar. Puede caer de plataformas
## persiguiendo al jugador (V0.4 p.2). El salto es el ataque: letal solo al caer.
## Stomp posible siempre. ★☆☆
## V0.8.6: anti-stuck (bloqueo de patrulla cuando se atasca en CHASE).
## V0.8.7.2: gate de LoS en CHASE (no persigue si hay geometría en medio) + más tiempo de
## patrulla forzada para que el Slime se aleje del jugador antes de re-perseguir.
## V0.8.7.3: gate de PLATAFORMA — el Slime solo persigue si el jugador está en su misma
## planta (|dy| < 14 px ≈ 1.4 tiles). Si está claramente en otra plataforma, patrulla y
## olvida de verdad (inspirado en TowerFall Wiki: los Slimes no persiguen al jugador).
## Autor: Claude Code · Versión: 0.8.7.3

enum G { PATROL, CHASE, WINDUP, AIRBORNE, LAND }

const PATROL_SPEED := 13.0   # V0.8.7.4: -15% (15 → 13) para pacing TowerFall
const CHASE_SPEED := 26.0    # V0.8.7.4: -15% (30 → 26)
const DETECT := 80.0
const JUMP_VY := -43.0       # V0.8.7.4: -15% (-50 → -43)
const JUMP_VX := 26.0        # V0.8.7.4: -15% (30 → 26) — sigue igualado a CHASE_SPEED
const SLIME_GRAVITY := 95.0  # V0.8.7.4: -15% (112 → 95) — escala con JUMP_VY para mantener el ratio
const WINDUP_T := 0.2
const LAND_T := 0.4
# V0.8.7.3: tolerancia vertical de "misma plataforma". El Slime solo persigue si el jugador
# está a menos de esta distancia en Y. 14 px ≈ 1.4 tiles (un Slime apenas salta 1 tile).
const PLATFORM_Y_TOLERANCE := 14.0

# V0.8.6.1 anti-stuck por PROGRESO real (no por velocidad: detecta también la oscilación en
# el sitio bajo un jugador inalcanzable) + gate de LoS (solo circula si hay geometría en medio).
const STUCK_WINDOW := 0.6
const STUCK_MIN_PROGRESS := 10.0
const STUCK_PATROL_T := 2.5   # V0.8.7.2: 1.5 → 2.5 (más tiempo para alejarse del radio de detección)
# V0.8.7.2: gate de LoS en CHASE — si llevamos más de este tiempo sin línea de visión al
# jugador (hay plataforma/escenario en medio y no podemos alcanzarlo), volvemos a PATROL.
const NO_LOS_THRESHOLD := 0.5

var _state: G = G.PATROL
var _dir := 1
var _timer := 0.0
var _patrol_lock := 0.0
var _no_los_t := 0.0   # V0.8.7.2: tiempo acumulado sin LoS al jugador en CHASE

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
		_no_los_t = 0.0   # V0.8.7.2: reset del timer de LoS mientras dura el lock
		return
	var p := get_nearest_player()
	# V0.8.7.3: gate de plataforma. Si el jugador está claramente en OTRA plataforma
	# (|dy| >= PLATFORM_Y_TOLERANCE ≈ 1.4 tiles arriba o abajo), NO perseguir. El Slime
	# sigue patrullando y se olvida del jugador hasta que baje a su planta. Inspirado en
	# TowerFall Wiki: los Slimes no persiguen al jugador entre plataformas.
	# V0.8.7.2: solo re-perseguir si hay LoS directa (sin paredes/escenario en medio). Si no,
	# seguir patrullando hasta tener línea de visión clara.
	if p != null and absf(p.global_position.x - global_position.x) < DETECT \
			and absf(p.global_position.y - global_position.y) < PLATFORM_Y_TOLERANCE \
			and has_clear_los(p):
		_state = G.CHASE
		_no_los_t = 0.0
		reset_stuck()   # ventana fresca al empezar a perseguir

func _chase(delta: float) -> void:
	is_attack_active = false
	var p := get_nearest_player()
	if p == null:
		_no_los_t = 0.0
		_state = G.PATROL
		return
	# V0.8.7.3: gate de plataforma dentro de CHASE. Si el jugador salta a otra plataforma
	# durante la persecución, salir inmediatamente a PATROL (sin esperar al gate de LoS).
	var dy_chase := p.global_position.y - global_position.y
	if absf(dy_chase) >= PLATFORM_Y_TOLERANCE:
		_no_los_t = 0.0
		_patrol_lock = STUCK_PATROL_T
		_dir = -_dir   # alejarse del jugador
		velocity.x = _dir * PATROL_SPEED
		_state = G.PATROL
		return
	# V0.8.7.2: gate de LoS. Si llevamos >NO_LOS_THRESHOLD sin línea de visión al jugador
	# (hay plataforma/escenario en medio y no podemos alcanzarlo) → volver a PATROL con
	# bloqueo para no re-perseguir inmediatamente.
	if not has_clear_los(p):
		_no_los_t += delta
		if _no_los_t > NO_LOS_THRESHOLD:
			_no_los_t = 0.0
			_patrol_lock = STUCK_PATROL_T
			_dir = -_dir   # alejarse del jugador
			velocity.x = _dir * PATROL_SPEED
			_state = G.PATROL
			return
	else:
		_no_los_t = 0.0
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
