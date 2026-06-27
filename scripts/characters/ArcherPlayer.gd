extends PlayerBase
class_name ArcherPlayer
## ArcherPlayer — Clase Arquero (§4.1 + Actualización V0.2).
## Ataque 1: flecha simple parabólica que se dispara al SOLTAR el botón (2A),
## manteniendo el movimiento bloqueado mientras se apunta (2B).
## Ataque 2: carga → 3 flechas en cono. Parámetros en ArrowStats.tres (5).
## Autor: Claude Code · Versión: 0.5.0

const ATK1_CD := 0.35
const CHARGE_MIN := 0.5
const CONE_SPREAD := deg_to_rad(15.0)

var _arrow_stats: ProjectileStats
var _atk1_cd := 0.0
var _charging := false
var _charge_time := 0.0

func _ready() -> void:
	body_size = Vector2(10, 16)
	body_color = Color(0.27, 0.55, 0.29)      # verde bosque
	projectile_color = Color(0.87, 0.72, 0.31) # dorado
	uses_projectiles = true
	super._ready()
	_arrow_stats = _load_arrow_stats()

func _load_arrow_stats() -> ProjectileStats:
	if ResourceLoader.exists("res://resources/ProjectileStats/ArrowStats.tres"):
		return load("res://resources/ProjectileStats/ArrowStats.tres")
	return ProjectileStats.new()

func _update_combat(delta: float) -> void:
	_atk1_cd = maxf(_atk1_cd - delta, 0.0)
	# V0.2 punto 2B: mientras se mantiene Ataque 1, se apunta y el cuerpo queda estático.
	aim_lock = Input.is_action_pressed(_a("attack1"))
	# V0.2 punto 2A: el disparo se lanza al SOLTAR el botón.
	if Input.is_action_just_released(_a("attack1")) and _atk1_cd <= 0.0 and not _charging and has_ammo():
		_fire_single()
	# Ataque 2 — carga del cono (hold + release, sin cambios)
	if Input.is_action_pressed(_a("attack2")) and has_ammo():
		_charging = true
		_charge_time += delta
		horizontal_control_scale = 0.5
	elif _charging:
		if _charge_time >= CHARGE_MIN:
			_fire_cone()
		_charging = false
		_charge_time = 0.0
	is_attacking = _charging

func _fire_single() -> void:
	var dir := get_aim_direction()
	spawn_projectile(dir, _arrow_stats.initial_speed, "arrow", _arrow_stats.proj_gravity)
	consume_ammo(1)
	_atk1_cd = ATK1_CD
	AudioManager.play_sfx("arrow_shoot")

func _fire_cone() -> void:
	var dir := get_aim_direction()
	var base_ang := dir.angle()
	var shots := mini(3, ammo)
	var offsets := [0.0, -CONE_SPREAD, CONE_SPREAD]
	for i in shots:
		var a: float = base_ang + offsets[i]
		spawn_projectile(Vector2.RIGHT.rotated(a), _arrow_stats.cone_speed, "arrow", _arrow_stats.proj_gravity)
	consume_ammo(shots)
	AudioManager.play_sfx("arrow_shoot")
	_squash(Vector2(0.8, 1.2))
