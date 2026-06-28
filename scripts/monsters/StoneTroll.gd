extends MonsterBase
class_name StoneTroll
## Troll de Piedra (§7.3 + V0.4 p.1/2). Persigue al jugador lentamente (puede caer
## de plataformas). Puñetazo a corto rango (hitbox visible, solo en sus frames activos)
## y pedrusco con windup si el jugador está por encima. Stompable. ★★☆
## V0.8.6: anti-stuck (bloqueo de patrulla cuando se atasca en CHASE).
## V0.8.7.2: gate de LoS en chase (no persigue si hay geometría en medio) + más tiempo de
## patrulla forzada para que el Troll se aleje antes de re-perseguir.
## Autor: Claude Code · Versión: 0.8.7.2

const PATROL_SPEED := 20.0
const CHASE_SPEED := 35.0      # V0.4 p.1b
const DETECTION_RANGE := 150.0 # V0.4 p.1b
const PUNCH_RANGE := 40.0
const PUNCH_CD := 2.0
const PUNCH_ACTIVE_T := 0.18
const PUNCH_WINDUP_T := 0.7              # V0.8.2 A-5/C-2: anticipación visible del puñetazo
const PUNCH_CANCEL_RANGE := PUNCH_RANGE * 2.5  # 100px: si el jugador se aleja, se cancela
const ROCK_CD := 5.0
const ROCK_SPEED := 160.0
const ROCK_GRAVITY := 180.0
const WINDUP_T := 0.4

# V0.8.6.1 anti-stuck por PROGRESO real + LoS (detecta la oscilación en el sitio sobre/bajo
# un jugador inalcanzable con geometría en medio). NO acumula en patrulla ni atacando.
const STUCK_WINDOW := 0.6
const STUCK_MIN_PROGRESS := 10.0
const STUCK_PATROL_T := 2.5   # V0.8.7.2: 1.5 → 2.5 (más tiempo para alejarse del radio de detección)
# V0.8.7.2: gate de LoS en chase — si llevamos más de este tiempo sin línea de visión al
# jugador (hay plataforma/escenario en medio y no podemos alcanzarlo), salimos del chase.
const NO_LOS_THRESHOLD := 0.5

var _dir := 1
var _punch_cd := 0.0
var _rock_cd := 1.5
var _state := "patrol"   # patrol | chase | windup | punch_windup | punch
var _timer := 0.0
var _patrol_lock := 0.0
var _no_los_t := 0.0   # V0.8.7.2: tiempo acumulado sin LoS al jugador en chase

func _ready() -> void:
	body_size = Vector2(20, 22)
	body_color = Color(0.5, 0.5, 0.45)
	flying = false
	stompable = true
	monster_name = "Troll"
	super._ready()

func _ai(delta: float) -> void:
	_punch_cd = maxf(_punch_cd - delta, 0.0)
	_rock_cd = maxf(_rock_cd - delta, 0.0)
	_patrol_lock = maxf(_patrol_lock - delta, 0.0)
	match _state:
		"windup":
			_windup(delta)
			return
		"punch_windup":
			_punch_windup(delta)
			return
		"punch":
			_punch_phase(delta)
			return
	is_attack_active = false
	# V0.8.6 P1B: durante el bloqueo anti-stuck, patrulla forzada (no re-persigue) para circular.
	if _patrol_lock > 0.0:
		_no_los_t = 0.0   # V0.8.7.2: reset del timer de LoS mientras dura el lock
		reset_stuck()
		if is_on_wall():
			_dir = -_dir
		velocity.x = _dir * PATROL_SPEED
		return
	var p := get_nearest_player()
	if p != null and global_position.distance_to(p.global_position) < DETECTION_RANGE:
		var dx := p.global_position.x - global_position.x
		var dy := p.global_position.y - global_position.y
		# V0.8.7.2: gate de LoS. Si llevamos >NO_LOS_THRESHOLD sin línea de visión al
		# jugador (hay plataforma/escenario en medio y no podemos alcanzarlo) → salimos
		# del chase con patrulla forzada, sin re-perseguir hasta tener LoS clara.
		if not has_clear_los(p):
			_no_los_t += delta
			if _no_los_t > NO_LOS_THRESHOLD:
				_no_los_t = 0.0
				_patrol_lock = STUCK_PATROL_T
				_dir = -_dir   # alejarse del jugador
				velocity.x = _dir * PATROL_SPEED
				return
		else:
			_no_los_t = 0.0
		# Pedrusco solo si el jugador está por encima Y hay línea de visión (no a través de geometría).
		if dy < -10.0 and absf(dx) < 100.0 and _rock_cd <= 0.0 and has_clear_los(p):
			_state = "windup"
			_timer = WINDUP_T
			velocity.x = 0.0
			reset_stuck()
			return
		# Puñetazo si está al lado y a la misma altura: primero la fase de anticipación.
		if absf(dx) < PUNCH_RANGE and absf(dy) < 24.0 and _punch_cd <= 0.0:
			_begin_punch_windup(signf(dx))
			return
		# Anti-stuck (V0.8.6.1): por progreso real + LoS. Si no avanza Y hay geometría entre el
		# Troll y el jugador (no puede alcanzarlo ni atacarlo) → patrulla forzada para circular.
		if is_stuck_no_los(delta, p, STUCK_WINDOW, STUCK_MIN_PROGRESS):
			_patrol_lock = STUCK_PATROL_T
			_dir = -_dir
			velocity.x = _dir * PATROL_SPEED
			return
		# Persecución: camina hacia el jugador (V0.4 p.2: sin miedo al borde).
		_dir = 1 if dx >= 0.0 else -1
		velocity.x = _dir * CHASE_SPEED
		return
	_no_los_t = 0.0
	reset_stuck()
	# Patrulla lenta cuando el jugador está lejos; gira en paredes sólidas.
	if is_on_wall():
		_dir = -_dir
	velocity.x = _dir * PATROL_SPEED

func _windup(delta: float) -> void:
	is_attack_active = false
	velocity.x = 0.0
	_timer -= delta
	if _visual != null:
		_visual.modulate = Color(1.6, 1.3, 0.7) if fmod(_timer, 0.2) < 0.1 else Color.WHITE
	if _timer <= 0.0:
		if _visual != null:
			_visual.modulate = Color.WHITE
		_throw_rock()
		_rock_cd = ROCK_CD
		_state = "patrol"

func _throw_rock() -> void:
	var p := get_nearest_player()
	if p == null:
		return
	var dir := (p.global_position - global_position).normalized()
	dir.y -= 0.5
	_spawn_monster_projectile(dir.normalized(), ROCK_SPEED, ROCK_GRAVITY, "rock", false)
	AudioManager.play_sfx("troll_throw")

## V0.8.2 C-2: fase de anticipación visible (0.7s) antes del puñetazo.
## El cooldown se resetea AQUÍ (al comenzar el windup), no al ejecutar el golpe.
func _begin_punch_windup(face: float) -> void:
	_state = "punch_windup"
	_timer = PUNCH_WINDUP_T
	velocity.x = 0.0
	is_attack_active = false   # el contacto no mata durante la carga
	_dir = 1 if face >= 0.0 else -1
	_punch_cd = PUNCH_CD
	reset_stuck()   # va a atacar: no es atasco

func _punch_windup(delta: float) -> void:
	is_attack_active = false
	velocity.x = 0.0
	_timer -= delta
	# Señal visual: parpadeo rojo intenso cada 0.1s (misma frecuencia que el pedrusco).
	if _visual != null:
		_visual.modulate = Color(1.8, 0.4, 0.4) if fmod(_timer, 0.2) < 0.1 else Color.WHITE
	# Cancelación: si el jugador se aleja más de 100px, abortar y volver a perseguir.
	var p := get_nearest_player()
	if p == null or global_position.distance_to(p.global_position) > PUNCH_CANCEL_RANGE:
		if _visual != null:
			_visual.modulate = Color.WHITE
		_state = "chase"
		_punch_cd = 0.0   # no penalizar un golpe cancelado: puede reintentar al alcanzarlo
		return
	# Reorientar hacia el jugador durante la carga.
	_dir = 1 if (p.global_position.x - global_position.x) >= 0.0 else -1
	if _timer <= 0.0:
		if _visual != null:
			_visual.modulate = Color.WHITE
		_begin_punch(float(_dir))

func _begin_punch(face: float) -> void:
	_state = "punch"
	_timer = PUNCH_ACTIVE_T
	velocity.x = 0.0
	is_attack_active = true
	# _punch_cd ya se reseteó en _begin_punch_windup (V0.8.2 C-2).
	var side := 1.0 if face >= 0.0 else -1.0
	var off := Vector2(side * (body_size.x * 0.5 + PUNCH_RANGE * 0.5), 0)
	var hb := MeleeHitbox.new()
	hb.hits_monsters = false
	hb.setup(self, Vector2(PUNCH_RANGE, 18), off, PUNCH_ACTIVE_T)
	add_child(hb)
	_punch_vfx(off, Vector2(PUNCH_RANGE, 18))   # V0.4 p.1a: el golpe ahora es VISIBLE
	AudioManager.play_sfx("troll_punch")

func _punch_vfx(off: Vector2, size: Vector2) -> void:
	var fx := Polygon2D.new()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	fx.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	fx.color = Color(0.85, 0.8, 0.7, 0.7)
	fx.position = off
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, PUNCH_ACTIVE_T)
	tw.tween_callback(fx.queue_free)

func _punch_phase(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		is_attack_active = false
		_state = "patrol"
