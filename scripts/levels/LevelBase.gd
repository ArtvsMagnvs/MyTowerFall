extends Node2D
class_name LevelBase
## LevelBase — Base de niveles (DOCUMENTO_MAESTRO.md §8).
## Construye geometría estática (sólidos + plataformas one-way), fondo, killzone
## de caída mortal y gestiona el sistema de oleadas del modo Historia.
## Las subclases definen el layout sobreescribiendo los métodos de datos.
## Autor: Claude Code · Versión: 0.4.0

const L_WORLD := 1
const L_PLAYER_HURT := 2
const L_MONSTER_HURT := 4
const L_HARMFUL := 8

signal on_wave_started(index: int, total: int)
signal on_level_cleared

# V0.8.2 F-1: tipos de monstruo → escena (las oleadas se definen por nombre de tipo).
const MONSTER_SCENES := {
	"Slime": "res://scenes/monsters/Slime.tscn",
	"Troll": "res://scenes/monsters/StoneTroll.tscn",
	"Bat": "res://scenes/monsters/ShadowBat.tscn",
	"Specter": "res://scenes/monsters/SpecterArcher.tscn",
}
const PORTAL_COLOR := Color(0.6, 0.1, 0.9, 1.0)   # F-1: violeta
const PORTAL_LEAD := 1.0     # F-1: el monstruo emerge 1.0s después de aparecer el portal

var _wave_index := -1
var _alive := 0              # monstruos vivos ya spawneados en la oleada actual
var _pending := 0           # monstruos de la oleada aún por spawnear (portales en curso)
var _wave_completing := false
var _running_waves := false

# ---- Datos sobreescritos por cada nivel ----
func level_title() -> String: return "Nivel"
func bg_color() -> Color: return Color(0.08, 0.1, 0.14)
func solids() -> Array: return []          # Array[Rect2]
func platforms() -> Array: return []       # Array[Rect2] (one-way)
func player_spawns() -> Array: return [Vector2(110, 150), Vector2(210, 150)]
func monster_spawns() -> Array: return [Vector2(160, 40)]
func deadly_bottom() -> bool: return false
## V0.8.2 F-2: cada oleada es un Array de mini-oleadas. Cada mini-oleada es
## [t_inicio, [ [tipo, spawn_num(1-based), delay], ... ] ]. La oleada se supera solo
## cuando TODOS los monstruos de TODAS sus mini-oleadas han muerto.
func waves() -> Array: return []
## V0.8.2 F-1: puntos de spawn (Marker2D "SpawnPoint_*" o, por defecto, monster_spawns()).
func get_spawn_points() -> Array:
	var markers: Array = []
	for child in get_children():
		if child is Marker2D and (child.name as String).begins_with("SpawnPoint"):
			markers.append(child)
	if not markers.is_empty():
		markers.sort_custom(func(a, b): return String(a.name) < String(b.name))
		var pts: Array = []
		for m in markers:
			pts.append((m as Marker2D).global_position)
		return pts
	return monster_spawns()
## V0.4 punto 11: zonas de wrapping. Cada una: {axis, lo, hi}.
func wrap_zones() -> Array: return []

func _ready() -> void:
	add_to_group("level")
	_setup_wrap_zones()
	_build_background()
	_build_geometry()
	if deadly_bottom():
		_build_killzone()

func _setup_wrap_zones() -> void:
	ScreenWrapper.clear_zones()
	for z in wrap_zones():
		ScreenWrapper.add_zone(z["axis"], z["lo"], z["hi"])

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = bg_color()
	bg.size = Vector2(320, 180)
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Capa decorativa lejana (parallax estático): bandas más oscuras.
	var band := ColorRect.new()
	band.color = bg_color().darkened(0.25)
	band.position = Vector2(0, 60)
	band.size = Vector2(320, 60)
	band.z_index = -99
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

func _build_geometry() -> void:
	var solid_body := StaticBody2D.new()
	solid_body.add_to_group("world")
	solid_body.collision_layer = L_WORLD
	solid_body.collision_mask = 0
	add_child(solid_body)
	for r in solids():
		_add_box(solid_body, r, _tile_color(), false)
	var plat_body := StaticBody2D.new()
	plat_body.add_to_group("world")
	plat_body.collision_layer = L_WORLD
	plat_body.collision_mask = 0
	add_child(plat_body)
	# V0.5.1 CAMBIO-10: las plataformas flotantes son SÓLIDAS por todos los lados
	# (sin one-way). Ninguna entidad atraviesa geometría en ninguna dirección.
	for r in platforms():
		_add_box(plat_body, r, _tile_color().lightened(0.12), false)

func _tile_color() -> Color:
	return bg_color().lightened(0.35)

func _add_box(body: StaticBody2D, r: Rect2, col: Color, one_way: bool) -> void:
	var col_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col_shape.shape = shape
	col_shape.position = r.position + r.size * 0.5
	col_shape.one_way_collision = one_way
	body.add_child(col_shape)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y)])
	poly.color = col
	add_child(poly)

func _build_killzone() -> void:
	var kz := Area2D.new()
	kz.collision_layer = 0
	kz.collision_mask = L_PLAYER_HURT | L_MONSTER_HURT
	kz.monitoring = true
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(800, 40)
	c.shape = s
	c.position = Vector2(160, 210)
	kz.add_child(c)
	kz.area_entered.connect(_on_killzone_entered)
	add_child(kz)

func _on_killzone_entered(area: Area2D) -> void:
	if area.has_meta("entity"):
		var e = area.get_meta("entity")
		if e.has_method("die"):
			e.die(self)

# ---- Sistema de oleadas con mini-oleadas y portales (V0.8.2 F) ----
func start_waves() -> void:
	if waves().is_empty():
		return
	_running_waves = true
	_next_wave()

func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves().size():
		_running_waves = false
		on_level_cleared.emit()
		return
	var wave: Array = waves()[_wave_index]
	on_wave_started.emit(_wave_index + 1, waves().size())
	_alive = 0
	_pending = _count_wave_monsters(wave)
	_wave_completing = false
	# Programar cada mini-oleada en su instante t y cada spawn con su delay interno.
	for mw in wave:
		var t: float = mw[0]
		var spawns: Array = mw[1]
		for sp in spawns:
			var delay: float = t + (sp[2] if (sp as Array).size() > 2 else 0.0)
			_schedule_spawn(sp[0], int(sp[1]), delay)

func _count_wave_monsters(wave: Array) -> int:
	var n := 0
	for mw in wave:
		n += (mw[1] as Array).size()
	return n

func _schedule_spawn(type: String, spawn_num: int, at: float) -> void:
	if at > 0.0:
		await get_tree().create_timer(at).timeout
	if not _running_waves:
		return
	await _spawn_with_portal(type, spawn_num)

## F-1: aparece un portal violeta; PORTAL_LEAD segundos después emerge el monstruo.
func _spawn_with_portal(type: String, spawn_num: int) -> void:
	var points := get_spawn_points()
	if points.is_empty():
		return
	var pos: Vector2 = points[(spawn_num - 1) % points.size()]
	_make_portal(pos)
	await get_tree().create_timer(PORTAL_LEAD).timeout
	if not _running_waves:
		return
	var path: String = MONSTER_SCENES.get(type, "")
	if path == "":
		push_warning("Tipo de monstruo desconocido en oleada: %s" % type)
		_pending -= 1
		_check_wave_complete()
		return
	var m := (load(path) as PackedScene).instantiate() as MonsterBase
	m.global_position = pos
	m.on_died.connect(_on_monster_died)
	add_child(m)
	_alive += 1
	_pending -= 1
	_check_wave_complete()

func _make_portal(pos: Vector2) -> void:
	var portal := Node2D.new()
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 7.0)   # círculo de 14px de diámetro
	poly.polygon = pts
	poly.color = PORTAL_COLOR
	portal.add_child(poly)
	portal.z_index = 5
	add_child(portal)
	portal.global_position = pos
	# Pulso suave 1.0 → 1.3 → 1.0 en 0.5s, en bucle hasta que el monstruo emerge.
	var tw := portal.create_tween().set_loops()
	tw.tween_property(portal, "scale", Vector2(1.3, 1.3), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(portal, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(PORTAL_LEAD).timeout.connect(func() -> void:
		if is_instance_valid(portal):
			portal.queue_free())

func _on_monster_died(_m: MonsterBase) -> void:
	_alive -= 1
	_check_wave_complete()

## La oleada solo se supera cuando no quedan spawns pendientes NI monstruos vivos.
func _check_wave_complete() -> void:
	if not _running_waves or _wave_completing:
		return
	if _pending <= 0 and _alive <= 0:
		_wave_completing = true
		await get_tree().create_timer(1.5).timeout
		_next_wave()

func current_wave() -> int:
	return _wave_index + 1

func total_waves() -> int:
	return waves().size()

# ---- Respawn (V0.3 punto 13) ----
func nearest_spawn(pos: Vector2) -> Vector2:
	var spawns := player_spawns()
	var best: Vector2 = spawns[0]
	var best_d := INF
	for s in spawns:
		var d: float = pos.distance_squared_to(s)
		if d < best_d:
			best_d = d
			best = s
	return best

## Posición de reaparición segura: si el cadáver quedó en el vacío o fuera de
## límites, usa el punto de spawn más cercano (evita morir al instante).
func safe_respawn_pos(pos: Vector2) -> Vector2:
	if deadly_bottom() and pos.y > 168.0:
		return nearest_spawn(pos)
	if pos.x < 4.0 or pos.x > 316.0 or pos.y > 200.0 or pos.y < -20.0:
		return nearest_spawn(pos)
	return pos
