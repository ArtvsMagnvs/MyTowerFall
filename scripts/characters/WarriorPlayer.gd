extends PlayerBase
class_name WarriorPlayer
## WarriorPlayer — Clase Guerrero (DOCUMENTO_MAESTRO.md §4.2).
## Ataque 1: golpe de espada (2 casillas, ≈28px). Ataque 2: carga con golpe.
## Nota MVP: el guerrero es melee; no consume munición (uses_projectiles=false).
## Autor: Claude Code · Versión: 0.4.0

const SWORD_RANGE := 28.0
const SWORD_THICK := 12.0
const SWORD_CD := 0.25
const CHARGE_MIN := 0.4
const CHARGE_SPEED := 500.0
const CHARGE_MAX_DIST := 120.0
const STUN_TIME := 0.2

var _atk1_cd := 0.0
var _charging := false
var _charge_time := 0.0
var _dashing_charge := false
var _charge_dir := Vector2.RIGHT
var _charge_dist := 0.0
var _stun := 0.0
var _charge_hitbox: MeleeHitbox

func _ready() -> void:
	body_size = Vector2(14, 16)
	body_color = Color(0.72, 0.21, 0.18)       # rojo carmesí
	projectile_color = Color(0.78, 0.79, 0.84)  # plata
	uses_projectiles = false
	super._ready()

func _update_combat(delta: float) -> void:
	_atk1_cd = maxf(_atk1_cd - delta, 0.0)
	if _stun > 0.0:
		_stun -= delta
		motion_override = true
		velocity.x = 0.0
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
		is_attacking = true
		return
	if _dashing_charge:
		_process_charge(delta)
		return
	# Ataque 1 — golpe de espada
	if Input.is_action_just_pressed(_a("attack1")) and _atk1_cd <= 0.0 and not _charging:
		_swing()
	# Ataque 2 — carga
	if Input.is_action_pressed(_a("attack2")):
		_charging = true
		_charge_time += delta
		horizontal_control_scale = 0.5
	elif _charging:
		if _charge_time >= CHARGE_MIN:
			_start_charge()
		_charging = false
		_charge_time = 0.0
	is_attacking = _charging

func _swing() -> void:
	var aim := get_aim_direction()
	var size: Vector2
	var offset: Vector2
	if absf(aim.x) >= absf(aim.y):
		size = Vector2(SWORD_RANGE, SWORD_THICK)
		offset = Vector2(signf(aim.x) * (body_size.x * 0.5 + SWORD_RANGE * 0.5), 0)
	else:
		size = Vector2(SWORD_THICK, SWORD_RANGE)
		offset = Vector2(0, signf(aim.y) * (body_size.y * 0.5 + SWORD_RANGE * 0.5))
	var hb := MeleeHitbox.new()
	hb.setup(self, size, offset, 0.06)
	add_child(hb)
	_atk1_cd = SWORD_CD
	AudioManager.play_sfx("sword")
	_slash_vfx(offset, size)

func _slash_vfx(offset: Vector2, size: Vector2) -> void:
	var fx := Polygon2D.new()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	fx.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	fx.color = Color(1, 1, 0.85, 0.7)
	fx.position = offset
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.12)
	tw.tween_callback(fx.queue_free)

func _start_charge() -> void:
	_dashing_charge = true
	_charge_dir = get_aim_direction()
	if _charge_dir == Vector2.ZERO:
		_charge_dir = Vector2(facing, 0)
	_charge_dir = _charge_dir.normalized()
	_charge_dist = 0.0
	is_attacking = true
	_charge_hitbox = MeleeHitbox.new()
	_charge_hitbox.setup(self, body_size + Vector2(4, 4), Vector2.ZERO, 999.0)
	add_child(_charge_hitbox)
	AudioManager.play_sfx("charge_release")

func _process_charge(delta: float) -> void:
	motion_override = true
	velocity = _charge_dir * CHARGE_SPEED
	_charge_dist += CHARGE_SPEED * delta
	if _charge_dist >= CHARGE_MAX_DIST or is_on_wall():
		_end_charge()

func _end_charge() -> void:
	_dashing_charge = false
	_stun = STUN_TIME
	velocity = Vector2.ZERO
	if is_instance_valid(_charge_hitbox):
		_charge_hitbox.queue_free()
