extends MonsterBase
class_name SpecterArcher
## Espectro Arquero (§7.2 + V0.3 puntos 8/16). Volador a distancia: mantiene
## 90-120px, retrocede si el jugador se acerca, dispara un proyectil espectral recto
## con leve aim-ahead. No atraviesa geometría. No stompable. Contacto = rebote. ★★☆
## V0.8.6: anti-stuck (desbloqueo perpendicular cuando se atasca contra geometría).
## V0.8.7.2: gate de LoS en shoot (no dispara a través de paredes/escenario) + más tiempo
## de desbloqueo perpendicular para alejarse antes de re-intentar.
## Autor: Claude Code · Versión: 0.8.7.2

const FLY_SPEED := 70.0
const BOLT_SPEED := 160.0
const BOLT_GRAVITY := 0.0
const SHOOT_CD := 5.0      # V0.4 punto 8 (×2)
const DETECT_RANGE := 75.0 # V0.4 punto 8 (−50%)

# V0.8.6.1 anti-stuck por PROGRESO real + LoS (desbloqueo perpendicular).
const STUCK_WINDOW := 0.5
const STUCK_MIN_PROGRESS := 8.0
const UNSTUCK_DURATION := 0.6   # V0.8.7.2: 0.3 → 0.6 (más tiempo de desbloqueo perpendicular)
const UNSTUCK_SPEED := 40.0

var _shoot_cd := 2.0
var _t := 0.0
var _unstuck_dir := Vector2.ZERO
var _unstuck_timer := 0.0

func _ready() -> void:
	body_size = Vector2(14, 18)
	body_color = Color(0.55, 0.6, 0.85)
	flying = true
	stompable = false
	solid_body = false   # V0.8.2 B-1: el Espectro es atravesable (no bloquea al jugador)
	monster_name = "Espectro"
	super._ready()

func _ignores_world() -> bool:
	return false   # V0.5 punto 7: el Espectro tampoco atraviesa geometría

## V0.5.1 BUG-4: clamp DESPUÉS de move_and_slide para no insertarse en geometría ni vibrar.
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_ai(delta)
	move_and_slide()
	_clamp_to_bounds()
	_update_wrap()
	_check_contact()

func _ai(delta: float) -> void:
	_t += delta
	is_attack_active = false   # su amenaza es el proyectil, no el contacto
	var p := get_nearest_player()
	# Movimiento de desbloqueo activo → reposicionamiento perpendicular puro.
	if _unstuck_timer > 0.0:
		velocity = _unstuck_dir * UNSTUCK_SPEED
		_unstuck_timer -= delta
		return
	# Anti-stuck (V0.8.6.1): por progreso real + LoS, solo si hay jugador. Si no avanza Y hay
	# geometría entre el Espectro y el jugador (no puede dispararle) → desbloqueo perpendicular.
	if p != null and is_stuck_no_los(delta, p, STUCK_WINDOW, STUCK_MIN_PROGRESS):
		var s := 1.0 if randf() > 0.5 else -1.0
		var tp := p.global_position - global_position
		var base := tp if tp.length() > 1.0 else Vector2.RIGHT
		_unstuck_dir = base.rotated(s * PI * 0.5).normalized()
		_unstuck_timer = UNSTUCK_DURATION
		velocity = _unstuck_dir * UNSTUCK_SPEED
		return
	if p == null:
		reset_stuck()
	var desired := Vector2(sin(_t * 1.5) * 15.0, cos(_t * 1.2) * 10.0)
	if p != null:
		var to_p := p.global_position - global_position
		var dist := to_p.length()
		# Acecho: se acerca hasta el rango de disparo (75px), dispara y retrocede.
		if dist < 40.0:
			desired = -to_p.normalized() * FLY_SPEED      # retroceder si está muy cerca
		elif dist > DETECT_RANGE - 10.0:
			desired = to_p.normalized() * 45.0            # acercarse para entrar en rango
		_shoot_cd -= delta
		# V0.8.7.2: gate de LoS en shoot — solo dispara si hay línea de visión directa al
		# jugador (sin paredes/escenario/plataformas en medio).
		if _shoot_cd <= 0.0 and dist <= DETECT_RANGE and has_clear_los(p):
			_shoot(p)
			_shoot_cd = SHOOT_CD
	velocity = velocity.lerp(desired.limit_length(FLY_SPEED), 0.08)
	# _clamp_to_bounds() se llama tras move_and_slide (ver _physics_process).

func _shoot(p: PlayerBase) -> void:
	var predicted := p.global_position + p.velocity * 0.3   # aim-ahead 0.3s
	var dir := (predicted - global_position).normalized()
	# V0.4 punto 7: el proyectil ya NO atraviesa plataformas (pierce=false).
	_spawn_monster_projectile(dir, BOLT_SPEED, BOLT_GRAVITY, "spectral", false)
	AudioManager.play_sfx("specter_shoot")

func _clamp_to_bounds() -> void:
	# V0.4: el área de juego es x∈[40,280]; mantener al Espectro dentro.
	global_position.x = clampf(global_position.x, ScreenWrapper.ARENA_LEFT + 6.0, ScreenWrapper.ARENA_RIGHT - 6.0)
	global_position.y = clampf(global_position.y, 12.0, ScreenWrapper.ARENA_BOTTOM * 0.65)
