# ACTUALIZACIÓN V0.5.1 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico
**Fecha:** 2026-06-25
**Versión destino:** 0.5.1
**Prerrequisito:** V0.5 aplicada. Esta actualización corrige los 7 bugs encontrados en la auditoría post-V0.5 y añade 4 nuevos cambios de diseño.

---

## ÍNDICE

- Bloque A — Correcciones de auditoría (bugs 1–7 del informe)
- Bloque B — Nuevos cambios de diseño (puntos 8–11)

---

# BLOQUE A — CORRECCIONES DE AUDITORÍA

## BUG-1 · CRÍTICO: ProjectileBase — cambiar de Area2D a CharacterBody2D

**Archivo:** `scripts/projectiles/ProjectileBase.gd`

**Problema:** `ProjectileBase extends Area2D` con `global_position += velocity * delta`. El movimiento manual causa tunneling — una flecha a 300 px/s recorre 5px por frame, y un tile mide 10px. En ciertos ángulos la flecha cruza la pared sin que `body_entered` dispare.

**Solución:** Cambiar el nodo raíz a `CharacterBody2D` y mover el proyectil con `move_and_collide()`. Esta función devuelve la colisión del frame actual sin tunneling.

**Cambio en la cabecera del script:**
```gdscript
# ANTES:
extends Area2D
class_name ProjectileBase

# DESPUÉS:
extends CharacterBody2D
class_name ProjectileBase
```

**Cambio en `_ready()`** — eliminar los signals de `body_entered` / `area_entered` y la configuración de `monitoring`. Añadir solo la máscara de colisión:
```gdscript
func _ready() -> void:
    add_to_group("projectile")
    collision_layer = L_HARMFUL
    collision_mask = L_WORLD
    if hostile_to_players:
        collision_mask |= L_PLAYER_HURT
    if hostile_to_monsters:
        collision_mask |= L_MONSTER_HURT
    _apply_kind_defaults()
    _build_shape()
    _build_visual()
    _build_wrap_ghost()
    if start_stuck:
        rotation = start_angle
        _stick()
```

**Cambio en `_physics_process(delta)`** — sustituir el bloque de movimiento manual:
```gdscript
func _physics_process(delta: float) -> void:
    if _stuck:
        _stuck_time -= delta
        if _stuck_time <= 0.0:
            _fade_and_free()
        elif pickable:
            _check_pickup()
        return
    _grace = maxf(_grace - delta, 0.0)
    velocity.y += proj_gravity * delta
    if attraction_enabled:
        _apply_attraction(delta)
    if velocity.length() > 1.0:
        rotation = velocity.angle()
    # move_and_collide detecta colisiones frame a frame (sin tunneling):
    var collision := move_and_collide(velocity * delta)
    if collision:
        _on_collision(collision)
    _update_wrap()
    # Limpieza fuera del área:
    if global_position.x < -20.0 or global_position.x > 340.0 \
            or global_position.y < -40.0 or global_position.y > 220.0:
        queue_free()
```

**Nuevo método `_on_collision(collision: KinematicCollision2D)`** — reemplaza `_on_body_entered` y `_on_area_entered`:
```gdscript
func _on_collision(collision: KinematicCollision2D) -> void:
    var collider := collision.get_collider()
    if collider == null or _grace > 0.0:
        return
    # Colisión con geometría del mundo (TileMap, StaticBody2D):
    if collider.is_in_group("world") or collider is StaticBody2D or collider is TileMapLayer:
        if kind == "arrow" or kind == "hatchet":
            _stick()
        else:
            _impact_vfx()
            queue_free()
        return
    # Colisión con entidad (jugador o monstruo):
    if collider.has_method("die"):
        if collider == owner_node:
            return  # no se daña a uno mismo
        collider.die(self)
        _impact_vfx()
        queue_free()
```

**Eliminar los métodos obsoletos:** `_on_body_entered()`, `_on_area_entered()`, `_check_world_border()`.

**Adaptar `_check_pickup()`** — ahora usa `get_overlapping_bodies()` de un Area2D hijo si es necesario, o directamente una detección por distancia:
```gdscript
func _check_pickup() -> void:
    # La flecha clavada es pickable. Detectar jugadores cercanos por distancia simple:
    for n in get_tree().get_nodes_in_group("player"):
        if not (n is PlayerBase) or not n.uses_projectiles:
            continue
        if global_position.distance_to(n.global_position) < 8.0:
            _try_pickup(n)
            return
```

**Verificación:**
- Disparar una flecha contra una pared diagonal → se clava sin atravesar.
- Disparar una flecha muy rápido (ARROW_INITIAL_SPEED × 2 en debug) contra una pared de 1 tile → no atraviesa.
- Una flecha clavada se puede recoger caminando encima.

---

## BUG-2 · CRÍTICO: ShadowBat — patrol no recalcula home_position al impactar geometría

**Archivo:** `scripts/monsters/ShadowBat.gd`

**Problema:** Cuando el bat choca con una pared durante el vuelo circular, `move_and_slide()` lo detiene pero el siguiente frame intenta moverse hacia el mismo punto (detrás de la pared). El bat vibra.

**Solución:** Al final de `_patrol()`, detectar si `move_and_slide()` ha producido colisiones y si es así ajustar `_home` empujándola en la dirección de la normal de la pared:

```gdscript
func _patrol(delta: float) -> void:
    is_attack_active = false
    _angle += (FLY_SPEED / PATROL_RADIUS) * delta
    var target := _home + Vector2(cos(_angle), sin(_angle) * 0.7) * PATROL_RADIUS
    velocity = (target - global_position).limit_length(FLY_SPEED)
    # Detección de jugador:
    var p := get_nearest_player()
    if p != null and global_position.distance_to(p.global_position) < DETECTION_RANGE:
        _state = BState.TRACKING
        _cooldown = randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
        return
    # Recalcular home si hay colisión con geometría para no vibrar contra paredes:
    # (Se llama DESPUÉS de que MonsterBase ya ejecutó move_and_slide() este frame)
    if get_slide_collision_count() > 0:
        for i in get_slide_collision_count():
            var col := get_slide_collision(i)
            # Empujar home_position en la dirección de la normal (alejar el círculo de la pared):
            _home += col.get_normal() * 4.0
        # Clamp: home no puede salir del arena:
        _home.x = clampf(_home.x, ScreenWrapper.ARENA_LEFT + PATROL_RADIUS, ScreenWrapper.ARENA_RIGHT - PATROL_RADIUS)
        _home.y = clampf(_home.y, PATROL_RADIUS, ScreenWrapper.ARENA_BOTTOM - PATROL_RADIUS)
```

**Nota importante:** `_patrol()` se llama desde `_ai()`, que corre ANTES de `move_and_slide()` en `MonsterBase._physics_process()`. Esto significa que `get_slide_collision_count()` devuelve las colisiones del frame ANTERIOR. Esto es correcto para el propósito de recalcular `_home` — un frame de delay es imperceptible y evita la vibración.

**Verificación:**
- Colocar el bat junto a una pared. En modo patrulla, debe desviar su círculo y seguir volando sin quedarse pegado.

---

## BUG-3 · CRÍTICO: Stomp — reemplazar Area2D overlap con RayCast2D

**Archivo:** `scripts/characters/PlayerBase.gd`

**Problema:** `_stomp_foot` (Area2D) con `get_overlapping_areas()` falla cuando el contacto dura menos de un frame de física (caída rápida). El jugador cae encima de un enemigo y no lo mata.

**Solución:** Eliminar `_stomp_foot` (Area2D) y reemplazarlo por un `RayCast2D` que lanza un rayo corto hacia abajo desde el borde inferior del jugador. Se actualiza en cada frame y detecta la colisión con la capa `L_STOMP_MONSTER | L_STOMP_PLAYER` independientemente de la velocidad.

**En `_build_stomp_nodes()`** — eliminar la creación de `_stomp_foot` y añadir el raycast:
```gdscript
func _build_stomp_nodes() -> void:
    # StompHitbox: zona superior (monitorable por el raycast de otros jugadores):
    _stomp_hitbox = Area2D.new()
    _stomp_hitbox.collision_layer = L_STOMP_PLAYER
    _stomp_hitbox.collision_mask = 0
    _stomp_hitbox.monitoring = false
    _stomp_hitbox.monitorable = true
    var c := CollisionShape2D.new()
    var s := RectangleShape2D.new()
    s.size = Vector2(body_size.x, 5)
    c.shape = s
    c.position = Vector2(0, -body_size.y * 0.5 + 1.0)
    _stomp_hitbox.add_child(c)
    _stomp_hitbox.set_meta("entity", self)
    add_child(_stomp_hitbox)

    # StompRayCast: rayo hacia abajo desde el pie, detecta StompHitbox de entidades:
    _stomp_ray = RayCast2D.new()
    _stomp_ray.position = Vector2(0, body_size.y * 0.5)   # borde inferior
    _stomp_ray.target_position = Vector2(0, 6)             # 6px hacia abajo
    _stomp_ray.collision_mask = L_STOMP_PLAYER | L_STOMP_MONSTER
    _stomp_ray.enabled = true
    add_child(_stomp_ray)
```

**Añadir la variable en la sección de variables de `PlayerBase`:**
```gdscript
var _stomp_ray: RayCast2D   # reemplaza _stomp_foot
```

**Reemplazar `_check_stomp()` completamente:**
```gdscript
func _check_stomp() -> void:
    if is_dead or _dash_time > 0.0:
        return   # dash esquiva dar stomp
    if _pre_move_vy < -30.0:
        return   # el jugador estaba subiendo fuerte — imposible stomp
    _stomp_ray.force_raycast_update()
    if not _stomp_ray.is_colliding():
        return
    var hit := _stomp_ray.get_collider()
    if hit == null or not hit.has_meta("entity"):
        return
    var target = hit.get_meta("entity")
    if target == self or not is_instance_valid(target):
        return
    if "is_dead" in target and target.is_dead:
        return
    if not target.has_method("receive_stomp"):
        return
    target.receive_stomp(self)
    AudioManager.play_sfx("stomp")
    _apply_stomp_bounce()
```

**Verificación:**
- Caer sobre un Slime desde 5 tiles de altura → muere 100% de las veces.
- Caer sobre un Slime desde 1 tile de altura → muere 100% de las veces.
- Saltar y caer sobre el Troll → muere.
- Encadenar stomp sobre 2 enemigos consecutivos manteniendo el botón de salto → ambos mueren.

---

## BUG-4 · MODERADO: SpecterArcher — `_clamp_to_bounds()` después de `move_and_slide()`

**Archivo:** `scripts/monsters/SpecterArcher.gd`

**Problema:** `_clamp_to_bounds()` se llama desde `_ai()` (antes de `move_and_slide()`), pudiendo insertar el Espectro dentro de geometría.

**Solución:** Mover la llamada a `_clamp_to_bounds()` para que ocurra después de `move_and_slide()`. Sobreescribir `_physics_process` en `SpecterArcher`:

```gdscript
func _physics_process(delta: float) -> void:
    if is_dead:
        return
    # El Espectro no tiene gravedad (flying = true), la aplica MonsterBase solo si flying=false.
    _ai(delta)
    move_and_slide()
    _clamp_to_bounds()   # DESPUÉS de move_and_slide, no durante _ai()
    _update_wrap()
    _check_contact()
```

**Eliminar** la llamada a `_clamp_to_bounds()` dentro de `_ai()`.

**Verificación:** El Espectro no debe saltar ni vibrar al llegar al límite del arena.

---

## BUG-5 · MODERADO: ShadowBat `_dashing()` — añadir parámetro `delta`

**Archivo:** `scripts/monsters/ShadowBat.gd`

**Solución:** Hacer consistente el patrón de todos los estados pasando `delta`:

```gdscript
# En _ai():
BState.DASHING: _dashing(delta)

# Firma del método:
func _dashing(delta: float) -> void:
    is_attack_active = true
    velocity = _dash_dir * DASH_SPEED
    _timer -= delta   # usar delta, no get_physics_process_delta_time()
    if get_slide_collision_count() > 0 or _timer <= 0.0:
        _state = BState.RECOVERING
        _timer = RECOVER_T
```

---

## BUG-6 · MENOR: MonsterBase — actualizar versión a 0.5.0

**Archivo:** `scripts/monsters/MonsterBase.gd`

Cambiar la línea de cabecera:
```
## Autor: Claude Code · Versión: 0.4.0
→
## Autor: Claude Code · Versión: 0.5.0
```

---

## BUG-7 · MENOR: Parámetro `_delta` mal nombrado en `_process_ledge_hang`

**Archivo:** `scripts/characters/PlayerBase.gd`

```gdscript
# ANTES:
func _process_ledge_hang(_delta: float) -> void:
    ...
    _ledge_slide += stats.ledge_slide_speed * _delta

# DESPUÉS:
func _process_ledge_hang(delta: float) -> void:
    ...
    _ledge_slide += stats.ledge_slide_speed * delta
```

---

# BLOQUE B — NUEVOS CAMBIOS DE DISEÑO

## CAMBIO-8 · UI — Rediseño completo: escala, legibilidad y tipografía

**Archivos:** `scenes/ui/MainMenu.tscn`, `scenes/ui/CharacterSelect.tscn`, `scenes/ui/OptionsMenu.tscn`, `scenes/ui/VersusMatch.tscn`, `scenes/ui/StoryMatch.tscn`, `scripts/ui/*.gd`

### El problema

La resolución nativa del juego es 320×180 con escalado nearest-neighbor. Las fuentes de píxeles pequeñas se ven borrosas porque el escalado nearest-neighbor magnifica cada pixel pero las etiquetas de texto en Godot 4 se renderizan con antialiasing por defecto, creando un conflicto visual con el estilo pixel-art. Además, los elementos UI están calibrados para una pantalla de juego de 320×180 sin tener en cuenta que el juego se renderiza a ~1920×1080 en la pantalla real.

### Solución: dos capas de rendering

El juego tiene dos espacios visuales que deben tratarse de forma diferente:

**Espacio de juego (arena):** Render en SubViewport 320×180 con nearest-neighbor. Aquí van los personajes, plataformas, tiles. Esta capa YA funciona bien.

**Espacio UI (menús y HUD):** Render directo a la resolución real de la ventana (ej. 1920×1080), SIN el SubViewport del juego. Usar fuentes de sistema, NO fuentes de píxeles. La UI debe ser un `CanvasLayer` con `follow_viewport = false`.

### Configuración de fuentes

En el `project.godot`, configurar la fuente por defecto del tema:
```
# En Project Settings → GUI → Theme → Default Font:
# Usar una fuente .ttf incluida en el proyecto. Recomendada:
# - Inter (licencia libre, muy legible)
# - Nunito (redonda, moderna, buena para juegos)
# - Roboto
#
# Descargar la .ttf y colocarla en: res://assets/fonts/ui_font.ttf
# Tamaño por defecto: 16px (se ve bien a 1080p)
```

Crear un `Theme` global en `res://resources/UITheme.tres` con:
```
default_font = preload("res://assets/fonts/ui_font.ttf")
default_font_size = 16
# Botones:
Button/font_size = 18
Button/normal background = color sólido semitransparente
Button/hover background = color levemente más claro
Button/pressed background = color más oscuro
# Labels:
Label/font_size = 16
# Título del juego (H1):
# Usar un Label con custom font_size = 32
```

### Reescalar elementos de la UI

**Problema de escala:** Los menús probablemente asumen 320×180 y se ven enormes en pantalla real. Con el escalado `2D` de Godot (`Stretch Mode = canvas_items`, `Aspect = expand`), la UI escala con el viewport. Cambiar a:

```
# En project.godot:
display/window/stretch/mode = "viewport"     ← antes era probablemente "canvas_items"
display/window/stretch/aspect = "keep"
display/window/size = (1280, 720)            ← resolución base de la ventana
```

Con `stretch/mode = "viewport"`, el mundo de juego (dentro del SubViewport 320×180) se escala con nearest-neighbor, pero la UI de `CanvasLayer` con `follow_viewport = false` se renderiza en la resolución real sin distorsión.

**MainMenu (`MainMenu.tscn`):**
- `VBoxContainer` centrado en la pantalla, ancho máximo 400px.
- Título "NIIDE: EL CÍRCULO DÁRICO": `Label`, font_size = 40, negrita, centrado.
- Subtítulo/tagline: font_size = 14, color grisáceo.
- Botones (Versus, Historia, Opciones, Salir): mínimo 200px ancho, 44px alto, separados 8px.
- Fondo: color oscuro semitransparente o imagen de fondo de bajo contraste.

**CharacterSelect (`CharacterSelect.tscn`):**
- Layout horizontal: dos paneles (P1 izquierda, P2 derecha), separados 32px.
- Cada panel: nombre del jugador (font_size 20), preview del personaje, nombre de la clase seleccionada (font_size 16), controles de selección.
- Cabe todo en una sola pantalla de 1280×720.

**OptionsMenu (`OptionsMenu.tscn`):**
- `ScrollContainer` con `VBoxContainer` interior. Máximo 600px de ancho centrado.
- Secciones claramente separadas con headers (font_size 14, color acento, mayúsculas).
- Remapeo de controles: tabla 2 columnas (acción | botón asignado), botón "Cambiar" al lado de cada fila.

**HUD (`HUD.gd`, paneles laterales):**
- Los paneles de 40px a cada lado (x: 0–40 y 280–320 en el espacio de juego) se renderizan dentro del SubViewport 320×180.
- Las vidas (cristales) y el contador de munición se renderizan aquí con fuente de píxeles pequeña — esto es intencional y correcto para el look del juego.
- El HUD del arena NO cambia de fuente. Solo cambian los menús que están fuera del arena.

### Resumen de cambios por archivo

| Archivo | Cambio |
|---|---|
| `project.godot` | `stretch/mode = viewport`, resolución base 1280×720 |
| `res://assets/fonts/ui_font.ttf` | Añadir fuente (Inter o Nunito) |
| `res://resources/UITheme.tres` | Crear tema global con la fuente y colores |
| `MainMenu.tscn` | Aplicar tema, reescalar a 1280×720, VBoxContainer centrado |
| `CharacterSelect.tscn` | Layout horizontal, dos paneles, reescalar |
| `OptionsMenu.tscn` | ScrollContainer, tabla de controles, reescalar |
| `VersusMatch.tscn` / `StoryMatch.tscn` | Verificar que la UI de partido no interfiere con el arena |
| Todos los `Label` en menús | Eliminar `custom_minimum_size` muy pequeño; usar font_size del tema |

**Verificación:**
- Abrir el MainMenu en 1280×720. Todo debe ser legible sin zoom. Sin borrosidad.
- Cambiar a 1920×1080. La UI debe escalar limpiamente.
- Entrar al arena. Los personajes deben verse pixelados (nearest-neighbor). Las fuentes del HUD pueden ser pixel-font porque están dentro del SubViewport.
- Ningún texto en menús debe verse borroso ni pixelado.

---

## CAMBIO-9 · UI — Botones de jugador navegan la interfaz

**Archivos:** `scripts/ui/MainMenu.gd`, `scripts/ui/CharacterSelect.gd`, `scripts/ui/OptionsMenu.gd`

**Diseño:** En cualquier pantalla de menú, los controles mapeados de **cualquier jugador** (P1 o P2) deben poder navegar y confirmar:

- Direcciones (izquierda/derecha/arriba/abajo) de cualquier jugador → equivalen a las flechas de teclado (navegación entre botones).
- Botón de salto de cualquier jugador → equivale a Enter/UI_Accept (confirmar botón enfocado).

**Implementación: crear `scripts/ui/UIInputBridge.gd` (autoload o nodo singleton por menú):**

```gdscript
extends Node
## UIInputBridge — Traduce los inputs de juego (P1/P2) a eventos de UI estándar.
## Añadir como hijo de cada menú que necesite soporte de gamepad/teclado de jugadores.

const PLAYERS := [1, 2]
const DIRECTIONS := ["up", "down", "left", "right"]
const CONFIRM_ACTIONS := ["jump"]

func _input(event: InputEvent) -> void:
    for pid in PLAYERS:
        # Direcciones → navegación UI:
        for dir in DIRECTIONS:
            var action := "p%d_%s" % [pid, dir]
            if InputMap.has_action(action) and Input.is_action_just_pressed(action):
                _emit_ui_action("ui_" + dir)
                return
        # Salto → confirmar:
        var jump_action := "p%d_jump" % pid
        if InputMap.has_action(jump_action) and Input.is_action_just_pressed(jump_action):
            _emit_ui_action("ui_accept")
            return

func _emit_ui_action(action: String) -> void:
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = true
    Input.parse_input_event(ev)
```

**Añadir este nodo a cada escena de menú** (`MainMenu.tscn`, `CharacterSelect.tscn`, `OptionsMenu.tscn`) como hijo del nodo raíz.

**Configurar el focus de los botones en cada menú:**
- El primer botón de cada menú debe tener `focus_mode = All` y llamar `grab_focus()` en `_ready()`.
- Todos los botones deben tener `focus_neighbor_top`, `focus_neighbor_bottom` configurados para una navegación predecible (evitar que el focus salte a elementos inesperados).

**Nota sobre el input en pausa/durante partida:** El `UIInputBridge` solo debe estar activo cuando el menú está visible. Si se instancia solo en las escenas de menú (no como autoload global), esto es automático.

**Verificación:**
- En el MainMenu, presionar el botón de salto de P1 → confirma el botón enfocado.
- Presionar dirección abajo de P2 → mueve el focus al siguiente botón.
- En CharacterSelect, P1 usa sus direcciones para elegir personaje, P2 usa las suyas.
- El teclado con flechas y Enter estándar sigue funcionando (compatibilidad hacia atrás).

---

## CAMBIO-10 · FÍSICA: Plataformas flotantes NO son atravesables desde abajo

**Archivos:** `scripts/levels/LevelBase.gd`, escenas de nivel `scenes/levels/Level_0*.tscn`, configuración del TileMap.

**Problema:** Las plataformas flotantes tienen `one_way_collision = true`, lo que en Godot 4 significa que el jugador puede atravesarlas desde abajo pero no desde arriba. Esto viola la regla universal establecida en V0.4 y reforzada en V0.5: **ninguna entidad atraviesa ningún componente del escenario en ninguna dirección.**

**Solución:** Deshabilitar completamente `one_way_collision` en todas las plataformas flotantes. Las plataformas son sólidas desde todos los lados.

**En el TileMap (todas las escenas de nivel):** Para cada tile que sea plataforma flotante (no el suelo/paredes):
- Abrir el TileSet en el editor.
- Seleccionar la capa de física de las plataformas flotantes.
- Desactivar `one_way` en la capa de colisión física del tile.

**Alternativamente, por código en `LevelBase.gd`:**
```gdscript
func _ready() -> void:
    # Asegurar que ninguna capa del TileMap tiene one_way_collision activo:
    for child in get_children():
        if child is TileMapLayer:
            # En Godot 4.x, la configuración one_way está en el TileSet, no en el TileMapLayer.
            # Si se configuró por código, deshabilitar:
            child.collision_use_kinematic_bodies = false
    # Alternativa si se configuró por TileSet: editar el TileSet asset directamente.
    super._ready()
```

**Nota de diseño:** Esta es la misma decisión tomada en V0.2 (BUG-003) y V0.4. Al desactivar `one_way`, el jugador NO puede pasar por plataformas desde abajo ni desde arriba atravesándolas. Para subir a una plataforma flotante hay que saltar desde debajo y llegar a su superficie por los lados o aterrizando encima. Si alguna plataforma del diseño del nivel requería ser "pass-through" por diseño intencional (no es el caso en los 3 niveles actuales según el DOCUMENTO_MAESTRO), documentarlo explícitamente.

**Verificación:**
- Jugador salta hacia una plataforma flotante desde abajo → NO la atraviesa, rebota o se detiene.
- Jugador cae sobre una plataforma flotante desde arriba → aterriza normalmente.
- Monstruo (Slime) en una plataforma: no cae si camina al borde, y no puede ser empujado a través de la plataforma.

---

## CAMBIO-11 · MURCIÉLAGO: Rediseño de comportamiento (corrección del V0.5)

**Archivo:** `scripts/monsters/ShadowBat.gd`

**Aclaración:** El diseño de vuelo en círculo del V0.5 fue incorrecto. El comportamiento real del Murciélago es:

- **Vuelo normal en línea recta**, como un enemigo de plataformas estándar. El bat vuela horizontalmente, rebota en paredes y obstáculos, a velocidad reducida.
- **Velocidad de vuelo = 50% de la velocidad original** (ya estaba en 50 px/s desde V0.5; mantener ese valor).
- **Dash de ataque en 8 direcciones** idéntico al dash del jugador en cuanto a distancia. El jugador tiene `DASH_SPEED = 240 px/s` y `DASH_DURATION = 0.12s`, lo que da una distancia de `240 × 0.12 = 28.8px ≈ 29px`. El dash del bat debe recorrer exactamente esa distancia.

### Nueva FSM del Murciélago

**Estados:** `FLYING → TRACKING → PREPARING_DASH → DASHING → RECOVERING → FLYING`

Los estados `PREPARING_DASH`, `DASHING` y `RECOVERING` se mantienen igual que en V0.5. Solo cambia el estado de vuelo normal (antes `PATROL` con círculo, ahora `FLYING` en línea recta).

### Constantes actualizadas

```gdscript
# Eliminar:
const PATROL_RADIUS := 40.0

# Mantener/actualizar:
const FLY_SPEED := 50.0           # velocidad de vuelo normal (sin cambio)
const DASH_SPEED := 240.0         # igual que el jugador
const DASH_DURATION := 0.12       # igual que el jugador → distancia = 28.8px
const DASH_COOLDOWN_MIN := 1.5
const DASH_COOLDOWN_MAX := 3.0
const DETECTION_RANGE := 80.0
const SAFE_DISTANCE := 30.0
const PREPARE_T := 0.2
const RECOVER_T := 0.4
```

### Implementación del nuevo estado FLYING

```gdscript
var _fly_dir := 1   # 1 = derecha, -1 = izquierda

func _flying(delta: float) -> void:
    is_attack_active = false
    # Volar en línea recta horizontal; rebotar al impactar paredes:
    velocity.x = _fly_dir * FLY_SPEED
    velocity.y = 0.0   # vuelo horizontal puro (sin gravedad, flying = true)
    # Rebotar en paredes (move_and_slide ya se encarga de la colisión):
    if get_slide_collision_count() > 0:
        for i in get_slide_collision_count():
            var col := get_slide_collision(i)
            var normal := col.get_normal()
            # Si la normal tiene componente horizontal significativa → rebotar horizontalmente:
            if absf(normal.x) > 0.5:
                _fly_dir = -_fly_dir
            # Si la normal tiene componente vertical (techo/suelo) → invertir Y:
            elif absf(normal.y) > 0.5:
                # Opcional: el bat puede variar levemente su altura al rebotar:
                pass
    # Pequeña variación vertical sinusoidal (hace el movimiento menos robótico):
    # Se aplica como offset suave, no como velocidad real, para no interferir con move_and_slide:
    var wave_y := sin(Time.get_ticks_msec() * 0.003) * 15.0
    # El bat vuela en torno a su altura de spawn ± 15px:
    var target_y := _home.y + wave_y
    velocity.y = (target_y - global_position.y) * 3.0   # spring suave hacia la altura objetivo
    # Detectar jugador para cambiar a TRACKING:
    var p := get_nearest_player()
    if p != null and global_position.distance_to(p.global_position) < DETECTION_RANGE:
        _state = BState.TRACKING
        _cooldown = randf_range(DASH_COOLDOWN_MIN, DASH_COOLDOWN_MAX)
```

### Cambios en el estado TRACKING

```gdscript
func _tracking(delta: float) -> void:
    is_attack_active = false
    var p := get_nearest_player()
    if p == null or global_position.distance_to(p.global_position) > DETECTION_RANGE * 1.5:
        _state = BState.FLYING   # ← antes era BState.PATROL
        _home = global_position
        return
    # El bat mantiene distancia de seguridad orbitando al jugador lentamente:
    var to_p := p.global_position - global_position
    if to_p.length() > SAFE_DISTANCE:
        velocity = to_p.limit_length(FLY_SPEED)
    else:
        velocity = -to_p.limit_length(FLY_SPEED * 0.6)
    # Actualizar dirección del dash a 8 vías:
    _dash_dir = _snap_8(to_p)
    _cooldown -= delta
    if _cooldown <= 0.0:
        _state = BState.PREPARING_DASH
        _timer = PREPARE_T
        velocity = Vector2.ZERO
```

### Cambios en la FSM principal

```gdscript
enum BState { FLYING, TRACKING, PREPARING_DASH, DASHING, RECOVERING }

func _ai(delta: float) -> void:
    match _state:
        BState.FLYING:          _flying(delta)
        BState.TRACKING:        _tracking(delta)
        BState.PREPARING_DASH:  _preparing(delta)
        BState.DASHING:         _dashing(delta)
        BState.RECOVERING:      _recovering(delta)
```

### Cambios en `_ready()`

```gdscript
func _ready() -> void:
    body_size = Vector2(16, 12)
    body_color = Color(0.3, 0.18, 0.4)
    flying = true
    stompable = true
    monster_name = "Murciélago"
    super._ready()
    _home = global_position
    _fly_dir = 1 if randf() > 0.5 else -1   # dirección inicial aleatoria
    _cooldown = randf_range(DASH_COOLDOWN_MIN, DASH_COOLDOWN_MAX)
    _state = BState.FLYING   # ← antes era BState.PATROL
```

**Verificación:**
- El bat vuela en línea recta, rebotando en paredes. No hace círculos.
- Al detectar al jugador (≤80px), cambia a TRACKING.
- Tras el cooldown, se congela 0.2s (PREPARING_DASH) y luego lanza un dash en 8 direcciones.
- La distancia del dash: `240 px/s × 0.12s = 28.8px` → visualmente igual que el dash del jugador.
- El bat muere si recibe stomp, flecha o espada durante DASHING o RECOVERING.
- El bat NO atraviesa paredes ni plataformas en ningún estado.

---

## TABLA DE VERIFICACIÓN FINAL V0.5.1

| # | Prueba | Criterio de éxito |
|---|---|---|
| A1 | Flecha contra pared de 1 tile | No atraviesa, se clava en la superficie |
| A1 | Flecha rápida (debug) contra pared | No tunneling |
| A2 | Bat en patrol junto a pared | No vibra, desvía el vuelo |
| A3 | Stomp desde 5 tiles de altura | Mata 100% de las veces |
| A3 | Stomp desde 1 tile de altura | Mata 100% de las veces |
| A4 | Espectro en borde del arena | No jitter, movimiento suave |
| A5 | Bat en dash (duración) | Timer consistente con delta correcto |
| 8 | MainMenu a 1280×720 | Todo legible, sin borrosidad, sin overflow |
| 8 | MainMenu a 1920×1080 | Escala limpiamente |
| 8 | Arena en juego | Personajes pixelados (nearest-neighbor) |
| 9 | MainMenu: salto P1 → confirmar | El botón enfocado se activa |
| 9 | MainMenu: dirección abajo P2 | Focus baja al siguiente botón |
| 9 | Teclado estándar (Enter/flechas) | Sigue funcionando |
| 10 | Salto hacia plataforma flotante desde abajo | No la atraviesa |
| 10 | Caer sobre plataforma flotante | Aterriza normalmente |
| 10 | Slime en plataforma flotante | No la atraviesa en ninguna dirección |
| 11 | Bat vuelo normal | Línea recta con rebote en paredes, no círculo |
| 11 | Bat dash | Misma distancia visual que el dash del jugador |
| 11 | Bat no atraviesa geometría | En ningún estado: FLYING, DASHING, RECOVERING |

---

## ORDEN DE IMPLEMENTACIÓN

```
Bloque A (bugs):
  → BUG-6 (MonsterBase versión) — 30 segundos, sin riesgo
  → BUG-7 (parámetro _delta)   — 1 minuto, sin riesgo
  → BUG-5 (ShadowBat delta)    — 5 minutos
  → BUG-4 (Specter clamp)      — 10 minutos
  → BUG-2 (Bat patrol home)    — 15 minutos
  → BUG-3 (Stomp RayCast)      — 20 minutos — REQUIERE test después
  → BUG-1 (ProjectileBase)     — 45 minutos — mayor refactor, REQUIERE test después

Bloque B (diseño):
  → CAMBIO-10 (plataformas)    — 20 minutos — cambio en TileSet/editor
  → CAMBIO-11 (Murciélago)     — 30 minutos — reemplazar _patrol/_flying
  → CAMBIO-9  (UI input)       — 30 minutos — UIInputBridge.gd nuevo
  → CAMBIO-8  (UI rediseño)    — 90 minutos — el más extenso, hacerlo último

Verificación final: ejecutar la tabla completa de 19 pruebas.
Actualizar CHANGELOG.md con versión 0.5.1.
```
