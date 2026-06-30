extends CharacterBody2D
class_name PlayerBase
## PlayerBase — Movimiento core del jugador (DOCUMENTO_MAESTRO.md §3 + Actualización V0.2).
## Salto + coyote + buffer, wall jump (zig-zag 1/vuelo y enganche vertical encadenable),
## dash con invuln, apuntado 8 dir con lock de movimiento, stomp PvP, colisión entre
## jugadores, muerte con cadáver+impulso y respawn con onda expansiva.
## Autor: Claude Code · Versión: 0.5.0

signal on_died(player_id: int)

# --- Capas de colisión (bits) ---
const L_WORLD := 1
const L_PLAYER_HURT := 2
const L_MONSTER_HURT := 4
const L_HARMFUL := 8
const L_PLAYER_BODY := 16     # cuerpo físico de los jugadores (colisión entre ellos)
const L_MONSTER_BODY := 128   # V0.5.1: cuerpo de monstruos (para proyectiles/stomp)
const L_STOMP_BODY := 256     # V0.5.1: bit en el cuerpo de entidades stompables (rayo de stomp)
const L_MONSTER_SOLID := 512  # V0.8.2 B-1: cuerpo de monstruos SÓLIDOS (bloquean al jugador; el Espectro NO lo lleva)

const ENTITY_SCALE := 0.6    # V0.2 punto 8: reducción del 40%
const SPAWN_INVULN_DURATION := 1.5   # V0.3 punto 13 (antes 1.0)

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, LEDGE_HANG, DEAD }
enum WallSide { NONE, LEFT, RIGHT }   # V0.4 p.10

@export var player_id: int = 1
@export var body_size := Vector2(12, 16)
@export var body_color := Color(0.5, 0.8, 0.4)
@export var projectile_color := Color(0.9, 0.85, 0.5)
@export var uses_projectiles := true

var stats: PlayerStats
var state: State = State.IDLE
var facing: int = 1
var horizontal_control_scale: float = 1.0
var is_attacking := false
var aim_lock := false          # V0.2 punto 2B: bloquea el movimiento mientras se apunta
var is_dead := false
# V0.8.2 E-3: mientras está congelado (cuenta atrás) ignora TODO input. Por defecto false
# para no romper tests ni instanciación directa; el controlador del match lo activa al spawn.
var frozen := false

# Munición universal de proyectiles
var ammo: int = 3
const AMMO_MAX := 5
const AMMO_START := 3

# Vidas (modo Versus) — V0.2 punto 11
var lives := 4
const LIVES_MAX := 4

# Timers / flags internos
var _coyote := 0.0
var _jump_buffer := 0.0
var _dash_time := 0.0
var _dash_cooldown := 0.0
var _wall_lock := 0.0
var _invuln := 0.0
var _was_on_floor := false
var _last_wall_jumped: WallSide = WallSide.NONE  # V0.4 p.10: no repetir la misma pared
var _wall_hang_used := false   # V0.3 p.9: solo un enganche vertical por vuelo
var _hanging := false          # enganche vertical en curso
var _wall_hang := 0.0
var _hang_normal := Vector2.RIGHT
var _dash_dir := Vector2.RIGHT
# V0.8.3 Punto 1: durante el dash el jugador atraviesa entidades vivas (otros jugadores
# y monstruos sólidos). Se guarda y restaura la máscara de colisión alrededor del dash.
var _dash_mask_saved := 0
var _dash_mask_active := false
var _pre_move_vy := 0.0   # velocidad vertical previa a move_and_slide (para stomp PvP)
var motion_override := false
var last_death_pos := Vector2.ZERO   # V0.3 p.13: dónde MURIÓ el jugador
var _last_corpse: Node = null        # V0.8.2 D-1: referencia al último cadáver (su pos final)

# Ledge grab (V0.3 punto 10 + V0.5 puntos 9/10)
var _ledge_hanging := false
var _ledge_slide := 0.0
var _ledge_side := 1
var _ledge_ray_low: RayCast2D
var _ledge_ray_high: RayCast2D
var _ledge_probe: RayCast2D   # vertical: encuentra la superficie superior del borde

var _visual: Node2D
var _body_rect: Polygon2D
var _aim_arrow: Polygon2D
var _hurtbox: Area2D
var _stomp_ray: RayCast2D    # V0.5.1 BUG-3: rayo hacia abajo que detecta cuerpos stompables
var _wall_slide_ray: RayCast2D   # V0.8.2 B-4: valida que hay pared real durante el wall slide
var _ammo_counter: Node2D
var _wrap_ghost: Node2D

func _ready() -> void:
	add_to_group("player")
	add_to_group("debuggable")
	body_size *= ENTITY_SCALE
	stats = _load_stats()
	ammo = AMMO_START
	collision_layer = L_PLAYER_BODY | L_STOMP_BODY   # stompable (V0.5.1)
	# V0.8.2 B-1: el jugador colisiona con otros jugadores y con los monstruos SÓLIDOS
	# (Slime/Troll/Murciélago). El Espectro no lleva L_MONSTER_SOLID → es atravesable.
	collision_mask = L_WORLD | L_PLAYER_BODY | L_MONSTER_SOLID
	_build_collision()
	_build_visual()
	_build_hurtbox()
	_build_stomp_nodes()
	_build_wall_slide_ray()
	_build_ledge_rays()
	_build_ammo_counter()
	_build_wrap_ghost()

func _build_wrap_ghost() -> void:
	# V0.4 punto 11: copia del visual para el efecto "medio cuerpo en cada lado".
	_wrap_ghost = _visual.duplicate()
	_wrap_ghost.visible = false
	get_parent().add_child(_wrap_ghost)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_wrap_ghost):
			_wrap_ghost.queue_free())

func _update_wrap() -> void:
	if _wrap_ghost == null:
		return
	var delta := ScreenWrapper.wrap_delta(global_position)
	if delta != Vector2.ZERO:
		global_position += delta
		_last_wall_jumped = WallSide.NONE   # V0.4 p.10/11: el hueco no es pared
		if delta.y != 0.0:
			velocity.y *= 0.5               # V0.5 punto 3: damping al wrap vertical
	var off := ScreenWrapper.ghost_offset(global_position, body_size * 0.5)
	if off != Vector2.ZERO:
		_wrap_ghost.visible = true
		_wrap_ghost.global_position = global_position + off
		_wrap_ghost.scale = _visual.scale
	else:
		_wrap_ghost.visible = false

func _build_ledge_rays() -> void:
	var reach := body_size.x * 0.5 + 4.0
	_ledge_ray_low = RayCast2D.new()
	_ledge_ray_low.position = Vector2(0, -body_size.y * 0.5 + 2.0)   # cerca del borde superior
	_ledge_ray_low.target_position = Vector2(reach, 0)
	_ledge_ray_low.collision_mask = L_WORLD
	_ledge_ray_low.enabled = true
	add_child(_ledge_ray_low)
	_ledge_ray_high = RayCast2D.new()
	_ledge_ray_high.position = Vector2(0, -body_size.y * 0.5 - 3.0)  # por encima de la cabeza
	_ledge_ray_high.target_position = Vector2(reach, 0)
	_ledge_ray_high.collision_mask = L_WORLD
	_ledge_ray_high.enabled = true
	add_child(_ledge_ray_high)
	# Sonda vertical para hallar la superficie superior del borde (snap exacto, p.10).
	_ledge_probe = RayCast2D.new()
	_ledge_probe.collision_mask = L_WORLD
	_ledge_probe.enabled = true
	add_child(_ledge_probe)

func _load_stats() -> PlayerStats:
	if ResourceLoader.exists("res://resources/PlayerStats.tres"):
		return load("res://resources/PlayerStats.tres")
	return PlayerStats.new()

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	add_child(col)

func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body_rect = Polygon2D.new()
	var hx := body_size.x * 0.5
	var hy := body_size.y * 0.5
	_body_rect.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_body_rect.color = body_color
	_visual.add_child(_body_rect)
	_aim_arrow = Polygon2D.new()
	_aim_arrow.polygon = PackedVector2Array([Vector2(0, -1.5), Vector2(6, 0), Vector2(0, 1.5)])
	_aim_arrow.color = projectile_color
	_visual.add_child(_aim_arrow)

func _build_hurtbox() -> void:
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = L_PLAYER_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.monitorable = true
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = body_size
	c.shape = s
	_hurtbox.add_child(c)
	_hurtbox.set_meta("entity", self)
	add_child(_hurtbox)

func _build_stomp_nodes() -> void:
	# V0.5.1 BUG-3: rayo hacia abajo desde el pie que detecta CUERPOS stompables
	# (capa L_STOMP_BODY). Detectar cuerpos es fiable a mitad de frame (a diferencia
	# de un Area2D, cuyo overlap puede reportarse con un frame de retraso).
	_stomp_ray = RayCast2D.new()
	_stomp_ray.position = Vector2(0, body_size.y * 0.5)   # borde inferior (pie)
	# V0.8.2 B-3: longitud corta → el stomp solo se registra en contacto visual real.
	# Con B-1 (monstruos sólidos) el cuerpo que cae queda bloqueado sobre el objetivo.
	# V0.8.3 Punto 3: 3px → 6px para garantizar la detección del Troll (el más grande)
	# en todos los frames a 60fps. Sigue siendo < 10px (alto de tile) → no atraviesa plataformas.
	_stomp_ray.target_position = Vector2(0, 6)
	# V0.8.2 B-2: incluir L_WORLD → el rayo se detiene en plataformas y no atraviesa para
	# matar a un monstruo que esté debajo de la geometría.
	_stomp_ray.collision_mask = L_WORLD | L_STOMP_BODY
	_stomp_ray.collide_with_bodies = true
	_stomp_ray.collide_with_areas = false
	_stomp_ray.hit_from_inside = true   # detecta aunque el pie ya solape al objetivo
	_stomp_ray.enabled = true
	add_child(_stomp_ray)
	_stomp_ray.add_exception(self)   # no detectar el propio cuerpo

func _build_wall_slide_ray() -> void:
	# V0.8.4 fix: rayo horizontal corto a la altura de los PIES (no del centro). Así el wall
	# slide se corta justo cuando los pies dejan el final del lateral de la pared/plataforma,
	# sin "deslizar en el aire" los ~5px del cuerpo que quedaban por debajo con el rayo central.
	_wall_slide_ray = RayCast2D.new()
	_wall_slide_ray.position = Vector2(0, body_size.y * 0.5 - 1.0)   # pies
	_wall_slide_ray.target_position = Vector2(8, 0)
	_wall_slide_ray.collision_mask = L_WORLD
	_wall_slide_ray.enabled = true
	add_child(_wall_slide_ray)

func _build_ammo_counter() -> void:
	if not uses_projectiles:
		return
	_ammo_counter = preload("res://scripts/characters/AmmoCounter.gd").new()
	_ammo_counter.position = Vector2(0, -body_size.y * 0.5 - 7)
	_ammo_counter.player = self
	add_child(_ammo_counter)

# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if frozen:
		_process_frozen(delta)
		return
	_tick_timers(delta)
	# V0.8.3 Punto 1: restaurar la colisión con entidades en cuanto el dash acaba.
	if _dash_mask_active and _dash_time <= 0.0:
		_exit_dash_phase()
	horizontal_control_scale = 1.0
	motion_override = false
	aim_lock = false
	if _hanging:
		_process_wall_hang(delta)
	elif _ledge_hanging:
		_process_ledge_hang(delta)
	else:
		_update_combat(delta)
		if motion_override:
			pass
		elif _dash_time > 0.0:
			_process_dash(delta)
		else:
			_process_normal(delta)
			_check_ledge_grab()
	_pre_move_vy = velocity.y   # se guarda antes de que la colisión la anule (stomp PvP)
	move_and_slide()
	_update_floor_state()
	_check_stomp()
	_update_wrap()
	_update_visual()

## V0.8.2 E-3: durante la cuenta atrás el jugador no responde a inputs; solo cae al suelo.
func _process_frozen(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	else:
		velocity.y = 0.0
	state = State.IDLE
	move_and_slide()
	_update_wrap()
	_update_visual()

## Hook de combate sobreescrito por las clases (ataques, cargas, aim_lock).
func _update_combat(_delta: float) -> void:
	pass

func _tick_timers(delta: float) -> void:
	_dash_time = maxf(_dash_time - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_wall_lock = maxf(_wall_lock - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if is_on_floor():
		_coyote = stats.coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)

func _process_normal(delta: float) -> void:
	var dir := Input.get_action_strength(_a("right")) - Input.get_action_strength(_a("left"))
	# V0.8.3 fix: el wall slide lo gobierna SOLO el rayo lateral, evaluado fresco cada frame
	# hacia el lado que se pulsa. NO se usa is_on_wall_only(), que Godot reporta con retraso y
	# dejaba el slide "pegado" en el aire tras acabar la pared. Sin pared confirmada a ≤8px en
	# el lado pulsado → no hay slide → cae con gravedad normal en ese mismo frame.
	var wall_sliding := not is_on_floor() and velocity.y > 0.0 and _wall_lock <= 0.0 \
			and _wall_on_press_side(dir)
	if not is_on_floor():
		var g := stats.gravity
		if wall_sliding:
			velocity.y = minf(velocity.y + g * delta, stats.wall_slide_speed)
		else:
			velocity.y = minf(velocity.y + g * delta, stats.max_fall_speed)
	# Control horizontal (instantáneo). Si se está apuntando (Arquero), queda estático.
	if _wall_lock <= 0.0:
		if aim_lock:
			if is_on_floor():
				velocity.x = 0.0
			# en el aire: sin control horizontal, conserva la inercia
		else:
			velocity.x = dir * stats.walk_speed * horizontal_control_scale
	if dir != 0 and not is_attacking and not aim_lock:
		facing = 1 if dir > 0 else -1
	var aim := get_aim_direction()
	if absf(aim.x) > 0.01:
		facing = 1 if aim.x > 0 else -1
	if Input.is_action_just_pressed(_a("jump")):
		_jump_buffer = stats.jump_buffer_time
	if _jump_buffer > 0.0:
		_try_jump()
	if Input.is_action_just_released(_a("jump")) and velocity.y < 0.0:
		velocity.y *= 0.45
	if Input.is_action_just_pressed(_a("dash")):
		_try_dash()
	_update_state(dir, wall_sliding)

## V0.8.3 fix: ¿hay pared sólida a ≤8px en el lado que el jugador está PULSANDO?
## Se lanza un rayo fresco (force_raycast_update) cada frame hacia ese lado. Si el jugador no
## pulsa hacia ningún lado, no hay wall slide (como en TowerFall: hay que empujar la pared).
## Al acabar la pared (vertical u horizontalmente) el rayo deja de chocar al instante.
func _wall_on_press_side(press: float) -> bool:
	if _wall_slide_ray == null or absf(press) < 0.3:
		return false
	_wall_slide_ray.target_position = Vector2(signf(press) * 8.0, 0)
	_wall_slide_ray.force_raycast_update()
	return _wall_slide_ray.is_colliding()

func _try_jump() -> void:
	if is_on_floor() or _coyote > 0.0:
		velocity.y = stats.jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash(Vector2(0.7, 1.3))
		AudioManager.play_sfx("jump")
	elif is_on_wall_only() and _wall_lock <= 0.0:
		_wall_jump()

## V0.2 puntos 13/14: dos tipos diferenciados según la dirección de apuntado.
func _wall_jump() -> void:
	var wall_normal := get_wall_normal()
	var aim := get_aim_direction()
	var vertical := aim.y < -0.3 and absf(aim.y) >= absf(aim.x)
	if vertical:
		# Enganche vertical: 1 por vuelo, lógica independiente (V0.3 p.9 / V0.4 p.10).
		if _wall_hang_used:
			return
		_start_wall_hang(wall_normal)
		return
	# Zig-zag (V0.4 p.10): permitido salvo repetir la MISMA pared sin alternar.
	var side := _wall_side_from_normal(wall_normal)
	if side == _last_wall_jumped:
		return
	_last_wall_jumped = side
	velocity.x = stats.wall_jump_push * wall_normal.x
	velocity.y = stats.jump_velocity
	_wall_lock = stats.wall_jump_lock
	_jump_buffer = 0.0
	_squash(Vector2(0.75, 1.25))
	AudioManager.play_sfx("jump")

## get_wall_normal() apunta hacia fuera de la pared: x>0 = pared a la izquierda.
func _wall_side_from_normal(normal: Vector2) -> WallSide:
	if normal.x > 0.0:
		return WallSide.LEFT
	elif normal.x < 0.0:
		return WallSide.RIGHT
	return WallSide.NONE

func _start_wall_hang(normal: Vector2) -> void:
	_hanging = true
	_wall_hang_used = true
	_wall_hang = 0.1
	_hang_normal = normal
	velocity = Vector2.ZERO
	_jump_buffer = 0.0
	state = State.WALL_SLIDE

func _process_wall_hang(delta: float) -> void:
	motion_override = true
	_wall_hang -= delta
	if _wall_hang > 0.0:
		velocity = Vector2.ZERO
		state = State.WALL_SLIDE
	else:
		# Enganche vertical: salto recto a la altura de un salto normal (V0.3 punto 9).
		velocity.y = stats.jump_velocity
		velocity.x = 0.0
		_hanging = false
		_squash(Vector2(0.7, 1.3))
		AudioManager.play_sfx("jump")

## V0.5 puntos 9/10: detecta el borde, exige mantener dirección y snapea a la esquina.
func _check_ledge_grab() -> void:
	if is_on_floor() or _dash_time > 0.0 or velocity.y <= 0.0:
		return
	var dir := Input.get_action_strength(_a("right")) - Input.get_action_strength(_a("left"))
	if absf(dir) < 0.5:
		return   # debe mantener la dirección hacia la pared para agarrarse
	var s := signf(dir)
	var reach := body_size.x * 0.5 + 4.0
	_ledge_ray_low.target_position = Vector2(reach * s, 0)
	_ledge_ray_high.target_position = Vector2(reach * s, 0)
	_ledge_ray_low.force_raycast_update()
	_ledge_ray_high.force_raycast_update()
	# Hay borde si el rayo superior del cuerpo choca pero el de encima de la cabeza no.
	if not (_ledge_ray_low.is_colliding() and not _ledge_ray_high.is_colliding()):
		return
	# Sonda vertical en la columna de la pared para hallar la superficie del borde.
	_ledge_probe.position = Vector2(reach * s, -body_size.y * 0.5 - 4.0)
	_ledge_probe.target_position = Vector2(0, 16)
	_ledge_probe.force_raycast_update()
	var top_y := global_position.y - body_size.y * 0.5
	if _ledge_probe.is_colliding():
		top_y = _ledge_probe.get_collision_point().y
	_enter_ledge_hang(int(s), top_y)

func _enter_ledge_hang(s: int, top_y: float) -> void:
	_ledge_hanging = true
	_ledge_side = s
	facing = s
	velocity = Vector2.ZERO
	_ledge_slide = 0.0
	# V0.5 punto 10: snap exacto — la parte superior del cuerpo queda al nivel del borde.
	global_position.y = top_y + body_size.y * 0.5
	state = State.LEDGE_HANG

func _process_ledge_hang(delta: float) -> void:
	motion_override = true
	state = State.LEDGE_HANG
	if Input.is_action_just_pressed(_a("jump")):
		velocity.y = stats.jump_velocity
		velocity.x = 0.0
		_ledge_hanging = false
		AudioManager.play_sfx("jump")
		return
	var dir := Input.get_action_strength(_a("right")) - Input.get_action_strength(_a("left"))
	var holding_wall := absf(dir) > 0.5 and signf(dir) == float(_ledge_side)
	if holding_wall:
		# V0.5 punto 9: mantener la dirección → colgado y estático.
		velocity = Vector2.ZERO
		_ledge_slide = 0.0
	else:
		# Soltar la dirección → deslizar hacia abajo; tras LEDGE_MAX_SLIDE, caer.
		velocity = Vector2(0, stats.ledge_slide_speed)
		_ledge_slide += stats.ledge_slide_speed * delta
		# V0.8.4 fix: si el lateral ya no está al lado (p.ej. plataforma fina), caer YA
		# en vez de seguir deslizando en el aire los 20px completos.
		var reach := body_size.x * 0.5 + 4.0
		_ledge_ray_low.target_position = Vector2(reach * _ledge_side, 0)
		_ledge_ray_low.force_raycast_update()
		if _ledge_slide >= stats.ledge_max_slide or not _ledge_ray_low.is_colliding():
			_ledge_hanging = false

func _try_dash() -> void:
	if _dash_time > 0.0:
		return
	if _dash_cooldown > 0.0 and not DebugManager.INFINITE_DASH:
		return
	# V0.5 punto 2: dash SOLO en los 4 ejes cardinales (nunca diagonal). El eje
	# dominante gana; en empate prioriza horizontal. Abajo no produce dash.
	var d := get_aim_direction()
	var dir: Vector2
	if absf(d.x) >= absf(d.y):
		dir = Vector2(signf(d.x), 0) if d.x != 0.0 else Vector2(float(facing), 0)
	else:
		if d.y < 0.0:
			dir = Vector2(0, -1)            # dash recto hacia arriba
		else:
			return                          # dash hacia abajo: prohibido
	_dash_dir = dir
	_dash_time = stats.dash_duration
	_dash_cooldown = stats.dash_cooldown
	_invuln = float(stats.dash_invuln_frames) / 60.0
	state = State.DASH
	_enter_dash_phase()   # V0.8.3 Punto 1: atravesar entidades durante el dash
	AudioManager.play_sfx("dash")
	_spawn_dash_ghost()

## V0.8.3 Punto 1: al entrar en DASH, retirar los bits de colisión con cuerpos de
## entidades (jugadores y monstruos sólidos) para atravesarlos. Conserva L_WORLD.
func _enter_dash_phase() -> void:
	if _dash_mask_active:
		return
	_dash_mask_saved = collision_mask
	collision_mask &= ~(L_PLAYER_BODY | L_MONSTER_SOLID)
	_dash_mask_active = true

## Al terminar el dash, restaurar la máscara previa (vuelve a chocar con entidades).
func _exit_dash_phase() -> void:
	if not _dash_mask_active:
		return
	collision_mask = _dash_mask_saved
	_dash_mask_active = false

func _process_dash(_delta: float) -> void:
	velocity = _dash_dir * stats.dash_speed
	if _dash_time <= 0.0:
		velocity *= 0.4

func _update_floor_state() -> void:
	if is_on_floor():
		if not _was_on_floor:
			_squash(Vector2(1.3, 0.7))
			AudioManager.play_sfx("land")
		_last_wall_jumped = WallSide.NONE   # V0.4 p.10: reset al tocar suelo
		_wall_hang_used = false
	_was_on_floor = is_on_floor()

func _update_state(dir: float, wall_sliding: bool = false) -> void:
	if _dash_time > 0.0:
		state = State.DASH
	elif wall_sliding:   # V0.8.2 B-4: solo WALL_SLIDE si el rayo confirma pared real
		state = State.WALL_SLIDE
	elif not is_on_floor():
		state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif absf(dir) > 0.01:
		state = State.RUN
	else:
		state = State.IDLE

# --------------------------------------------------------------------------
func get_aim_direction() -> Vector2:
	var ax := Input.get_action_strength(_a("right")) - Input.get_action_strength(_a("left"))
	var ay := Input.get_action_strength(_a("down")) - Input.get_action_strength(_a("up"))
	var v := Vector2(signf(ax) if absf(ax) > 0.3 else 0.0, signf(ay) if absf(ay) > 0.3 else 0.0)
	if v == Vector2.ZERO:
		return Vector2(facing, 0)
	return v.normalized()

func _update_visual() -> void:
	if _body_rect:
		_body_rect.scale.x = absf(_body_rect.scale.x) * facing
	if _aim_arrow:
		_aim_arrow.rotation = get_aim_direction().angle()
	if _visual:
		_visual.scale = _visual.scale.lerp(Vector2.ONE, 0.25)
		# Parpadeo durante la invulnerabilidad (respawn / dash) — V0.2 punto 11
		if _invuln > 0.0:
			_visual.visible = int(_invuln * 15.0) % 2 == 0
		else:
			_visual.visible = true

func _squash(s: Vector2) -> void:
	if _visual:
		_visual.scale = s

func _spawn_dash_ghost() -> void:
	for i in 3:
		var ghost := _body_rect.duplicate() as Polygon2D
		ghost.color = Color(body_color.r, body_color.g, body_color.b, 0.35 - i * 0.1)
		ghost.global_position = global_position
		ghost.scale = Vector2(facing, 1)
		get_parent().add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tw.tween_callback(ghost.queue_free)

# --------------------------------------------------------------------------
# Stomp universal (V0.5 p.5 · reescrito V0.8.3 fix)
## PRIMARIO: usa las colisiones REALES de move_and_slide. Cuando el jugador aterriza sobre
## un cuerpo stompable (Slime/Troll/Murciélago sólidos, u otro jugador), move_and_slide
## reporta la colisión con la normal hacia ARRIBA — aunque el monstruo se mueva o el jugador
## caiga descentrado y resbale de lado. Esto es mucho más fiable que un rayo central, que
## fallaba porque el cuerpo sólido (B-1) desvía al jugador antes de evaluar el rayo.
## Respeta B-2 de forma natural: si hay una plataforma entre medias, el jugador colisiona con
## ella (no con el monstruo de debajo), así que no hay stomp a través de geometría.
func _check_stomp() -> void:
	if is_dead or _dash_time > 0.0:
		return                       # el dash esquiva dar stomp
	if _pre_move_vy < -30.0:
		return                       # ascendía con fuerza: imposible stomp
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var c = col.get_collider()
		# normal.y < -0.5 → el jugador cayó SOBRE la entidad (esta lo empuja hacia arriba).
		if _is_stompable_target(c) and col.get_normal().y < -0.5:
			_do_stomp(c)
			return
	# SECUNDARIO (red de seguridad): rayo corto desde el pie. Cubre casos sin colisión de
	# deslizamiento (p.ej. el objetivo asciende hacia un jugador quieto). Incluye L_WORLD,
	# así que se detiene en plataformas y no atraviesa geometría (B-2).
	if _stomp_ray == null:
		return
	_stomp_ray.force_raycast_update()
	if not _stomp_ray.is_colliding():
		return
	var target = _stomp_ray.get_collider()
	if _is_stompable_target(target):
		_do_stomp(target)

func _is_stompable_target(c) -> bool:
	if c == null or c == self or not is_instance_valid(c):
		return false
	if not c.has_method("receive_stomp"):
		return false   # geometría u otra cosa: no es stompeable
	if "is_dead" in c and c.is_dead:
		return false
	return true

func _do_stomp(target) -> void:
	target.receive_stomp(self)
	AudioManager.play_sfx("stomp")
	_apply_stomp_bounce()

func _apply_stomp_bounce() -> void:
	# Mantener salto amplifica el rebote para encadenar stompeos (V0.5 p.5).
	var held := Input.is_action_pressed(_a("jump"))
	velocity.y = stats.stomp_bounce_held if held else stats.stomp_bounce

## Recibe un stomp desde arriba. El dash y la invulnerabilidad protegen.
func receive_stomp(attacker: Node) -> void:
	die(attacker)   # die() ya ignora si está en dash/invulnerable/godmode

# --------------------------------------------------------------------------
# Munición
func has_ammo() -> bool:
	return ammo > 0

func consume_ammo(n: int = 1) -> void:
	ammo = maxi(ammo - n, 0)

func add_ammo(n: int = 1) -> bool:
	if ammo >= AMMO_MAX:
		return false
	ammo = mini(ammo + n, AMMO_MAX)
	if _ammo_counter:
		_ammo_counter.pop()
	return true

## Instancia un proyectil universal. grav < 0 = usar el valor por defecto del proyectil.
func spawn_projectile(dir: Vector2, speed: float, kind: String, grav: float = -1.0) -> ProjectileBase:
	var p := ProjectileBase.new()
	p.kind = kind
	p.proj_color = projectile_color
	p.owner_node = self
	p.hostile_to_players = true
	p.hostile_to_monsters = true
	p.pickable = true
	if grav >= 0.0:
		p.proj_gravity = grav
	get_parent().add_child(p)
	var muzzle := global_position + dir.normalized() * (body_size.x * 0.5 + 4)
	p.setup(muzzle, dir, speed)
	return p

# --------------------------------------------------------------------------
# Muerte (un golpe = un kill) — V0.2 puntos 9/10: cadáver con impulso
func is_invulnerable() -> bool:
	return _invuln > 0.0 or _dash_time > 0.0

func die(source: Node = null) -> void:
	if is_dead or is_invulnerable() or DebugManager.GODMODE:
		return
	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	last_death_pos = global_position   # V0.3 p.13: el cristal viajará aquí
	AudioManager.play_sfx("death")
	_spawn_corpse(source)
	_spawn_death_particles()
	on_died.emit(player_id)
	_visual.visible = false
	set_physics_process(false)

func _spawn_corpse(source: Node) -> void:
	var impulse := Vector2.ZERO
	var carry := false
	var acol := projectile_color
	var aangle := 0.0
	if source is ProjectileBase:
		impulse = source.velocity.normalized() * source.death_impulse
		carry = source.carries_pickup
		acol = source.proj_color
		aangle = source.velocity.angle()
	var c := Corpse.new()
	c.setup(global_position, body_size, body_color, impulse, carry, acol, aangle)
	# Diferido: die() puede invocarse durante un callback de colisión (flush de físicas),
	# y activar el área del cadáver en ese momento da el error "flushing queries".
	get_parent().add_child.call_deferred(c)
	_last_corpse = c   # V0.8.2 D-1: el cristal viajará a la posición FINAL del cadáver

func _spawn_death_particles() -> void:
	for i in 12:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
		p.color = body_color if i % 2 == 0 else projectile_color
		p.global_position = global_position
		get_parent().add_child(p)
		var ang := TAU * i / 12.0
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", global_position + Vector2.RIGHT.rotated(ang) * 14.0, 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(p.queue_free)

## Reaparición con invulnerabilidad/parpadeo y onda expansiva (V0.2 punto 11).
func respawn(at: Vector2) -> void:
	global_position = at
	is_dead = false
	is_attacking = false
	velocity = Vector2.ZERO
	ammo = AMMO_START
	state = State.IDLE
	_last_wall_jumped = WallSide.NONE
	_wall_hang_used = false
	_hanging = false
	_wall_hang = 0.0
	_ledge_hanging = false
	_visual.visible = true
	_invuln = SPAWN_INVULN_DURATION
	set_physics_process(true)
	_spawn_shockwave()

func _spawn_shockwave() -> void:
	# Onda expansiva 3×3 casillas que mata a quien esté cerca al aparecer.
	var hb := MeleeHitbox.new()
	hb.hits_players = true
	hb.hits_monsters = true
	hb.setup(self, Vector2(24, 24), Vector2.ZERO, 0.12)
	add_child(hb)
	AudioManager.play_sfx("spawn")
	var ring := Polygon2D.new()
	var r := 4.0
	ring.polygon = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	ring.color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.7)
	ring.global_position = global_position
	get_parent().add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(4, 4), 0.25)
	tw.tween_property(ring, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(ring.queue_free)

func _a(action: String) -> String:
	return "p%d_%s" % [player_id, action]

func get_debug_info() -> String:
	var names := ["IDLE", "RUN", "JUMP", "FALL", "WALL", "DASH", "LEDGE", "DEAD"]
	return "P%d %s vel(%d,%d) ammo:%d lives:%d lastwall:%d hang:%s" % [
		player_id, names[state], int(velocity.x), int(velocity.y), ammo, lives, _last_wall_jumped, _hanging]
