extends CharacterBody2D
class_name MonsterBase
## MonsterBase — Base de monstruos (DOCUMENTO_MAESTRO.md §7).
## Muere de un golpe (flecha, espada, stomp). Gestiona hurtbox, stomp,
## contacto letal, gravedad opcional y detección del jugador.
## Las subclases implementan la IA en _ai(delta).
## V0.8.7: LoS compartido (has_clear_los/path_blocked) y anti-stuck por progreso (is_stuck_no_los).
## Autor: Claude Code · Versión: 0.8.7

signal on_died(monster: MonsterBase)

const L_WORLD := 1
const L_PLAYER_HURT := 2
const L_MONSTER_HURT := 4
const L_HARMFUL := 8
const L_MONSTER_BODY := 128   # V0.5.1: cuerpo de monstruos (proyectiles lo golpean)
const L_STOMP_BODY := 256     # V0.5.1: bit de cuerpo stompable (rayo de stomp del jugador)
const L_MONSTER_SOLID := 512  # V0.8.2 B-1: cuerpo físico que bloquea al jugador (Espectro=off)

const ENTITY_SCALE := 0.6   # V0.2 punto 8: reducción del 40%

@export var body_size := Vector2(10, 12)
@export var body_color := Color(0.4, 0.7, 0.3)
@export var flying := false
@export var stompable := true
@export var solid_body := true   # V0.8.2 B-1: bloquea físicamente al jugador (Espectro=false)
@export var contact_deadly := false   # (obsoleto en V0.3; ver is_attack_active)
@export var gravity := 900.0
@export var monster_name := ""        # V0.3 punto 14

var is_dead := false
var is_attack_active := false # V0.3 punto 8: solo el ataque activo mata por contacto
var _visual: Node2D
var _body_poly: Polygon2D
var _contact_area: Area2D
var _wrap_ghost: Node2D
# V0.8.7.1: anti-stuck por LÍNEA DE ATAQUE (casi instantáneo) + escape de patrulla por distancia.
var _los_ray: RayCast2D
var _no_los_timer := 0.0    # tiempo seguido sin línea de visión de ataque
var _patrol_dist := 0.0     # distancia recorrida durante el escape de patrulla
var _patrol_prev := Vector2.ZERO
# Anti-stuck por PROGRESO: anclas y ventana (V0.8.7). El _ready() las inicializa con
# la posición actual; is_stuck_no_los() y reset_stuck() las usan/ponen a cero.
var _stuck_anchor := Vector2.ZERO
var _stuck_check := 0.0

func _ready() -> void:
	add_to_group("monster")
	add_to_group("debuggable")
	body_size *= ENTITY_SCALE
	# V0.5.1: el cuerpo va en L_MONSTER_BODY (lo golpean los proyectiles) y, si es
	# stompable, también en L_STOMP_BODY (lo detecta el rayo de stomp del jugador).
	# V0.8.2 B-1: si es sólido, además L_MONSTER_SOLID para bloquear al jugador.
	collision_layer = L_MONSTER_BODY \
			| (L_STOMP_BODY if stompable else 0) \
			| (L_MONSTER_SOLID if solid_body else 0)
	collision_mask = L_WORLD if not _ignores_world() else 0
	_build_collision()
	_build_visual()
	_build_hurtbox()
	_build_contact_area()        # V0.3 punto 8: siempre (gestiona ataque y rebote lateral)
	_build_name_label()          # V0.3 punto 14
	_build_wrap_ghost()          # V0.4 punto 11
	_build_los_ray()             # V0.8.6.1: rayo de línea de visión compartido
	_stuck_anchor = global_position
	# V0.4 punto 2: sin detección de borde — los monstruos pueden caer de plataformas.

# V0.8.6.1: rayo de línea de visión (solo geometría de escenario, L_WORLD), origen en el centro.
func _build_los_ray() -> void:
	_los_ray = RayCast2D.new()
	_los_ray.position = Vector2.ZERO
	_los_ray.collision_mask = L_WORLD
	_los_ray.enabled = true
	add_child(_los_ray)

## ¿Hay línea de visión limpia (sin geometría) hasta el objetivo?
func has_clear_los(target: Node2D) -> bool:
	if _los_ray == null or target == null or not is_instance_valid(target):
		return false
	_los_ray.target_position = target.global_position - global_position
	_los_ray.force_raycast_update()
	return not _los_ray.is_colliding()

## ¿Hay geometría a lo largo de 'dir' dentro de 'dist' px? (para no cargar un ataque que choca).
func path_blocked(dir: Vector2, dist: float) -> bool:
	if _los_ray == null or dir == Vector2.ZERO:
		return false
	_los_ray.target_position = dir.normalized() * dist
	_los_ray.force_raycast_update()
	return _los_ray.is_colliding()

## Anti-stuck por PROGRESO: cada 'window' s comprueba si el monstruo se ha desplazado al menos
## 'min_progress' px. Devuelve true (atascado → debe circular) solo si NO progresó Y NO tiene
## línea de visión al jugador (hay geometría en medio: no puede atacar). Si ve al jugador
## (puede atacar) o si avanza, NO se considera atascado. Resetea su ventana en cada evaluación.
func is_stuck_no_los(delta: float, target: Node2D, window: float, min_progress: float) -> bool:
	_stuck_check += delta
	if _stuck_check < window:
		return false
	var progressed := global_position.distance_to(_stuck_anchor) >= min_progress
	var los := target != null and has_clear_los(target)
	_stuck_anchor = global_position
	_stuck_check = 0.0
	return (not progressed) and (not los)

## Reinicia la ventana del anti-stuck (al patrullar o atacar, no debe acumular).
func reset_stuck() -> void:
	_stuck_anchor = global_position
	_stuck_check = 0.0

func _build_wrap_ghost() -> void:
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
		if delta.y != 0.0:
			velocity.y *= 0.5               # V0.5 punto 3: damping al wrap vertical
	var off := ScreenWrapper.ghost_offset(global_position, body_size * 0.5)
	if off != Vector2.ZERO:
		_wrap_ghost.visible = true
		_wrap_ghost.global_position = global_position + off
	else:
		_wrap_ghost.visible = false

func _ignores_world() -> bool:
	return false

func _build_collision() -> void:
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = body_size
	c.shape = s
	add_child(c)

func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_body_poly = Polygon2D.new()
	var hx := body_size.x * 0.5
	var hy := body_size.y * 0.5
	_body_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_body_poly.color = body_color
	_visual.add_child(_body_poly)

func _build_hurtbox() -> void:
	var hb := Area2D.new()
	hb.collision_layer = L_MONSTER_HURT
	hb.collision_mask = 0
	hb.monitoring = false
	hb.monitorable = true
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = body_size
	c.shape = s
	hb.add_child(c)
	hb.set_meta("entity", self)
	add_child(hb)

func _build_contact_area() -> void:
	_contact_area = Area2D.new()
	_contact_area.collision_layer = L_HARMFUL
	_contact_area.collision_mask = L_PLAYER_HURT
	_contact_area.monitoring = true
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = body_size
	c.shape = s
	_contact_area.add_child(c)
	add_child(_contact_area)

func _build_name_label() -> void:
	if monster_name == "":
		return
	var lbl := Label.new()
	lbl.text = monster_name
	lbl.add_theme_font_size_override("font_size", 5)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(60, 8)
	lbl.position = Vector2(-30, -body_size.y * 0.5 - 11)
	lbl.z_index = 20
	add_child(lbl)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 260.0)   # V0.8.2 A-2: cap de caída ÷2
	_ai(delta)
	move_and_slide()
	_update_wrap()
	_check_contact()

## Sobreescrito por cada monstruo.
func _ai(_delta: float) -> void:
	pass

## V0.5 p.5: recibe un stomp desde arriba — muerte inmediata sin importar el estado.
func receive_stomp(attacker: Node) -> void:
	die(attacker)

## V0.3 punto 8: el contacto lateral/inferior solo mata si el ataque está activo;
## si no, aplica un rebote suave sin daño.
func _check_contact() -> void:
	if is_dead or _contact_area == null:
		return
	for area in _contact_area.get_overlapping_areas():
		if not area.has_meta("entity"):
			continue
		var p = area.get_meta("entity")
		if not (p is PlayerBase) or p.is_dead:
			continue
		# El stomp desde arriba lo gestiona _check_stomp.
		if p.velocity.y > 10.0 and p.global_position.y < global_position.y - body_size.y * 0.3:
			continue
		if is_attack_active:
			p.die(self)
		else:
			_apply_side_bump(p)

func _apply_side_bump(p: PlayerBase) -> void:
	var d := signf(p.global_position.x - global_position.x)
	if d == 0.0:
		d = 1.0
	p.velocity.x += d * 60.0   # impulso pequeño, solo horizontal — sin daño

func die(source: Node = null) -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx("monster_death")
	_spawn_corpse(source)
	_spawn_particles()
	on_died.emit(self)
	queue_free()

## V0.2 puntos 9/10: cuerpo despedido por el impulso del proyectil (con flecha si aplica).
func _spawn_corpse(source: Node) -> void:
	var impulse := Vector2.ZERO
	var carry := false
	var acol := body_color.lightened(0.3)
	var aangle := 0.0
	if source is ProjectileBase:
		impulse = source.velocity.normalized() * source.death_impulse
		carry = source.carries_pickup
		acol = source.proj_color
		aangle = source.velocity.angle()
	var c := Corpse.new()
	c.setup(global_position, body_size, body_color, impulse, carry, acol, aangle)
	# Diferido: die() suele invocarse durante un callback de colisión (flush de físicas).
	get_parent().add_child.call_deferred(c)

func _spawn_particles() -> void:
	for i in 8:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		p.color = body_color
		p.global_position = global_position
		get_parent().add_child(p)
		var ang := TAU * i / 8.0
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", global_position + Vector2.RIGHT.rotated(ang) * 16.0, 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)

func get_nearest_player() -> PlayerBase:
	var best: PlayerBase = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("player"):
		if n is PlayerBase and not n.is_dead:
			var d := global_position.distance_squared_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

func _spawn_monster_projectile(dir: Vector2, speed: float, grav: float, kind: String, _pierce: bool = false) -> void:
	var p := ProjectileBase.new()
	p.kind = kind
	p.proj_color = body_color.lightened(0.3)
	p.owner_node = self
	p.proj_gravity = grav
	p.hostile_to_players = true
	p.hostile_to_monsters = false
	p.pickable = false
	get_parent().add_child(p)
	p.setup(global_position + dir.normalized() * (body_size.x * 0.5 + 4), dir, speed)

func get_debug_info() -> String:
	return "%s @(%d,%d)" % [name, int(global_position.x), int(global_position.y)]
