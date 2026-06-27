# ACTUALIZACIÓN V0.5 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico  
**Fecha:** 2026-06-24  
**Objetivo:** Correcciones de mecánicas y comportamientos después de pruebas de la V0.4. Cada punto tiene requisitos de verificación explícitos — no marcar como completado hasta que la verificación pase.

---

## REGLA UNIVERSAL DE ESTA ACTUALIZACIÓN (LEER PRIMERO)

> **NINGÚN jugador, monstruo, proyectil ni entidad del juego puede atravesar ningún componente sólido del escenario: paredes, suelo, techo, plataformas flotantes.** Esta regla no tiene excepciones. Si una entidad la viola, es un bug crítico.

Esta regla ya existe en el DOCUMENTO_MAESTRO y en el punto 7 de V0.4, pero se repite aquí como recordatorio. Antes de implementar cualquier otro punto, verificar que esta regla se cumple. Si durante la implementación de algún punto se detecta que alguna entidad atraviesa geometría, detener y corregir antes de continuar.

---

## 1. ALTURA DE SALTO ×2

**Archivos:** `PlayerStats.tres`

**Cambio:**
```
# Valor actual (post V0.4):
JUMP_VELOCITY      = -127.0  px/s
WALL_JUMP_VERTICAL = -134.5  px/s

# Nuevos valores (×2):
JUMP_VELOCITY      = -254.0  px/s
WALL_JUMP_VERTICAL = -269.0  px/s
```

**Altura máxima resultante** con `GRAVITY = 900 px/s²`:
- `h = v² / (2g) = 254² / (2 × 900) = 64516 / 1800 ≈ 35.8px`
- El jugador sube aproximadamente **36px = 3.6 tiles** en un salto desde el suelo.

**Verificación obligatoria:**
1. Con el nuevo salto, revisar los 3 niveles y confirmar que ninguna plataforma que debería ser inalcanzable se vuelve trivial.
2. Ajustar alturas de plataformas en los niveles si el diseño queda desequilibrado (documentar los cambios en el CHANGELOG).
3. Confirmar que el ledge grab sigue siendo necesario para algunas plataformas altas, no todo es alcanzable con salto directo.

---

## 2. ELIMINAR DASH DIAGONAL COMPLETAMENTE

**Archivos:** `PlayerBase.gd`

**Regla nueva:** El dash solo puede ser en los 4 ejes cardinales: izquierda, derecha, arriba, abajo. **Nunca en diagonal.**

En V0.3 p.7 se eliminó el dash vertical hacia abajo pero se permitió el diagonal. En V0.4 p.3 se restauró el dash hacia arriba. Ahora se elimina cualquier componente diagonal del dash.

**Implementación — reemplazar `_get_dash_direction()` completamente:**
```gdscript
func _get_dash_direction() -> Vector2:
    # Solo 4 direcciones posibles. El eje con mayor magnitud gana.
    var aim = aim_direction  # Vector2 con componentes en [-1, 0, 1]
    
    # Si ambos ejes tienen la misma magnitud (diagonal pura), priorizar horizontal:
    if abs(aim.x) >= abs(aim.y):
        # Dash horizontal
        if aim.x > 0:
            return Vector2.RIGHT
        elif aim.x < 0:
            return Vector2.LEFT
        else:
            return Vector2(sign(facing_direction), 0)  # usa la dirección en que mira
    else:
        # Dash vertical — solo hacia arriba
        if aim.y < 0:
            return Vector2.UP
        else:
            # Intento de dash hacia abajo: NO ejecutar
            return Vector2.ZERO  # Vector2.ZERO indica "no hay dash válido"
    
# En el método que llama a _get_dash_direction():
func _try_dash():
    var dir = _get_dash_direction()
    if dir == Vector2.ZERO:
        return  # input inválido, no hacer nada
    _execute_dash(dir)
```

**Verificar:** Probar las 8 direcciones de input. Solo 3 deben producir dash (izquierda, derecha, arriba). Las diagonales deben resolverse al eje dominante. Abajo no debe producir nada.

---

## 3. REDUCIR VELOCIDAD DE CAÍDA AL ATRAVESAR SUELO/TECHO (WRAPPING VERTICAL) — SOLO PARA ATERRIZAJES DE WRAPPING

**Archivos:** `PlayerBase.gd`, `MonsterBase.gd`, `ScreenWrapper.gd`

**Problema:** Cuando un jugador o monstruo cae por el hueco del suelo y reaparece por el techo, llega con la velocidad de caída acumulada (que puede ser muy alta), lo que hace que el aterrizaje sea desorientador e injusto.

**Solución:** Al ejecutar un wrapping vertical (suelo→techo o techo→suelo), reducir `velocity.y` a la mitad en el momento de la reposición.

**Implementación en `ScreenWrapper.gd` / `_apply_wrap_position()`:**
```gdscript
func _apply_wrap_position_and_velocity(entity: Node2D):
    for zone in wrap_zones:
        if zone.axis == "vertical":
            # Rango X del hueco en el suelo/techo:
            if entity.global_position.x < zone.entry_range.x or \
               entity.global_position.x > zone.entry_range.y:
                continue
            
            var arena_height = ARENA_BOTTOM - ARENA_TOP
            
            if entity.global_position.y > ARENA_BOTTOM:
                # Cayó por el suelo → aparece por el techo
                entity.global_position.y -= arena_height
                if entity.has_method("_apply_wrap_velocity_damping"):
                    entity._apply_wrap_velocity_damping("vertical")
                    
            elif entity.global_position.y < ARENA_TOP:
                # Salió por el techo → aparece por el suelo
                entity.global_position.y += arena_height
                if entity.has_method("_apply_wrap_velocity_damping"):
                    entity._apply_wrap_velocity_damping("vertical")
```

**En `PlayerBase.gd` y `MonsterBase.gd`, implementar:**
```gdscript
func _apply_wrap_velocity_damping(axis: String):
    if axis == "vertical":
        velocity.y *= 0.5   # reducir velocidad vertical a la mitad al hacer wrapping
    elif axis == "horizontal":
        velocity.x *= 0.5   # opcional: también para wrapping horizontal si hay problemas
```

**Esta reducción aplica a:**
- Jugadores (ambos)
- Monstruos (Slime, Troll)
- El Murciélago y el Espectro (aunque vuelan, el wrapping les puede afectar)

**Esta reducción NO aplica a:**
- Proyectiles (flechas, proyectil espectral, pedrusco): los proyectiles mantienen su velocidad completa al hacer wrapping para que el ataque "por la espalda" sea efectivo.

---

## 4. REDUCIR VELOCIDAD DEL SLIME A LA MITAD

**Archivos:** `SlimeStats.tres`, `Slime.gd`

**Cambio en `SlimeStats.tres`:**
```
# Valores actuales (establecidos en V0.3 p.15):
SLIME_PATROL_SPEED = 30.0  px/s
SLIME_CHASE_SPEED  = 60.0  px/s
SLIME_JUMP_FORCE_Y = -200.0 px/s  (velocidad vertical del salto de ataque)

# Nuevos valores (÷2):
SLIME_PATROL_SPEED = 15.0  px/s
SLIME_CHASE_SPEED  = 30.0  px/s
SLIME_JUMP_FORCE_Y = -100.0 px/s
```

**Nota sobre el salto de ataque:** Con `JUMP_FORCE_Y = -100` y `GRAVITY = 900`:
- Altura máxima del salto del Slime: 100²/(2×900) ≈ 5.5px
- El Slime es ahora un enemigo muy lento y de baja altura — fácil individualmente, peligroso en grupo.

**Verificar:** El Slime debe ser claramente más lento que el jugador caminando. El jugador camina a 78 px/s; el Slime en chase a 30 px/s — el jugador puede alejarse fácilmente. El peligro del Slime viene de que hay varios en pantalla, no de su velocidad.

---

## 5. STOMP — REIMPLEMENTACIÓN ROBUSTA Y UNIVERSAL

**Archivos:** `PlayerBase.gd`, `MonsterBase.gd`, `Slime.gd`, `StoneTroll.gd`, `ShadowBat.gd`, `SpecterArcher.gd`

El stomp es una mecánica fundamental y actualmente falla en algunos casos. Esta sección reemplaza completamente la implementación existente con una nueva que sea determinista e inequívoca.

### Definición exacta del stomp

**Un stomp ocurre cuando:**
1. Una entidad atacante (jugador A) cae sobre una entidad objetivo (jugador B o monstruo).
2. La entidad atacante tiene `velocity.y > 0` (está cayendo, no subiendo).
3. El borde inferior del atacante toca el borde superior del objetivo.
4. La entidad atacante NO está en estado `DASH` (el dash esquiva tanto dar como recibir stomp).

**El resultado siempre es:**
- El objetivo muere instantáneamente.
- El atacante recibe un rebote hacia arriba: `velocity.y = STOMP_BOUNCE = -180.0 px/s`.
- Si el jugador mantiene pulsado el botón de salto durante el rebote: el rebote se amplifica a `STOMP_BOUNCE_HELD = -254.0 px/s` (igual que el salto normal), permitiendo encadenar stompeos.

### Implementación — `StompDetector` (nodo hijo de cada entidad)

En lugar de depender del `CharacterBody2D.move_and_slide()` o de `Area2D.body_entered()`, usar un **`RayCast2D` dedicado** para el stomp. Esto es más robusto porque funciona independientemente de la velocidad o el framerate.

**Estructura de nodos de cada jugador y monstruo:**
```
PlayerBase (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D      ← hitbox de cuerpo (física)
├── StompRayCast (RayCast2D)    ← detecta entidades stompables debajo
└── StompHitbox (Area2D)        ← es detectada por los raycasts de otros
```

**Configuración del `StompRayCast`:**
- Posición: parte inferior del personaje (offset `Vector2(0, half_height)`)
- Dirección: `Vector2(0, 4)` — apunta 4px hacia abajo
- Target layers: capa `"stompable"` (ver abajo)
- `enabled = true` siempre

**Capa de colisión `"stompable"` (Layer 5):**
- Todos los jugadores y monstruos añaden su `StompHitbox` a la capa 5.
- El `StompRayCast` tiene `collision_mask` que incluye Layer 5.
- El `StompHitbox` es un `Area2D` con `CollisionShape2D` que cubre la parte superior del sprite (los 4-5px superiores).

**Lógica del stomp en `_physics_process(delta)`:**
```gdscript
func _check_stomp():
    if state == PlayerState.DASH:
        return  # el dash hace inmune al stomp (tanto dar como recibir)
    
    if velocity.y <= 0:
        return  # solo puede hacer stomp mientras cae (velocity.y positiva = bajando)
    
    stomp_raycast.force_raycast_update()
    
    if stomp_raycast.is_colliding():
        var hit = stomp_raycast.get_collider()
        
        # Verificar que el objeto golpeado es stompable (tiene el método die()):
        if not hit.has_method("receive_stomp"):
            return
        
        # Verificar que no es uno mismo:
        if hit == self:
            return
        
        # Ejecutar el stomp:
        hit.receive_stomp(self)
        _apply_stomp_bounce()

func _apply_stomp_bounce():
    var held_jump = Input.is_action_pressed("jump_p" + str(player_index))
    velocity.y = STOMP_BOUNCE_HELD if held_jump else STOMP_BOUNCE
```

**Implementar `receive_stomp()` en `MonsterBase.gd` y `PlayerBase.gd`:**
```gdscript
# MonsterBase.gd:
func receive_stomp(attacker: Node):
    die()  # muerte inmediata, sin importar el estado del monstruo

# PlayerBase.gd:
func receive_stomp(attacker: Node):
    if state == PlayerState.DASH:
        return  # el dash también protege de recibir stomp
    if is_invincible:
        return  # invulnerabilidad post-spawn
    die()
```

### Casos especiales verificados

| Situación | Resultado correcto |
|---|---|
| Jugador cae sobre Slime en el aire | Slime muere, jugador rebota |
| Jugador cae sobre Slime en el suelo | Slime muere, jugador rebota |
| Jugador cae sobre Troll | Troll muere, jugador rebota |
| Jugador cae sobre Murciélago (en cualquier estado) | Murciélago muere, jugador rebota |
| Jugador cae sobre Espectro (con corona espinosa) | **Espectro NO recibe stomp** — su `StompHitbox` tiene `monitoring = false` permanentemente |
| Jugador A cae sobre Jugador B | B muere, A rebota |
| Jugador A en dash cae sobre entidad | Nadie muere — el dash esquiva dar y recibir stomp |
| Jugador en stomp bounce cae sobre otro monstruo | Puede encadenar stompeos consecutivos |
| Slime salta y cae sobre jugador (desde arriba) | Jugador muere (el `StompRayCast` del Slime también funciona) |

### Verificación del stomp

Crear una escena de test `StompTest.tscn` con:
1. Un jugador estático en el suelo.
2. Un Slime estático en el suelo junto a él.
3. Un segundo jugador cayendo desde arriba.

Probar los 8 casos de la tabla anterior. Todos deben producir el resultado correcto el 100% de las veces.

---

## 6. MURCIÉLAGO SOMBRA — NUEVO COMPORTAMIENTO COMPLETO

**Archivos:** `ShadowBat.gd`, `BatStats.tres`, `ShadowBat.tscn`

El comportamiento anterior (circular + dive-bomb) se reemplaza completamente. Leer el nuevo diseño entero antes de implementar.

### Nuevo diseño del Murciélago

**Concepto:** El Murciélago es un enemigo ágil que patrulla lentamente el área y ataca con dash explosivos. Su peligrosidad viene de la imprevisibilidad del dash y de que se puede mover en 8 direcciones. No es un enemigo "pasivo que espera" — activamente busca al jugador.

### Parámetros en `BatStats.tres`

```
BAT_FLY_SPEED           = 50.0   px/s  (vuelo circular lento)
BAT_DASH_SPEED          = 280.0  px/s  (dash de ataque)
BAT_DASH_DURATION       = 0.18   s     (distancia: 280×0.18 = ~50px)
BAT_DASH_COOLDOWN_MIN   = 1.5    s
BAT_DASH_COOLDOWN_MAX   = 3.0    s     (cooldown aleatorio entre ataques)
BAT_DETECTION_RANGE     = 80.0   px    (radio de detección del jugador)
BAT_PATROL_RADIUS       = 40.0   px    (radio del vuelo circular de patrulla)
```

### FSM del nuevo Murciélago

**Estados:** `PATROL → TRACKING → PREPARING_DASH → DASHING → RECOVERING → PATROL`

#### Estado PATROL
- El murciélago vuela en un patrón circular suave alrededor de su `home_position` (la posición donde spawneó o la última posición de descanso).
- Radio del círculo: `BAT_PATROL_RADIUS = 40px`.
- Velocidad: `BAT_FLY_SPEED = 50 px/s`.
- Usa `sin/cos` para el movimiento circular suave, no física real. La gravedad **no afecta** al Murciélago en ningún estado.
- **El Murciélago NO puede atravesar geometría** durante el patrol. Implementar detección de obstáculos: si el path circular choca con una pared o plataforma, ajustar la posición para no penetrar y deformar el círculo localmente. Usar `move_and_collide()` o casteo de rayo para la validación de posición.
- Si detecta al jugador dentro de `BAT_DETECTION_RANGE`: transición a TRACKING.

#### Estado TRACKING
- El murciélago deja de hacer el círculo y se orienta hacia el jugador.
- Se mueve lentamente hacia el jugador manteniendo una distancia de seguridad de ~30px (no se acerca más de 30px en modo tracking).
- Calcula la dirección del próximo dash: `dash_direction = (player.position - bat.position).normalized()`.
- Redondea `dash_direction` a la **dirección de 8 vías más cercana** (los 8 vectores unitarios: N, NE, E, SE, S, SO, O, NO).
- Espera el cooldown aleatorio (`BAT_DASH_COOLDOWN_MIN` a `BAT_DASH_COOLDOWN_MAX`).
- Al finalizar el cooldown: transición a PREPARING_DASH.
- Si el jugador sale de `BAT_DETECTION_RANGE × 1.5`: volver a PATROL.

#### Estado PREPARING_DASH (anticipación visual — 0.2s)
- El Murciélago se queda completamente quieto durante 0.2s.
- Animación `bat_prepare`: alas replegadas hacia atrás, "comprimiéndose".
- Este estado es la señal visual para el jugador de que viene un dash. **0.2s es el tiempo de reacción del jugador.**
- La dirección del dash queda fijada en este estado — no se actualiza si el jugador se mueve.
- Al terminar: transición a DASHING.

#### Estado DASHING (ataque)
- El Murciélago se lanza en línea recta en `dash_direction` a `BAT_DASH_SPEED = 280 px/s`.
- Duración: `BAT_DASH_DURATION = 0.18s` o hasta impactar geometría.
- `is_attack_active = true` durante todo este estado.
- **El dash mata al contacto** a cualquier jugador que toque (excepto si el jugador está en dash propio).
- **El Murciélago es vulnerable durante el dash:** puede ser matado por flecha, espada, stomp, o proyectil. Usar `receive_stomp()` y `receive_damage()` normales.
- **Colisión con geometría:** Al impactar una pared, plataforma o cualquier geometría, el dash se detiene inmediatamente. El Murciélago **no atraviesa** nada. Transición a RECOVERING.
- Animación: `bat_dive` (el sprite se estira en la dirección del movimiento).

#### Estado RECOVERING (0.4s de stun post-dash)
- El Murciélago queda quieto durante 0.4s tras el dash (independientemente de si impactó o no).
- `is_attack_active = false`.
- Animación: `bat_stun` (ojos en espiral).
- Durante este estado el Murciélago es vulnerable al stomp desde arriba.
- Al terminar: volver a PATROL (resetear `home_position` a la posición actual).

### Colisión con geometría — implementación

El Murciélago **no puede** atravesar paredes, plataformas ni ninguna geometría. Usar `move_and_collide()` para su movimiento:

```gdscript
func _physics_process(delta):
    match state:
        BatState.PATROL:
            var target_pos = _calculate_patrol_position()
            var move_vec = (target_pos - global_position).normalized() * BAT_FLY_SPEED * delta
            var collision = move_and_collide(move_vec)
            if collision:
                # Murciélago choca con geometría durante el patrol:
                # Ajustar la home_position para que el nuevo círculo no choque
                _recalculate_home_position(collision.get_normal())
        
        BatState.DASHING:
            var move_vec = dash_direction * BAT_DASH_SPEED * delta
            var collision = move_and_collide(move_vec)
            if collision:
                # Dash bloqueado por geometría — parar inmediatamente
                _transition_to(BatState.RECOVERING)
```

### Sobre la corona espinosa (StompHitbox)

Revertir: el Murciélago **sí puede recibir stomp** durante RECOVERING (como en V0.3). Durante DASHING también puede recibir stomp (es un momento de riesgo para el jugador pero válido).

---

## 7. REGLA UNIVERSAL: NINGUNA ENTIDAD ATRAVIESA GEOMETRÍA

**Archivos:** `PlayerBase.gd`, `MonsterBase.gd`, `Slime.gd`, `StoneTroll.gd`, `ShadowBat.gd`, `SpecterArcher.gd`, `ProjectileBase.gd`

Esta sección define la verificación sistemática que debe ejecutarse para confirmar que la regla se cumple.

### Auditoría de colisiones

Para cada entidad, verificar:

**1. Tipo de nodo correcto:**
- Jugadores: `CharacterBody2D` con `move_and_slide()`. ✓ (ya implementado)
- Monstruos terrestres (Slime, Troll): `CharacterBody2D` con `move_and_slide()`.
- Monstruos voladores (Murciélago, Espectro): `CharacterBody2D` con `move_and_collide()` o `move_and_slide()` con gravedad desactivada.
- Proyectiles: `CharacterBody2D` o `RigidBody2D`, **nunca `Area2D` puro** para el movimiento.

**Si algún monstruo usa `Area2D` como nodo raíz para el movimiento**: cambiar a `CharacterBody2D`. Un `Area2D` no tiene físicas de colisión con geometría — solo detecta overlaps.

**2. Capas de colisión correctas:**
```
Layer 1: world_geometry    → TileMap (suelo, paredes, plataformas)
Layer 2: players           → CharacterBody2D de jugadores
Layer 3: monsters          → CharacterBody2D de monstruos
Layer 4: projectiles       → proyectiles en vuelo
Layer 5: stompable         → StompHitbox de jugadores y monstruos
```

Cada entidad debe tener:
- Su `collision_layer` en la capa correcta.
- Su `collision_mask` incluyendo Layer 1 (para colisionar con geometría).

**3. Verificación específica del Espectro Arquero:**
El Espectro vuela y tiene `CharacterBody2D`. Verificar que su `collision_mask` incluye Layer 1. Al implementar su movimiento con `move_and_slide()`, la geometría lo detendrá naturalmente.

**Test de penetración (ejecutar para cada entidad):**
Colocar la entidad junto a una pared en el editor. Ejecutar el juego y hacer que la entidad intente moverse hacia la pared. Confirmar que no penetra. Hacer lo mismo con el suelo y el techo.

---

## 8. ATRACCIÓN DE FLECHAS — REIMPLEMENTACIÓN COMPLETA

**Archivos:** `Arrow.gd`

La implementación anterior (`velocity += attraction_direction * strength * delta` global) no produce el efecto deseado. Esta sección la reemplaza con una implementación específica y robusta.

### Concepto exacto del comportamiento deseado

Una flecha que pasa **dentro de un radio de 1× el tamaño del monstruo** (medido desde el centro del monstruo) experimenta una deflexión sutil en su trayectoria, como si el monstruo tuviera una pequeña masa gravitacional. La deflexión:
- Es proporcional a la distancia (más cerca = más deflexión).
- No es instantánea — se aplica gradualmente mientras la flecha está en el radio de influencia.
- No convierte la flecha en un misil teledirigido — si la flecha entra al radio y sale antes de impactar, la deflexión es pequeña.
- Solo aplica si el monstruo está "delante" de la flecha (dentro de un cono de ~120° en la dirección de vuelo).

### Implementación

```gdscript
# En Arrow.gd, constantes:
const ATTRACTION_RADIUS_FACTOR = 1.2    # radio = 1.2 × ancho del monstruo
const ATTRACTION_STRENGTH      = 400.0  # fuerza de atracción (px/s²) — como aceleración
const ATTRACTION_CONE_DEGREES  = 60.0   # cono delante de la flecha (±60° = 120° total)

func _apply_target_attraction(delta: float):
    # Buscar monstruos y jugadores enemigos cercanos:
    var targets = []
    targets += get_tree().get_nodes_in_group("monsters")
    targets += get_tree().get_nodes_in_group("players")
    
    # Excluir al jugador que disparó:
    targets.erase(shooter)
    
    for target in targets:
        var to_target = target.global_position - global_position
        var distance  = to_target.length()
        
        # Calcular el radio de influencia: 1.2 × la mitad del ancho del monstruo
        var target_radius = target.get_node("CollisionShape2D").shape.extents.x * ATTRACTION_RADIUS_FACTOR
        # Si el nodo no tiene extents (CapsuleShape, etc.), usar un valor por defecto:
        if target_radius <= 0:
            target_radius = 12.0  # radio por defecto si no se puede leer
        
        if distance > target_radius:
            continue  # fuera del radio de influencia
        
        # Verificar que el monstruo está dentro del cono delante de la flecha:
        var flight_direction = velocity.normalized()
        var angle_to_target  = rad_to_deg(flight_direction.angle_to(to_target.normalized()))
        if abs(angle_to_target) > ATTRACTION_CONE_DEGREES:
            continue  # el monstruo está detrás o muy lateral — no atraer
        
        # Calcular la fuerza de atracción:
        # La fuerza es mayor cuanto más cerca está el objetivo (proporcional a 1/distancia):
        var attraction_factor = 1.0 - (distance / target_radius)  # 0 en el borde, 1 en el centro
        var attraction_vec    = to_target.normalized() * ATTRACTION_STRENGTH * attraction_factor
        
        # Aplicar la atracción como aceleración (modifica velocity):
        velocity += attraction_vec * delta
        
        # Limitar para que no se vuelva un misil: la velocidad no puede superar
        # ARROW_INITIAL_SPEED × 1.15 (un 15% más rápido como máximo por la atracción):
        var max_speed = ARROW_INITIAL_SPEED * 1.15
        if velocity.length() > max_speed:
            velocity = velocity.normalized() * max_speed
        
        # Solo atraer hacia el objetivo más cercano (break tras el primero válido):
        break
```

### Por qué este enfoque funciona mejor que el anterior

- **Aceleración, no velocidad directa:** `velocity += accel * delta` simula la atracción gravitacional real (F = ma). La flecha gana impulso gradualmente hacia el objetivo.
- **Radio basado en el tamaño del monstruo:** Automáticamente escala con el tamaño. Un Troll (grande) tiene mayor zona de influencia que un Slime (pequeño).
- **Cono de detección:** Evita que una flecha que ya pasó sea "jalada hacia atrás". Solo se activa si el objetivo está aproximadamente delante.
- **Factor de distancia:** Cuanto más cerca del centro del monstruo, más fuerte la deflexión. En el borde del radio es casi imperceptible.
- **Cap de velocidad:** Evita que la flecha se acelere de forma no realista.

### Valores de ajuste

Después de implementar, ajustar estos valores visualmente:
- `ATTRACTION_STRENGTH = 400.0`: si la atracción parece demasiado agresiva, reducir a 300. Si es imperceptible, subir a 500.
- `ATTRACTION_RADIUS_FACTOR = 1.2`: si el radio parece demasiado grande, reducir a 0.9. 
- El efecto debe ser: "casi pasa de largo pero lo roza" se convierte en impacto. Una flecha que pasa a 2-3px de distancia impacta.

---

## 9. LEDGE GRAB — REQUIERE MANTENER DIRECCIÓN PARA AGARRARSE

**Archivos:** `PlayerBase.gd`

### Problema actual
El jugador se agarra a una esquina y se queda colgado sin necesitar mantener ningún botón. Debe deslizarse hacia abajo si suelta la dirección.

### Comportamiento correcto

En estado `LEDGE_HANG`:
- Si el jugador **mantiene presionada** la dirección hacia la pared (← si está agarrado a la pared derecha, → si está agarrado a la pared izquierda): **permanece colgado, sin caer**.
- Si el jugador **suelta** la dirección (o presiona la contraria): **desliza hacia abajo** a velocidad `LEDGE_SLIDE_SPEED = 30.0 px/s`.
- Si el jugador presiona **salto**: ejecuta el ledge jump (salto desde el borde) y sale del estado.
- Si desliza hacia abajo más de `LEDGE_MAX_SLIDE = 20px` desde el punto de agarre: suelta automáticamente el borde y cae en estado `FALL`.

**Implementación — modificar el estado LEDGE_HANG en `PlayerBase.gd`:**
```gdscript
func _process_ledge_hang(delta):
    var hold_direction = _get_hold_direction_toward_wall()
    # hold_direction es el Vector2 que apunta hacia la pared donde está agarrado
    # Ejemplo: si la pared está a la derecha → hold_direction = Vector2.RIGHT
    
    var player_input_dir = _get_horizontal_input()  # -1, 0, o 1
    var is_holding_wall  = (player_input_dir == sign(hold_direction.x))
    
    if is_holding_wall:
        # El jugador mantiene presionada la dirección correcta:
        velocity = Vector2.ZERO  # completamente estático
        ledge_slide_distance = 0.0  # resetear el contador de deslizamiento
    else:
        # El jugador no mantiene la dirección — deslizar hacia abajo:
        velocity = Vector2(0, LEDGE_SLIDE_SPEED)
        ledge_slide_distance += LEDGE_SLIDE_SPEED * delta
        
        if ledge_slide_distance >= LEDGE_MAX_SLIDE:
            _transition_to(PlayerState.FALL)  # soltar el borde
            return
    
    # Input de salto: ledge jump
    if Input.is_action_just_pressed("jump_p" + str(player_index)):
        velocity.y = JUMP_VELOCITY
        velocity.x = 0
        _transition_to(PlayerState.JUMP)
        return
    
    # Aplicar posición (sin gravedad):
    move_and_slide()
```

**Añadir a `PlayerStats.tres`:**
```
LEDGE_SLIDE_SPEED = 30.0   px/s
LEDGE_MAX_SLIDE   = 20.0   px   (máximo deslizamiento antes de soltar)
```

---

## 10. LEDGE GRAB — POSICIÓN EXACTA EN LA ESQUINA (NO POR DEBAJO)

**Archivos:** `PlayerBase.gd`

### Problema actual
El personaje a veces se agarra unos píxeles por debajo de la esquina, quedando "hundido" en la pared en lugar de en el borde exacto.

### Causa raíz
El estado `LEDGE_HANG` se activa cuando el `RayCast2D` lateral detecta la pared, pero no verifica que la esquina superior esté libre. Si el jugador está ligeramente por debajo del borde cuando el raycast detecta la pared, el snap se hace a la posición actual (que está bajo el borde).

### Fix — snap a la posición correcta al activar LEDGE_HANG

Al transicionar al estado `LEDGE_HANG`, calcular y aplicar la posición exacta:

```gdscript
func _enter_ledge_hang_state():
    state = PlayerState.LEDGE_HANG
    ledge_slide_distance = 0.0
    velocity = Vector2.ZERO
    
    # Encontrar la posición exacta del borde:
    # El RayCast2D lateral (`ledge_raycast_side`) ha detectado la pared.
    # El RayCast2D superior (`ledge_raycast_top`) ha confirmado que hay espacio arriba.
    
    # La posición Y correcta es: el borde del tile donde el raycast superior
    # encuentra la superficie del tile. Usar get_collision_point():
    var top_raycast_hit_y = ledge_raycast_top.get_collision_point().y
    
    # Ajustar la posición Y del personaje para que la parte superior de su hitbox
    # quede exactamente al nivel del borde (top_raycast_hit_y):
    var player_half_height = $CollisionShape2D.shape.extents.y
    global_position.y = top_raycast_hit_y + player_half_height
    
    # Nota: esto es un snap de posición — ocurre en un solo frame y es imperceptible
    # si la diferencia es ≤ 3-4px. Si la diferencia fuera mayor, el ledge grab
    # no debería haberse activado (revisar las condiciones de activación).
```

**Condiciones de activación del ledge grab que deben verificarse antes de llamar a `_enter_ledge_hang_state()`:**

```gdscript
func _check_ledge_grab() -> bool:
    if velocity.y <= 0:
        return false  # solo al caer o en horizontal
    
    if state == PlayerState.DASH:
        return false  # el dash no se agarra
    
    # Raycast lateral: ¿hay una pared en la dirección de movimiento horizontal?
    ledge_raycast_side.force_raycast_update()
    if not ledge_raycast_side.is_colliding():
        return false
    
    # Raycast superior: ¿hay espacio libre justo encima del personaje a la altura del ledge?
    ledge_raycast_top.force_raycast_update()
    if ledge_raycast_top.is_colliding():
        return false  # hay techo encima — no se puede agarrar
    
    # Verificar que el punto de impacto del raycast lateral está dentro de los
    # últimos LEDGE_DETECTION_THRESHOLD píxeles del borde superior del tile:
    var wall_hit_y    = ledge_raycast_side.get_collision_point().y
    var player_top_y  = global_position.y - $CollisionShape2D.shape.extents.y
    
    # La esquina debe estar dentro de 8px de la parte superior del jugador:
    if abs(wall_hit_y - player_top_y) > 8.0:
        return false  # la pared empieza demasiado abajo — no es un ledge grab
    
    # El jugador debe estar presionando la dirección hacia la pared:
    var wall_side     = _get_wall_side_from_normal(ledge_raycast_side.get_collision_normal())
    var player_input  = _get_horizontal_input()
    if player_input != sign(wall_side.x):
        return false  # el jugador no está dirigiéndose hacia la pared
    
    return true
```

**Resultado:** El ledge grab solo se activa cuando el jugador está exactamente en la altura correcta (±8px del borde), y al activarse hace snap a la posición exacta del borde. No puede activarse por debajo.

---

## TABLA DE VERIFICACIÓN FINAL

| Nº | Prueba | Criterio de éxito |
|---|---|---|
| 1 | Salto desde el suelo | Jugador alcanza ~36px de altura (3.6 tiles) |
| 1 | Ledge grab en plataforma alta (>36px) | Necesario para subir — no se puede con salto directo |
| 2 | Input diagonal + dash | El dash va en el eje dominante, nunca diagonal |
| 2 | Input ↓ + dash | No ocurre ningún dash |
| 3 | Jugador cae por hueco del suelo (wrap vertical) | Reaparece por el techo con `velocity.y × 0.5` |
| 3 | Monstruo cae por hueco | Mismo comportamiento |
| 4 | Slime patrol | Velocidad visiblemente menor que el jugador caminando |
| 4 | Slime jump de ataque | Salto bajo, ≈5px de altura |
| 5 | Stomp sobre Slime en el aire | Slime muere 100% de las veces |
| 5 | Stomp sobre Slime en el suelo | Slime muere 100% de las veces |
| 5 | Stomp sobre jugador | Jugador muere 100% de las veces |
| 5 | Dash sobre enemigo | Ninguno muere — el dash esquiva dar y recibir stomp |
| 5 | Stomp encadenado (2 monstruos consecutivos) | Funciona si se mantiene el botón de salto |
| 6 | Murciélago patrullando | No atraviesa ninguna pared o plataforma |
| 6 | Murciélago en PREPARING_DASH | Se queda quieto 0.2s, visible para el jugador |
| 6 | Murciélago en DASHING | Mata al contacto. Se puede matar con flecha/stomp |
| 6 | Murciélago impacta geometría en dash | Para inmediatamente, entra en RECOVERING |
| 6 | Murciélago cerca del jugador (≤30px) | No se queda quieto — mantiene distancia o dashea |
| 7 | Todos los monstruos contra una pared | Ninguno la penetra. Verificar con debug hitboxes (F1) |
| 7 | Proyectil espectral hacia plataforma | Impacta en la superficie y desaparece |
| 8 | Flecha pasa a 2px de un monstruo | La deflexión la hace impactar |
| 8 | Flecha pasa a 15px (fuera del radio) | No hay deflexión visible |
| 8 | Flecha con monstruo detrás (>60° lateral) | No hay deflexión |
| 9 | Ledge grab + soltar dirección | Personaje desliza hacia abajo a 30 px/s |
| 9 | Ledge grab + mantener dirección | Personaje se queda completamente quieto |
| 9 | Deslizar >20px | Personaje suelta el borde y cae |
| 10 | Activar ledge grab | Personaje snapea exactamente al borde, no por debajo |
| 10 | Intentar ledge grab a media pared | No se activa — solo en la esquina superior |

---

## ORDEN DE IMPLEMENTACIÓN

```
Bloque A — Parámetros (inmediato, sin riesgo):
  → Punto 1  (salto ×2)
  → Punto 4  (Slime velocidad ÷2)
  → Punto 5  (stomp: añadir STOMP_BOUNCE a PlayerStats.tres)

Bloque B — Física y colisiones (regla universal):
  → Punto 7  (auditoría de capas y tipos de nodo)
  → Punto 3  (damping de velocidad en wrap vertical)

Bloque C — Mecánicas de jugador:
  → Punto 2  (eliminar dash diagonal)
  → Punto 10 (ledge grab snap a esquina exacta)
  → Punto 9  (ledge grab requiere mantener dirección)

Bloque D — Stomp (requiere que el Bloque C esté limpio):
  → Punto 5  (reimplementación completa con StompRayCast)

Bloque E — IA del Murciélago:
  → Punto 6  (nuevo comportamiento completo)

Bloque F — Flechas:
  → Punto 8  (reimplementación de la atracción gravitacional)

Bloque G — Verificación final:
  → Ejecutar toda la tabla de verificación
  → Actualizar CHANGELOG.md (versión 0.6.0)
  → Cerrar bugs correspondientes en BUGS.md
```

**Nota crítica sobre el Bloque D:** El stomp reimplementado con `RayCast2D` solo funciona correctamente si la regla universal del Bloque B ya se cumple. Si los monstruos pueden atravesar geometría, el stomp puede producir resultados inconsistentes porque el jugador y el monstruo pueden estar en posiciones físicamente imposibles. Siempre aplicar el Bloque B antes del D.
