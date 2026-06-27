# ACTUALIZACIÓN V0.8.3 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico
**Fecha:** 2026-06-26
**Versión destino:** 0.8.3
**Prerrequisito:** Leer CLAUDE.md antes de empezar. Aplicar sobre v0.8.2.

---

## RESUMEN EJECUTIVO

Esta actualización corrige 4 bugs. Dos de ellos (puntos 2 y 4) son correcciones de cambios de V0.8.2 que no se aplicaron correctamente. Todos los puntos son quirúrgicos: afectan archivos muy concretos y no requieren rediseño de sistemas.

---

## ÍNDICE

- **Punto 1** — El dash debe atravesar jugadores y monstruos (regresión introducida en V0.8.2 B-1)
- **Punto 2** — Wall slide no debe continuar más allá del borde de una plataforma flotante (V0.8.2 B-4 no aplicado correctamente)
- **Punto 3** — Stomp falla con el Troll (investigar y corregir)
- **Punto 4** — El jugador reaparece en el punto de muerte, no en la posición del cadáver (V0.8.2 D-1 no aplicado correctamente)

---

# PUNTO 1 — EL DASH DEBE ATRAVESAR JUGADORES Y MONSTRUOS

## Contexto y causa raíz

**Archivo:** `scripts/characters/PlayerBase.gd`

En V0.8.2 se añadió `L_MONSTER_BODY = 128` al `collision_mask` del jugador (punto B-1) para que los monstruos sean físicamente sólidos. Esto es correcto para el movimiento normal. Sin embargo, ese cambio también afecta al estado DASH, lo que hace que el jugador ya no pueda atravesar monstruos ni otros jugadores durante el dash.

**Comportamiento correcto (era así antes de V0.8.2):** Durante el dash, el jugador debe atravesar físicamente a cualquier entidad viva (monstruos y otros jugadores). La colisión física con entidades solo aplica fuera del dash.

## Solución

Modificar el `collision_mask` del jugador temporalmente durante el estado DASH:

**Al ENTRAR en el estado DASH** (inicio del dash):
- Eliminar `L_MONSTER_BODY` (128) y `L_PLAYER_BODY` (16) del `collision_mask` actual del jugador
- Guardar el valor original del `collision_mask` en una variable temporal para restaurarlo después

**Al SALIR del estado DASH** (cuando el dash termina, antes de transicionar a cualquier otro estado — FALL, NORMAL, etc.):
- Restaurar el `collision_mask` al valor guardado antes del dash (que incluye L_MONSTER_BODY y L_PLAYER_BODY)

| Momento | Operación sobre `collision_mask` |
|---|---|
| Inicio del DASH | Eliminar bits L_PLAYER_BODY (16) y L_MONSTER_BODY (128) |
| Fin del DASH | Restaurar al valor previo al dash |

**Aclaración importante:** Este cambio de `collision_mask` es ADICIONAL e INDEPENDIENTE del sistema de invulnerabilidad a daño (`dash_invuln_frames = 6`). El sistema de invulnerabilidad a daño ya existía y no debe modificarse. Este punto solo afecta a la colisión física de cuerpos.

**Aclaración sobre el Espectro:** El Espectro Arquero no tiene `L_MONSTER_BODY` y ya era atravesable siempre. Este cambio no le afecta.

## Verificación

| Prueba | Resultado esperado |
|---|---|
| Dash hacia un Slime | El jugador atraviesa el Slime durante el dash; al acabar el dash, el jugador ya no puede atravesarlo |
| Dash hacia un Troll | El jugador atraviesa el Troll durante el dash |
| Dash hacia el otro jugador (Versus) | Los jugadores se atraviesan mutuamente durante el dash |
| Movimiento normal contra un Slime (sin dash) | El jugador choca contra el Slime como antes (colisión física normal) |

---

# PUNTO 2 — WALL SLIDE NO DEBE CONTINUAR SIN PARED

## Contexto y causa raíz

**Archivo:** `scripts/characters/PlayerBase.gd`

V0.8.2 B-4 especificó añadir un RayCast2D lateral (`_wall_slide_ray`) para detener el wall slide cuando se acaba la pared. Este cambio no fue aplicado correctamente o no funciona en todos los casos.

**El bug específico ocurre en dos situaciones:**
1. El jugador salta contra el lateral de una plataforma flotante fina (1–2 tiles de altura) y empieza el wall slide. El slide continúa hacia abajo aunque la pared ya haya acabado.
2. El jugador se agarra a un borde de plataforma (LEDGE_GRAB) y al soltarse entra en WALL_SLIDE. La misma situación: el slide puede continuar sin pared.

## Especificación del RayCast de validación (completa y definitiva)

Añadir un nodo `RayCast2D` hijo de `PlayerBase` con las siguientes propiedades:

| Propiedad | Valor |
|---|---|
| Nombre del nodo | `_wall_slide_ray` |
| `enabled` | `true` |
| `collision_mask` | `L_WORLD` = 1 |
| Posición inicial (espacio local) | (0, 0) — centro del cuerpo |
| `target_position` inicial | (8, 0) — se actualiza dinámicamente en código |

## Lógica de actualización (cada frame en estado WALL_SLIDE)

En el método que procesa el estado WALL_SLIDE dentro del `_physics_process` o equivalente FSM:

1. Actualizar la dirección del rayo según la pared actual:
   - Si la pared está a la DERECHA del jugador: `target_position.x = +8`, `target_position.y = 0`
   - Si la pared está a la IZQUIERDA del jugador: `target_position.x = -8`, `target_position.y = 0`
2. Llamar `_wall_slide_ray.force_raycast_update()`
3. Evaluar: si `_wall_slide_ray.is_colliding()` devuelve `false` → transicionar al estado FALL inmediatamente en ese mismo frame

Esta validación debe ejecutarse en TODOS los frames que el estado sea WALL_SLIDE, sin excepción, independientemente de cómo se llegó a ese estado (desde salto, desde LEDGE_GRAB, o cualquier otro estado previo).

## Verificación

| Prueba | Resultado esperado |
|---|---|
| Wall slide en una plataforma flotante fina (1 tile de alto) | El slide se detiene exactamente al llegar al borde inferior del tile; cae con gravedad normal |
| Wall slide en una pared de escenario alta (varios tiles) | El slide funciona con normalidad sin interrupciones |
| Soltarse de un ledge grab lateral | Si no hay pared debajo del borde, cae inmediatamente sin slide fantasma |

---

# PUNTO 3 — STOMP FALLA CON EL TROLL

## Contexto

**Archivos a revisar:** `scenes/monsters/StoneTroll.tscn`, `scripts/characters/PlayerBase.gd`

El stomp no detecta correctamente al Troll en algunos casos. Hay dos causas posibles que deben investigarse en este orden:

## Causa A — StompHitbox mal posicionada en el Troll

La `StompHitbox` de cada monstruo debe estar centrada horizontalmente y posicionada en el borde SUPERIOR del sprite del monstruo. Si está descentrada o demasiado baja, el `_stomp_ray` del jugador puede pasar por encima sin detectarla.

**Verificación:** Abrir `scenes/monsters/StoneTroll.tscn` y localizar el nodo `StompHitbox` (Area2D). Comprobar:

| Propiedad a verificar | Valor correcto |
|---|---|
| `position.x` | 0 (centrado) |
| `position.y` | Debe ser igual a `-(mitad del alto del CollisionShape2D del Troll)`. El Troll mide 22px de alto post-escala, por lo que el CollisionShape2D tiene half-height = 11px → `position.y = -11` |
| Ancho del CollisionShape2D de la StompHitbox | Al menos 16px (para ser detectable aunque el jugador no caiga exactamente en el centro) |

Si cualquier valor está incorrecto, corregirlo a los valores de la tabla.

## Causa B — Longitud del _stomp_ray insuficiente tras V0.8.2 B-3

V0.8.2 B-3 redujo la longitud del `_stomp_ray` a 3px para evitar activaciones prematuras. Para monstruos grandes como el Troll, 3px puede ser insuficiente para detectar la StompHitbox en todos los frames (especialmente a 60fps con velocidades de caída altas).

**Fix:** Aumentar la longitud del `_stomp_ray` de 3px a **6px**.

| Parámetro | Valor tras V0.8.2 B-3 | Valor nuevo |
|---|---|---|
| `_stomp_ray.target_position.y` | 3 px | 6 px |

6px es suficientemente corto para no causar activaciones prematuras visualmente, pero garantiza que el rayo alcanza la StompHitbox del Troll (la más alta de todos los monstruos) en todos los frames posibles.

## Nota sobre la interacción con V0.8.2 B-2

V0.8.2 B-2 añadió `L_WORLD` al `collision_mask` del `_stomp_ray` para que el rayo se detenga en plataformas. Este fix sigue siendo correcto y no debe revertirse. La longitud de 6px sigue siendo demasiado corta para atravesar una plataforma (los tiles son de 10px de alto), así que no hay conflicto.

## Verificación

| Prueba | Resultado esperado |
|---|---|
| Caer encima del Troll desde cualquier altura | El Troll muere siempre que el pie del jugador lo toca por arriba |
| Caer en el centro del Troll | Stomp detectado |
| Caer en el borde lateral del Troll | Stomp detectado (si el área de la StompHitbox es ≥16px de ancho) |
| Jugador en plataforma encima del Troll (sin contacto) | Troll NO muere (B-2 sigue activo) |

---

# PUNTO 4 — JUGADOR REAPARECE EN LA POSICIÓN DEL CADÁVER

## Contexto y causa raíz

**Archivos:** `scripts/characters/PlayerBase.gd`, `scripts/ui/StoryMatch.gd`

V0.8.2 D-1 especificó que el cristal de respawn debe viajar hasta la posición del cadáver y que el jugador debe reaparecer allí. Esto no fue implementado: el jugador sigue reapareciendo en el punto de muerte (`last_death_pos`).

## Implementación exacta — paso a paso

### Paso 1: PlayerBase.gd — guardar referencia al cadáver

Localizar la función donde se crea el nodo `Corpse` (probablemente `_spawn_corpse()` o dentro de `die()`).

En esa función, el código actual hace algo similar a:
```
# (pseudocódigo del estado actual)
var c = Corpse.new()
# ... configura c ...
get_parent().add_child.call_deferred(c)
```

Añadir una variable de instancia en PlayerBase:
- Nombre: `_last_corpse`
- Tipo: `Node2D` (o `Node`)
- Valor inicial: `null`

Inmediatamente después de construir el nodo `c` (y ANTES o DESPUÉS de `call_deferred` — el nodo ya existe aunque no esté en el árbol todavía), asignar:
`_last_corpse = c`

**Nota crítica:** `call_deferred` solo retrasa la inserción en el árbol de escena, pero el nodo ya existe en memoria. Se puede guardar la referencia antes de `call_deferred` sin ningún problema.

---

### Paso 2: StoryMatch.gd — animar cristal al cadáver y revivir allí

Localizar la función de respawn (probablemente `_respawn_player()` o equivalente).

El código actual lee `_player.last_death_pos` como destino del cristal y como posición de spawn.

**Cambios exactos:**

**Cambio 1 — Añadir delay de 0.35 segundos antes de iniciar la animación:**

Justo al inicio de la secuencia de animación del cristal, añadir una espera:
`await get_tree().create_timer(0.35).timeout`

Esto da tiempo al cadáver a desplazarse por su impulso y detenerse antes de leer su posición.

**Cambio 2 — Calcular el target del cristal:**

Después del delay, calcular el target con esta lógica de prioridad:

```
# (pseudocódigo — Claude Code debe escribir el GDScript real)
Si _player._last_corpse != null Y is_instance_valid(_player._last_corpse):
    target = _player._last_corpse.global_position
Si no:
    target = _level.safe_respawn_pos(_player.last_death_pos)  # fallback
```

**Cambio 3 — Usar el mismo target para la posición de spawn:**

La posición donde reaparece el jugador debe ser la misma que el target del cristal (pasada por `safe_respawn_pos()` para evitar quedar dentro de geometría):
`posición de spawn = _level.safe_respawn_pos(target)`

---

### Resumen del flujo completo tras el fix

1. El jugador muere → `die()` crea el `Corpse` y guarda la referencia en `_last_corpse`
2. El `Corpse` vuela con impulso de física durante ~0.3–0.5s
3. La pantalla espera el tiempo de respawn habitual hasta iniciar la animación del cristal
4. Justo antes de iniciar la animación: delay adicional de 0.35s
5. Se lee `_last_corpse.global_position` (posición actual del cadáver, ya detenido)
6. El cristal viaja desde el HUD hasta la posición del cadáver
7. El jugador reaparece en esa posición (ajustada por `safe_respawn_pos()`)

## Verificación

| Prueba | Resultado esperado |
|---|---|
| Morir con una flecha que empuja el cadáver a la izquierda | El cristal viaja hacia la izquierda, donde descansa el cadáver. El jugador reaparece allí |
| Morir sin impulso (el cadáver queda en el sitio) | El cristal viaja al punto de muerte (que coincide con la posición del cadáver). Sin diferencia visual con el comportamiento anterior |
| Morir en el nivel 2 y el cadáver cae al vacío | El cristal usa el fallback (`safe_respawn_pos`). El jugador reaparece en el punto seguro más cercano |
| Morir en modo Versus | No aplica (esta lógica es solo para StoryMatch) |

---

## ORDEN DE IMPLEMENTACIÓN

```
Punto 1 — Dash traversal (15 min):
  PlayerBase.gd: guardar/restaurar collision_mask al entrar/salir del estado DASH

Punto 2 — Wall slide sin pared (20 min):
  PlayerBase.gd: añadir _wall_slide_ray (RayCast2D, 8px, L_WORLD)
                 evaluar en cada frame de WALL_SLIDE; forzar FALL si no colisiona

Punto 3 — Stomp en Troll (20 min):
  StoneTroll.tscn: verificar y corregir posición/tamaño de StompHitbox
  PlayerBase.gd: cambiar longitud del _stomp_ray de 3px a 6px

Punto 4 — Resurrección en posición del cadáver (20 min):
  PlayerBase.gd: añadir variable _last_corpse; asignarla al crear el Corpse
  StoryMatch.gd: delay 0.35s + leer _last_corpse.global_position como target

Total estimado: ~75 min
```

---

## TABLA DE VERIFICACIÓN FINAL V0.8.3

| # | Prueba | Criterio de éxito |
|---|---|---|
| 1a | Dash hacia un Slime | El jugador lo atraviesa durante el dash |
| 1b | Dash hacia otro jugador (Versus) | Los jugadores se atraviesan mutuamente durante el dash |
| 1c | Movimiento normal contra un Slime | Colisión física normal, el jugador no lo atraviesa |
| 2a | Wall slide en plataforma flotante fina | El slide se corta exactamente al acabar la pared |
| 2b | Wall slide en pared de escenario alta | El slide funciona con normalidad |
| 2c | Soltarse de un ledge grab en esquina de plataforma | Cae sin slide fantasma si no hay pared debajo |
| 3a | Caer encima del Troll (centro) | Stomp registrado, Troll muere |
| 3b | Caer encima del Troll (borde lateral) | Stomp registrado, Troll muere |
| 3c | Jugador en plataforma justo encima del Troll | Troll NO muere (no hay stomp) |
| 4a | Morir con proyectil que empuja el cadáver | Cristal viaja al cadáver; jugador reaparece allí |
| 4b | Morir sin impulso lateral | Cristal viaja al punto de muerte = posición del cadáver |
| 4c | Cadáver cae al vacío (Nivel 2) | Jugador reaparece en punto seguro (fallback) |

---

## ARCHIVOS MODIFICADOS EN ESTA ACTUALIZACIÓN

| Archivo | Cambios |
|---|---|
| `scripts/characters/PlayerBase.gd` | Puntos 1, 2, 3 y 4 |
| `scripts/ui/StoryMatch.gd` | Punto 4 |
| `scenes/monsters/StoneTroll.tscn` | Punto 3 (StompHitbox) |

**Ningún otro archivo debe modificarse.**
