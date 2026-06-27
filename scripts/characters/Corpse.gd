extends CharacterBody2D
class_name Corpse
## Corpse — Cuerpo muerto que sale despedido por el impulso del impacto
## (efecto TowerFall, V0.2 puntos 9/10). Vuela con gravedad, choca con el mundo,
## puede llevar una flecha clavada recogible y se desvanece tras unos segundos.
## Autor: Claude Code · Versión: 0.5.0

const L_WORLD := 1
const L_PLAYER_HURT := 2

var sz := Vector2(8, 8)
var col := Color.WHITE
var grav := 700.0
var lifetime := 2.5
var carries_arrow := false
var arrow_color := Color.WHITE
var arrow_angle := 0.0

var _arrow_poly: Polygon2D
var _pickup: Area2D
var _t := 0.0
var _spawn_pos := Vector2.ZERO

func setup(pos: Vector2, size: Vector2, color: Color, impulse: Vector2, carry: bool, acol: Color, aangle: float = 0.0) -> void:
	_spawn_pos = pos
	sz = size
	col = color
	velocity = impulse
	carries_arrow = carry
	arrow_color = acol
	arrow_angle = aangle

func _ready() -> void:
	global_position = _spawn_pos
	collision_layer = 0
	collision_mask = L_WORLD
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = sz
	c.shape = s
	add_child(c)
	var hx := sz.x * 0.5
	var hy := sz.y * 0.5
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	body.color = col.darkened(0.25)
	add_child(body)
	if carries_arrow:
		_arrow_poly = Polygon2D.new()
		_arrow_poly.polygon = PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(6, 0), Vector2(4, 1), Vector2(-4, 1)])
		_arrow_poly.color = arrow_color
		_arrow_poly.rotation = arrow_angle
		add_child(_arrow_poly)
		_pickup = Area2D.new()
		_pickup.collision_layer = 0
		_pickup.collision_mask = L_PLAYER_HURT
		_pickup.monitoring = true
		var pc := CollisionShape2D.new()
		var ps := RectangleShape2D.new()
		ps.size = sz + Vector2(6, 6)
		pc.shape = ps
		_pickup.add_child(pc)
		add_child(_pickup)

func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y = minf(velocity.y + grav * delta, 600.0)
	move_and_slide()
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)  # fricción al rozar
	if carries_arrow and _pickup != null:
		_check_pickup()
	var remaining := lifetime - _t
	if remaining <= 0.0:
		_drop_stuck_arrow()
		queue_free()
	elif remaining < 0.4:
		modulate.a = remaining / 0.4

## V0.3 punto 4 fase 3: al desaparecer el cadáver, la flecha queda clavada en el suelo.
func _drop_stuck_arrow() -> void:
	if not carries_arrow:
		return
	var a := ProjectileBase.new()
	a.kind = "arrow"
	a.proj_color = arrow_color
	a.setup_stuck(global_position, arrow_angle)  # fija flags antes de _ready
	get_parent().add_child(a)

func _check_pickup() -> void:
	for area in _pickup.get_overlapping_areas():
		if area.has_meta("entity"):
			var p = area.get_meta("entity")
			if p is PlayerBase and not p.is_dead and p.uses_projectiles:
				if p.add_ammo(1):
					AudioManager.play_sfx("pickup")
					carries_arrow = false
					if is_instance_valid(_arrow_poly):
						_arrow_poly.queue_free()
					_pickup.queue_free()
					_pickup = null
					return
