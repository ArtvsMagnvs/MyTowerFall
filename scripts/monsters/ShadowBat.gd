extends MonsterBase
class_name ShadowBat
## Murciélago Sombra (V0.5.1 CAMBIO-11). Vuela en línea recta horizontal rebotando en
## paredes (no en círculo). Al detectar al jugador, lo orbita, telegrafía y se lanza en
## un dash de 8 direcciones a la misma distancia que el dash del jugador (≈29px). No
## atraviesa geometría (move_and_slide). Vulnerable a flecha/espada/stomp. ★★★
## V0.8.6: anti-stuck (desbloqueo perpendicular), PREPARING_DASH 0.15s, LoS reforzado.
## V0.8.7.2: gate de LoS en TRACKING (abandona el tracking si no hay LoS y vuelve a FLYING),
## unstuck vertical cuando el jugador está sobre todo arriba/abajo (el perpendicular no sacaba
## al Bat de debajo de la plataforma), más tiempo de unstuck.
## Autor: Claude Code · Versión: 0.8.7.2

enum BState { FLYING, TRACKING, PREPARING_DASH, DASHING, RECOVERING }

const FLY_SPEED := 43.0            # V0.8.7.4: -15% (50 → 43)
const DASH_SPEED := 204.0          # V0.8.7.4: -15% (240 → 204); igual que el jugador
const DASH_DURATION := 0.12        # igual que el jugador → distancia ≈ 28.8px
const DASH_COOLDOWN_MIN := 1.5
const DASH_COOLDOWN_MAX := 3.0
const DETECTION_RANGE := 80.0
const SAFE_DISTANCE := 30.0
const PREPARE_T := 0.15   # V0.8.6 P2: 0.2 ×0.75 (preparación de dash más corta)
const RECOVER_T := 0.4

# V0.8.6.1: anti-stuck por PROGRESO real + LoS (desbloqueo perpendicular en TRACKING).
const STUCK_WINDOW := 0.6
const STUCK_MIN_PROGRESS := 12.0
const UNSTUCK_DURATION := 0.6   # V0.8.7.2: 0.4 → 0.6 (más tiempo de desbloqueo)
const UNSTUCK_SPEED := 51.0       # V0.8.7.4: -15% (60 → 51)
const DASH_DISTANCE := DASH_SPEED * DASH_DURATION   # ≈24.5px (V0.8.7.4: DASH_SPEED ×0.85)
# V0.8.7.2: gate de LoS en TRACKING — si llevamos más de este tiempo sin línea de visión
# al jugador (hay plataforma/escenario en medio), abandonamos el tracking y volvemos a FLYING.
const NO_LOS_THRESHOLD := 0.5

var _state: BState = BState.FLYING
var _home := Vector2.ZERO
var _fly_dir := 1
var _cooldown := 0.0
var _timer := 0.0
var _t := 0.0
var _dash_dir := Vector2.RIGHT
var _unstuck_dir := Vector2.ZERO
var _unstuck_timer := 0.0
var _no_los_t := 0.0   # V0.8.7.2: tiempo acumulado sin LoS al jugador en TRACKING

func _ready() -> void:
	body_size = Vector2(16, 12)
	body_color = Color(0.3, 0.18, 0.4)
	flying = true
	stompable = true
	monster_name = "Murciélago"
	super._ready()   # construye el _los_ray compartido (MonsterBase, L_WORLD)
	_home = global_position
	_fly_dir = 1 if randf() > 0.5 else -1
	_cooldown = randf_range(DASH_COOLDOWN_MIN, DASH_COOLDOWN_MAX)
	_state = BState.FLYING

func _ai(delta: float) -> void:
	_t += delta
	match _state:
		BState.FLYING: _flying(delta)
		BState.TRACKING: _tracking(delta)
		BState.PREPARING_DASH: _preparing(delta)
		BState.DASHING: _dashing(delta)
		BState.RECOVERING: _recovering(delta)

func _flying(_delta: float) -> void:
	is_attack_active = false
	# Rebotar en paredes (colisiones del frame anterior de move_and_slide): evita vibrar.
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var nx := get_slide_collision(i).get_normal().x
			if absf(nx) > 0.5:
				_fly_dir = -1 if nx < 0.0 else 1
				_home = global_position   # nueva referencia de altura tras el rebote
	velocity.x = _fly_dir * FLY_SPEED
	# Vaivén vertical suave alrededor de la altura de referencia.
	var target_y := _home.y + sin(_t * 3.0) * 14.0
	velocity.y = (target_y - global_position.y) * 3.0
	var p := get_nearest_player()
	# V0.8.7.2: solo re-entrar en TRACKING si hay línea de visión directa al jugador (sin
	# paredes/escenario/plataformas en medio). Si no, seguir volando en FLYING.
	if p != null and global_position.distance_to(p.global_position) < DETECTION_RANGE and has_clear_los(p):
		_state = BState.TRACKING
		_cooldown = randf_range(DASH_COOLDOWN_MIN, DASH_COOLDOWN_MAX)
		_unstuck_timer = 0.0
		_no_los_t = 0.0
		reset_stuck()

func _tracking(delta: float) -> void:
	is_attack_active = false
	var p := get_nearest_player()
	if p == null or global_position.distance_to(p.global_position) > DETECTION_RANGE * 1.5:
		_home = global_position
		_unstuck_timer = 0.0
		_no_los_t = 0.0
		reset_stuck()
		_state = BState.FLYING
		return
	var to_p := p.global_position - global_position
	# Movimiento de desbloqueo activo → reposicionamiento puro (sin dash ni LoS).
	if _unstuck_timer > 0.0:
		_no_los_t = 0.0   # V0.8.7.2: el timer de LoS no acumula durante el unstuck
		velocity = _unstuck_dir * UNSTUCK_SPEED
		_unstuck_timer -= delta
		return
	# V0.8.7.2: gate de LoS. Si llevamos >NO_LOS_THRESHOLD sin línea de visión al jugador
	# (hay plataforma/escenario en medio y no podemos alcanzarlo) → abandonamos TRACKING
	# y volvemos a FLYING. Evitamos el bucle de "orbitar sin avanzar + intentar cargar dash
	# contra plataforma".
	if not has_clear_los(p):
		_no_los_t += delta
		if _no_los_t > NO_LOS_THRESHOLD:
			_home = global_position
			_unstuck_timer = 0.0
			_no_los_t = 0.0
			_state = BState.FLYING
			return
	else:
		_no_los_t = 0.0
	# Anti-stuck (V0.8.6.1): por progreso real + LoS. Si no avanza Y hay geometría entre el Bat
	# y el jugador (no puede alcanzarlo) → desbloqueo perpendicular (no dash).
	if is_stuck_no_los(delta, p, STUCK_WINDOW, STUCK_MIN_PROGRESS):
		# V0.8.7.2: si el jugador está sobre todo arriba/abajo, el perpendicular no saca al
		# Bat de debajo de la plataforma (queda horizontal). Usamos dirección opuesta al
		# jugador (alejarse) en ese caso.
		var base := to_p if to_p.length() > 1.0 else Vector2.RIGHT
		if absf(to_p.y) > absf(to_p.x) * 1.5:
			_unstuck_dir = Vector2(0, -signf(to_p.y))
		else:
			var s := 1.0 if randf() > 0.5 else -1.0
			_unstuck_dir = base.rotated(s * PI * 0.5).normalized()
		_unstuck_timer = UNSTUCK_DURATION
		velocity = _unstuck_dir * UNSTUCK_SPEED
		return
	if to_p.length() > SAFE_DISTANCE:
		velocity = to_p.limit_length(FLY_SPEED)
	else:
		velocity = -to_p.limit_length(FLY_SPEED * 0.6)
	_dash_dir = _snap_8(to_p)
	_cooldown -= delta
	# V0.8.6.1 P3: NO carga el dash salvo que: 1) cooldown listo, 2) LoS limpia AL JUGADOR, y
	# 3) el CAMINO REAL del dash (dirección snappeada a 8, su distancia) esté despejado. El (3)
	# es clave: el LoS al jugador puede ir en un ángulo libre mientras la dirección snappeada
	# choca contra la plataforma — antes eso dejaba al Bat "clavado" cargando contra el muro.
	if _cooldown <= 0.0 and has_clear_los(p) and not path_blocked(_dash_dir, DASH_DISTANCE + 4.0):
		reset_stuck()
		_state = BState.PREPARING_DASH
		_timer = PREPARE_T
		velocity = Vector2.ZERO

func _preparing(delta: float) -> void:
	is_attack_active = false
	velocity = Vector2.ZERO
	_timer -= delta
	if _visual != null:
		_visual.scale = Vector2(0.8, 0.8)   # anticipación visible
	if _timer <= 0.0:
		if _visual != null:
			_visual.scale = Vector2.ONE
		_state = BState.DASHING
		_timer = DASH_DURATION
		AudioManager.play_sfx("bat_dive")

func _dashing(delta: float) -> void:
	is_attack_active = true
	velocity = _dash_dir * DASH_SPEED
	_timer -= delta
	# Se detiene al impactar geometría (no la atraviesa) o al agotar la duración.
	if get_slide_collision_count() > 0 or _timer <= 0.0:
		_state = BState.RECOVERING
		_timer = RECOVER_T

func _recovering(delta: float) -> void:
	is_attack_active = false
	velocity = Vector2.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_home = global_position
		_fly_dir = 1 if randf() > 0.5 else -1
		_cooldown = randf_range(DASH_COOLDOWN_MIN, DASH_COOLDOWN_MAX)
		_state = BState.FLYING

func _snap_8(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2.RIGHT
	var step := PI / 4.0
	var snap_ang: float = roundf(v.angle() / step) * step
	return Vector2.RIGHT.rotated(snap_ang)
