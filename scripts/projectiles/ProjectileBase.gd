extends CharacterBody2D
class_name ProjectileBase
## ProjectileBase — Proyectil universal (DOCUMENTO_MAESTRO.md §5b).
## V0.5.1 BUG-1: CharacterBody2D + move_and_collide (sin tunneling). Choca con la
## geometría del mundo y con los cuerpos de jugadores/monstruos. Parábola con gravedad,
## clavado de flechas/hachas (8s), recogida y atracción gravitacional.
## Autor: Claude Code · Versión: 0.5.1

const L_WORLD := 1
const L_HARMFUL := 8
const L_PLAYER_BODY := 16
const L_MONSTER_BODY := 128

const STUCK_LIFETIME := 8.0
# V0.5 punto 8: atracción gravitacional (aceleración).
const ATTRACTION_RADIUS_FACTOR := 1.2
const ATTRACTION_STRENGTH := 400.0
const ATTRACTION_CONE_DEG := 60.0
const ATTRACTION_MAX_FACTOR := 1.15

var proj_gravity := 400.0
var death_impulse := 0.0
var carries_pickup := false
var attraction_enabled := false
var owner_node: Node = null
var hostile_to_players := true
var hostile_to_monsters := true
var pickable := true
var proj_color := Color(0.9, 0.85, 0.5)
var kind := "arrow"

var start_stuck := false       # V0.3 punto 4: nace ya clavado (flecha caída del cadáver)
var start_angle := 0.0
var _base_speed := 300.0

var _stuck := false
var _stuck_time := 0.0
var _poly: Polygon2D
var _wrap_ghost: Node2D

func setup(pos: Vector2, dir: Vector2, speed: float) -> void:
	global_position = pos
	velocity = dir.normalized() * speed
	_base_speed = speed

## V0.3 punto 4: crea una flecha ya clavada en una superficie (no mata, recogible).
func setup_stuck(pos: Vector2, angle: float) -> void:
	global_position = pos
	start_stuck = true
	start_angle = angle
	hostile_to_players = false
	hostile_to_monsters = false
	pickable = true

func _ready() -> void:
	add_to_group("projectile")
	collision_layer = L_HARMFUL
	collision_mask = L_WORLD
	if hostile_to_players:
		collision_mask |= L_PLAYER_BODY
	if hostile_to_monsters:
		collision_mask |= L_MONSTER_BODY
	if owner_node is PhysicsBody2D:
		add_collision_exception_with(owner_node)   # nunca colisiona con quien lo disparó
	_apply_kind_defaults()
	_build_shape()
	_build_visual()
	_build_wrap_ghost()
	if start_stuck:
		rotation = start_angle
		_stick()

func _build_wrap_ghost() -> void:
	_wrap_ghost = _poly.duplicate()
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
	var off := ScreenWrapper.ghost_offset(global_position, Vector2(5, 3))
	if off != Vector2.ZERO:
		_wrap_ghost.visible = true
		_wrap_ghost.global_position = global_position + off
		_wrap_ghost.rotation = rotation
	else:
		_wrap_ghost.visible = false

func _apply_kind_defaults() -> void:
	match kind:
		"arrow", "hatchet":
			death_impulse = 110.0
			carries_pickup = true
			attraction_enabled = true
		"rock":
			death_impulse = 70.0
		"spectral":
			death_impulse = 60.0

func _build_shape() -> void:
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(6, 3)
	c.shape = s
	add_child(c)

func _build_visual() -> void:
	_poly = Polygon2D.new()
	match kind:
		"hatchet":
			_poly.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
		"spectral":
			_poly.polygon = PackedVector2Array([Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)])
		"rock":
			_poly.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
		_: # arrow
			_poly.polygon = PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(6, 0), Vector2(4, 1), Vector2(-4, 1)])
	_poly.color = proj_color
	add_child(_poly)

func _physics_process(delta: float) -> void:
	if _stuck:
		_stuck_time -= delta
		if _stuck_time <= 0.0:
			_fade_and_free()
		elif pickable:
			_check_pickup()
		return
	velocity.y += proj_gravity * delta
	if attraction_enabled:
		_apply_attraction(delta)
	if velocity.length() > 1.0:
		rotation = velocity.angle()
	# move_and_collide detecta colisiones frame a frame (sin tunneling):
	var collision := move_and_collide(velocity * delta)
	if collision:
		_on_collision(collision)
		return
	_update_wrap()
	# Limpieza fuera del área:
	if global_position.x < -20.0 or global_position.x > 340.0 \
			or global_position.y < -40.0 or global_position.y > 220.0:
		queue_free()

func _on_collision(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	if collider == null:
		return
	# Geometría del mundo:
	if collider.is_in_group("world") or collider is StaticBody2D:
		if kind == "arrow" or kind == "hatchet":
			_stick()
		else:
			_impact_vfx()
			queue_free()
		return
	# Entidad (jugador o monstruo):
	if collider == owner_node:
		return
	if collider.has_method("die"):
		collider.die(self)
		_impact_vfx()
		queue_free()

## V0.5 punto 8: atracción gravitacional hacia el objetivo cercano en el cono frontal.
func _apply_attraction(delta: float) -> void:
	if velocity.length() < 1.0:
		return
	var vel_dir := velocity.normalized()
	for grp in ["monster", "player"]:
		for n in get_tree().get_nodes_in_group(grp):
			if n == owner_node or not (n is Node2D):
				continue
			if "is_dead" in n and n.is_dead:
				continue
			var to: Vector2 = n.global_position - global_position
			var distance := to.length()
			var target_radius := 12.0
			if "body_size" in n:
				target_radius = n.body_size.x * 0.5 * ATTRACTION_RADIUS_FACTOR
			if distance > target_radius or distance < 0.01:
				continue
			if rad_to_deg(absf(vel_dir.angle_to(to / distance))) > ATTRACTION_CONE_DEG:
				continue
			var factor := 1.0 - (distance / target_radius)
			velocity += (to / distance) * ATTRACTION_STRENGTH * factor * delta
			var max_speed := _base_speed * ATTRACTION_MAX_FACTOR
			if velocity.length() > max_speed:
				velocity = velocity.normalized() * max_speed
			return

func _stick() -> void:
	_stuck = true
	_stuck_time = STUCK_LIFETIME
	velocity = Vector2.ZERO
	add_to_group("stuck_projectile")

## V0.5.1 BUG-1: la flecha clavada se recoge por proximidad (sin Area2D).
func _check_pickup() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		if not (n is PlayerBase) or not n.uses_projectiles:
			continue
		if global_position.distance_to(n.global_position) < 8.0:
			_try_pickup(n)
			return

func _try_pickup(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	if not (p is PlayerBase) or not p.uses_projectiles:
		return
	if p.add_ammo(1):
		AudioManager.play_sfx("pickup")
		queue_free()

func _impact_vfx() -> void:
	AudioManager.play_sfx("arrow_impact")

func _fade_and_free() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
