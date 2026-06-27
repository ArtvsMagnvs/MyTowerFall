extends Area2D
class_name MeleeHitbox
## MeleeHitbox — Hitbox de ataque cuerpo a cuerpo temporal.
## Mata cualquier entidad (jugador o monstruo) que toque, salvo su dueño.
## Usado por el golpe de espada y el cuerpo de carga del Guerrero.
## Autor: Claude Code · Versión: 0.4.0

const L_PLAYER_HURT := 2
const L_MONSTER_HURT := 4
const L_HARMFUL := 8

var owner_node: Node = null
var hits_players := true
var hits_monsters := true
var _life := 0.05

func setup(p_owner: Node, size: Vector2, offset: Vector2, duration: float) -> void:
	owner_node = p_owner
	position = offset
	_life = duration
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = size
	c.shape = s
	add_child(c)

func _ready() -> void:
	collision_layer = L_HARMFUL
	collision_mask = 0
	if hits_players:
		collision_mask |= L_PLAYER_HURT
	if hits_monsters:
		collision_mask |= L_MONSTER_HURT
	monitoring = true
	area_entered.connect(_on_area_entered)
	# Comprobar solapamientos ya existentes en el primer frame
	await get_tree().physics_frame
	for a in get_overlapping_areas():
		_on_area_entered(a)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not area.has_meta("entity"):
		return
	var target: Node = area.get_meta("entity")
	if target == owner_node:
		return
	if target.has_method("die"):
		target.die(owner_node)
