# ACTUALIZACIÓN V0.8.2 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico
**Fecha:** 2026-06-26
**Versión destino:** 0.8.2
**Prerrequisito:** Leer CLAUDE.md antes de empezar. Aplicar sobre la base de código actual (v0.8.0/0.8.1).

---

## ÍNDICE DE CAMBIOS

- Bloque A — Parámetros numéricos (cambios de valores en archivos .tres o constantes)
- Bloque B — Correcciones de física y colisiones
- Bloque C — Correcciones de IA de monstruos
- Bloque D — Corrección del sistema de respawn
- Bloque E — UI: correcciones de crash, escala y cuenta atrás
- Bloque F — Sistema de portales y mini-oleadas (nueva funcionalidad)

Cada punto indica con precisión el archivo afectado, el valor actual, el valor nuevo, y el comportamiento esperado. No hay ambigüedad intencional.

---

# BLOQUE A — PARÁMETROS NUMÉRICOS

## A-1 · Dash del jugador: cooldown ×2

**Archivo:** `resources/PlayerStats.tres`

| Parámetro | Valor actual | Valor nuevo |
|---|---|---|
| `dash_cooldown` | 0.6 s | 1.2 s |

No cambia ningún otro parámetro del dash (velocidad, duración, invulnerabilidad).

---

## A-2 · Velocidad máxima de caída: reducir 50%

**Archivos:** `resources/PlayerStats.tres` y `scripts/monsters/MonsterBase.gd`

| Lugar | Parámetro / expresión | Valor actual | Valor nuevo |
|---|---|---|---|
| `PlayerStats.tres` | `max_fall_speed` | 520.0 | 260.0 |
| `MonsterBase.gd` | cap en la línea `minf(velocity.y + gravity * delta, 600.0)` | 600.0 | 260.0 |

La aceleración (valor de `gravity = 900`) no cambia. Solo se reduce la velocidad terminal de caída.

---

## A-3 · Slime: corrección de velocidad durante el salto de ataque

**Archivo:** `scripts/monsters/Slime.gd`

| Constante | Valor actual | Valor nuevo | Motivo |
|---|---|---|---|
| `JUMP_VX` | 70.0 | 30.0 | Igualar al CHASE_SPEED para eliminar la percepción de "aceleración" al saltar |

El jugador percibe el Slime como más rápido cerca porque su velocidad horizontal durante el salto (70) dobla su velocidad de persecución (30). Con este cambio ambas son iguales.

---

## A-4 · Slime: salto más alto y más lento

**Archivo:** `scripts/monsters/Slime.gd`

El objetivo de diseño es: altura del salto ×2, pero el movimiento se siente más lento y "flotante". Esto requiere reducir la velocidad de impulso Y reducir la gravedad propia del Slime para que alcance la nueva altura con la nueva velocidad.

**Cálculo:**
- Altura actual: `h = JUMP_VY² / (2 × gravity) = 100² / (2 × 900) ≈ 5.6 px`
- Altura objetivo: `5.6 × 2 = 11.1 px`
- Nueva velocidad de impulso: `JUMP_VY = -50` (mitad de la actual → sube más despacio)
- Gravedad necesaria para alcanzar 11.1px con v=50: `g = 50² / (2 × 11.1) ≈ 112 px/s²`

| Constante / propiedad | Valor actual | Valor nuevo |
|---|---|---|
| `JUMP_VY` | -100.0 | -50.0 |
| `gravity` (propiedad heredada de MonsterBase, sobreescribir en `_ready()` del Slime) | 900.0 | 112.0 |

**Implementación:** MonsterBase expone `@export var gravity := 900.0`. En `Slime._ready()`, después de `super._ready()`, asignar `gravity = 112.0`. MonsterBase ya usa `self.gravity` en su loop de física, así que el override es automático.

El cap de velocidad máxima de caída del Slime también se ve afectado por la gravedad menor: con g=112 el Slime tardará mucho más en alcanzar el cap de 260 px/s durante la caída, lo que refuerza la sensación "lenta y flotante". Esto es el comportamiento correcto.

---

## A-5 · Troll: añadir fase de windup al puñetazo

**Archivo:** `scripts/monsters/StoneTroll.gd`

Añadir una nueva constante:

| Constante | Valor |
|---|---|
| `PUNCH_WINDUP_T` | 0.7 s |

El flujo del ataque de puñetazo cambia de:
`condición cumplida → puñetazo inmediato`

A:
`condición cumplida → estado "punch_windup" (0.7s, visual visible) → ejecutar puñetazo`

Ver Bloque C para la especificación de comportamiento.

---

# BLOQUE B — CORRECCIONES DE FÍSICA Y COLISIONES

## B-1 · Monstruos físicamente sólidos (excepto Espectro)

**Archivos:** `scripts/monsters/MonsterBase.gd`, `scripts/monsters/SpecterArcher.gd`, `scripts/characters/PlayerBase.gd`

**Problema:** El jugador puede atravesar físicamente a los monstruos (Slime, Troll, Murciélago) porque MonsterBase tiene `collision_layer = 0`. Los monstruos solo detectan al jugador mediante sus Areas (hurtbox, contact_area), pero no tienen cuerpo físico con el que el jugador colisione.

**Solución:** Añadir una nueva capa de colisión `L_MONSTER_BODY = 128` para el cuerpo físico de los monstruos sólidos. Esta capa es DISTINTA de L_MONSTER_HURT (que es para recibir daño de proyectiles) y se usa solo para la colisión física entre cuerpos.

**Reglas:**
- Slime, StoneTroll, ShadowBat → su `CharacterBody2D` pone `collision_layer` a incluir `L_MONSTER_BODY`
- SpecterArcher → su `CharacterBody2D` NO incluye `L_MONSTER_BODY` (el Espectro es atravesable intencionadamente)
- PlayerBase → su `collision_mask` debe incluir `L_MONSTER_BODY` para que el cuerpo del jugador colisione con el cuerpo del monstruo

**Comportamiento esperado:** El jugador choca contra el Slime, Troll y Murciélago como si fueran paredes vivas (con rebote físico, sin daño). El jugador puede moverse a través del Espectro sin colisión.

**Nota importante:** Esta colisión física NO debe producir daño. El daño por contacto lo sigue gestionando `MonsterBase._check_contact()` a través de su `contact_area` con `is_attack_active`. Añadir la capa física es solo para impedir la superposición visual de sprites.

---

## B-2 · Stomp no atraviesa plataformas (Troll muere sin razón)

**Archivos:** `scripts/characters/PlayerBase.gd`

**Problema:** El `_stomp_ray` (RayCast2D del pie del jugador) tiene `collision_mask = L_STOMP_PLAYER | L_STOMP_MONSTER`. Como no incluye `L_WORLD`, el rayo atraviesa plataformas y detecta la StompHitbox del Troll aunque haya una plataforma de escenario entre el jugador y el monstruo. El jugador aterriza en una plataforma flotante que está directamente encima del Troll, el rayo pasa a través y mata al Troll.

**Solución:** Añadir `L_WORLD` a la `collision_mask` del `_stomp_ray`.

| Parámetro | Valor actual | Valor nuevo |
|---|---|---|
| `_stomp_ray.collision_mask` | `L_STOMP_PLAYER \| L_STOMP_MONSTER` | `L_WORLD \| L_STOMP_PLAYER \| L_STOMP_MONSTER` |

Con `L_WORLD` en la máscara, el RayCast2D se detiene en la primera geometría sólida que encuentra. Si hay una plataforma entre el jugador y el Troll, el rayo impacta la plataforma y no continúa hasta la StompHitbox del Troll.

---

## B-3 · Stomp se activa antes de tocar visualmente al monstruo

**Archivo:** `scripts/characters/PlayerBase.gd`

**Problema:** El stomp mata al monstruo (o jugador) antes de que haya contacto visual. El jugador cae encima de una entidad y esta muere unos pixels antes de que el pie del jugador toque la parte superior del sprite. La sensación es que el stomp tiene una "zona fantasma" prematura.

**Causa probable:** El `_stomp_ray` (RayCast2D que parte desde el jugador hacia abajo) tiene el origen demasiado alto en el cuerpo del jugador (en el centro, no en el pie), o tiene una longitud excesiva. Si el rayo llega varios pixels por delante del pie visual, detecta la `StompHitbox` del objetivo antes de que los sprites se solapen.

**Solución:** Ajustar origen y longitud del `_stomp_ray` para que solo detecte contacto real.

**Especificación:**

| Propiedad del `_stomp_ray` | Valor actual (a verificar) | Valor correcto |
|---|---|---|
| Posición Y del nodo (en local del jugador) | centro del cuerpo (≈ 0) | borde inferior del CollisionShape2D (= `collision_shape_height / 2`) |
| Longitud del rayo (`target_position.y`) | desconocida (verificar) | **3 px** hacia abajo |

**Regla:** El rayo debe partir exactamente del pie del jugador y extenderse solo 3px hacia abajo. Con esto, el stomp solo se registra cuando el pie del jugador ya está a 3px o menos de la parte superior del objetivo — equivalente a contacto visual.

**Nota de compatibilidad:** Este ajuste se aplica al mismo nodo `_stomp_ray` que B-2. B-2 modifica `collision_mask`; B-3 modifica la posición de origen y la longitud. Ambos cambios son compatibles y deben aplicarse juntos.

---

## B-4 · Wall slide se detiene al acabar la pared de una plataforma flotante

**Archivo:** `scripts/characters/PlayerBase.gd`

**Problema:** Cuando el jugador salta contra el lateral de una plataforma flotante fina y empieza el wall slide, el deslizamiento continúa hacia abajo más allá del borde inferior de la plataforma, como si la pared siguiera existiendo. El resultado: el jugador flota en el aire deslizándose sin pared.

**Causa:** La condición de wall slide en el loop de física comprueba `is_on_wall_only()`. En los bordes exactos de los tiles de plataforma, Godot puede devolver `is_on_wall_only() = true` durante un frame extra después de que el cuerpo haya pasado la esquina inferior. Además, el estado FSM `WALL_SLIDE` puede mantenerse un frame después de perder el contacto.

**Solución:** Validación adicional con un RayCast2D lateral corto. En cada frame que el jugador está en wall slide, lanzar un rayo horizontal corto en la dirección de la pared. Si el rayo NO detecta geometría (`L_WORLD`), forzar la transición al estado `FALL` inmediatamente y aplicar gravedad normal.

**Especificación del RayCast de validación:**

| Propiedad | Valor |
|---|---|
| Nombre | `_wall_slide_ray` |
| Posición de origen | centro del cuerpo (0, 0) en espacio local |
| Longitud | 8 px en la dirección hacia la pared (se actualiza en cada frame según `facing`) |
| `collision_mask` | `L_WORLD` |
| Uso de `force_raycast_update()` | sí, en cada frame que el estado sea `WALL_SLIDE` |

**Regla:** Si el jugador está en estado `WALL_SLIDE` y `_wall_slide_ray.is_colliding()` devuelve `false`, cambiar el estado a `FALL` en ese mismo frame.

---

# BLOQUE C — CORRECCIONES DE IA DE MONSTRUOS

## C-1 · Slime no se acelera al acercarse (ya resuelto en A-3 y A-4)

Este punto queda cubierto por los cambios de A-3 (`JUMP_VX = 30`) y A-4 (nueva gravedad del Slime). No hay implementación adicional necesaria.

---

## C-2 · Troll: fase de windup antes del puñetazo

**Archivo:** `scripts/monsters/StoneTroll.gd`

**Comportamiento actual:** Cuando se cumplen las condiciones del puñetazo, el Troll ejecuta `_begin_punch()` inmediatamente.

**Comportamiento nuevo:**
El FSM del Troll añade un nuevo estado `"punch_windup"` que se inserta ANTES del puñetazo.

**Flujo completo del ataque:**

1. Se cumplen las condiciones del puñetazo (jugador al lado, misma altura, `_punch_cd <= 0`)
2. Troll entra en estado `"punch_windup"`:
   - Se queda completamente quieto (`velocity.x = 0`)
   - Se orienta hacia el jugador (actualiza `_dir`)
   - Duración: `PUNCH_WINDUP_T = 0.7s`
   - Señal visual: el sprite del Troll oscila entre su color normal y un rojo más intenso cada 0.1s (frecuencia igual al windup del pedrusco actual). Esto le indica al jugador que viene un golpe.
   - `is_attack_active = false` durante todo el windup (el contacto no mata durante la carga)
3. Al terminar los 0.7s: ejecutar `_begin_punch()` (la lógica actual del puñetazo, sin cambios)

**Cooldown:** El `_punch_cd` se resetea cuando COMIENZA el windup, no cuando ejecuta el golpe.

**Condición de cancelación:** Si durante el windup el jugador se aleja más de `PUNCH_RANGE × 2.5` (= 100px), cancelar el windup, volver a `"chase"`, y NO resetear `_punch_cd` (el Troll puede intentar el puñetazo de nuevo cuando alcance al jugador).

---

## C-3 · Troll: investigación de muerte espontánea

**Archivos:** `scripts/monsters/StoneTroll.gd`, `scripts/characters/PlayerBase.gd`

**Causas confirmadas:**
1. **Stomp a través de plataforma** — cubierto en B-2.
2. **Posible causa secundaria:** El MeleeHitbox del puñetazo del Troll tiene `hits_monsters = false`. Verificar que esta propiedad está correctamente configurada y que el hitbox del puñetazo no puede detectar el hurtbox del propio Troll (el offset del hitbox debe estar fuera del área del hurtbox del Troll).

**Verificación requerida tras aplicar B-2:** Ejecutar MonsterTest con el Troll debajo de una plataforma y el jugador aterrizando sobre ella. Si el Troll deja de morir espontáneamente, B-2 era la causa única. Si sigue ocurriendo, investigar si el Troll tiene algún overlap con su propia `contact_area` o con la `contact_area` de otro monstruo adyacente.

---

## C-4 · Murciélago: solo hace dash cuando tiene línea de visión limpia

**Archivo:** `scripts/monsters/ShadowBat.gd`

**Problema:** El Murciélago intenta hacer el dash de ataque aunque haya una esquina o pared de escenario en medio. El dash se bloquea inmediatamente al inicio y el Murciélago queda atascado en el ciclo PREPARING_DASH → DASHING (colisión inmediata) → RECOVERING.

**Solución:** Antes de iniciar PREPARING_DASH, verificar línea de visión con un RayCast2D desde la posición del Murciélago hacia la posición del jugador.

**Especificación del RayCast de línea de visión:**
- Se ejecuta en el estado TRACKING, justo antes de la decisión de transicionar a PREPARING_DASH
- Dirección: desde `global_position` del Murciélago hasta `player.global_position`
- `collision_mask`: **solo `L_WORLD`** — no incluir capas de monstruos, jugadores, ni proyectiles. Solo geometría de escenario bloquea la LoS.
- Si el rayo NO colisiona con nada: hay línea de visión → puede iniciar PREPARING_DASH normalmente
- Si el rayo SÍ colisiona: hay obstáculo de escenario → no iniciar el dash. El Murciélago permanece en TRACKING, sigue moviéndose para buscar un ángulo limpio, y comprueba la LoS en cada frame hasta que el cooldown expire de nuevo

**Regla de comportamiento:** El Murciélago solo cancela el dash por geometría de escenario. Que haya otro monstruo en medio NO cancela el dash (el Murciélago puede impactar con otro monstruo durante el vuelo, simplemente sigue su trayectoria).

---

# BLOQUE D — CORRECCIÓN DEL SISTEMA DE RESPAWN

## D-1 · El cristal viaja hasta donde está el cadáver, no donde murió el jugador

**Archivos:** `scripts/characters/PlayerBase.gd`, `scripts/ui/StoryMatch.gd`

**Problema actual:** En `PlayerBase.die()`, se guarda `last_death_pos = global_position`. El cadáver (`Corpse`) se crea en esa posición pero luego se desplaza por su impulso de física. En `StoryMatch._respawn_player()`, la animación del cristal viaja a `_player.last_death_pos`, que es la posición de muerte, no la posición final del cadáver.

**Comportamiento correcto:** El cristal debe viajar hasta donde el cadáver descansa finalmente, no al punto donde el jugador murió.

**Solución en dos partes:**

**Parte 1 — PlayerBase:**
- Cuando se crea el `Corpse` en `_spawn_corpse()`, guardar una referencia al nodo Corpse creado: `_last_corpse: Node = null` (variable de instancia)
- Asignar: inmediatamente después de `get_parent().add_child.call_deferred(c)`, guardar la referencia en `_last_corpse = c`
- El `Corpse` debe tener una propiedad accesible `global_position` (ya la tiene por ser Node2D)

**Parte 2 — StoryMatch:**
- En `_respawn_player()`, en lugar de usar `_player.last_death_pos` como destino del cristal, usar la posición actual del `_player._last_corpse` en el momento en que el cristal llega
- Añadir un delay de 0.35s antes de iniciar la animación del cristal (dar tiempo al impulso del cadáver a disiparse y al cadáver a detenerse)
- El target de la animación del cristal es `_player._last_corpse.global_position` (leído en el momento de iniciar la animación, después del delay)
- Si `_player._last_corpse` es null o no es un nodo válido (ej: el cadáver cayó al vacío del nivel 2), usar `_level.safe_respawn_pos(_player.last_death_pos)` como fallback (comportamiento actual)

**Flujo completo de respawn con este cambio:**
1. Jugador muere → `die()` crea el Corpse y guarda referencia en `_last_corpse`
2. El Corpse vuela con impulso de física ~0.3-0.5s
3. Después de 0.35s de delay, `_respawn_player()` lee la posición del cadáver
4. El cristal parte del HUD y viaja en arco hasta donde descansa el cadáver
5. Al llegar el cristal, el jugador reaparece en esa posición (con `safe_respawn_pos()` como ajuste final para no quedar dentro de geometría)

---

# BLOQUE E — UI: CRASH, ESCALA Y CUENTA ATRÁS

## E-1 · Crash al navegar la UI con flechas o WASD

**Archivos:** `scripts/ui/MainMenu.gd`, `scripts/ui/CharacterSelect.gd`, `scripts/ui/OptionsMenu.gd`

**Problema:** Las teclas de flecha y WASD están mapeadas como acciones de movimiento de jugadores (`p1_up`, `p1_left`, etc.) Y son procesadas por el sistema de navegación de UI de Godot (que las lee como `ui_up`, `ui_left`, etc.). Cuando el foco de la UI navega a un nodo sin `focus_mode` configurado, Godot puede entrar en un bucle o intentar ejecutar callbacks inválidos, causando freeze o crash.

**Solución:** Consumir explícitamente los eventos de teclado de movimiento en cada escena de menú para que NO lleguen al sistema de navegación de UI de Godot.

**Implementación:**
- En el `_input()` o `_unhandled_input()` de MainMenu, CharacterSelect y OptionsMenu:
  - Interceptar `InputEventKey` para las teclas: A, D, W, S, flecha izquierda, flecha derecha, flecha arriba, flecha abajo
  - Llamar `get_viewport().set_input_as_handled()` para consumir el evento y evitar que el motor lo procese como navegación de UI
- Gestionar la navegación de los menús exclusivamente con el botón Escape y los clics del ratón (o a través del sistema UIInputBridge especificado en V0.5.1 cuando se implemente, que traduce inputs de jugador a navegación controlada)

**Importante:** NO bloquear Enter, Espacio, ni los botones de ataque/dash — solo los ejes de movimiento (WASD y flechas).

---

## E-2 · Reducir tamaño de botones y texto en toda la UI al 40% del tamaño actual

**Archivos:** `scenes/ui/MainMenu.tscn`, `scenes/ui/CharacterSelect.tscn`, `scenes/ui/OptionsMenu.tscn`

El usuario indica una reducción del 60%, lo que significa que el tamaño final debe ser el 40% del tamaño actual.

**Aplicar a todos los elementos interactivos y textuales en las tres escenas:**

| Elemento | Propiedad | Reducción |
|---|---|---|
| `Button` | `custom_minimum_size` (alto) | ×0.4 del valor actual |
| `Button` | `theme_override_font_size` | ×0.4 del valor actual |
| `Label` (títulos y subtítulos) | `theme_override_font_size` | ×0.4 del valor actual |
| `Label` (texto general) | `theme_override_font_size` | ×0.4 del valor actual |
| Separaciones y márgenes entre elementos | `separation` en containers | ×0.4 del valor actual |

**Referencia de tamaños estimados resultantes** (basada en el font_size de 11px visible en `StoryMatch.gd`):
- Si el tamaño actual de botones es ≈44px de alto → nuevo: ≈18px
- Si el font_size actual de botones es ≈18px → nuevo: ≈7px
- Si el font_size de títulos principales es ≈40px → nuevo: ≈16px

Aplicar la misma reducción proporcional a cualquier elemento de UI en las tres escenas sin excepción. El objetivo es que todos los menús quepan cómodamente en pantalla sin necesidad de scroll.

---

## E-3 · Cuenta atrás 3, 2, 1 al inicio de partida

**Archivos:** `scripts/ui/StoryMatch.gd`, `scripts/ui/VersusMatch.gd`

**Comportamiento requerido:**
1. La escena de juego carga normalmente (nivel, jugadores, HUD)
2. Los jugadores aparecen en sus posiciones de spawn pero están completamente bloqueados: no pueden moverse, saltar, disparar ni hacer dash
3. Se muestra una cuenta atrás en el centro de la pantalla:
   - Durante 1.0s: muestra el texto **"3"**
   - Durante 1.0s: muestra el texto **"2"**
   - Durante 1.0s: muestra el texto **"1"**
   - Durante 0.5s: muestra el texto **"¡YA!"**
4. Al terminar la cuenta atrás, los jugadores quedan habilitados y el juego empieza

**Bloqueo de jugadores durante la cuenta atrás:**
- Añadir un flag booleano `frozen: bool = true` en `PlayerBase`
- Mientras `frozen = true`, ignorar TODOS los inputs (movimiento, salto, dash, ataque)
- Al terminar la cuenta atrás, el controlador del match (StoryMatch o VersusMatch) llama `_player.frozen = false` en todos los jugadores activos

**Los monstruos en modo Historia** tampoco deben spawnearse durante la cuenta atrás. La primera mini-oleada comienza cuando `frozen = false` se establece en los jugadores.

**Display de la cuenta atrás:**
- Texto grande centrado en pantalla (font_size ≈ 48 px en el viewport de 320×180 — usar CanvasLayer de alta prioridad)
- Color: blanco con outline negro
- El texto aparece y desaparece sin animación de fade (cambio directo por simplicidad)

---

# BLOQUE F — SISTEMA DE PORTALES Y MINI-OLEADAS

## F-1 · Sistema de portales de spawn

**Archivos:** `scripts/levels/LevelBase.gd`, `scripts/levels/Level01.gd`, `scripts/levels/Level02.gd`, `scripts/levels/Level03.gd`

**Concepto:** Los monstruos no aparecen instantáneamente en el nivel. Primero aparece un portal visible en una posición específica del nivel, y 1 segundo después el monstruo emerge de él.

**Portal — especificación visual:**
- Color: violeta (`Color(0.6, 0.1, 0.9, 1.0)`)
- Forma: círculo o polígono de 14px de diámetro (placeholder geométrico, como el resto del arte)
- Efecto: pulsa con un parpadeo suave (ciclo de escala de 1.0 a 1.3 en 0.5s)
- Desaparece cuando el monstruo ha emergido completamente (1 segundo después de aparecer el portal)

**Flujo de spawn por monstruo:**
1. El sistema de oleadas ordena el spawn de un monstruo en la posición `SpawnPoint_N`
2. Aparece el portal en `SpawnPoint_N` con la animación de pulso
3. Exactamente 1.0s después, el monstruo se instancia y se añade al nivel en la posición del portal
4. El portal desaparece
5. El monstruo comienza su IA normalmente

**Puntos de spawn en los niveles:**
Cada nivel define en su escena nodos `Marker2D` con el nombre `SpawnPoint_N` (donde N = 1, 2, 3...). El LevelBase expone un método `get_spawn_points() -> Array[Vector2]` que devuelve las posiciones globales de todos estos nodos. Estos puntos deben estar distribuidos por el nivel: algunos en partes altas, algunos en partes bajas, evitando las posiciones de spawn de los jugadores.

**Número de puntos de spawn recomendados por nivel:** 4–6 puntos distribuidos simétricamente en el nivel.

---

## F-2 · Sistema de mini-oleadas dentro de cada oleada

**Archivos:** `scripts/levels/LevelBase.gd`, `scripts/levels/Level01.gd`, `scripts/levels/Level02.gd`, `scripts/levels/Level03.gd`

**Concepto:** Cada "oleada" del modo Historia se compone de 2 a 4 "mini-oleadas". Los monstruos de una mini-oleada spawnan en los primeros segundos de esa mini-oleada. Cuando todos los monstruos de una OLEADA completa están muertos, se considera la oleada superada y se inicia la siguiente.

**Definición de datos de oleada:**
Cada nivel define sus oleadas como un array de arrays de mini-oleadas. Cada mini-oleada es un array de spawns. Cada spawn tiene: `[tipo_monstruo, punto_spawn_index, delay_dentro_de_minioleada]`.

**Delays entre mini-oleadas:** Entre el último spawn de una mini-oleada y el primer spawn de la siguiente: 2.5 a 3.5 segundos (ver tablas abajo).

**Composición de oleadas por nivel:**

### Level 01 — Bosque Antiguo (3 oleadas)

**Oleada 1**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2
- Mini-oleada 2 (t = 3.0s): Troll en spawn_3

**Oleada 2**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2, Slime en spawn_4
- Mini-oleada 2 (t = 2.5s): Troll en spawn_3, Bat en spawn_5

**Oleada 3**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Bat en spawn_2
- Mini-oleada 2 (t = 3.0s): Troll en spawn_3, Slime en spawn_4
- Mini-oleada 3 (t = 6.0s): Specter en spawn_5

---

### Level 02 — Ruinas Voladoras (3 oleadas)

**Oleada 1**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2
- Mini-oleada 2 (t = 2.5s): Specter en spawn_5
- Mini-oleada 3 (t = 5.0s): Troll en spawn_3

**Oleada 2**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2, Slime en spawn_4
- Mini-oleada 2 (t = 2.0s): Bat en spawn_3, Bat en spawn_5
- Mini-oleada 3 (t = 5.0s): Troll en spawn_2, Specter en spawn_4

**Oleada 3**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Bat en spawn_3
- Mini-oleada 2 (t = 2.5s): Specter en spawn_5, Troll en spawn_2
- Mini-oleada 3 (t = 5.5s): Bat en spawn_4, Bat en spawn_1
- Mini-oleada 4 (t = 8.0s): Troll en spawn_3

---

### Level 03 — Torre del Caos (3 oleadas)

**Oleada 1**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2, Specter en spawn_5
- Mini-oleada 2 (t = 2.5s): Troll en spawn_3, Bat en spawn_4
- Mini-oleada 3 (t = 5.5s): Bat en spawn_1, Bat en spawn_2

**Oleada 2**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2, Slime en spawn_3
- Mini-oleada 2 (t = 2.0s): Bat en spawn_4, Bat en spawn_5, Specter en spawn_2
- Mini-oleada 3 (t = 4.5s): Troll en spawn_1, Troll en spawn_3
- Mini-oleada 4 (t = 8.0s): Bat en spawn_4, Bat en spawn_5, Specter en spawn_3

**Oleada 3 — Oleada final**
- Mini-oleada 1 (t = 0s): Slime en spawn_1, Slime en spawn_2, Bat en spawn_4, Bat en spawn_5
- Mini-oleada 2 (t = 2.0s): Specter en spawn_3, Specter en spawn_4
- Mini-oleada 3 (t = 4.5s): Troll en spawn_1, Troll en spawn_2
- Mini-oleada 4 (t = 7.5s): Troll en spawn_3, Bat en spawn_4, Bat en spawn_5, Specter en spawn_2

---

**Notas sobre los índices de spawn_point:** Los índices (spawn_1 a spawn_5) son relativos a cada nivel y deben distribuirse en el nivel por Claude Code al editar las escenas. Como referencia general:
- spawn_1 y spawn_2: zonas laterales altas o medias
- spawn_3: zona central o superior
- spawn_4 y spawn_5: zonas laterales bajas u opuestas a spawn_1/2

Los índices se aplican rotativamente para variar los puntos de entrada. Si un nivel tiene menos de 5 puntos de spawn definidos, usar `spawn_point_index % total_spawn_points` para no salir del array.

---

## TABLA DE VERIFICACIÓN FINAL V0.8.2

| # | Prueba | Criterio de éxito |
|---|---|---|
| A-1 | Hacer dash y volver a hacer dash | Mínimo 1.2s entre dashes |
| A-2 | Caer desde el techo | Velocidad máxima de caída visiblemente más lenta que antes |
| A-3 | Slime saltando cerca del jugador | La velocidad horizontal del salto es igual a la de persecución, sin "acelerón" |
| A-4 | Slime saltando | Alcanza aproximadamente el doble de altura que antes, pero sube más despacio |
| A-5 | Troll con jugador al lado | Hay 0.7s de anticipación visual antes de que ejecute el puñetazo |
| B-1 | Caminar hacia un Slime | El jugador choca contra el Slime como contra una pared, no lo atraviesa |
| B-1 | Caminar hacia el Espectro | El jugador atraviesa el Espectro sin colisión física |
| B-2 | Jugador en plataforma sobre Troll | El Troll NO muere. Solo muere si el jugador le salta encima directamente |
| B-3 | Caer encima de un Slime o Murciélago | El stomp se registra en el frame de contacto visual, no antes |
| B-4 | Wall slide en plataforma flotante fina | El deslizamiento se detiene exactamente al acabar la pared; cae con gravedad normal |
| C-4 | Murciélago con pared entre él y el jugador | El Murciélago NO inicia el dash; espera a tener línea de visión limpia |
| D-1 | Jugador muere con impulso de proyectil | El cristal viaja hasta donde descansa el cadáver, no al punto de muerte |
| E-1 | Pulsar WASD o flechas en MainMenu | No hay crash ni freeze; las teclas no mueven nada en el menú |
| E-2 | Abrir cualquier menú | Todos los botones y textos son notablemente más pequeños (60% reducción) |
| E-3 | Iniciar una partida | Aparece la cuenta atrás 3, 2, 1, ¡YA! antes de poder mover al jugador |
| F-1 | Iniciar partida en modo Historia | No hay monstruos en el mapa. Aparecen portales violeta y 1s después emerge el monstruo |
| F-1 | Portal de spawn | El portal pulsa visualmente y desaparece cuando el monstruo ha emergido |
| F-2 | Primera oleada del Nivel 1 | Primero entran 2 Slimes. 3s después entra el Troll. No entran todos a la vez |
| F-2 | Contador de oleada | La oleada no se marca como completada hasta que todos los monstruos de TODAS las mini-oleadas están muertos |

---

## ORDEN DE IMPLEMENTACIÓN

```
Bloque A (parámetros — 30 min):
  A-1 dash_cooldown en PlayerStats.tres
  A-2 max_fall_speed en PlayerStats.tres + cap en MonsterBase
  A-3 JUMP_VX del Slime
  A-4 JUMP_VY + gravity override del Slime
  A-5 Constante PUNCH_WINDUP_T del Troll

Bloque B (colisiones — 75 min):
  B-1 Añadir L_MONSTER_BODY = 128; configurar capas en MonsterBase y PlayerBase
  B-2 Añadir L_WORLD al collision_mask del _stomp_ray
  B-3 Ajustar origen y longitud del _stomp_ray (borde del pie, 3px de longitud)
  B-4 Añadir _wall_slide_ray y lógica de cancelación de wall slide

Bloque C (IA — 60 min):
  C-2 FSM del Troll: nuevo estado punch_windup
  C-3 Verificación de muerte espontánea del Troll (tras B-2)
  C-4 LoS RayCast en ShadowBat antes de iniciar dash

Bloque D (respawn — 30 min):
  D-1 _last_corpse en PlayerBase + lectura de posición con delay en StoryMatch

Bloque E (UI — 60 min):
  E-1 Consumir input en MainMenu, CharacterSelect, OptionsMenu
  E-2 Escalar elementos UI al 40% en las tres escenas
  E-3 Sistema de cuenta atrás en StoryMatch y VersusMatch

Bloque F (portales y mini-oleadas — 90 min):
  F-1 Portal de spawn (visual + delay de 1s) en LevelBase
  F-2 Redefinir estructura de oleadas en Level01, Level02, Level03

Verificación final: ejecutar la tabla completa (19 pruebas).
Actualizar CHANGELOG.md con versión 0.8.2.
Actualizar CLAUDE.md: parámetros nuevos, nuevo estado del Troll, sistema de portales.
```
