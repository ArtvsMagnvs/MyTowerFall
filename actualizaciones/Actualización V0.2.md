# ACTUALIZACIÓN V0.2 — INSTRUCCIONES PARA CLAUDE CODE
**Fecha:** 2026-06-23  
**Prioridad:** Implementar todos los puntos antes de continuar con nuevas funcionalidades  
**Referencia:** DOCUMENTO_MAESTRO.md, BUGS.md

Este documento describe correcciones de bugs y ajustes de mecánicas detectados en la versión actual. Implementa cada punto en orden. Al terminar cada uno, marca su estado en BUGS.md o en CHANGELOG.md según corresponda.

---

## 1. SUELO FLOTANTE TRAVERSABLE DESDE ABAJO
**Tipo:** Bug  
**Archivo afectado:** Escenas de nivel (`Level_01_Forest.tscn`, `Level_02_Ruins.tscn`, `Level_03_Tower.tscn`) y posiblemente `LevelBase.gd`

**Problema:** Las plataformas flotantes permiten que el jugador las atraviese desde abajo. No debería ser posible.

**Fix:**  
- Todas las plataformas flotantes deben usar `StaticBody2D` con colisión sólida en **todos los lados**, no `pass_through`.
- El comportamiento correcto es: se puede aterrizar desde arriba, pero NO se puede atravesar desde abajo ni desde los lados.
- Revisar que ninguna plataforma tenga activado `one_way_collision = true` en su `CollisionShape2D`. Si lo tiene, desactivarlo.
- Nota: En Godot 4, el `one_way_collision` en `StaticBody2D` es lo que causa este comportamiento. Asegurarse de que esté en `false` en todas las plataformas flotantes del juego.

---

## 2. DISPARO AL SOLTAR EL BOTÓN + LOCK DE MOVIMIENTO DURANTE APUNTADO
**Tipo:** Bug + ajuste de mecánica  
**Archivo afectado:** `ArcherPlayer.gd`, `PlayerBase.gd`

**Problema A — Disparo al presionar en lugar de al soltar:**  
El disparo del ataque 1 se lanza al presionar el botón. Debe lanzarse al **soltar** el botón. Esto permite al jugador mantener el botón pulsado mientras elige la dirección y soltar para disparar.

**Fix A:**  
- En `ArcherPlayer.gd`, cambiar la detección del ataque 1 de `Input.is_action_just_pressed("attack1_p1")` a `Input.is_action_just_released("attack1_p1")` (y equivalente para P2).
- El ataque 2 (carga) ya usa hold+release, no cambia.

**Problema B — El personaje camina al usar las flechas de dirección durante el apuntado:**  
Cuando el jugador mantiene pulsado el botón de ataque y usa las teclas de dirección para apuntar, el personaje se desplaza horizontalmente. Solo debería cambiar la dirección de disparo.

**Fix B:**  
- En `PlayerBase.gd`, añadir un flag `is_aiming: bool`. Se activa cuando `attack1` está pulsado (`Input.is_action_pressed`).
- Cuando `is_aiming == true`:
  - Las teclas de dirección **solo actualizan `aim_direction`**, no modifican `velocity.x`.
  - El personaje queda estático horizontalmente (en suelo). En el aire, la gravedad sigue actuando con normalidad pero no hay control horizontal.
- Cuando `is_aiming == false`: comportamiento de movimiento normal.
- Este flag aplica **solo al Arquero**. El Guerrero no tiene disparo que requiera apuntado estático.

---

## 3. STOMP EN VERSUS NO MATA
**Tipo:** Bug  
**Archivo afectado:** `PlayerBase.gd`, sistema de hitbox de stomp

**Problema:** Saltar encima de otro jugador en el modo Versus no lo mata. En Modo Historia sí funciona el stomp sobre monstruos.

**Fix:**  
- El sistema de stomp comprueba colisión con la hitbox superior de entidades del grupo `monsters`. Añadir también el grupo `players` a la comprobación.
- En `PlayerBase.gd`, en la función que gestiona el stomp (`_check_stomp()` o equivalente), cambiar:
  ```gdscript
  # Antes:
  get_tree().get_nodes_in_group("monsters")
  # Después:
  get_tree().get_nodes_in_group("monsters") + get_tree().get_nodes_in_group("players")
  ```
- Asegurarse de excluir al propio jugador de la lista (no puede hacerse stomp a sí mismo).
- El rebote hacia arriba post-stomp debe funcionar igual que con monstruos.

---

## 4. JUGADORES SE TRASPASAN EN VERSUS (SIN COLISIÓN ENTRE PLAYERS)
**Tipo:** Bug  
**Archivo afectado:** `PlayerBase.gd`, capas de colisión del proyecto

**Problema:** Los dos jugadores no colisionan entre sí, pueden ocupar el mismo espacio.

**Fix:**  
- En Godot 4 con `CharacterBody2D`, las colisiones entre cuerpos del mismo tipo requieren configurar las capas de colisión (`collision_layer` y `collision_mask`) correctamente.
- Asignar a los jugadores una capa dedicada, por ejemplo **Layer 2: "players"**.
- Asegurarse de que el `collision_mask` de cada jugador incluye la **Layer 2** para que detecten y colisionen con otros jugadores.
- La colisión entre jugadores debe ser solo de **empuje físico** (se bloquean mutuamente) — no causa daño por contacto. El daño sigue siendo solo por ataques explícitos (flecha, espada, stomp).

---

## 5. DISTANCIA CORTA DE LAS FLECHAS EN TRAYECTORIA RECTA
**Tipo:** Bug / ajuste de parámetros  
**Archivo afectado:** `ProjectileBase.gd`, `ArrowStats.tres`

**Problema:** Las flechas disparadas en línea recta (horizontal) recorren muy poca distancia antes de caer al suelo por la gravedad.

**Fix:**  
- Aumentar `PROJECTILE_INITIAL_SPEED` en `ArrowStats.tres`. Valor sugerido de partida: **500 px/s** (actualmente 320 px/s según el documento maestro). Ajustar hasta que una flecha disparada horizontalmente cruce aproximadamente 2/3 de la pantalla antes de tocar suelo.
- Alternativamente o adicionalmente, reducir `proj_gravity` para las flechas. Valor sugerido: **250 px/s²** (actualmente 400 px/s²).
- **Parámetro de referencia objetivo:** Una flecha disparada horizontalmente desde el centro de la pantalla debe poder alcanzar la pared opuesta si se dispara con ligera inclinación hacia arriba. En línea recta pura, debe recorrer al menos 180px antes de caer más de 20px.
- Exponer ambos valores (`initial_speed`, `proj_gravity`) en `ArrowStats.tres` para poder ajustar fácilmente sin tocar código.

---

## 6. LIGERA ATRACCIÓN GRAVITATORIA DE FLECHAS HACIA ENEMIGOS CERCANOS
**Tipo:** Nueva funcionalidad  
**Archivo afectado:** `ProjectileBase.gd`, `Arrow.gd`

**Descripción:**  
Las flechas deben tener una ligera desviación de trayectoria hacia enemigos o jugadores que estén cerca de su camino. **No es autoaim** — la flecha no va a perseguir al objetivo. Es una atracción sutil que hace que las flechas "casi rozar" a un enemigo acaben impactando, dando una sensación de que el mundo físico tiene algo de magnetismo hacia los combatientes.

**Implementación:**  
- En `Arrow.gd`, en el `_physics_process(delta)`, después de aplicar la gravedad normal:
  1. Obtener todos los nodos del grupo `enemies` y `players` en un radio de **30px** alrededor de la flecha.
  2. Excluir al jugador que disparó la flecha.
  3. Para cada objetivo dentro del radio, calcular un vector de atracción suave:
     ```gdscript
     var attraction = (target.global_position - global_position).normalized()
     velocity += attraction * ARROW_ATTRACTION_STRENGTH * delta
     ```
  4. `ARROW_ATTRACTION_STRENGTH = 180.0` (ajustable). Este valor es bajo suficiente para que la flecha no cambie de trayectoria de forma obvia, pero suficiente para que a distancias cortas "jale" ligeramente.
- La atracción solo aplica cuando el objetivo está en el **cono de influencia** (≈ 60° delante de la dirección de la flecha). Evita que una flecha que pasa de largo sea atraída hacia atrás.
- Apagar la atracción en el último frame antes del impacto (cuando `distance < 4px`) para que el impacto sea limpio.

---

## 7. PANEL DE CONFIGURACIÓN DE BOTONES — PROBLEMAS DE LAYOUT
**Tipo:** Bug de UI  
**Archivo afectado:** `OptionsMenu.tscn`, `OptionsMenu.gd`, `ControlsRemapper.gd`

**Problemas detectados:**
- El panel es demasiado grande y algunos bindings quedan fuera de la pantalla (los de Ataque 2 de ambos jugadores).
- El botón "Atrás" / "Salir" colisiona con un botón de configuración de teclas del Jugador 2.

**Fix:**  
- Rediseñar el layout del panel de controles usando un `ScrollContainer` dentro del panel. Así el contenido puede ser más alto que la pantalla y el usuario hace scroll para ver todos los bindings.
- La altura visible del panel debe ser máximo **140px** (en la resolución nativa 320×180). El contenido interior puede ser más alto — el scroll lo gestiona.
- El botón "Atrás" debe estar **fuera del ScrollContainer**, anclado en la parte inferior de la pantalla con posición fija, separado del área de scroll. Nunca debe solaparse con los elementos de configuración.
- Layout sugerido:
  ```
  [Panel de Controles]
    [Título: "CONTROLES"]
    [ScrollContainer — altura fija 120px]
      [Columna P1] [Columna P2]   ← toda la lista de bindings aquí
    [Botón ATRÁS — fuera del scroll, abajo del panel]
  ```
- Verificar en resolución 320×180 que el botón Atrás no se superpone con ningún elemento del scroll, ni en el estado inicial ni al hacer scroll hasta abajo.

---

## 8. REDUCIR TAMAÑO DE PERSONAJES Y MONSTRUOS UN 40%
**Tipo:** Ajuste visual  
**Archivos afectados:** Todos los sprites + `PlayerBase.gd`, `MonsterBase.gd`, hitboxes

**Problema:** Los personajes y monstruos son demasiado grandes en relación al tamaño de los niveles.

**Fix:**  
- Reducir el `scale` de todos los nodos `Sprite2D` de personajes y monstruos al **60%** del tamaño actual (`Vector2(0.6, 0.6)`).
- Esto afecta también a las `CollisionShape2D` — deben redimensionarse proporcionalmente (no solo escalar el sprite visualmente; la hitbox debe coincidir con el nuevo tamaño).
- Actualizar los valores de hitbox en el DOCUMENTO_MAESTRO en consecuencia (los tamaños de canvas en píxeles en la sección 9b siguen siendo válidos como referencia de arte; lo que cambia es la escala en engine).
- Revisar que los spawn points de los niveles siguen siendo válidos con el nuevo tamaño (un personaje más pequeño no debe aparecer dentro de geometría).
- Revisar que el contador de proyectiles encima del personaje sigue posicionado correctamente tras el rescalado.

---

## 9. FLECHAS IMPACTADAS EN ENEMIGOS DEBEN MANTENERSE Y SER RECOGIBLES
**Tipo:** Bug + ajuste de mecánica  
**Archivo afectado:** `Arrow.gd`, `ProjectileBase.gd`

**Problema:** Cuando una flecha impacta en un enemigo o jugador, desaparece inmediatamente. Debe quedarse clavada en el cuerpo y poder recogerse.

**Fix:**  
- Al detectar impacto en una entidad (enemigo o jugador), la flecha **no se destruye**. En su lugar:
  1. Desactivar la `CollisionShape2D` de la flecha (ya no puede matar a nadie más).
  2. Hacer que la flecha se convierta en "hijo" del nodo de la entidad impactada (`reparent(target_node)`), fijándose a su posición relativa. La flecha viaja con el cuerpo muerto.
  3. La flecha permanece visible durante los **2-3 segundos** que el cuerpo permanece en pantalla antes de desaparecer.
  4. Durante esos 2-3 segundos, si un jugador pasa sobre el cuerpo (o toca el área de recogida), puede recoger la flecha como si estuviera clavada en el suelo.
  5. Cuando el cuerpo desaparece (timer de muerte), la flecha desaparece con él.
- El hitbox de recogida de la flecha sigue activo mientras esté clavada en el cuerpo.

---

## 10. IMPULSO DE FLECHA AL IMPACTAR — EFECTO TOWER FALL
**Tipo:** Nueva funcionalidad  
**Archivo afectado:** `Arrow.gd`, `PlayerBase.gd`, `MonsterBase.gd`

**Descripción:**  
Cuando una flecha impacta en un enemigo o jugador, el impacto aplica un impulso en la dirección de la flecha al cuerpo muerto. El cuerpo muerto vuela en esa dirección (puede clavarse en una pared, caer en el vacío, etc.). La flecha permanece clavada en el cuerpo durante el vuelo.

**Implementación:**  
- En `Arrow.gd`, al detectar impacto en una entidad:
  1. Llamar a `target.apply_death_impulse(velocity.normalized() * ARROW_DEATH_IMPULSE_FORCE)` en la entidad impactada.
  2. `ARROW_DEATH_IMPULSE_FORCE = 220.0` (ajustable). Debe ser suficiente para que el cuerpo se desplace visiblemente pero no salga disparado de forma exagerada.
- En `PlayerBase.gd` y `MonsterBase.gd`, implementar `apply_death_impulse(impulse: Vector2)`:
  ```gdscript
  func apply_death_impulse(impulse: Vector2):
      # Activar estado "dead_flying": el cuerpo ya no responde a inputs
      # pero sigue afectado por física (gravedad + el impulso recibido)
      state = "dead_flying"
      velocity = impulse
  ```
- En el estado `dead_flying`:
  - La gravedad sigue actuando (el cuerpo sigue una parábola).
  - El cuerpo puede colisionar con paredes y suelos (rebota o se queda "pegado" visualmente).
  - No puede causar ni recibir daño.
  - Tras 2-3 segundos, el cuerpo desaparece con efecto de fundido.
- El impulso de la flecha del Troll (pedrusco) también aplica impulso al impactar, pero con fuerza reducida (`ROCK_DEATH_IMPULSE_FORCE = 140.0`).

---

## 11. VIDAS Y SISTEMA DE RESPAWN EN VERSUS
**Tipo:** Nueva funcionalidad  
**Archivos afectados:** `PlayerBase.gd`, `HUD.tscn`, `HUD.gd`, `VersusMatch.gd`

**Descripción:**  
Cada jugador tiene **4 vidas** en el modo Versus. Al morir, se consume una vida. Si llega a 0, pierde la ronda. El respawn es automático y visual.

### Sistema de vidas
- El HUD muestra las vidas restantes en las esquinas superiores:
  - **P1:** Esquina superior izquierda.
  - **P2:** Esquina superior derecha.
- Las vidas se representan con **iconos del personaje** (usar `player_icon` 8×8px), no con números.
- Al perder una vida, el icono correspondiente desaparece con una pequeña animación (fade out + scale down).

### Efecto de respawn
Al respawnear (consumir una vida y volver a aparecer):
1. Una **bola de energía** sale del icono de vida en el HUD, viaja en arco hacia el punto de spawn del personaje, y al llegar activa al personaje.
   - La bola es un sprite pequeño (6×6px) del color del personaje.
   - La trayectoria es una curva suave (usar `Tween` con `ease_in_out`).
   - Duración del viaje: **0.6 segundos**.
2. Al llegar la bola, el personaje **aparece con un efecto de spawn** que dura **1 segundo**:
   - Durante ese segundo: el personaje **parpadea** (alternando visible/invisible cada 4 frames) y es **inmune a cualquier daño** (`is_invincible = true`).
   - Al inicio del efecto (frame 0): se genera una **onda expansiva** de daño a su alrededor.

### Onda expansiva de spawn
- Hitbox cuadrado de **3×3 casillas** centrado en el personaje al aparecer, es decir, 1 casilla en cada dirección:
  ```
  XXX
  XYX
  XXX
  ```
  Traducido a píxeles (con personaje de ≈8px tras reducción del 40%): radio de **8px** en cada dirección cardinal y diagonal.
- La onda mata instantáneamente a cualquier entidad (enemigo o jugador rival) en ese radio.
- Visual: un anillo de energía que se expande rápidamente desde el personaje y desaparece (animación de 4 frames, VFX `vfx_spawn_wave`).
- Sonido: efecto de impacto mágico.

---

## 12. REDUCIR ALTURA DE SALTO UN 50%
**Tipo:** Ajuste de parámetros  
**Archivo afectado:** `PlayerStats.tres`

**Problema:** Los saltos recorren demasiada distancia vertical, casi toda la pantalla.

**Fix:**  
- En `PlayerStats.tres`, reducir `JUMP_VELOCITY` a la mitad del valor actual:
  ```
  # Antes:
  JUMP_VELOCITY = -340.0
  # Después:
  JUMP_VELOCITY = -170.0
  ```
- Ajustar también `WALL_JUMP_VERTICAL` proporcionalmente:
  ```
  # Antes:
  WALL_JUMP_VERTICAL = -360.0
  # Después:
  WALL_JUMP_VERTICAL = -180.0
  ```
- Tras el cambio, verificar que todos los niveles siguen siendo accesibles (que el jugador puede alcanzar las plataformas más altas con el nuevo salto). Si alguna plataforma queda fuera de alcance, bajar su altura en el nivel correspondiente.
- El `WALL_JUMP_PUSH` horizontal NO se reduce — el impulso lateral del zig-zag permanece igual.

---

## 13. WALL JUMP ZIG-ZAG — LIMITAR A UNA SOLA DIAGONAL
**Tipo:** Bug de mecánica  
**Archivo afectado:** `PlayerBase.gd`

**Problema:** El wall jump en zig-zag permite redirigir al personaje de vuelta a la misma pared en bucle, escalando toda la pantalla indefinidamente.

**Fix:**  
- Tras un wall jump zig-zag, activar un flag `wall_jump_used: bool = true`.
- Mientras `wall_jump_used == true`:
  - El personaje puede moverse y caer normalmente.
  - **No puede hacer otro wall jump** hasta que toque el suelo (`is_on_floor()`).
  - Al tocar suelo, resetear `wall_jump_used = false`.
- Esto significa que el zig-zag entre dos paredes solo es posible **si hay suelo intermedio** donde el jugador aterriza y resetea el flag. No puede encadenar wall jumps indefinidamente en el aire.
- El wall jump vertical (hacia arriba, apuntando ↑) **sí se puede encadenar** — no usa este flag. Tiene su propio comportamiento descrito en el punto 14.

---

## 14. NUEVO TIPO DE WALL JUMP: ENGANCHE Y SALTO VERTICAL
**Tipo:** Nueva mecánica (diferenciación del sistema de wall jump)  
**Archivo afectado:** `PlayerBase.gd`, `PlayerStats.tres`

**Descripción:**  
Se añade un segundo tipo de wall jump claramente diferenciado del zig-zag. El jugador debe elegir explícitamente cuál ejecutar mediante la dirección de las flechas de apuntado en el momento del salto.

### Diferenciación de los dos tipos de wall jump

| Tipo | Input requerido al saltar tocando pared | Resultado |
|---|---|---|
| **Zig-zag** | Salto + dirección opuesta a la pared (← si pared derecha, → si pared izquierda) | Impulso diagonal alejándose de la pared. Solo 1 por vuelo. |
| **Enganche vertical** | Salto + ↑ (dirección hacia arriba) | El personaje se engancha brevemente a la pared y salta hacia arriba con impulso vertical fuerte. Puede encadenarse. |

### Implementación del enganche vertical
- Al detectar `is_on_wall() AND jump_pressed AND aim_direction == UP`:
  1. Activar estado `wall_hang` durante **0.1s** (freeze breve — el personaje se queda pegado a la pared visualmente con la animación `wall_slide`).
  2. Tras ese breve enganche, aplicar impulso:
     ```
     velocity.x = 0  (o impulso mínimo hacia dentro de la pared — ≈ 20px/s)
     velocity.y = WALL_JUMP_VERTICAL  (-180.0 tras la reducción del punto 12)
     ```
  3. El personaje sube casi verticalmente.
- **Encadenamiento:** El enganche vertical no activa `wall_jump_used`. Se puede repetir en la misma pared siempre que el jugador llegue a ella con velocidad suficiente (tocando la pared con `is_on_wall()`). Esto permite subir una pared alta en múltiples engaches si el jugador tiene habilidad.
- **Sin spam infinito:** El breve `wall_hang` de 0.1s y el hecho de que necesitas llegar a la pared de nuevo (caer un poco antes de volver a enganchar) previene el spam.
- **Diferencia visual con zig-zag:** En el zig-zag el personaje sale disparado diagonalmente. En el enganche vertical sube casi recto, pegado a la pared.

### Asegurarse de que los dos tipos NO se confunden
- El código debe evaluar `aim_direction` en el momento exacto del input de salto, no el movimiento.
- Si `aim_direction` es exactamente ↑ → enganche vertical.
- Si `aim_direction` es la dirección opuesta a la pared → zig-zag.
- Si `aim_direction` es ambigua (diagonal como ↗ o ↖) → usar el componente dominante (más vertical = enganche, más horizontal = zig-zag).
- Añadir al debug overlay (F1) el estado actual del wall jump para facilitar el testing.

---

## NOTAS FINALES PARA ESTA ACTUALIZACIÓN

**Orden de implementación recomendado:**
1. Puntos 8 (reducir tamaño) y 12 (reducir salto) primero — son cambios de parámetros globales que afectan cómo se ven y sienten todos los demás.
2. Puntos 1, 3, 4 — bugs de física/colisión, base del gameplay correcto.
3. Puntos 2, 13, 14 — mecánicas de movimiento y disparo.
4. Puntos 5, 6 — ajuste y mejora de flechas.
5. Puntos 9, 10 — comportamiento de flechas al impactar.
6. Punto 11 — sistema de vidas y respawn (más complejo, añade bastante código nuevo).
7. Punto 7 — UI, lo menos urgente para gameplay.

**Al terminar esta actualización:**
- Actualizar CHANGELOG.md con la versión 0.3.0 (o 0.2.1 si se considera hotfix).
- Cerrar los bugs correspondientes en BUGS.md.
- Añadir al DOCUMENTO_MAESTRO los cambios de parámetros definitivos (`JUMP_VELOCITY`, `proj_gravity`, etc.) una vez ajustados y probados.
