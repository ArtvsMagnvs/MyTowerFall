# CLAUDE.md — Memoria permanente del proyecto
**Leer este archivo COMPLETAMENTE antes de hacer cualquier tarea en este proyecto.**
Actualizar las secciones relevantes cuando se tomen nuevas decisiones o cambie el estado.

---

## VISIÓN DEL PROYECTO

**Título:** Niide: El Círculo Dárico
**Título anterior (obsoleto):** My Tower Fall — ya no usar en ningún sitio
**Género:** Plataformas de acción 2D rápida, multijugador local y modo historia
**Inspiración directa:** TowerFall Ascension
**Plataforma objetivo:** PC (Windows), instalable
**Motor:** Godot 4.x (GDScript), versión exacta del proyecto: `4.3` (declarada en `project.godot`)
**Renderer:** GL Compatibility

### Pilares de diseño (establecidos en el DOCUMENTO_MAESTRO y nunca modificados)
- **Un golpe, un kill.** Sin barras de vida. Ninguna entidad sobrevive a ningún impacto.
- **Velocidad y fluidez.** El movimiento debe sentirse instantáneo y satisfactorio.
- **Diferenciación de clases.** Cada clase cambia radicalmente el estilo de juego.
- **Legibilidad visual.** Todo lo que puede matar debe ser visible y anticipable.

---

## ESTADO ACTUAL

**Versión en `project.godot`:** 0.8.7.3
**Última versión del CHANGELOG:** 0.8.7.3 (2026-06-28) — Gate de plataforma en CHASE (Slime + Troll; Bat/Espectro sin cambios)
**Fase de desarrollo:** Mecánicas de juego terminadas. Arte en placeholder geométrico. Audio API lista, sin assets.
**Siguiente tarea documentada:** Continuar en 0.8.x con ajustes de mecánicas hasta cerrar en 0.9.0.

### Qué está funcionando
- Movimiento completo del jugador (salto, coyote, buffer, wall jump zig-zag, enganche vertical, dash, apuntado 8 dir, ledge grab)
- Dos clases: Arquero y Guerrero, con sus dos ataques cada uno
- Sistema de proyectiles universal (física parabólica, clavado, recogida, atracción gravitacional)
- Cuatro monstruos con IA propia: Slime, Espectro Arquero, Troll de Piedra, Murciélago Sombra
- Stomp (jugador↔jugador y jugador↔monstruo)
- Screen wrapping estilo TowerFall (ghost sprite)
- Sistema de vidas (4 vidas, respawn con onda expansiva, cristal que viaja al cadáver)
- Tres niveles completos (diseño de arena 240×180)
- Modos Versus (mejor de 5 rondas) e Historia (3 niveles, oleadas, 4 vidas)
- HUD con paneles laterales de 40px
- Menús: MainMenu, CharacterSelect, OptionsMenu con remapeo de controles
- Autoloads: VersionManager, ScreenWrapper, DebugManager, InputManager, AudioManager, GameManager, SceneManager
- Suite de tests headless: SmokeTest, MonsterTest, StompTest, IntegrationTest, V03Test, V04Test, V05Test, V051Test, V082Test (B-1/B-2), V083Test (dash atraviesa/wall slide/stomp Troll/cadáver), V083fixTest (stomp descentrado/en movimiento + wall slide al soltar input), V084Test (wall slide sin air-slide), V084uiTest (navegación de menús sin crash), V086Test (anti-stuck 4 monstruos + LoS Bat), V086bTest (anti-stuck encima/debajo con plataforma en medio + Bat no carga dash sin LoS + V0.8.7.2 gate de LoS en TRACKING), FWaveTest (portales/mini-oleadas N1)

### Qué está pendiente (no implementado)
- Arte pixel art (todos los sprites son placeholders geométricos)
- Assets de audio (la API de AudioManager existe pero no hay archivos de sonido)
- (V0.5.1 y V0.8.2 ya aplicadas y verificadas en headless)

---

## ARQUITECTURA

### Resolución y rendering
```
Viewport nativo del juego: 320×180 px
Ventana base: 1280×720 px
Escalado: stretch/mode = "viewport", aspect = "keep"
Filtro de texturas: nearest-neighbor (textures/canvas_textures/default_texture_filter=0)
FPS: 60 (physics_ticks_per_second = 60)
Gravedad global: 900.0 px/s²
```

### Área de juego
```
Arena de juego:   x∈[40, 280], ancho 240px
Paneles HUD:      x∈[0, 40] (P1) y x∈[280, 320] (P2), 40px cada uno
Alto del arena:   180px completos (y∈[0, 180])
Tile size:        10×10 px
Grid del arena:   24×18 tiles
```

### Autoloads (orden de carga en project.godot)
| Autoload | Archivo | Responsabilidad |
|---|---|---|
| VersionManager | autoloads/VersionManager.gd | Versión semántica del juego |
| ScreenWrapper | autoloads/ScreenWrapper.gd | Wrapping estilo Pac-Man, ghost offsets |
| DebugManager | autoloads/DebugManager.gd | Flags GODMODE, SHOW_HITBOXES, INFINITE_DASH; overlay F1 |
| InputManager | autoloads/InputManager.gd | Remapeo por jugador, persistencia en user://input_config.cfg |
| AudioManager | autoloads/AudioManager.gd | play_sfx(), API lista sin assets |
| GameManager | autoloads/GameManager.gd | Modo activo, clases elegidas, puntuaciones, progreso Historia |
| SceneManager | autoloads/SceneManager.gd | Transiciones de escena |

### Capas de colisión (bits, definidas en cada script como constantes)
> NOTA: esquema vigente desde V0.5.1/V0.8.2. Los bits 32/64 (L_STOMP_PLAYER/MONSTER)
> de versiones antiguas quedaron obsoletos al reescribir el stomp con RayCast contra cuerpos.
```
L_WORLD         = 1    TileMap (suelo, paredes, plataformas)
L_PLAYER_HURT   = 2    Hurtbox de jugadores (Area2D, detectable por proyectiles)
L_MONSTER_HURT  = 4    Hurtbox de monstruos (Area2D, detectable por proyectiles)
L_HARMFUL       = 8    Proyectiles en vuelo y contact_area de monstruos
L_PLAYER_BODY   = 16   CharacterBody2D físico de jugadores (colisión entre jugadores)
L_MONSTER_BODY  = 128  (V0.5.1) cuerpo de monstruos — lo golpean los proyectiles (TODOS los monstruos)
L_STOMP_BODY    = 256  (V0.5.1) bit en el cuerpo de entidades stompables — lo detecta el rayo de stomp
L_MONSTER_SOLID = 512  (V0.8.2 B-1) cuerpo físico SÓLIDO que bloquea al jugador. Lo llevan
                       Slime/Troll/Murciélago; el Espectro NO (es atravesable, solid_body=false).
                       El jugador incluye este bit en su collision_mask.
```

### Jerarquía de clases
```
CharacterBody2D
├── PlayerBase (scripts/characters/PlayerBase.gd)
│   ├── ArcherPlayer  (scripts/characters/ArcherPlayer.gd)
│   └── WarriorPlayer (scripts/characters/WarriorPlayer.gd)
└── MonsterBase (scripts/monsters/MonsterBase.gd)
    ├── Slime         (scripts/monsters/Slime.gd)
    ├── StoneTroll    (scripts/monsters/StoneTroll.gd)
    ├── SpecterArcher (scripts/monsters/SpecterArcher.gd)
    └── ShadowBat     (scripts/monsters/ShadowBat.gd)

Area2D
└── ProjectileBase (scripts/projectiles/ProjectileBase.gd)
    NOTA: pendiente migrar a CharacterBody2D (BUG-1 de V0.5.1)

Resource
├── PlayerStats   (scripts/characters/PlayerStats.gd)
│   └── resources/PlayerStats.tres  ← valores canónicos actuales
└── ProjectileStats (scripts/projectiles/ProjectileStats.gd)
    └── resources/ProjectileStats/ArrowStats.tres
```

---

## PARÁMETROS CANÓNICOS ACTUALES

Estos son los valores vigentes en `resources/PlayerStats.tres` y `ArrowStats.tres` a fecha de V0.8.0. **Cualquier cambio de valores debe actualizarse aquí.**

### Jugador (`PlayerStats.tres`)
```
walk_speed          = 78.0   px/s
jump_velocity       = -254.0 px/s    (×2 aplicado en V0.5)
gravity             = 900.0  px/s²   (también en project.godot)
max_fall_speed      = 260.0  px/s    (V0.8.2 A-2: ÷2)
wall_jump_push      = 97.5   px/s    (horizontal)
wall_jump_vertical  = -269.0 px/s    (×2 aplicado en V0.5)
wall_slide_speed    = 60.0   px/s
wall_jump_lock      = 0.15   s
dash_speed          = 240.0  px/s
dash_duration       = 0.12   s       → distancia del dash: 240×0.12 = 28.8px ≈ 29px
dash_cooldown       = 1.2    s       (V0.8.2 A-1: ×2)
dash_invuln_frames  = 6      frames  (≈ 0.1s a 60fps)
coyote_time         = 0.08   s
jump_buffer_time    = 0.1    s
stomp_bounce        = -180.0 px/s
stomp_bounce_held   = -254.0 px/s    (manteniendo salto → encadena stompeos)
ledge_slide_speed   = 30.0   px/s
ledge_max_slide     = 20.0   px
```

### Proyectiles (`ArrowStats.tres`)
```
initial_speed  = 300.0  px/s   (flecha simple)
cone_speed     = 272.0  px/s   (cono ×3 del arquero, -10% de initial_speed)
proj_gravity   = 200.0  px/s²
```

### Altura máxima de salto
`h = v² / (2g) = 254² / (2×900) ≈ 35.8px ≈ 3.6 tiles`

---

## GAMEPLAY — MECÁNICAS IMPLEMENTADAS

### Movimiento del jugador
- **Salto:** Coyote time (0.08s) + jump buffer (0.1s). Soltar el botón a mitad de salto reduce la velocidad al 45%.
- **Wall jump zig-zag:** Puede alternarse entre paredes opuestas indefinidamente sin tocar el suelo. NO puede repetir la misma pared dos veces seguidas. Usa `WallSide enum {NONE, LEFT, RIGHT}` y `_last_wall_jumped`. Se resetea al tocar suelo.
- **Wall hang (enganche vertical):** Apuntando ↑ pegado a una pared. Solo 1 por vuelo (flag `_wall_hang_used`). Dura 0.1s y lanza al jugador recto hacia arriba a `jump_velocity`. NO se encadena con el zig-zag.
- **Wall slide (reescrito V0.8.4/V0.8.5):** lo gobierna SOLO el `_wall_slide_ray` (8px, `L_WORLD`), lanzado fresco cada frame hacia el lado que se PULSA (no se usa `is_on_wall_only()`, que daba lag y "slide fantasma"). **V0.8.5: el rayo se ancla a la altura de los PIES** (`body_size.y*0.5-1`), no del centro, para que el slide se corte justo cuando los pies dejan el final del lateral (antes los pies seguían ~5px en el aire). Sin pared a ≤8px → cae con gravedad normal ese mismo frame. Slide capado a `wall_slide_speed` (60).
- **Ledge grab (V0.8.5):** el deslizamiento al soltar cae de inmediato si el lateral ya no está al lado (rayo `_ledge_ray_low`), evitando deslizar en el aire en plataformas finas.
- **Dash:** Solo en 4 ejes cardinales: izquierda, derecha, arriba. El dash hacia abajo está prohibido. El eje dominante del input gana; en empate, gana horizontal. Durante el dash: invulnerabilidad (`dash_invuln_frames = 6`), esquiva dar y recibir stomp, y **atraviesa físicamente a otros jugadores y monstruos sólidos** (V0.8.3 P1: se retira `L_PLAYER_BODY|L_MONSTER_SOLID` de la máscara al entrar en DASH y se restaura al salir). Fuera del dash, colisión física normal.
- **Ledge grab:** Al caer pegado a una esquina, se agarra. Requiere mantener la dirección hacia la pared para quedarse colgado; soltar = deslizar 30px/s y suelta tras 20px. Snap exacto a la esquina superior (sonda vertical `_ledge_probe`). Saltar desde el grab = salto normal hacia arriba.
- **Screen wrapping vertical:** Al caer por el hueco del suelo y reaparecer por el techo, `velocity.y *= 0.5`. Los proyectiles NO tienen este damping.
- **Apuntado:** 8 direcciones libres. Independiente del movimiento. Determina la dirección de disparo y del dash.
- **Escala de entidad:** Todos los personajes y monstruos a 60% del tamaño original (`ENTITY_SCALE = 0.6`).

### Combate
- **Un golpe = un kill.** Sin excepciones. La muerte genera un `Corpse` con impulso en la dirección del proyectil.
- **Stomp:** Caer sobre la cabeza de una entidad (jugador o monstruo) la mata. Rebote: -180 px/s (o -254 manteniendo salto para encadenar). El dash esquiva dar y recibir stomp. **Detección (reescrita V0.8.4):** PRIMARIO = las colisiones reales de `move_and_slide` (`get_slide_collision`): si el jugador toca un cuerpo stompable (`receive_stomp`) con `normal.y < -0.5` (cayó sobre él), hay stomp — robusto ante monstruos en movimiento e impactos descentrados (el rayo central fallaba porque el cuerpo sólido B-1 desviaba al jugador antes de evaluarlo). SECUNDARIO = `_stomp_ray` de 6px desde el pie (red de seguridad, incluye `L_WORLD` → no atraviesa plataformas, B-2).
- **Impulso de muerte:** El cadáver sale despedido en la dirección del proyectil. Fuerza: 110 (flecha/hacha), 70 (pedrusco), 60 (espectral).
- **Invulnerabilidad post-spawn:** 1.5s con parpadeo.
- **Onda expansiva al respawn:** hitbox 3×3 tiles (24×24px) durante 0.12s.

### Sistema de proyectiles
- **Física:** Parabólica (`proj_gravity = 200 px/s²`). Rotación según trayectoria.
- **Clavado:** Al impactar geometría, las flechas y hachas quedan clavadas 8s (recogibles). Los proyectiles espectrales y piedras desaparecen al impactar.
- **Atracción gravitacional:** Radio = 1.2× la media anchura del objetivo, cono frontal de ±60°. Fuerza como aceleración (400 px/s²), proporcional a la cercanía. Tope: 1.15× velocidad inicial.
- **Munición:** Stock inicial 3, máximo 5. Contador visual sobre el personaje.
- **Recogida:** Caminar sobre una flecha clavada la recoge (+1 munición).

### Arquero (`ArcherPlayer`)
- Color: verde bosque / dorado
- A1 (hold + release): flecha parabólica en la dirección apuntada. Mientras se mantiene el botón, `aim_lock = true` (sin movimiento horizontal). Dispara al soltar.
- A2 (hold 0.5s + release): 3 flechas en cono (±15°). Consume hasta 3 municiones.
- Cooldown A1: 0.35s.

### Guerrero (`WarriorPlayer`)
- Color: rojo carmesí / plata
- `uses_projectiles = false` — no consume munición, no recoge flechas.
- A1: golpe de espada, alcance 28px (2 casillas), hitbox activa 0.06s. Cooldown 0.25s. Golpe disponible en el aire.
- A2 (hold 0.4s + release): carga a 500 px/s, máximo 120px, deja stun 0.2s al final o al chocar con pared.

---

## MONSTRUOS

### Reglas universales de monstruos
- **Un golpe = muere.** Sin barra de vida.
- **Ningún monstruo atraviesa ninguna geometría.** `collision_mask` incluye siempre `L_WORLD`.
- **Anti-stuck (V0.8.6 + reescrito V0.8.7 + V0.8.7.2 + V0.8.7.3):** ningún monstruo se queda inmóvil ni entra en bucle "clavado-cíclico" ante un jugador inalcanzable. **Detección por PROGRESO real + LoS** (en `MonsterBase.is_stuck_no_los`): cada 0.5–0.6s mide el desplazamiento NETO; se considera atascado solo si NO avanzó **Y** NO hay línea de visión al jugador (`has_clear_los`, rayo `L_WORLD` compartido) = hay geometría en medio y no puede atacar. Esto detecta la **oscilación en el sitio** (velocidad alta, avance ~0) que la detección por velocidad de V0.8.6 no veía. **V0.8.7.2 añade:** gate de LoS en CHASE/TRACKING (si un monstruo acumula >0.5s sin LoS al jugador, sale del estado y vuelve a PATROL/FLYING, y no re-engage hasta tener LoS directa). **V0.8.7.3 añade (Slime + Troll solamente):** gate de **PLATAFORMA** — `PLATFORM_Y_TOLERANCE = 14 px` (~1.4 tiles). El Slime solo entra en CHASE si `|dy| < 14 px`; el Troll, análogamente, si `|dy| >= 14 px` patrulla a `PATROL_SPEED` (no persigue). Si el jugador salta a otra plataforma durante la persecución, salida inmediata a PATROL con lock. Inspirado en TowerFall Wiki: Cultists/Slimes/Crows no persiguen entre plataformas — la high ground advantage es real. **El pedrusco del Troll NO se gatea** (puede lanzarlo a otra plataforma si hay LoS). Terrestres (Slime/Troll) → **bloqueo de patrulla** 2.5s (`_patrol_lock`, gira y se aleja → circula con el wrapping). Voladores (Bat/Specter) → **desbloqueo perpendicular** 0.6s (`_unstuck_timer`/`_unstuck_dir`; el Bat usa dirección vertical cuando el jugador está sobre todo arriba/abajo). NO acumula patrullando ni atacando (`reset_stuck`). El pedrusco del Troll exige `has_clear_los` (no atraviesa plataformas). El disparo del Espectro exige `has_clear_los` (no dispara a través de paredes).
- El contacto lateral/inferior solo mata si `is_attack_active = true`. Si no, aplica un rebote suave sin daño.
- `MonsterBase` implementa: hurtbox, stomp hitbox, contact area, ghost sprite wrap, name label, `receive_stomp()`, `die()`.

### Slime (antes "Goblin Saltarín") — ★☆☆
- Color: verde
- Tamaño: 10×12px (post-escala)
- **Patrol:** camina a 15px/s, gira en paredes
- **Chase:** camina a 30px/s hacia el jugador, puede caer de plataformas
- **Windup (0.2s) + salto de ataque:** JUMP_VY = -50, JUMP_VX = 30 (V0.8.2 A-3/A-4). Letal solo en la caída.
- **Gravedad propia reducida:** `gravity = 112` (override en `_ready()`, V0.8.2 A-4): salto el doble de alto y sensación flotante.
- **Land (0.4s):** pausa tras aterrizar, luego vuelve a Chase o Patrol.
- Stompable siempre. Cuerpo SÓLIDO (bloquea al jugador, V0.8.2 B-1).

### Espectro Arquero — ★★☆
- Color: azul violáceo
- Tamaño: 14×18px
- `flying = true`, `stompable = false`
- Mantiene 75-90px de distancia. Retrocede si el jugador se acerca a <40px. Se acerca si está lejos.
- Disparo espectral a 160px/s, sin gravedad. Cooldown 5s. Aim-ahead de 0.3s.
- Rango de detección: 75px.
- No stompable (corona espinosa — no implementada visualmente).
- Colisiona con geometría del mundo (no la atraviesa).
- **Atravesable por el jugador** (`solid_body = false`, V0.8.2 B-1): el cuerpo del jugador NO choca con él (a diferencia de los demás monstruos). Sigue siendo vulnerable a flechas (lleva `L_MONSTER_BODY`).

### Troll de Piedra — ★★☆
- Color: gris
- Tamaño: 20×22px (el más grande)
- Patrol: 20px/s, gira en paredes
- Chase: 35px/s, persigue y puede caer de plataformas
- **Puñetazo:** rango 40px, cooldown 2s, solo si el jugador está al lado a la misma altura. Hitbox visible (VFX amarillo).
  - **Windup de puñetazo (V0.8.2 C-2):** estado FSM `punch_windup` de 0.7s ANTES del golpe, con parpadeo rojo cada 0.1s e `is_attack_active=false`. El `_punch_cd` se resetea al COMENZAR el windup. Si el jugador se aleja >100px (PUNCH_RANGE×2.5) se cancela sin penalizar el cooldown.
- **Pedrusco:** velocidad 160px/s, gravedad 180px/s². Solo si el jugador está POR ENCIMA (dy < -10). Windup visible 0.4s. Cooldown 5s.
- Stompable.

### Murciélago Sombra — ★★★
- Color: morado oscuro
- Tamaño: 16×12px
- `flying = true`, `stompable = true`
- **FLYING:** vuela en línea recta horizontal a 50px/s, rebota en paredes. Pequeña oscilación sinusoidal vertical (±15px alrededor de `_home.y`).
- **TRACKING:** se acerca al jugador manteniéndose a ≥30px. Calcula la dirección del dash a 8 vías. Cooldown aleatorio 1.5–3s.
- **PREPARING_DASH (0.15s, V0.8.6 P2):** quieto, visual comprimido. Señal visual de anticipación (antes 0.2s).
- **TRACKING → PREPARING_DASH (V0.8.2 C-4 + V0.8.7):** antes de lanzarse exige (1) cooldown listo, (2) **línea de visión limpia al jugador** (`has_clear_los`, `L_WORLD`), y (3) que el **camino real del dash** (dirección snappeada a 8, su distancia ≈29px) esté despejado (`path_blocked`). El (3) es clave: el LoS al jugador puede ir en un ángulo libre mientras la dirección snappeada choca con la plataforma — sin esa comprobación el Bat se quedaba "clavado" cargando el dash contra el muro. Otro monstruo en medio NO cancela el dash.
- **DASHING:** 240px/s durante 0.12s (= 28.8px, misma distancia que el dash del jugador). `is_attack_active = true`. Mata al contacto. Para al impactar geometría. Vulnerable a flecha/stomp.
- **RECOVERING (0.4s):** quieto, `is_attack_active = false`. Vulnerable a stomp.
- Nota: el código vigente usa **vuelo en línea recta** con rebote (FLYING state, V0.5.1). El círculo de V0.5 quedó obsoleto.

---

## NIVELES

### Parámetros comunes
- Arena: 240×180px, centrada en x∈[40, 280]
- Tile: 10×10px
- Los tres niveles siguen diseño simétrico con 3 capas de plataformas y paredes para wall jump.
- Todos tienen zonas de wrapping configuradas en ScreenWrapper (llamar `add_zone()` en el nivel).

### Level 01 — Bosque Antiguo (`Level_01_Forest.tscn`)
- Script: `scripts/levels/Level01.gd`

### Level 02 — Ruinas Voladoras (`Level_02_Ruins.tscn`)
- Script: `scripts/levels/Level02.gd`
- Tiene caída mortal (killzone)

### Level 03 — Torre del Caos (`Level_03_Tower.tscn`)
- Script: `scripts/levels/Level03.gd`

---

## MODOS DE JUEGO

### Versus (2 jugadores local)
- Mejor de 5 rondas (`rounds_to_win = 3`)
- Selección de personaje y arena en CharacterSelect
- 4 vidas por jugador por ronda
- Al quedarse sin vidas: pierde la ronda. Al ganar `rounds_to_win` rondas: gana el match.

### Historia (1 jugador)
- 3 niveles en orden (Forest → Ruins → Tower)
- 4 vidas totales (no por nivel)
- **Cuenta atrás 3,2,1,¡YA! al iniciar** (V0.8.2 E-3): jugadores `frozen`; los monstruos no spawnan hasta que termina.
- **Sistema de oleadas con mini-oleadas y portales** (V0.8.2 F): cada oleada se compone de 2–4 mini-oleadas escalonadas. Cada monstruo emerge de un **portal violeta** 1s después de aparecer este. La oleada solo se supera cuando mueren TODOS los monstruos de TODAS sus mini-oleadas. Totales: N1=13, N2=18, N3=30.
- Game Over: "HAS CAÍDO" con opción de reintentar
- El cristal de respawn viaja a la **posición final del cadáver** (V0.8.2 D-1; 0.35s de espera + arco de 0.9s), o spawn seguro si cayó al vacío.

### Versus — cuenta atrás
- V0.8.2 E-3: misma cuenta atrás 3,2,1,¡YA! con ambos jugadores `frozen` al inicio del match.

---

## CONTROLES (por defecto, remapeables)

| Acción | P1 | P2 |
|---|---|---|
| Izquierda | A | ← |
| Derecha | D | → |
| Arriba | W | ↑ |
| Abajo | S | ↓ |
| Salto | Espacio | Enter |
| Dash | LShift | / (BUG-002 abierto) |
| Ataque 1 | Q | K |
| Ataque 2 | E | L |

Los controles se guardan en `user://input_config.cfg`. El remapeo es interactivo por jugador desde OptionsMenu → Controles.

---

## ESTRUCTURA DE CARPETAS

```
My Tower Fall/
├── CLAUDE.md                      ← este archivo
├── project.godot
├── export_presets.cfg
├── docs/
│   ├── DOCUMENTO_MAESTRO.md       ← diseño del juego (v0.3.0, puede estar desactualizado)
│   ├── CHANGELOG.md               ← historial de versiones
│   └── BUGS.md                    ← registro de bugs
├── actualizaciones/
│   ├── Actualización V0.2.md
│   ├── Actualización V0.3.md
│   ├── Actualización V0.4.md
│   └── Actualización V0.5.1.md    ← PENDIENTE DE APLICAR
├── Actualización V0.5.md          ← en raíz (mover a actualizaciones/ si se quiere organizar)
├── resources/
│   ├── PlayerStats.tres           ← parámetros canónicos del jugador
│   └── ProjectileStats/
│       └── ArrowStats.tres        ← parámetros de flechas
├── scenes/
│   ├── characters/
│   │   ├── Archer.tscn
│   │   └── Warrior.tscn
│   ├── levels/
│   │   ├── Level_01_Forest.tscn
│   │   ├── Level_02_Ruins.tscn
│   │   └── Level_03_Tower.tscn
│   ├── monsters/
│   │   ├── Slime.tscn
│   │   ├── StoneTroll.tscn
│   │   ├── SpecterArcher.tscn
│   │   └── ShadowBat.tscn
│   └── ui/
│       ├── MainMenu.tscn
│       ├── CharacterSelect.tscn
│       ├── OptionsMenu.tscn
│       ├── VersusMatch.tscn
│       └── StoryMatch.tscn
├── scripts/
│   ├── autoloads/        (7 autoloads, ver sección Arquitectura)
│   ├── characters/       (PlayerBase, ArcherPlayer, WarriorPlayer, PlayerStats, AmmoCounter, Corpse, MeleeHitbox)
│   ├── monsters/         (MonsterBase, Slime, StoneTroll, SpecterArcher, ShadowBat)
│   ├── projectiles/      (ProjectileBase, ProjectileStats)
│   ├── levels/           (LevelBase, Level01, Level02, Level03)
│   └── ui/               (MainMenu, CharacterSelect, OptionsMenu, ControlsRemapper, HUD, StoryMatch, VersusMatch)
├── tests/
│   ├── SmokeTest.{gd,tscn}
│   ├── MonsterTest.{gd,tscn}
│   ├── StompTest.{gd,tscn}
│   ├── IntegrationTest.{gd,tscn}
│   ├── V03Test.{gd,tscn}
│   ├── V04Test.{gd,tscn}
│   └── V05Test.{gd,tscn}
└── assets/               (vacío — pendiente arte pixel art y audio)
```

---

## CONVENCIONES DE CÓDIGO

### Nombrado
- Clases: `PascalCase` (`PlayerBase`, `ShadowBat`)
- Variables: `snake_case`. Variables privadas internas: prefijo `_` (`_dash_time`, `_ledge_ray_low`)
- Constantes locales: `UPPER_SNAKE_CASE` (`ENTITY_SCALE`, `DASH_SPEED`)
- Acciones de input: `"p1_jump"`, `"p2_dash"` (formato `"p{id}_{accion}"`)
- Método auxiliar para acciones: `func _a(action: String) -> String: return "p%d_%s" % [player_id, action]`

### Patrones obligatorios
- **FSM explícita** en jugadores y monstruos. Los estados son `enum` con nombre descriptivo.
- **`_ai(delta)`** en monstruos — sobreescrito en cada subclase. `MonsterBase._physics_process` llama `_ai(delta)` → `move_and_slide()` → `_update_wrap()` → `_check_contact()`.
- **`call_deferred`** para añadir `Corpse` al árbol: `get_parent().add_child.call_deferred(c)`. NUNCA `add_child` directo dentro de callbacks de colisión.
- **Recursos externos** para parámetros tuneables: `PlayerStats.tres`, `ArrowStats.tres`. No hardcodear valores en el código si el parámetro puede necesitar ajuste.
- **Grupos:** jugadores en `"player"`, monstruos en `"monster"`, proyectiles en `"projectile"`, proyectiles clavados en `"stuck_projectile"`, Slimes en `"slimes"`.
- **`set_meta("entity", self)`** en todas las hurtboxes y stomp hitboxes para recuperar la entidad desde un callback de área.
- **Versión en la cabecera de cada script:** `## Autor: Claude Code · Versión: X.Y.Z`

### Colisiones — reglas que no se rompen
- **Ninguna entidad (jugador, monstruo, proyectil) traversa geometría del escenario.** Esta regla no tiene excepciones.
- `CharacterBody2D` con `move_and_slide()` para jugadores y monstruos.
- Los proyectiles son `Area2D` con movimiento manual actualmente (pendiente migrar a `CharacterBody2D` + `move_and_collide()` en V0.5.1, BUG-1).
- **Plataformas flotantes:** sólidas desde TODOS los lados. `one_way_collision = false`. (Decisión tomada en V0.2, confirmada en V0.4, reforzada en V0.5 y V0.5.1.)

---

## BUGS ABIERTOS

| ID | Severidad | Descripción |
|---|---|---|
| BUG-002 | BAJO | Dash de P2 mapeado a `/` en lugar de RShift. Workaround: remapeo manual. |

Los bugs identificados en la auditoría post-V0.5 están documentados en `actualizaciones/Actualización V0.5.1.md` (Bloque A) y aún no se han aplicado al código:
- BUG-1: ProjectileBase usa Area2D con movimiento manual (tunneling)
- BUG-2: ShadowBat patrol vibra contra paredes (no implementado `_recalculate_home_position`)
- BUG-3: Stomp usa Area2D overlap, no RayCast2D
- BUG-4: SpecterArcher `_clamp_to_bounds()` antes de `move_and_slide()`
- BUG-5: ShadowBat `_dashing()` sin parámetro delta
- BUG-6: MonsterBase versión string no actualizada (0.4.0 → 0.5.0)
- BUG-7: Parámetro `_delta` nombrado incorrectamente en `_process_ledge_hang`

---

## ERRORES CONOCIDOS — NO REPETIR

| Error | Causa | Fix aplicado |
|---|---|---|
| `ProjectileBase.gravity` colisiona con `Area2D.gravity` nativa | Nombre de variable = propiedad nativa de la clase base | Renombrado a `proj_gravity` en todos los scripts (BUG-001, V0.4.0) |
| "Can't change this state while flushing queries" | `Corpse` se añadía al árbol dentro de un callback de colisión | `get_parent().add_child.call_deferred(c)` en PlayerBase y MonsterBase |
| `round()` en GDScript infiere Variant → parse error en runtime | Función `round()` con argumento sin tipo explícito | Usar `roundf()` para float, `roundi()` para int |
| `snapped()` colisiona con nombre de función nativa | Variable nombrada `snapped` | Renombrar siempre las variables que coincidan con builtins |
| Wall jump zig-zag infinito (escalada sin techo) | Flag booleano reseteaba solo al tocar suelo | `WallSide enum` + `_last_wall_jumped` — bloquea repetir la misma pared, permite alternar indefinidamente |
| Non-equal opposite anchors en StoryMatch | `size` explícito en nodo con anclas full-rect | Eliminar `size` explícito cuando las anclas ya dimensionan el nodo |
| Cuelgue/crash del motor al pulsar WASD/flechas en menús | `UIInputBridge` sintetizaba `ui_*` con `Input.parse_input_event`, que re-entra en `_input` con `is_action_just_pressed` aún true el mismo frame → recursión infinita | NUNCA usar `parse_input_event` para traducir input dentro de `_input`. Navegar el foco con la API de `Control` (`find_next/prev_valid_focus`+`grab_focus`) y detección de flanco en `_process` (V0.8.5) |
| Wall slide / detección de "fin de pared" con rayo en el centro del cuerpo | El rayo a la altura del centro mantiene el slide hasta que el CENTRO pasa el borde; los pies siguen ~5px en el aire | Anclar el rayo a la altura de los PIES para cortar cuando los pies dejan el lateral (V0.8.5) |

---

## DECISIONES IMPORTANTES YA TOMADAS

Estas decisiones NO deben revertirse sin motivo documentado:

1. **Un golpe = un kill.** Sin barras de vida en ningún modo.
2. **Plataformas flotantes sólidas desde todos los lados** (`one_way_collision = false`). Decidido en V0.2, revocado brevemente en V0.4 (error), restaurado en V0.5 y confirmado definitivamente en V0.5.1.
3. **Dash hacia abajo: prohibido.** Solo izquierda, derecha, arriba. Desde V0.3 (sin excepción desde entonces).
4. **Dash diagonal: prohibido.** Solo 3 ejes cardinales (izq, der, arriba). Desde V0.5.
5. **Wall hang (enganche vertical): máximo 1 por vuelo.** Independiente del zig-zag.
6. **El título del juego es "Niide: El Círculo Dárico".** No "My Tower Fall". Cambiado en V0.3.
7. **`ENTITY_SCALE = 0.6`** para todos los personajes y monstruos. Aplicado en V0.2.
8. **Arquero dispara al SOLTAR el botón**, no al pulsar.
9. **El contacto lateral/inferior con monstruos solo mata si `is_attack_active = true`.**
10. **El dash esquiva tanto DAR como RECIBIR stomp.**
11. **`call_deferred` obligatorio** al añadir `Corpse` desde callbacks de colisión.
12. **Screen wrapping vertical** reduce `velocity.y *= 0.5` para jugadores y monstruos (no proyectiles).
13. **UI de menús:** tipografía normal (no pixel font), resolución 1280×720, sin blurriness. (Decidido en V0.5.1, pendiente implementar.)

---

## RIESGOS TÉCNICOS CONOCIDOS

| Riesgo | Descripción | Estado |
|---|---|---|
| Tunneling de proyectiles | `ProjectileBase` usa Area2D + movimiento manual. Flechas rápidas pueden atravesar tiles de 10px | Pendiente fix (V0.5.1 BUG-1) |
| Stomp en contactos de alta velocidad | Area2D overlap puede no registrarse si el contacto dura <1 frame | Pendiente fix (V0.5.1 BUG-3) |
| Bat vibración en paredes | Sin recálculo de `_home_position` al colisionar | Pendiente fix (V0.5.1 BUG-2) |
| BUG-002 (P2 dash = `/`) | Godot no distingue LShift/RShift en el mismo teclado | Abierto, workaround manual |
| Arte placeholder | Todos los sprites son geometría (polígonos de color) | Fase 6 del plan — sin fecha |
| Sin audio | AudioManager funcional pero sin archivos de sonido | Sin fecha |

---

## PIPELINE DE DESARROLLO

### Cómo se trabaja en este proyecto
1. Cada sesión de trabajo produce un documento de actualización (`actualizaciones/Actualización VX.Y.md`).
2. El documento de actualización es la instrucción para Claude Code: contiene código exacto, valores exactos y tabla de verificación.
3. Claude Code aplica el documento y actualiza `CHANGELOG.md`.
4. Los bugs encontrados se registran en `docs/BUGS.md`.
5. Después de aplicar una actualización, se hace una auditoría del código para verificar que se implementó correctamente.

### Documentos de actualización existentes
| Documento | Estado |
|---|---|
| actualizaciones/Actualización V0.2.md | Aplicada (v0.5.0) |
| actualizaciones/Actualización V0.3.md | Aplicada (v0.6.0) |
| actualizaciones/Actualización V0.4.md | Aplicada (v0.7.0) |
| Actualización V0.5.md (en raíz) | Aplicada (v0.8.0) |
| actualizaciones/Actualización V0.5.1.md | Aplicada (v0.8.1) |
| actualizaciones/Actualización V0.8.2.md | Aplicada (v0.8.2) |
| actualizaciones/Actualización V0.8.3.md | Aplicada (v0.8.3) |
| (hotfix directo) stomp+wall slide reescritos | Aplicada (v0.8.4) |
| (hotfix directo) wall slide pies + UIInputBridge | Aplicada (v0.8.5) |
| actualizaciones/Actualización V0.8.6.md | Aplicada (v0.8.6) |

### Debug en desarrollo
- `F1`: toggle del overlay de debug (FPS, estado jugador, velocidad, monstruos, última pared, hang)
- Flags en `DebugManager`: `GODMODE`, `SHOW_HITBOXES`, `INFINITE_DASH`
- Tests headless en `tests/` — ejecutar después de cada cambio importante

---

## ASSETS (estado actual)

### Arte
**Todo en placeholder geométrico.** No hay sprites finales.
La lista completa de assets pendientes está en `docs/DOCUMENTO_MAESTRO.md` §9b:
- Personajes: 14 sprites por clase (arquero y guerrero), incluidos frames de animación
- Monstruos: 5×4 sprites por monstruo
- Proyectiles: 8 assets
- VFX: 8 assets
- Tilesets: 3 niveles × 2 tilesets + fondos
- UI: 14 assets
- Intros: 3 ilustraciones de nivel
- Selección de personaje: assets de pantalla CharacterSelect

### Audio
**Sin archivos de sonido.** Los strings de SFX que llama `AudioManager.play_sfx()` son:
`"jump"`, `"land"`, `"dash"`, `"stomp"`, `"death"`, `"spawn"`, `"arrow_shoot"`, `"arrow_impact"`, `"pickup"`, `"sword"`, `"charge_release"`, `"monster_death"`, `"troll_throw"`, `"troll_punch"`, `"specter_shoot"`, `"bat_dive"`

---

## DECISIONES PENDIENTES O CONTRADICTORIAS

### Contradicción 1: Plataformas one-way
- **V0.2 (BUG-003):** Plataformas sólidas por todos los lados (one_way desactivado).
- **V0.4 nota:** "Las plataformas flotantes deberían ser pass-through desde abajo per diseño TowerFall."
- **V0.5 y V0.5.1:** Confirmado definitivamente que NO son pass-through. Sólidas desde todos los lados.
- **Resolución:** La posición final es: **sólidas desde todos los lados, `one_way = false`**. La nota de V0.4 fue un error de criterio, no una decisión adoptada.

### Contradicción 2: ShadowBat — comportamiento de vuelo en patrulla
- **V0.5 (obsoleto):** Vuelo en círculo (`PATROL` state con `_angle` + `sin/cos`).
- **V0.5.1 (vigente en código):** Vuelo en línea recta con rebote en paredes (`FLYING` state).
- **Resolución:** RESUELTO. El código usa línea recta (FLYING). V0.8.2 C-4 añade además la comprobación de línea de visión antes del dash.

### Pendiente sin decidir: Tipografía UI
- V0.5.1 especifica "Inter o Nunito" como opciones, pero no se ha decidido cuál usar.
- Pendiente: descargar la fuente e incluirla en `assets/fonts/`.

### Pendiente sin decidir: Diseño visual de monstruos
- El DOCUMENTO_MAESTRO §9 describe la dirección artística pixel art.
- No hay ningún sprite final creado. Toda la Fase 6 del plan está pendiente.

### Pendiente sin decidir: Gamepad
- InputManager tiene soporte para gamepad 1 / gamepad 2 en el selector de dispositivo.
- No se ha probado ni especificado el mapeo por defecto de gamepad.

---

## ESTRATEGIA DE VERSIONES

```
0.8.x  →  Correcciones y ajustes mecánicos. Cada sub-update de mecánicas sube el patch.
           Ejemplo: V0.5.1 → v0.8.1, siguiente corrección → v0.8.2, etc.

0.9.0  →  HITO: mecánicas 100% completas y sin bugs conocidos.
           Cierre definitivo de programación de gameplay.
           No se toca ninguna mecánica después de este punto.

0.9.x  →  Trabajo exclusivamente estético:
           arte pixel art, sprites, animaciones, UI final, lore, música, sonido.
           Cero cambios de gameplay o física.

1.0.0  →  HITO: juego completo y publicable.
```

**Regla:** ningún cambio de mecánica o física entra en la rama 0.9.x. Si se detecta un bug de gameplay durante la producción artística, se documenta y se evalúa si merece reabrir la rama 0.8.x antes de continuar.

---

## PRÓXIMAS PRIORIDADES (en orden)

1. (Hecho) V0.5.1 → v0.8.1 y V0.8.2 → v0.8.2, ambas aplicadas y verificadas en headless.
2. Verificación manual en editor de los cambios visuales de V0.8.2 (escala UI ×0.4, cuenta atrás, portales) — no cubierta por headless.
3. Continuar en 0.8.x hasta que todas las mecánicas estén limpias → cerrar en 0.9.0.
4. Fase 0.9.x: producción de assets de pixel art y audio (sin fecha).
