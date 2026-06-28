# CHANGELOG — Niide: El Círculo Dárico

Formato: [SemVer](https://semver.org/) — MAJOR.MINOR.PATCH

---

## [0.8.7.2] — 2026-06-28 — Gate de LoS en CHASE/TRACKING + más tiempo de unstuck
V0.8.7 (progreso+LoS) corregía el "clavado indefinido" pero dejaba un bucle feo: el monstruo
camina ~25 px hacia el jugador → entra en CHASE → choca con la base de la plataforma →
unstuck 1.5s → vuelve a entrar en CHASE → repite. El jugador lo percibía como "clavado"
aunque técnicamente avanzara. Además el unstuck perpendicular del Murciélago no servía
cuando el jugador estaba justo encima/debajo (quedaba horizontal y no lo sacaba de debajo
de la plataforma).

### Solución 1 — Más tiempo de unstuck (solución "cinturón")
- **Slime / Troll:** `STUCK_PATROL_T` 1.5s → **2.5s** (más tiempo de patrulla forzada
  alejándose antes de re-perseguir).
- **Espectro / Murciélago:** `UNSTUCK_DURATION` 0.3/0.4s → **0.6s** (más tiempo de
  desbloqueo perpendicular).

### Solución 2 — Gate de LoS en CHASE/TRACKING (solución "de raíz")
Si el monstruo lleva **>0.5s sin línea de visión** al jugador (hay plataforma, suelo o
estructura en medio y no puede alcanzarlo), abandona la persecución y vuelve a PATROL
(o FLYING). La persecución solo se reanuda cuando vuelve a haber LoS directa.
- **Slime / Troll / Murciélago:** nuevo `_no_los_t` y `NO_LOS_THRESHOLD = 0.5s`; en CHASE
  (o TRACKING) el monstruo sale del estado si acumula >0.5s sin LoS. En PATROL (o FLYING)
  ya no re-entra en CHASE/TRACKING si no hay LoS.
- **Espectro:** la misma lógica pero aplicada al **disparo** (no dispara si no hay LoS).
- **Murciélago (extra):** unstuck vertical cuando el jugador está sobre todo arriba/abajo
  (`absf(to_p.y) > absf(to_p.x) * 1.5`) — antes el perpendicular lo dejaba horizontal y no
  lo sacaba de debajo de la plataforma.

### Aplicado también al Slime y al Espectro
El usuario mencionó "Troll y Murciélago" para la Solución 2; la misma lógica se aplicó al
Slime (mismo bucle) y al Espectro (disparaba a través de paredes). Constantes y
velocidades de los monstruos intactas (sin cambios de `CHASE_SPEED`, `PATROL_SPEED`,
`FLY_SPEED`, `DETECT`, `DETECTION_RANGE` ni nada de `PlayerStats.tres`).

### Tests
- `V086bTest` actualizado: F y G ahora aceptan como respuesta anti-stuck válida tanto el
  unstuck perpendicular como la vuelta a FLYING (gate de LoS). E sigue verificando que el
  Troll patrulla y se mueve. **Suite headless completa: 50+ asserts, 0 fallos, 0 regresiones**.

## [0.8.7] — 2026-06-27 — HOTFIX anti-stuck (progreso real + LoS) y dash del Murciélago
El anti-stuck de V0.8.6 (basado en VELOCIDAD) no cubría dos casos reportados: monstruos que
**oscilan en el sitio** (velocidad alta, desplazamiento neto ~0) bajo/sobre un jugador
inalcanzable con plataforma/suelo en medio; y el Murciélago **cargando el dash a través de
una plataforma**. Reescrito con detección por progreso y comprobaciones de línea de visión.

### Anti-stuck por PROGRESO real + línea de visión (los 4 monstruos)
- **Causa raíz:** la detección por `|velocity.x|`/`velocity.length()` no detecta la oscilación izquierda-derecha (o arriba-abajo) en el sitio: la velocidad es alta aunque el monstruo no avance. Por eso el Troll se quedaba "clavado" oscilando bajo/sobre un jugador en una plataforma.
- **Fix (en `MonsterBase`, compartido):** `is_stuck_no_los()` mide el **desplazamiento neto** en una ventana de 0.5–0.6s; se considera atascado solo si NO avanzó **Y** NO hay **línea de visión** al jugador (`has_clear_los`, rayo `L_WORLD`) — es decir, hay geometría en medio y no puede atacar. Si ve al jugador (puede atacarlo) o si avanza, NO se considera atascado. Terrestres → bloqueo de patrulla 1.5s; voladores → desbloqueo perpendicular.
- **Troll:** además, el pedrusco ahora exige `has_clear_los` (no se lanza a través de una plataforma).

### Murciélago: no carga el dash sin línea de visión NI camino despejado
- **Causa raíz:** el LoS comprobaba el ángulo EXACTO al jugador, pero el dash va en dirección **snappeada a 8**; si el ángulo libre y la dirección snappeada diferían, el dash chocaba contra la plataforma → bucle PREPARING→DASHING(choca)→RECOVERING = "clavado cargando el ataque".
- **Fix:** antes de entrar en PREPARING_DASH se exige (1) cooldown listo, (2) **LoS limpia al jugador**, y (3) que el **camino real del dash** (dirección snappeada, su distancia ≈29px) esté **despejado** (`path_blocked`). Si la plataforma está en medio, ni siquiera intenta cargar el ataque.

### Tests
- Nuevo `V086bTest` (3 asserts): Troll bajo jugador elevado con plataforma en medio → circula (no clavado); Bat debajo/encima de plataforma → nunca carga el dash sin LoS ni con el camino bloqueado. Suite headless completa: **45 asserts, 0 fallos**.

## [0.8.6] — 2026-06-27 — IA de monstruos (anti-stuck + ajustes del Murciélago)
Implementación de la **Actualización V0.8.6** (3 puntos). Verificado en headless con escenarios
NO lineales (atascos contra muros, líneas de visión bloqueadas, persecución limpia).

### Punto 1 — Anti-stuck universal (ningún monstruo se queda inmóvil)
- **Terrestres (Slime, Troll):** si en persecución no se desplazan (`is_on_floor()` y `|velocity.x| < 8`) durante 0.6s, vuelven a PATROL. **Refuerzo sobre la spec:** como ambos re-detectan al jugador al instante por distancia (un simple cambio de estado no desatasca), se añade un **bloqueo de patrulla** de 1.5s (`_patrol_lock`) que fuerza la patrulla (girando para alejarse) antes de re-perseguir, garantizando la circulación (con el screen wrapping acaban reencontrando al jugador). NO acumula en `punch_windup`/`windup`/`LAND`.
- **Voladores (Bat, Specter):** si `velocity.length()` < umbral (15/10) durante 0.6/0.5s, ejecutan un **movimiento de desbloqueo perpendicular** al jugador (Bat: 0.4s a 60px/s; Specter: 0.3s a 40px/s) y retoman su comportamiento. El desbloqueo NO dispara dash ni LoS.
- Verificado: V086Test (los 4 monstruos se desatascan y se mueven; persecución limpia NO dispara el anti-stuck).

### Punto 2 — ShadowBat: PREPARING_DASH más corto
- `PREPARE_T` 0.2 → **0.15s** (0.2 × 0.75). La anticipación del dash es más breve.

### Punto 3 — ShadowBat: línea de visión reforzada antes del dash
- Verificado y consolidado el `_los_ray` (origen (0,0), solo `L_WORLD`). Orden de comprobaciones en la transición TRACKING→PREPARING_DASH: 1) cooldown listo, 2) ángulo válido (siempre, vía `_snap_8`), 3) LoS libre (`force_raycast_update` + `is_colliding`). Si hay geometría entre el Bat y el jugador, NO inicia el dash; sigue en TRACKING.
- Verificado: V086Test (pared entre medias → no dash; sin pared → dash).

### Tests
- Nuevo `V086Test` (7 asserts). Suite headless completa: **42 asserts, 0 fallos**.

## [0.8.5] — 2026-06-26 — HOTFIX (wall slide en el aire + cuelgue de UI, causas raíz)
Dos bugs que llevaban varias actualizaciones sin resolverse de verdad. Esta vez se
**reprodujeron en headless** para hallar la causa raíz antes de tocar nada.

### Corregido — "Slide en el aire" al acabar el lateral de una pared/plataforma
- **Causa raíz (reproducida con diagnóstico):** el `_wall_slide_ray` estaba en el CENTRO del cuerpo, así que el wall slide seguía activo hasta que el centro pasaba el borde inferior de la pared — dejando los ~5px inferiores del cuerpo (los pies) deslizándose en el aire por debajo del final del lateral.
- **Fix:** el rayo se ancla ahora a la altura de los **PIES** (`body_size.y*0.5 - 1`). El slide se corta justo cuando los pies dejan el final del lateral (verificado: el pie no rebasa el borde inferior más de ~1.5px, antes ~5px).
- **Extra (plataformas finas):** en plataformas de 6px el comportamiento dominante es el *ledge grab*; su deslizamiento de 20px también podía quedar en el aire. Ahora el ledge slide cae de inmediato si el lateral ya no está al lado (`_ledge_ray_low`).

### Corregido — El juego se congelaba/crasheaba al usar WASD o flechas en los menús
- **Causa raíz (reproducida con diagnóstico):** `UIInputBridge` sintetizaba acciones `ui_*` con `Input.parse_input_event`, que **re-entraba en su propio `_input`** mientras `is_action_just_pressed` seguía siendo true ese mismo frame → recursión infinita → corrupción/cuelgue del motor (errores internos "Unreferenced static string", "Pages in use at exit"). El parche E-1 (consumir teclas) no lo arreglaba porque el bridge sondea el input independientemente de consumir el evento.
- **Fix:** `UIInputBridge` reescrito para mover el foco DIRECTAMENTE con la API de `Control` (`find_next/prev_valid_focus`, `grab_focus`) con detección de flanco en `_process` — sin `parse_input_event`, sin recursión. La activación (Enter/Espacio) la gestiona `ui_accept` por defecto. Se mantiene el consumo de WASD/flechas en los menús para que la navegación sea de un solo paso (sin doble salto con la navegación por defecto). Verificado: V084uiTest (un paso por pulsación con flechas y WASD; sin cuelgue en MainMenu/CharacterSelect/OptionsMenu).

### Tests
- Nuevos `V084Test` (wall slide sin air-slide) y `V084uiTest` (navegación de menús sin crash). Suite headless completa: **35 asserts, 0 fallos**.

## [0.8.4] — 2026-06-26 — HOTFIX (stomp y wall slide reescritos)
Las correcciones de V0.8.2/V0.8.3 para el stomp y el wall slide **fallaban en el juego real**
(no en los tests, que usaban condiciones irreales: monstruo congelado y alineado al píxel, e
input perfecto). Reescritura de ambos sistemas con un enfoque robusto, y tests realistas.

### Corregido — Stomp que no mataba a los monstruos
- **Causa raíz:** con los monstruos sólidos (V0.8.2 B-1), al caer DESCENTRADO sobre un monstruo `move_and_slide` desviaba al jugador de lado en el mismo frame, así que el `_stomp_ray` central —evaluado DESPUÉS del movimiento— apuntaba al vacío. El rayo era demasiado frágil para objetivos pequeños, en movimiento o impactos descentrados.
- **Fix:** el stomp se detecta ahora con las **colisiones reales de `move_and_slide`** (`get_slide_collision`): si el jugador toca un cuerpo stompable con la normal hacia arriba (cayó sobre él), hay stomp — aunque el monstruo se mueva o el contacto sea descentrado. El rayo de 6px se conserva como red de seguridad secundaria. Respeta B-2 de forma natural (si hay plataforma en medio, se colisiona con ella, no con el monstruo). Verificado: V083fixTest (descentrado ±3px en Slime, +5px en Troll, y Slime con IA activa).

### Corregido — Wall slide fantasma (deslizar por el aire sin pared)
- **Causa raíz:** la condición dependía de `is_on_wall_only()`, que Godot reporta con retraso, dejando el slide "pegado" tras acabar la pared.
- **Fix:** el wall slide lo gobierna ahora **solo el rayo lateral** (`_wall_slide_ray`), lanzado fresco cada frame hacia el lado que se pulsa (`force_raycast_update`). Sin pared confirmada a ≤8px en el lado pulsado → no hay slide → cae con gravedad normal ese mismo frame. Sin estado que se quede "pegado". Verificado: V083fixTest (al soltar el input a mitad de slide, la velocidad pasa de 60 a 225 px/s) y V083Test (al acabar la pared, cae de 60 a 260).

### Tests
- Nuevo `V083fixTest` (5 asserts). Suite headless completa: **31 asserts, 0 fallos**.

## [0.8.3] — 2026-06-26
Implementación de la **Actualización V0.8.3** (4 correcciones quirúrgicas, dos de ellas
afinando cambios de V0.8.2). Verificado en headless: nuevo `V083Test` (4 asserts) + suite
completa (26 asserts, 0 fallos).

### Corregido
- **Punto 1 — El dash atraviesa entidades:** al entrar en DASH el jugador retira `L_PLAYER_BODY|L_MONSTER_SOLID` de su `collision_mask` (guardado y restaurado al terminar el dash), atravesando a otros jugadores y a monstruos sólidos. Fuera del dash la colisión física es normal. Independiente de la invulnerabilidad por dash. Verificado: V083 (dash_through_slime: el jugador cruza al Slime).
- **Punto 2 — Wall slide sin pared:** el `_wall_slide_ray` (V0.8.2 B-4) ahora orienta su dirección por la **normal real de la pared** (`get_wall_normal`), no por el input, para ser robusto al salir de un ledge grab o con inercia. Al acabar la pared de una plataforma se transiciona a FALL en el mismo frame. Verificado: V083 (wall_slide_stops: el slide se capa a 60px/s y al acabar la pared cae libre hasta 260px/s).
- **Punto 3 — Stomp en el Troll:** longitud del `_stomp_ray` 3px → **6px** (sigue < 10px, no atraviesa plataformas, mantiene B-2). Investigada la "Causa A" del documento (StompHitbox en `StoneTroll.tscn`): NO aplica — en esta arquitectura el stomp detecta el CUERPO del monstruo (capa `L_STOMP_BODY`, centrado y de ancho completo, construido en código por `MonsterBase`); no existe un nodo StompHitbox que reposicionar. Verificado: V083 (stomp_kills_troll).
- **Punto 4 — Respawn en la posición del cadáver:** ya estaba implementado en V0.8.2 D-1 (`PlayerBase._last_corpse` + `StoryMatch._respawn_player` con delay de 0.35s, lectura de `_last_corpse.global_position` y `safe_respawn_pos`). Revisado y confirmado conforme a la spec. Verificado: V083 (corpse_ref_displaced: el cadáver se desplaza ~35px por el impulso y `_last_corpse` lo refleja).

### Notas
- `scenes/monsters/StoneTroll.tscn` no requirió cambios (solo tiene el script; el cuerpo se construye en `MonsterBase`).

## [0.8.2] — 2026-06-26
Implementación de la **Actualización V0.8.2** (bloques A–F). Verificado en headless
(Smoke/Monster/Stomp/V03/V04/V05/V051/Integration + nuevos V082/FWave/FWave23: 30+ asserts).

### Bloque A — Parámetros
- **A-1** `dash_cooldown` 0.6 → **1.2 s** (`PlayerStats.tres`).
- **A-2** Velocidad terminal de caída ÷2: `max_fall_speed` 520 → **260** (`PlayerStats.tres`) y cap de monstruos 600 → **260** (`MonsterBase`). La aceleración (g=900) no cambia.
- **A-3** Slime `JUMP_VX` 70 → **30** (igual a `CHASE_SPEED`: sin "acelerón" al saltar).
- **A-4** Slime: salto más alto y flotante — `JUMP_VY` -100 → **-50** y gravedad propia `gravity` 900 → **112** (override en `Slime._ready()`). Altura ×2.
- **A-5** Troll: nueva constante `PUNCH_WINDUP_T = 0.7 s`.

### Bloque B — Física y colisiones
- **B-1** **Monstruos físicamente sólidos** (Slime/Troll/Murciélago) vía nuevo bit `L_MONSTER_SOLID=512` + `@export var solid_body`. El **Espectro** lleva `solid_body=false` (atravesable). El jugador añade `L_MONSTER_SOLID` a su `collision_mask`. Se conserva `L_MONSTER_BODY` en TODOS los monstruos para que los proyectiles los maten (incl. Espectro). Verificado (V082).
- **B-2** El `_stomp_ray` incluye `L_WORLD`: el stomp no atraviesa plataformas para matar a un Troll situado debajo. Verificado (V082).
- **B-3** `_stomp_ray` con origen en el pie y **longitud fija 3px**: el stomp solo se registra en contacto real (sin zona fantasma). Posible gracias a B-1 (el cuerpo que cae queda bloqueado sobre el objetivo).
- **B-4** Nuevo `_wall_slide_ray` (8px, `L_WORLD`): el wall slide exige pared real; al pasar la esquina inferior de una plataforma, cae con gravedad normal.

### Bloque C — IA de monstruos
- **C-2** Troll: nuevo estado FSM `punch_windup` (0.7s, parpadeo rojo cada 0.1s, `is_attack_active=false`). El `_punch_cd` se resetea al COMENZAR el windup; si el jugador se aleja >100px se cancela (sin penalizar el cooldown).
- **C-3** Muerte espontánea del Troll resuelta por B-2 (stomp a través de plataforma). `MeleeHitbox` del puñetazo conserva `hits_monsters=false`. Verificado (V082).
- **C-4** Murciélago: `RayCast2D` de línea de visión (solo `L_WORLD`) antes de PREPARING_DASH; no se lanza si hay geometría en medio, sigue buscando ángulo.

### Bloque D — Respawn
- **D-1** El cristal viaja hasta la posición FINAL del cadáver: `PlayerBase._last_corpse` guarda la referencia; `StoryMatch._respawn_player()` espera 0.35s, lee `global_position` del cadáver y aplica `safe_respawn_pos()` (fallback al spawn seguro si el cadáver cayó al vacío).

### Bloque E — UI
- **E-1** MainMenu/CharacterSelect/OptionsMenu consumen WASD y flechas (`set_input_as_handled`) para evitar el freeze por doble navegación; la navegación la mantiene `UIInputBridge`. OptionsMenu NO consume durante el remapeo.
- **E-2** Todos los botones/textos/separaciones de los 3 menús reducidos al **40%** del tamaño anterior.
- **E-3** **Cuenta atrás 3, 2, 1, ¡YA!** al iniciar partida (Historia y Versus): nuevo flag `PlayerBase.frozen` bloquea todo input; los monstruos no spawnan hasta `frozen=false`.

### Bloque F — Portales y mini-oleadas
- **F-1** Los monstruos emergen de un **portal violeta** (`Color(0.6,0.1,0.9)`, círculo 14px, pulso 1.0→1.3 en 0.5s) que aparece 1.0s antes. `LevelBase.get_spawn_points()` (Marker2D `SpawnPoint_*` o `monster_spawns()` por defecto).
- **F-2** Cada oleada se compone de **mini-oleadas** escalonadas (estructura `[t, [[tipo, spawn_num, delay], ...]]`). La oleada solo se supera cuando mueren TODOS los monstruos de TODAS sus mini-oleadas (contadores `_alive` + `_pending`). Composiciones por nivel: N1=13, N2=18, N3=30 monstruos. Verificado (FWave/FWave23).

### Notas técnicas
- Esquema de capas ampliado: `L_MONSTER_SOLID=512` (cuerpo físico sólido, separado de `L_MONSTER_BODY=128` que usan los proyectiles). Esto evita el conflicto de capas del documento, que habría dejado al Espectro inmune a las flechas.
- `PlayerBase.frozen` por defecto `false` (no rompe tests ni instanciación directa); los controladores de match lo activan al spawn.

## [0.8.1] — 2026-06-25
Implementación de la **Actualización V0.5.1** (7 correcciones de auditoría + 4 cambios de
diseño). Verificado en headless (Smoke/Monster/Stomp/V03/V04/V05/V051/Integration: 17 asserts)
y por captura visual del menú.

### Corregido (Bloque A — auditoría)
- **BUG-1** `ProjectileBase` pasa de `Area2D` a **`CharacterBody2D` con `move_and_collide`**: sin tunneling. Golpea geometría (capa mundo) y cuerpos de jugador/monstruo (capas `L_PLAYER_BODY`/`L_MONSTER_BODY`); excepción de colisión con el dueño; recogida por proximidad. Verificado: flecha a 600px/s contra pared de 1 tile no la atraviesa (V051Test).
- **BUG-2/CAMBIO-11** El Murciélago ya no vibra contra paredes (vuelo en línea recta con rebote).
- **BUG-3** **Stomp reescrito con `RayCast2D`** hacia abajo que detecta cuerpos stompables (capa `L_STOMP_BODY`), con `hit_from_inside` y longitud dinámica (anti sub-frame). Determinista para jugador↔monstruo y PvP. Verificado (V03/V05/Stomp tests).
- **BUG-4** El Espectro hace `_clamp_to_bounds()` **después** de `move_and_slide()` (sin jitter ni inserción en geometría).
- **BUG-5** `ShadowBat._dashing(delta)` usa `delta` (consistencia de timing).
- **BUG-6** Versión de cabecera de `MonsterBase` actualizada.
- **BUG-7** Parámetro `delta` correctamente nombrado en `_process_ledge_hang`.

### Cambiado / Añadido (Bloque B — diseño)
- **CAMBIO-8** **UI rediseñada**: `stretch_mode = canvas_items` (texto de menús nítido a resolución real, sin pixelado) + `UITheme` común (fuente del motor, botones con estilo y foco). El HUD del arena se mantiene en su espacio. Verificado por captura a 1280×720.
- **CAMBIO-9** Nuevo `UIInputBridge`: los controles de P1/P2 (direcciones → navegación, salto → confirmar) manejan los menús; el teclado estándar sigue funcionando.
- **CAMBIO-10** Plataformas flotantes **sólidas por todos los lados** (sin one-way): ninguna entidad las atraviesa. Verificado (V051Test).
- **CAMBIO-11** Murciélago: vuelo en línea recta con rebote (no círculo); dash en 8 direcciones a la misma distancia que el dash del jugador (≈29px); no atraviesa geometría.

### Notas técnicas
- El stomp detecta **cuerpos** (no áreas): un `RayCast2D` contra cuerpos es fiable a mitad del paso de física, a diferencia del overlap de `Area2D` (que se reporta con 1 frame de retraso). Cumple el contrato `receive_stomp()` del documento.
- Esquema de capas: `L_PLAYER_BODY=16`, `L_MONSTER_BODY=128`, `L_STOMP_BODY=256` (bit añadido al cuerpo de entidades stompables).

## [0.8.0] — 2026-06-25
Implementación de la **Actualización V0.5** (10 puntos). Correcciones de mecánicas tras
pruebas de V0.4. Verificado en headless (Smoke/Monster/Stomp/Integration/V03/V04/V05).

### Cambiado
- **(1)** Altura de salto ×2: `jump_velocity` -127→**-254**, `wall_jump_vertical` -134.5→**-269** (≈36px).
- **(2)** Dash solo en 4 ejes cardinales (nunca diagonal): el eje dominante gana, abajo no hace nada.
- **(3)** Damping al wrap vertical: jugadores y monstruos reducen `velocity.y` a la mitad al cruzar suelo/techo (los proyectiles no).
- **(4)** Slime ÷2: patrol 30→**15**, chase 60→**30**, salto de ataque -200→**-100**.
- **(9)** Ledge grab: exige **mantener la dirección** hacia la pared; si se suelta, desliza a 30px/s y suelta tras 20px.
- **(10)** Ledge grab: **snap exacto** a la esquina (sonda vertical), no se hunde por debajo del borde.

### Corregido (bugs)
- **(5)** **Stomp reescrito** y unificado (Area2D de pie + StompHitbox por capas): determinista para jugador↔monstruo y jugador↔jugador. Rebote -180 (o -254 manteniendo salto, encadenable). El dash esquiva dar y recibir stomp. El Espectro no es stompeable.
- **(6)** **Murciélago rediseñado**: FSM PATROL→TRACKING→PREPARING_DASH→DASHING→RECOVERING, dash en 8 direcciones con anticipación visible (0.2s), cooldown aleatorio (1.5–3s); no atraviesa geometría; vulnerable a flecha/espada/stomp.
- **(7)** El **Espectro ya no atraviesa geometría** (colisiona con el mundo); auditadas las capas de todas las entidades.
- **(8)** **Atracción de flechas reescrita** como aceleración gravitacional: radio = 1.2× el tamaño del objetivo, cono frontal de 120°, factor por cercanía y tope (1.15× velocidad inicial).
- Corregido parse error en `ShadowBat` (`round`/nombre `snapped`) detectado al cargar el script en runtime.

### Notas técnicas
- El stomp final usa solapamiento de Area2D (no RayCast) por fiabilidad del timing dentro del paso de física; cumple el mismo contrato `receive_stomp()` del documento.

## [0.7.0] — 2026-06-24
Implementación de la **Actualización V0.4** (13 puntos). Cierra la fase de
mecánicas/física/movimiento. Verificado en headless (Smoke/Monster/Stomp/Integration/V03/V04)
y por captura visual.

### Añadido
- **(11)** **Screen wrapping** estilo TowerFall/Pac-Man (nuevo autoload `ScreenWrapper`): jugadores,
  monstruos y proyectiles cruzan los huecos del borde y aparecen por el lado opuesto de forma
  continua (efecto "medio cuerpo en cada lado" con sprite ghost). Zonas de wrap por nivel.
- **(13)** **Área de juego 240×180** con paneles HUD laterales de 40px (vidas apiladas en vertical).
- **(3)** **Dash hacia arriba** restaurado (y diagonal-arriba), misma distancia; el dash hacia abajo sigue prohibido.

### Cambiado
- **(6)** Movimiento y salto −35%: `WALK_SPEED` 120→**78**, `JUMP_VELOCITY` -195→**-127**,
  `WALL_JUMP_PUSH` 150→**97.5**, `WALL_JUMP_VERTICAL` -207→**-134.5** (gravedad sin cambios).
- **(9)** Flechas −20%: `initial_speed` 375→**300**, `cone_speed` 340→**272**, `proj_gravity` 250→**200**.
- **(5)** Impulso de muerte −50%: flecha 220→**110**, pedrusco 140→**70**.
- **(8)** Espectro: cooldown ×2 (**5s**) y rango −50% (**75px**); ahora se acerca, dispara y retrocede.
- **(10)** Zig-zag de pared **por pared** (sin tocar suelo): izq→der→izq indefinido, pero no la misma
  pared dos veces; el enganche vertical mantiene su límite de 1/vuelo independiente.
- **(1)** Troll: **persigue** al jugador (35 px/s, detección 150px) y puede caer de plataformas; su
  golpe ahora es **visible** y solo activo en sus frames (sin "ataque invisible a distancia").
- **(4)** **Goblin Saltarín → Slime** (archivos, clase, escena, etiqueta, grupo `slimes`, referencias).
- **(12)** **Rediseño de los 3 niveles** (simétricos, 3 capas, paredes para wall jump, plataformas
  pass-through, zonas de wrapping) dentro del área 240×180.

### Corregido (bugs)
- **(7)** Ningún proyectil atraviesa ya la geometría: el proyectil del Espectro choca con las
  plataformas y se disipa; flechas/hachas se clavan. Limpieza de proyectiles fuera de límites.
- **(2)** Eliminado el bloqueo de caída de plataforma de los monstruos (ahora persiguen y caen).

## [0.6.0] — 2026-06-24
Implementación de la **Actualización V0.3** (16 puntos). Verificado en headless
(SmokeTest, MonsterTest, StompTest, IntegrationTest y V03Test específico) + captura visual.

### Cambiado
- **(1)** El juego pasa a llamarse **Niide: El Círculo Dárico** (título + subtítulo en el menú, `project.godot`, export).
- **(2)** Altura de salto +15%: `jump_velocity` -170→**-195**, `wall_jump_vertical` -180→**-207**.
- **(3)** Movimiento general −25%: `walk_speed` 160→**120**, `wall_jump_push` 200→**150**, `dash_speed` 400→300.
- **(7)** Dash solo horizontal (sin dash vertical) y `dash_speed` 300→**240** (≈29px de recorrido).
- **(11)** Atracción de flechas más fuerte: fuerza 180→**300**, radio 30→**40**.
- **(12)** Velocidad de flechas −25%: inicial 500→**375**, cono 650→**340**.
- **(8)** El contacto lateral con enemigos pasivos ya **no mata** (solo durante su ataque activo); rebote suave sin daño.

### Corregido (bugs)
- **(5)** El stomp sobre el Goblin funciona **en cualquier estado**, incluso en el aire (hitbox de stomp siempre activa).
- **(6)** Troll: pedrusco más lento (160 px/s) y parabólico (grav 180), cooldown 5s, **windup visible** de 0.4s, y solo lo lanza si el jugador está por encima.
- **(9)** El enganche vertical en pared se limita a **uno por vuelo** y no se encadena con el zig-zag; usa la altura de un salto normal.
- **(4)** Las flechas ya no desaparecen al impactar: quedan **clavadas en el cadáver** (recogibles) y, al desvanecerse este, **caen clavadas al suelo** con su ángulo de impacto (8s).

### Añadido
- **(10)** Nueva mecánica **Ledge Grab**: el jugador se agarra al borde de una plataforma (estado `LEDGE_HANG`), salta o se suelta; auto-soltado a los 3s.
- **(13)** Sistema de **4 vidas en Modo Historia** (HUD P1) con Game Over "HAS CAÍDO" y reinicio de nivel. El cristal de respawn viaja al **cadáver** (o spawn seguro si cayó al vacío); viaje +50% más lento (0.9s) e invulnerabilidad post-spawn 1.0→1.5s.
- **(14)** **Nombres de monstruos** visibles sobre cada uno ("Goblin Saltarín", "Espectro", "Troll", "Murciélago").
- **(15)** Goblin rediseñado: **camina** para desplazarse (PATROL/CHASE) y **solo salta para atacar**; letal solo en la caída del salto.
- **(16)** Balance de IA aplicado a los 4 monstruos según la especificación autoritativa (velocidades, rangos, cadencias, detección de borde de plataforma para no caerse).

## [0.5.0] — 2026-06-23
Implementación de la **Actualización V0.2** (14 puntos: bugs, ajustes y mecánicas nuevas).
Verificado en headless (SmokeTest, MonsterTest, IntegrationTest) y por captura visual.

### Corregido (bugs)
- **(1)** Plataformas flotantes ahora son sólidas por todos los lados (sin `one_way_collision`): no se atraviesan desde abajo.
- **(2A)** El Ataque 1 del Arquero se dispara al **soltar** el botón (no al pulsarlo): permite apuntar antes de soltar.
- **(2B)** Mientras se apunta (Ataque 1 mantenido) el Arquero queda **estático** horizontalmente; las flechas solo cambian la dirección de disparo.
- **(3)** El **stomp en Versus** ahora mata: saltar sobre la cabeza del rival lo elimina y rebota al atacante.
- **(4)** Los jugadores **colisionan físicamente** entre sí (capa `L_PLAYER_BODY`); empuje sin daño por contacto.
- **(5)** Flechas con más alcance: velocidad inicial 320→**500** px/s y gravedad 400→**250** px/s², expuestas en `ArrowStats.tres`.
- **(9)** Las flechas que impactan en un cuerpo se quedan clavadas en él y son **recogibles** mientras el cadáver existe.
- **(13)** El wall jump **zig-zag** se limita a **uno por vuelo** (se resetea al tocar suelo): no más escalada infinita.

### Añadido (mecánicas nuevas)
- **(6)** Atracción magnética sutil de las flechas hacia combatientes cercanos (radio 30px, cono 60°) — no es autoaim.
- **(10)** **Impulso de impacto estilo TowerFall**: el cuerpo muerto sale despedido en la dirección del proyectil (`Corpse` con física, fuerza 220 flecha / 140 pedrusco) y se desvanece en ~2.5s.
- **(11)** **Sistema de 4 vidas + respawn en Versus**: iconos de vida en las esquinas, bola de energía del HUD al punto de spawn, parpadeo + invulnerabilidad 1s y **onda expansiva** (3×3 casillas) que mata al reaparecer. La ronda se pierde al quedarse sin vidas.
- **(14)** **Enganche vertical** como segundo tipo de wall jump (apuntando ↑): breve enganche de 0.1s y subida casi recta, **encadenable** (distinto del zig-zag). Estado del wall jump añadido al overlay de debug (F1).

### Corregido (post-V0.2)
- Error "Can't change this state while flushing queries": el cadáver (`Corpse`) se creaba durante un callback de colisión; ahora se añade al árbol con `call_deferred` (en `PlayerBase` y `MonsterBase`).
- Warnings "non-equal opposite anchors" en `StoryMatch`: se eliminó el `size` explícito en Controls con anclas full-rect (las anclas ya lo dimensionan).

### Cambiado (ajustes)
- **(8)** Personajes y monstruos reducidos al **60%** (escala global `ENTITY_SCALE`), con colisiones reescaladas en consecuencia.
- **(12)** Altura de salto reducida 50%: `jump_velocity` -340→**-170**, `wall_jump_vertical` -360→**-180** (`wall_jump_push` sin cambios). La verticalidad pasa a depender del dash y de los enganches verticales encadenados.
- **(7)** Panel de Controles rediseñado con `ScrollContainer` (todos los bindings accesibles) y botón "Volver" fijo fuera del scroll.

## [0.4.0] — 2026-06-23
Primera implementación jugable (MVP) en **Godot 4.7 / GDScript**. Todo el gameplay
core funciona con arte placeholder geométrico, según las prioridades del documento
(movimiento primero, un golpe = un kill, Versus valida el core, arte después).

### Añadido — Proyecto y arquitectura
- Proyecto Godot 4 a 320×180 (escala entera, filtro nearest), 60 FPS, GL Compatibility
- 6 autoloads: `VersionManager`, `DebugManager`, `InputManager`, `AudioManager`, `GameManager`, `SceneManager`
- Estructura completa de carpetas (scripts/scenes/resources/assets)

### Añadido — Movimiento (Fase 1)
- `PlayerBase`: movimiento horizontal instantáneo, gravedad, salto con **coyote time** y **jump buffer**
- **Wall jump** zig-zag y vertical, con `wall_jump_lock` anti-exploit y wall slide
- **Dash** direccional (8 dir) con ventana de invulnerabilidad, cooldown y estela de fantasmas
- Apuntado independiente en 8 direcciones, squash & stretch en salto/aterrizaje
- Parámetros en `PlayerStats.tres` (tuneable desde el inspector)

### Añadido — Clases y combate (Fase 2)
- `ArcherPlayer`: flecha simple parabólica (A1) y carga → 3 flechas en cono (A2)
- `WarriorPlayer`: golpe de espada de 2 casillas (A1) y carga con golpe (A2)
- Un golpe = un kill; muerte con explosión de partículas; stomp con rebote
- Sistema **universal de proyectiles** (`ProjectileBase`): parábola con gravedad, clavado 8s,
  recogida, contador visual de munición (iconos, máx. 5, stock inicial 3)

### Añadido — Monstruos (Fase 3)
- `MonsterBase` (hurtbox, stomp, contacto letal, detección) + Goblin, Espectro, Troll, Murciélago
  con IA propia (patrol/salto, vuelo+disparo, golpe+pedrusco, circling+picado+stun)

### Añadido — Niveles (Fase 4)
- `LevelBase`: geometría (sólidos + plataformas one-way), fondo con capa parallax,
  killzone de caída mortal y **sistema de oleadas**
- 3 arenas: Bosque Antiguo, Ruinas Voladoras (caída mortal), Torre del Caos

### Añadido — Modos y UI (Fase 5)
- `MainMenu`, `CharacterSelect` (Versus P1/P2/arena · Historia 1 clase)
- **Versus** al mejor de 5 con rondas, respawn e invulnerabilidad temporal
- **Historia**: intro narrativa → oleadas → victoria → siguiente nivel → ending; reintento al morir
- `OptionsMenu`: pestañas Audio (sliders) y Controles con **remapeo interactivo** por jugador,
  resolución de conflictos, selector de dispositivo y persistencia en `user://input_config.cfg`
- HUD (rondas Versus / indicador de oleada / banners)

### Añadido — Debug (Fase 1, obligatorio)
- Overlay con F1 (FPS, estado/velocidad del jugador, monstruos), flags GODMODE/SHOW_HITBOXES/INFINITE_DASH

### Corregido
- `ProjectileBase.gravity` colisionaba con la propiedad nativa de `Area2D` → renombrado a `proj_gravity`
- Inferencia de tipo desde Array Variant en el cono del arquero
- Casts explícitos al instanciar escenas hacia sus tipos derivados

### Notas / desviaciones del MVP (ver README.md)
- Arte: placeholders geométricos (Fase 6 de pixel art pendiente)
- Audio: API lista, sin assets de sonido todavía
- Guerrero melee sin munición; el hacha arrojadiza universal queda preparada en `ProjectileBase`
- Dash por defecto de P2 = `/` (los dos Shift no se distinguen en un mismo teclado)
- Remapeo persistente y por defecto cubre teclado; el gamepad usa la disposición por defecto

## [0.3.0] — 2026-06-23
### Añadido
- Animaciones con descripción de personalidad por clase: arquero (ligero/ágil) y guerrero (pesado/potente)
- Variantes `attack1_air` y `attack2_charge_air` para ambas clases (ataques en el aire)
- Principio de coherencia de personaje en animaciones: anclas de diseño (silueta, paleta, expresión)
- Alcance del ataque básico del guerrero: 2 casillas (≈28px) en la dirección apuntada, hitbox rectangular
- Ataque 2 del arquero y guerrero disponible durante salto y caída libre
- Sección 9b completa: dirección artística unificada con checklist de coherencia
- Lista exhaustiva de todos los assets: personajes (14+14 sprites), monstruos (5×4 sprites), proyectiles (8), VFX (8), tilesets (3 niveles × 2 tilesets+fondos), UI (14 assets), intros (3 ilustraciones), selección de personaje
- Fase 6 del plan de desarrollo expandida con orden de producción y estimación realista (8-12 sesiones)

## [0.2.0] — 2026-06-23
### Añadido
- Sistema de física con gravedad para proyectiles (trayectoria parabólica, `PROJECTILE_GRAVITY = 400 px/s²`)
- Proyectiles se clavan en superficies (suelo, paredes, plataformas) y persisten 8 segundos
- Sistema de recogida de proyectiles: cualquier jugador puede recoger proyectiles clavados
- Contador visual de proyectiles sobre el personaje (iconos pixel art, no números; máx. 5)
- Stock inicial de 3 proyectiles al spawn; máximo 5
- Proyectiles universales: misma física para todas las clases, solo cambia el sprite (flecha/hacha)
- Pantalla de Opciones → pestaña de Controles con remapeo interactivo por jugador
- Soporte de dispositivo independiente por jugador (teclado / gamepad 1 / gamepad 2)
- Persistencia de controles en `user://input_config.cfg`
- Controles por defecto: P1 en WASD+QE+Espacio+Shift, P2 en Flechas+KL+Enter+RShift

## [0.1.0] — 2026-06-23
### Añadido
- Documento maestro de diseño y planificación completo
- Definición del sistema de movimiento (salto, wall jump, dash, dirección)
- Diseño de clases: Arquero y Guerrero con sus ataques
- Diseño de 4 monstruos con comportamientos únicos
- Diseño de 3 niveles (Bosque Antiguo, Ruinas Voladoras, Torre del Caos)
- Estructura de carpetas del proyecto Godot 4
- Plan de desarrollo por fases (0–9)
- Sistema de versionado y debug
