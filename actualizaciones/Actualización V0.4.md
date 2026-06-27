# ACTUALIZACIÓN V0.4 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico  
**Fecha:** 2026-06-24  
**Objetivo de esta versión:** Cerrar definitivamente la fase de mecánicas/física/movimiento y dejar los parámetros base listos para producción artística. No se debe empezar arte final hasta que esta versión esté aprobada.

---

## CONTEXTO DE INVESTIGACIÓN: TOWERFALL Y SUS PRINCIPIOS DE DISEÑO

Investigación realizada antes de escribir este documento. Leerla antes de implementar.

### Resolución y arena
TowerFall usa resolución nativa **320×240 (4:3)**. En pantallas 16:9 rellena los laterales con arte decorativo, manteniendo el área de juego en 4:3 en el centro. El gameplay no ocurre en los paneles laterales — son puramente HUD y decoración. Esta es una decisión deliberada de diseño: el área de combate cuadrada garantiza que arriba/abajo y derecha/izquierda sean simétricas en alcance.

### Screen wrapping
El wrapping es una mecánica robada del arcade clásico (Pac-Man). Si un jugador sale por el borde derecho, entra por el izquierdo. **No es un teleport**: el personaje transiciona suavemente — cuando está a medio salir, la mitad de su cuerpo es visible en el borde derecho y la otra mitad en el borde izquierdo. Los proyectiles también hacen wrapping, lo que crea ataques "por la espalda" si disparas hacia el lado correcto.

### Diseño de mapas de TowerFall
- **Siempre simétricos izquierda-derecha.**
- **3-4 niveles de altura** con saltos entre ellos calibrados para que sean posibles pero no triviales.
- **Plataformas flotantes** accesibles combinando salto normal + ledge grab.
- **Paredes gruesas** en los laterales (no solo bordes) con salientes que crean superficies de wall jump.
- Los **huecos de wrapping** (izquierda-derecha, arriba-abajo) son decisiones de diseño explícitas, no espacios vacíos accidentales.
- El suelo siempre tiene al menos una capa de tiles de grosor. Las paredes laterales también.
- La proporción de espacio vacío vs. plataformas es deliberadamente amplia — hay mucho espacio abierto para que los proyectiles con gravedad tengan margen.

### Movimiento en TowerFall (referencia calibrada)
TowerFall tiene un feel de movimiento ágil pero con peso. Los saltos son medios — no cubren toda la pantalla, pero son suficientes para alcanzar cualquier plataforma combinando jump + wall jump + ledge grab. La clave es que nunca hay una sola forma de llegar a un lugar — siempre hay 2-3 rutas.

---

## TABLA DE PARÁMETROS FINALES (REFERENCIA RÁPIDA)

Al terminar esta actualización, los valores en `PlayerStats.tres` deben ser exactamente:

```
WALK_SPEED             = 78.0    px/s   (120 × 0.65)
JUMP_VELOCITY          = -127.0  px/s   (195 × 0.65, redondeado)
WALL_JUMP_PUSH         = 97.5    px/s   (150 × 0.65)
WALL_JUMP_VERTICAL     = -134.5  px/s   (207 × 0.65, redondeado)
GRAVITY                = 900.0   px/s²  (no cambia)
DASH_SPEED             = 240.0   px/s   (ya establecido en V0.3 p.7)
DASH_DURATION          = 0.12    s      (no cambia)
DASH_COOLDOWN          = 0.6     s      (no cambia)
DASH_INVULN_FRAMES     = 6       frames (no cambia)
COYOTE_TIME            = 0.08    s      (no cambia)
JUMP_BUFFER_TIME       = 0.1     s      (no cambia)

ARROW_INITIAL_SPEED    = 300.0   px/s   (375 × 0.80)
ARROW_CHARGED_SPEED    = 272.0   px/s   (340 × 0.80, redondeado)
ARROW_PROJ_GRAVITY     = 200.0   px/s²  (ajuste para parábola visual correcta con nueva velocidad)
ARROW_ATTRACTION_STR   = 300.0          (sin cambio desde V0.3)
ARROW_ATTRACTION_RADIUS= 40.0    px     (sin cambio desde V0.3)
```

Guardar estos valores como referencia. Cualquier ajuste fino posterior debe documentarse en CHANGELOG.

---

## 1. TROLL — ELIMINAR ATAQUE INVISIBLE Y HACER QUE PERSIGA AL JUGADOR
**Archivos:** `StoneTroll.gd`, `TrollStats.tres`

### 1a. Eliminar el ataque desconocido invisible
El Troll tiene un segundo ataque además del pedrusco que no es visible y golpea a distancia. Esto es probablemente el **golpe de puño** (`attack_punch`) cuyo hitbox está mal configurado y se está activando a distancia incorrecta, o bien un `Area2D` de daño que está siempre activo alrededor del Troll.

**Pasos:**
1. Abrir `StoneTroll.gd` y revisar todos los `Area2D` y `CollisionShape2D` del nodo.
2. Desactivar cualquier hitbox que no sea: (a) el hitbox de cuerpo del Troll (para recibir stomp), y (b) el hitbox del puño que solo debe activarse durante los frames 2-4 de `troll_attack_punch`.
3. Asegurarse de que el hitbox del puño (`punch_hitbox`) está en un nodo hijo que se activa con `$punch_hitbox.monitoring = true` solo en los frames correctos y `false` en todos los demás estados.
4. Si hay un `Area2D` de "daño por contacto" permanente (common mistake al implementar el MonsterBase): eliminarlo del Troll. El Troll solo daña al jugador durante sus ataques activos, nunca por contacto pasivo (principio de `is_attack_active` de V0.3 p.8).

### 1b. El Troll persigue al jugador
**Comportamiento actualizado:**
- El Troll ya no patrulla de un extremo al otro sin objetivo. Ahora sigue al jugador activamente.
- Si el jugador está en la misma plataforma → Troll camina hacia él.
- Si el jugador está en una plataforma diferente → Troll puede caer de su plataforma (ver punto 2) para seguirle.
- El Troll sigue sin saltar hacia plataformas superiores (no tiene capacidad de salto).
- **Velocidad de persecución:** `TROLL_CHASE_SPEED = 35.0 px/s` (más lento que el patrol del Goblin — el Troll es lento pero implacable).
- Si el jugador está fuera de `TROLL_DETECTION_RANGE = 150px`, el Troll patrulla lentamente su posición actual.

---

## 2. ELIMINAR BLOQUEO DE CAÍDA DE PLATAFORMA PARA MONSTRUOS
**Archivos:** `MonsterBase.gd`, `GoblinJumper.gd`, `StoneTroll.gd`, `ShadowBat.gd`, `SpecterArcher.gd`

**Problema:** Actualmente los monstruos tienen lógica que les impide caer de plataformas (probablemente un check de tipo `if near_edge: turn_around`).

**Fix:**
- En `MonsterBase.gd`, eliminar cualquier detección de borde del tipo:
  ```gdscript
  # ELIMINAR esto:
  var floor_ahead = _check_floor_ahead()
  if not floor_ahead:
      direction = -direction  # giro en el borde
  ```
- Los monstruos ahora siguen al jugador sin miedo a caer. Si el jugador está en una plataforma inferior, el monstruo cae hacia él.
- **Excepción:** El Espectro Arquero vuela y no tiene relevancia. El Murciélago Sombra también vuela.
- **El Slime (antiguo Goblin):** Con el nuevo comportamiento (camina, salta para atacar), el Slime naturalmente puede caer de plataformas si el jugador está debajo. Esto es correcto.
- **El Troll:** Ahora que persigue al jugador, puede caer de plataformas. Su peso hace que la caída sea dramática y peligrosa.

---

## 3. RESTAURAR DASH HACIA ARRIBA (MISMA DISTANCIA QUE LATERAL)
**Archivos:** `PlayerBase.gd`, `PlayerStats.tres`

En V0.3 p.7 se eliminó el dash vertical. Ahora se restaura el dash **hacia arriba únicamente** con la misma distancia que el lateral. El dash hacia abajo **no** se restaura.

**Implementación:**
- En `_get_dash_direction()` en `PlayerBase.gd`:
  - Si `aim_direction == Vector2.UP` → `dash_direction = Vector2.UP`. Permitido.
  - Si `aim_direction == Vector2.DOWN` → No ejecutar dash. Prohibido.
  - Si `aim_direction` es diagonal con componente hacia abajo (↙ ↘) → usar solo componente horizontal.
  - Si `aim_direction` es diagonal hacia arriba (↖ ↗) → permitir diagonal pero con la misma velocidad `DASH_SPEED`. El dash diagonal natural.
- El dash hacia arriba usa exactamente `DASH_SPEED = 240.0` y `DASH_DURATION = 0.12s`, resultando en 28.8px de distancia — igual que el lateral.
- Durante el dash hacia arriba, la **gravedad se desactiva** exactamente igual que en el dash lateral.
- La invulnerabilidad y el ghost trail se aplican igual.

**Nota de diseño:** El dash hacia arriba es útil para escapar de monstruos que caen y para llegar a ledge grabs con más control. Tiene el mismo cooldown que los otros dashes.

---

## 4. RENOMBRAR GOBLIN SALTARÍN → SLIME
**Archivos:** `GoblinJumper.gd`, `GoblinStats.tres`, `GoblinJumper.tscn`, todas las referencias

- Renombrar el archivo `GoblinJumper.gd` → `Slime.gd`
- Renombrar `GoblinStats.tres` → `SlimeStats.tres`
- Renombrar la escena `GoblinJumper.tscn` → `Slime.tscn`
- En el `Label` de nombre (implementado en V0.3 p.14): cambiar `"Goblin Saltarín"` → `"Slime"`
- Actualizar todas las referencias en `LevelBase.gd`, `Level01.gd`, `Level02.gd`, `Level03.gd` y cualquier archivo que instancie o haga referencia al nodo por nombre.
- Renombrar el grupo de Godot de `"goblins"` (si existe) a `"slimes"`.

---

## 5. REDUCIR DISTANCIA DE IMPULSO DE MUERTE UN 50%
**Archivos:** `Arrow.gd`, `PlayerBase.gd`, `MonsterBase.gd`

En V0.2 p.10 se implementó el impulso de muerte. La distancia actual es excesiva.

```gdscript
# Valor actual:
ARROW_DEATH_IMPULSE_FORCE = 220.0

# Nuevo valor (−50%):
ARROW_DEATH_IMPULSE_FORCE = 110.0

# Pedrusco del Troll:
ROCK_DEATH_IMPULSE_FORCE = 140.0 → 70.0
```

Con este valor, el cuerpo muerto se desplaza de forma visible y dramática, pero sin salir disparado fuera de la pantalla. A velocidad `110.0 px/s` con gravedad `900 px/s²`, el cuerpo recorre aproximadamente 30-40px horizontalmente antes de caer — suficiente para el efecto visual de TowerFall sin ser exagerado.

---

## 6. REDUCIR VELOCIDAD DE MOVIMIENTO Y SALTO UN 35% ADICIONAL
**Archivos:** `PlayerStats.tres`

Este es el ajuste más importante de la actualización. Los valores ya reducidos de versiones anteriores se reducen un **35% más**.

```
# Valores actuales (post V0.3) → nuevos valores (× 0.65):

WALK_SPEED         = 120.0  →  78.0   px/s
JUMP_VELOCITY      = -195.0 →  -127.0 px/s  (redondeado desde -126.75)
WALL_JUMP_PUSH     = 150.0  →  97.5   px/s
WALL_JUMP_VERTICAL = -207.0 →  -134.5 px/s  (redondeado desde -134.55)
```

**La gravedad NO cambia** (`900.0 px/s²`). Esto hace que con la menor velocidad de salto, el arco del salto sea más corto y más tenso — el personaje sube menos y cae más rápido proporcionalmente. Esto es deseable y se alinea con el feel de TowerFall.

**Verificar tras el cambio:**
1. Con `JUMP_VELOCITY = -127`: tiempo al pico = 127/900 = 0.141s. Altura máxima = 127²/(2×900) = **8.97px ≈ 9px** (≈ 1 tile de 10px de altura con tiles base, casi 2 tiles de 8px).
2. Verificar que con ledge grab el jugador puede alcanzar plataformas de 2 niveles.
3. Con wall jump zig-zag (impulso horizontal 97.5 + vertical -134.5) el jugador puede subir 2-3 plataformas de altura.
4. Ajustar las alturas de plataformas en los 3 niveles si es necesario (ver punto 12).

---

## 7. PROYECTILES — NINGUNO ATRAVIESA GEOMETRÍA DE ESCENARIO
**Archivos:** `ProjectileBase.gd`, `SpectralBolt.gd`, `Rock.gd`, `Arrow.gd`

**Problema:** El proyectil del Espectro Arquero atraviesa plataformas y suelos. **Ningún proyectil del juego debe atravesar ninguna geometría física** (paredes, suelo, techo, plataformas flotantes).

**Fix global en `ProjectileBase.gd`:**
- Todos los proyectiles usan `Area2D` para la detección de impacto. Añadir detección de colisión con geometría:
  ```gdscript
  # En _physics_process(delta):
  var collision = move_and_collide(velocity * delta)
  if collision:
      _on_hit_surface(collision)
  ```
- Alternativamente, si los proyectiles usan `RayCast2D` o `Area2D` con `body_entered`: asegurarse de que la `collision_mask` del proyectil incluye la capa de tiles del tileset (`Layer 1: world_geometry`).
- La capa `world_geometry` debe incluir: TileMap del suelo, TileMap de plataformas, paredes sólidas, techo. Todo geometry estático del nivel.
- `StaticBody2D` de plataformas y paredes deben estar en la `Layer 1`.
- Los proyectiles deben tener `collision_mask` que incluya `Layer 1`.

**Comportamiento al impactar geometría:**
- **Flechas y hachas:** Se clavan en la superficie (estado `STUCK_IN_SURFACE`). Ya implementado en V0.2.
- **Proyectil espectral:** Desaparece al impactar geometría (no se clava). VFX de disipación (3 frames de fade).
- **Pedrusco:** Desaparece al impactar el suelo después de su parábola (es un proyectil de área pequeña).

**Verificar en los 3 niveles** que ningún proyectil del Espectro Arquero ni del Troll atraviesa plataformas desde ningún ángulo.

---

## 8. ESPECTRO ARQUERO — COOLDOWN ×2, RANGO −50%
**Archivos:** `SpecterArcher.gd`, `SpecterStats.tres`

```
# Valores actuales (post V0.3):
SPECTER_ATTACK_COOLDOWN    = 2.5s
SPECTER_DETECTION_RANGE    = 150px (estimado)

# Nuevos valores:
SPECTER_ATTACK_COOLDOWN    = 5.0s   (×2)
SPECTER_DETECTION_RANGE    = 75px   (−50%)
```

**Comportamiento resultante:** El Espectro solo dispara cuando el jugador está a menos de 75px (≈ 5 tiles). A esa distancia, el proyectil sigue siendo una amenaza real pero el jugador tiene tiempo para reaccionar. La cadencia de 5s entre disparos hace que cada proyectil sea un evento significativo, no spam.

**Verificar:** Con rango de 75px, el Espectro debe reposicionarse activamente para entrar en rango de disparo. Esto le da más comportamiento de "acecho" — se acerca, dispara, retrocede.

---

## 9. REDUCIR VELOCIDAD DE FLECHAS UN 20% ADICIONAL
**Archivos:** `ArrowStats.tres`

```
# Valores actuales (post V0.3):
ARROW_INITIAL_SPEED  = 375.0
ARROW_CHARGED_SPEED  = 340.0

# Nuevos valores (× 0.80):
ARROW_INITIAL_SPEED  = 300.0
ARROW_CHARGED_SPEED  = 272.0   (redondeado desde 272)

# Ajuste de gravedad de flecha para parábola correcta con nueva velocidad:
ARROW_PROJ_GRAVITY   = 200.0   (reducido desde 250 para compensar la menor velocidad inicial)
```

**Calibración de la parábola resultante:**
Con velocidad 300 px/s horizontal y gravedad 200 px/s²:
- Tiempo para cruzar el área de juego (240px de ancho): 0.8s
- Caída en ese tiempo: ½ × 200 × 0.8² = 64px
- Una flecha disparada horizontal desde el centro del área caerá unos 64px antes de llegar al borde opuesto. Esto es equivalente a unas 6 tiles de caída — una parábola visible pero no tan agresiva que haga inútil el disparo horizontal a media distancia.

Verificar esta parábola visualmente y ajustar `ARROW_PROJ_GRAVITY` si hace falta. El objetivo es que el juego se sienta igual que TowerFall: las flechas tienen arco visible pero son útiles hasta media pantalla sin necesidad de compensar demasiado.

---

## 10. WALL JUMP ZIG-ZAG — LÓGICA POR PARED (SIN TOCAR SUELO)
**Archivos:** `PlayerBase.gd`

**Comportamiento deseado (idéntico al TowerFall):** El jugador puede hacer zig-zag entre la pared izquierda y la pared derecha indefinidamente sin tocar el suelo, SIEMPRE QUE alterne entre paredes. Lo que NO puede hacer es usar la misma pared dos veces seguidas.

**Reemplazar completamente la lógica de `_wall_jump_used`** con el siguiente sistema:

```gdscript
# En PlayerBase.gd, reemplazar _wall_jump_used por:
enum WallSide { NONE, LEFT, RIGHT }
var _last_wall_jumped: WallSide = WallSide.NONE

func _try_wall_jump_zigzag():
    if not is_on_wall():
        return false
    
    var current_wall = _get_current_wall_side()  # devuelve LEFT o RIGHT
    
    # Bloquear si es la misma pared que la última usada:
    if current_wall == _last_wall_jumped:
        return false
    
    # Ejecutar zig-zag:
    _last_wall_jumped = current_wall
    velocity.x = wall_normal.x * WALL_JUMP_PUSH   # impulso en dirección opuesta a la pared
    velocity.y = JUMP_VELOCITY
    return true

func _get_current_wall_side() -> WallSide:
    # get_wall_normal() devuelve Vector2(1,0) si la pared está a la izquierda del jugador
    # y Vector2(-1,0) si está a la derecha
    var normal = get_wall_normal()
    if normal.x > 0:
        return WallSide.LEFT   # pared a la izquierda
    elif normal.x < 0:
        return WallSide.RIGHT  # pared a la derecha
    return WallSide.NONE

func _on_landed():
    _last_wall_jumped = WallSide.NONE  # reset al aterrizar
    _wall_hang_used = false
```

**Con esta lógica:**
- Izquierda → Derecha → Izquierda → ... funciona indefinidamente (zig-zag real).
- Izquierda → Izquierda: bloqueado.
- Tocar suelo: resetea, puede volver a usar cualquier pared.

**El enganche vertical** (`_wall_hang_used`) mantiene su lógica separada del V0.3: 1 por vuelo, resetea al aterrizar. No interactúa con `_last_wall_jumped`.

**El wrapping de pantalla** (punto 11) puede crear situaciones donde el jugador sale por un lado y entra por el otro. En ese caso, `_last_wall_jumped` debe resetearse al hacer wrapping, ya que técnicamente el jugador no está tocando ninguna pared.

---

## 11. NUEVA MECÁNICA: SCREEN WRAPPING (CONTINUACIÓN DE PANTALLA)
**Archivos:** `PlayerBase.gd`, `MonsterBase.gd`, `ProjectileBase.gd`, `Arrow.gd`, `LevelBase.gd`, nuevo componente `ScreenWrapper.gd`

### Concepto fundamental
Esta es la mecánica más compleja de esta actualización. Leer completamente antes de implementar.

**No es un teleport.** Cuando un jugador (o proyectil, o monstruo) llega al borde de la pantalla donde hay un hueco de wrapping, continúa moviéndose de forma continua y aparece en el lado opuesto. A mitad de la transición, el cuerpo está a caballo entre los dos bordes: la mitad visible en el borde derecho y la otra mitad visible en el borde izquierdo.

Esto es idéntico al wrapping de TowerFall Ascension y al de juegos arcade clásicos como Pac-Man.

**Los huecos de wrapping son parte del diseño del nivel, no de todas las paredes.** Un mapa puede tener un hueco de wrapping en el lado izquierdo y derecho a media altura (por ejemplo), pero tener paredes sólidas arriba y abajo. Solo donde el diseño del nivel deja un hueco hay wrapping.

### Componente `ScreenWrapper.gd` (Autoload o nodo en cada nivel)
```gdscript
class_name ScreenWrapper

# El nivel define sus zonas de wrapping:
var wrap_zones: Array[WrapZone] = []

class WrapZone:
    var axis: String          # "horizontal" o "vertical"
    var entry_range: Vector2  # (min_pos, max_pos) en el eje perpendicular
    # Ejemplo: hueco derecho de y=40 a y=120:
    #   axis = "horizontal", entry_range = Vector2(40, 120)
    # El lado opuesto (izquierdo) tiene el mismo entry_range

# En el área de juego de 240×180px con offset de 40px izquierda:
# Coordenadas del área: x ∈ [40, 280], y ∈ [0, 180]
const ARENA_LEFT   = 40.0
const ARENA_RIGHT  = 280.0
const ARENA_TOP    = 0.0
const ARENA_BOTTOM = 180.0
```

### Implementación del wrapping visual continuo

El truco para el efecto "medio cuerpo en cada lado" es renderizar **dos instancias del sprite** cuando el objeto está cerca del borde:

```gdscript
# En PlayerBase.gd (y MonsterBase, ProjectileBase):
# Añadir un nodo Sprite2D hijo llamado "WrapGhost"
@onready var wrap_ghost: Sprite2D = $WrapGhost

func _update_wrap_ghost():
    var arena_width  = ScreenWrapper.ARENA_RIGHT - ScreenWrapper.ARENA_LEFT
    var arena_height = ScreenWrapper.ARENA_BOTTOM - ScreenWrapper.ARENA_TOP
    
    wrap_ghost.visible = false
    
    for zone in ScreenWrapper.wrap_zones:
        if zone.axis == "horizontal":
            # Distancia al borde derecho/izquierdo:
            var dist_right = ScreenWrapper.ARENA_RIGHT - global_position.x
            var dist_left  = global_position.x - ScreenWrapper.ARENA_LEFT
            
            # ¿Estamos en el rango Y de esta zona?
            if global_position.y < zone.entry_range.x or global_position.y > zone.entry_range.y:
                continue
            
            if dist_right < sprite_half_width:
                # Mitad del cuerpo asomando por el derecho → mostrar ghost en el izquierdo
                wrap_ghost.visible = true
                wrap_ghost.global_position = Vector2(
                    global_position.x - arena_width,
                    global_position.y
                )
            elif dist_left < sprite_half_width:
                # Mitad del cuerpo asomando por el izquierdo → ghost en el derecho
                wrap_ghost.visible = true
                wrap_ghost.global_position = Vector2(
                    global_position.x + arena_width,
                    global_position.y
                )

func _apply_wrap_position():
    # Cuando el CENTRO del objeto cruza el borde: reposicionar
    for zone in ScreenWrapper.wrap_zones:
        if zone.axis == "horizontal":
            if global_position.y < zone.entry_range.x or global_position.y > zone.entry_range.y:
                continue
            if global_position.x > ScreenWrapper.ARENA_RIGHT:
                global_position.x -= (ScreenWrapper.ARENA_RIGHT - ScreenWrapper.ARENA_LEFT)
            elif global_position.x < ScreenWrapper.ARENA_LEFT:
                global_position.x += (ScreenWrapper.ARENA_RIGHT - ScreenWrapper.ARENA_LEFT)
        
        # (lógica análoga para axis == "vertical")
```

Llamar a `_apply_wrap_position()` y `_update_wrap_ghost()` en cada `_physics_process()`.

### Wrapping de proyectiles
Las flechas y proyectiles hacen wrapping exactamente igual. El `WrapGhost` de la flecha también debe rotar correctamente (mismo ángulo que el sprite principal). La flecha que aparece por el otro lado continúa su trayectoria con la misma velocidad y gravedad — no se "reinicia".

### Regla para el flag `_last_wall_jumped` y wrapping
Si el jugador hace wrapping horizontal, resetear `_last_wall_jumped = WallSide.NONE`. El jugador no está tocando una pared — está pasando por un hueco.

### Configuración de zonas de wrapping por nivel
Cada nivel define sus `WrapZone[]` en su script de nivel:

**Nivel 1 — Bosque Antiguo:** Wrapping horizontal en ambos lados a nivel del suelo (y ∈ [150, 180]). Solo el hueco del suelo hace wrapping. Los lados tienen paredes sólidas en la parte superior.

**Nivel 2 — Ruinas Voladoras:** Wrapping horizontal en ambos lados (toda la altura, y ∈ [0, 180]) — las paredes laterales son solo plataformas pequeñas, el resto son huecos. Wrapping vertical en el centro (hueco inferior, x ∈ [80, 160]).

**Nivel 3 — Torre del Caos:** Wrapping vertical en ambas mitades del suelo y techo (x ∈ [40, 120] y x ∈ [120, 200]). Paredes sólidas en los laterales.

---

## 12. REDISEÑO DE MAPAS — ESTRUCTURA TIPO TOWERFALL

### Marco técnico del área de juego

**CAMBIO CRÍTICO DE RESOLUCIÓN Y LAYOUT:**

TowerFall usa 4:3 para el área de juego dentro de una pantalla 16:9. Replicar esto en Niide:

```
Pantalla completa: 320×180 px (16:9, sin cambios)

Layout del frame:
┌──────────┬────────────────────────┬──────────┐
│          │                        │          │
│  HUD P1  │    ÁREA DE JUEGO       │  HUD P2  │
│  40×180  │      240×180           │  40×180  │
│          │                        │          │
└──────────┴────────────────────────┴──────────┘
  x: 0-39        x: 40-279               x: 280-319
```

- **Área de juego:** 240×180px. Coordenadas mundiales: `x ∈ [40, 280]`, `y ∈ [0, 180]`.
- **Panel HUD izquierdo (P1):** 40px de ancho. Muestra: vidas P1, contador proyectiles si aplica.
- **Panel HUD derecho (P2):** 40px de ancho. Muestra: vidas P2, contador proyectiles.
- **Tile base:** 10×10px.
- **Grid de juego:** 24 tiles ancho × 18 tiles alto.

Ajustar en `project.godot` o en el script de `LevelBase.gd` el offset del viewport/cámara para que el área de juego empiece en x=40. Los paneles HUD son nodos de UI fuera del viewport de juego o superpuestos con CanvasLayer.

### Principios de diseño de todos los mapas

1. **Simetría izquierda-derecha** obligatoria.
2. **3 capas de altura:**
   - Capa baja: suelo + plataformas bajas (y ∈ [140, 180])
   - Capa media: plataformas medias (y ∈ [80, 130])
   - Capa alta: plataformas altas (y ∈ [20, 70])
3. **Paredes laterales con grosor:** Las paredes de los bordes deben tener al menos 2-3 tiles de grosor para crear superficies de wall jump con recorrido vertical.
4. **Plataformas flotantes:** Cada plataforma flotante tiene entre 3-6 tiles de largo. Las más cortas están en la capa alta (más difíciles de aterrizar).
5. **Alcanzabilidad con los parámetros actuales:**
   - Salto normal desde el suelo alcanza ~9px de altura ≈ 1 tile.
   - Con ledge grab: puede "subir" hasta plataformas a ~18px (2 tiles) haciendo grab + jump desde el borde.
   - Wall jump vertical: alcanza ~13.5px adicionales (WALL_JUMP_VERTICAL/GRAVITY en altura). Subir paredes altas requiere 2-3 enganches.
   - **IMPORTANTE:** Las plataformas de capa media deben estar a 16-20px del suelo (alcanzables con ledge grab desde abajo). Las de capa alta, a 30-40px del suelo (requieren wall jump o llegar por plataformas intermedias).
6. **Plataformas pass-through:** Las plataformas flotantes permiten pasar a través desde abajo. El suelo y las paredes son sólidos. (Revertir el cambio de V0.2 p.1 para las plataformas flotantes — estas SÍ son pass-through, pero el suelo principal no.)
   - **NOTA:** Esto revierte el punto 1 de V0.2. Las plataformas flotantes en TowerFall siempre son pass-through desde abajo. El problema original era que el SUELO también era pass-through — solo arreglar el suelo, no las plataformas flotantes.

### NIVEL 1 — BOSQUE ANTIGUO (Rediseño completo)

**Dimensiones del área:** 240×180px, grid 24×18 tiles de 10px.

```
Representación ASCII del layout (cada carácter = 1 tile de 10px):
Columnas: 1-24 (área de juego). Filas: 1-18 (arriba=1, abajo=18).

Fila  1: ████████████████████████   ← techo sólido
Fila  2: █                      █
Fila  3: █                      █
Fila  4: █         ████         █   ← plataforma alta central (4 tiles)
Fila  5: █                      █
Fila  6: █  ████           ████ █   ← plataformas altas laterales
Fila  7: █                      █
Fila  8: █                      █
Fila  9: █     ██         ██    █   ← plataformas medias (2 tiles)
Fila 10: █                      █
Fila 11: █                      █
Fila 12: ████                ████   ← "hombros" de las paredes laterales
Fila 13: █   ████████████████   █   ← plataforma media principal
Fila 14: █                      █
Fila 15: █                      █
Fila 16: █  █              █    █   ← pilares bajos
Fila 17: ████              ████     ← paredes bajas laterales
Fila 18: ████████████████████████   ← suelo sólido
           ^              ^
           Paredes laterales gruesas (2 tiles)
           Hueco de wrapping en fila 18, x ∈ [6,20] (suelo central)
```

**Paredes laterales:** Filas 1-18, columnas 1-2 (izquierda) y 23-24 (derecha). Grosor 2 tiles. Crean superficie de wall jump.

**Zonas de wrapping:** Hueco en el suelo (fila 18) entre columnas 5-20. Los jugadores que caen por ahí aparecen por el techo (fila 1) en la misma posición horizontal.

**Plataformas flotantes (pass-through desde abajo):**
- Plataforma alta central: filas 4, columnas 11-14 (4 tiles de largo)
- Plataformas altas laterales: filas 6, columnas 3-6 y 19-22 (4 tiles)
- Plataformas medias pequeñas: filas 9, columnas 6-7 y 18-19 (2 tiles)
- Plataforma media principal: filas 13, columnas 4-21 (18 tiles — ancha, accesible desde el suelo con ledge grab)

**Hombros de pared (fila 12):** Los tiles de la fila 12 en columnas 1-4 y 21-24 crean un saliente horizontal en la pared — un ledge para agarrarse.

### NIVEL 2 — RUINAS VOLADORAS (Rediseño completo)

**Concepto:** Plataformas suspendidas en el vacío. Sin suelo central. Wrapping en los laterales (toda la altura) y en el centro del suelo/techo.

```
Fila  1: ██                    ██   ← techo parcial (laterales)
Fila  2: █                      █
Fila  3: █    ████      ████    █   ← plataformas altas
Fila  4: █                      █
Fila  5: █                      █
Fila  6:      ██          ██         ← plataformas pequeñas sin pared
Fila  7:                             ← hueco (wrapping lateral activo aquí)
Fila  8:    ██████    ██████          ← plataformas medias principales
Fila  9:                             ← hueco
Fila 10:                             ← hueco
Fila 11:      ████    ████           ← plataformas medias bajas
Fila 12:                             ← hueco
Fila 13: █                      █
Fila 14: █    ████      ████    █   ← plataformas bajas ancladas a pared
Fila 15: █                      █
Fila 16: █                      █
Fila 17: ██                    ██   ← suelo parcial (laterales)
Fila 18:      [VACÍO CENTRAL]        ← caída mortal / wrapping vertical
```

**Paredes laterales:** Solo presentes en filas 1-4 y 13-17 (arriba y abajo). El centro de las paredes (filas 5-12) son huecos de wrapping horizontal. Los jugadores que salen por el hueco del lado derecho entran por el izquierdo en la misma posición Y (y viceversa).

**Caída mortal / wrapping vertical:** El hueco del suelo en el centro (columnas 5-20, fila 18) conecta con el techo (fila 1). Caer por ahí apareces cayendo desde arriba.

### NIVEL 3 — TORRE DEL CAOS (Rediseño completo)

**Concepto:** Diseño vertical con múltiples niveles. Wrapping top-bottom en los dos laterales del suelo.

```
Fila  1: ████████████████████████   ← techo sólido
Fila  2: █  ████          ████  █
Fila  3: █                      █   ← zona alta abierta
Fila  4: █                      █
Fila  5: ██████              ██████  ← plataformas altas que tocan pared
Fila  6: █                      █
Fila  7: █    ████      ████    █   ← plataformas medias-altas
Fila  8: █                      █
Fila  9: █                      █
Fila 10: █  ██████    ██████    █   ← plataformas medias centrales
Fila 11: █                      █
Fila 12: █                      █
Fila 13: ████                ████   ← plataformas-pared medias bajas
Fila 14: █                      █
Fila 15: █    ████      ████    █   ← plataformas bajas
Fila 16: █                      █
Fila 17: ████████████████████████   ← suelo sólido
Fila 18: [WRAPPING] ██████ [WRAPPING] ← suelo con huecos en laterales
```

**Wrapping:** Huecos en el suelo en columnas 1-5 y 20-24. Los jugadores que caen por esos huecos aparecen cayendo desde el techo en la misma posición X.

---

## 13. IMPLEMENTACIÓN TÉCNICA DEL ÁREA DE JUEGO 240×180 CON PANELES HUD

**Archivos afectados:** `project.godot`, `HUD.tscn`, `MainCamera.gd` (o equivalente), todos los niveles

### Ajuste del viewport y cámara:

En Godot 4, usar un `SubViewport` de 240×180 para el área de juego, o alternativamente configurar el offset de cámara para que el origen del mundo sea `x=40`:

```gdscript
# Opción A: Offset de cámara
# En LevelBase.gd o la cámara del nivel:
$Camera2D.offset = Vector2(-40, 0)  # desplaza la vista 40px a la derecha
# El mundo empieza en x=0 pero se renderiza en x=40 en pantalla

# Opción B (recomendada): Usar CanvasLayer para los paneles HUD
# El HUD (CanvasLayer layer=1) tiene dos paneles:
#   Panel izquierdo: posición (0,0), tamaño 40×180
#   Panel derecho:  posición (280,0), tamaño 40×180
# El juego se renderiza en la resolución normal 320×180
# Los tiles y objetos del nivel solo ocupan x ∈ [40, 280]
```

**Opción B es más simple** y no requiere cambiar nada del viewport. Solo asegurarse de que todos los niveles tienen tiles y objetos posicionados en x ∈ [40, 280].

### Contenido de los paneles HUD:
- **Panel izquierdo (P1):**
  - Arriba: 4 iconos de vida (8×8px cada uno, apilados verticalmente)
  - Abajo: indicador de ronda ganada (en Versus)
- **Panel derecho (P2):** Espejo del izquierdo.
- **Fondo de los paneles:** Color oscuro semitransparente o arte decorativo de la temática del nivel. No compiten visualmente con el área de juego.

---

## TABLA DE VERIFICACIÓN FINAL

Antes de declarar esta actualización completa, verificar cada punto:

| Nº | Verificación | Método |
|---|---|---|
| 1 | Troll no tiene ataque invisible. Camina hacia el jugador. | Prueba manual en nivel 1 |
| 2 | Slime puede caer de plataformas si el jugador está debajo | Prueba manual |
| 3 | Dash arriba funciona. Dash abajo no existe. Distancia = dash lateral | Prueba manual |
| 4 | "Goblin Saltarín" ya no aparece en ningún nombre ni string en el proyecto | Grep en todos los .gd y .tscn |
| 5 | Impulso de muerte visible pero no exagerado (~30-40px de desplazamiento) | Prueba manual |
| 6 | `WALK_SPEED = 78`, `JUMP_VELOCITY = -127` en `PlayerStats.tres` | Leer el archivo |
| 7 | Proyectil espectral impacta en plataforma y desaparece | Prueba manual en nivel 2 |
| 8 | Espectro no dispara a >75px. Cooldown mínimo 5s entre disparos | Prueba con debug overlay |
| 9 | `ARROW_INITIAL_SPEED = 300` en `ArrowStats.tres` | Leer el archivo |
| 10 | Zig-zag: izq→der→izq funciona. Izq→izq bloqueado. Reset al tocar suelo | Prueba manual en pared |
| 11 | Wrapping: cuerpo visible en ambos bordes durante transición | Visual test en nivel 1 |
| 11 | Flecha disparada a la derecha aparece por la izquierda | Visual test |
| 12 | Nivel 1 cargable y jugable. Plataformas alcanzables con jump+ledge | Prueba completa |
| 12 | Nivel 2 cargable y jugable. Wrapping lateral funciona | Prueba completa |
| 12 | Nivel 3 cargable y jugable. Wrapping vertical funciona | Prueba completa |
| 13 | HUD de 40px visible a ambos lados. Área de juego en 240×180 | Visual check |
| — | `CHANGELOG.md` actualizado con versión `0.5.0` | Leer el archivo |
| — | Bugs cerrados actualizados en `BUGS.md` | Leer el archivo |

---

## ORDEN DE IMPLEMENTACIÓN

```
Bloque A — Parámetros (sin código nuevo, solo valores):
  → Punto 6  (velocidad -35%)
  → Punto 9  (flechas -20%)
  → Punto 5  (impulso muerte -50%)
  → Punto 8  (Espectro cooldown/rango)

Bloque B — Fixes de comportamiento:
  → Punto 4  (renombrar Slime)
  → Punto 1  (Troll: quitar ataque, perseguir)
  → Punto 2  (quitar bloqueo de caída de monstruos)
  → Punto 7  (proyectiles no atraviesan geometría)

Bloque C — Mecánicas de movimiento:
  → Punto 10 (zig-zag por pared, sin tocar suelo)
  → Punto 3  (dash hacia arriba restaurado)

Bloque D — Nueva mecánica mayor:
  → Punto 11 (screen wrapping — implementar ScreenWrapper.gd, luego integrar en PlayerBase, MonsterBase, ProjectileBase)

Bloque E — Rediseño de mapas:
  → Punto 13 (layout HUD + área de juego 240px)
  → Punto 12 (rediseñar los 3 niveles con nuevos layouts)
  → Verificar alcanzabilidad de plataformas con los parámetros del Bloque A
```

**No empezar el Bloque E hasta que el Bloque D esté funcionando**, porque el wrapping afecta directamente al diseño de los bordes de los mapas.
