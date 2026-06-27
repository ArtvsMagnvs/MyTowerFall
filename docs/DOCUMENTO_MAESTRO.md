# MY TOWER FALL — DOCUMENTO MAESTRO DE DISEÑO Y PLANIFICACIÓN
**Versión:** 0.3.0  
**Fecha:** 2026-06-23  
**Estado:** Planificación inicial

---

## ÍNDICE
1. [Visión General del Juego](#1-visión-general-del-juego)
2. [Tecnología y Arquitectura](#2-tecnología-y-arquitectura)
3. [Sistema de Movimiento](#3-sistema-de-movimiento)
4. [Clases de Personaje](#4-clases-de-personaje)
5. [Sistema de Combate](#5-sistema-de-combate)
6. [Modos de Juego](#6-modos-de-juego)
7. [Monstruos y Enemigos](#7-monstruos-y-enemigos)
8. [Niveles y Escenarios](#8-niveles-y-escenarios)
9. [Estilo Visual Pixel Art](#9-estilo-visual-pixel-art)
10. [Menú Principal y UI](#10-menú-principal-y-ui)
11. [Estructura de Carpetas del Proyecto](#11-estructura-de-carpetas-del-proyecto)
12. [Plan de Desarrollo por Fases](#12-plan-de-desarrollo-por-fases)
13. [Sistema de Versiones y Debug](#13-sistema-de-versiones-y-debug)
14. [Registro de Cambios y Errores](#14-registro-de-cambios-y-errores)

---

## 1. VISIÓN GENERAL DEL JUEGO

**Título:** My Tower Fall  
**Género:** Plataformas de acción rápida, multijugador local y modo historia  
**Inspiración:** TowerFall Ascension  
**Plataforma objetivo:** PC (Windows), instalable  
**Motor:** Godot 4.x (GDScript)

### Concepto Central
My Tower Fall es un juego de plataformas de acción 2D pixel art donde la velocidad y la habilidad son la clave. Los jugadores controlan héroes de diferentes clases en arenas estáticas llenas de plataformas y paredes. Cada combate es letal: **un solo golpe mata**. Esto obliga a dominar el movimiento, el timing y la lectura del enemigo.

A diferencia de TowerFall, los personajes no son arquetipos intercambiables: cada clase tiene un estilo de juego único que cambia radicalmente la forma de jugar.

### Pillares de diseño
- **Velocidad y fluidez:** El movimiento debe sentirse instantáneo y satisfactorio.
- **Un golpe, un kill:** Sin barras de vida. La tensión es máxima en cada intercambio.
- **Lectura y anticipación:** La habilidad viene de predecir y reaccionar, no de stats.
- **Pixel Art vivo y expresivo:** El juego debe ser hermoso y lleno de personalidad.

---

## 2. TECNOLOGÍA Y ARQUITECTURA

### Motor: Godot 4.x
- **Lenguaje:** GDScript (y C# para sistemas de alto rendimiento si es necesario)
- **Renderer:** Compatibilidad 2D (OpenGL/Vulkan)
- **Resolución base:** 320×180 px (escala entera x4 = 1280×720, x6 = 1920×1080)
- **FPS objetivo:** 60 FPS constantes

### Por qué Godot 4
- Gratuito y open source
- Excelente soporte pixel art (filtrado nearest-neighbor nativo)
- Input handling de baja latencia ideal para juegos de acción
- Export a Windows .exe instalable sin dependencias externas
- Física y CharacterBody2D perfectos para plataformero

### Arquitectura General
```
Autoloads (Singletons):
├── GameManager      → Estado global, modo de juego activo, puntuaciones
├── SceneManager     → Transiciones de escena, carga/descarga
├── InputManager     → Mappings de controles, remapeo dinámico, detección gamepad/teclado, persistencia en user://input_config.cfg
├── AudioManager     → Pool de sonidos, música, gestión de volumen
├── DebugManager     → Overlay debug, logs, flags de desarrollo
└── VersionManager   → Número de versión, changelogs en runtime

Escenas principales:
├── MainMenu         → Menú principal
├── CharacterSelect  → Selección de personaje
├── VersusMatch      → Partida PvP local
├── StoryMode        → Controlador del modo historia
└── Level_XX         → Escenas de nivel individuales
```

### Convenciones de código
- Nombres de clases: `PascalCase`
- Nombres de variables y funciones: `snake_case`
- Constantes: `UPPER_SNAKE_CASE`
- Señales: prefijo `on_` → `on_player_died`
- Cada archivo `.gd` tiene cabecera con: clase, autor, versión, descripción
- Máximo 200 líneas por archivo; extraer en sub-clases si se supera

---

## 3. SISTEMA DE MOVIMIENTO

> **PRIORIDAD MÁXIMA.** El movimiento es el alma del juego. Debe ser preciso, fluido y rápido. Cualquier imprecisión en el movimiento es un bug crítico.

### Movimientos disponibles

| Acción | Input | Descripción |
|---|---|---|
| Moverse | ← → | Desplazamiento horizontal en suelo y aire |
| Salto | Espacio / A (gamepad) | Salto estándar |
| Wall Jump Zig-Zag | Espacio + dirección opuesta a la pared | Salto desde la pared hacia el lado contrario (impulso diagonal) |
| Wall Jump Vertical | Espacio + ↑ tocando la pared | Salto vertical hacia arriba desde la pared |
| Dash | Shift / B (gamepad) | Dash rápido en la dirección actual; ventana de invulnerabilidad breve |
| Ataque 1 | X / X (gamepad) | Ataque rápido (ver clase) |
| Ataque 2 (carga) | X (hold) / X hold | Ataque cargado (ver clase) |
| Apuntar | ← ↑ ↓ → | Cambia la dirección de ataque (independiente del movimiento) |

### Detalles técnicos del movimiento

#### Parámetros base (ajustables en `PlayerStats` resource)
```
WALK_SPEED          = 78.0   px/s
JUMP_VELOCITY       = -254.0 px/s   (V0.5 p.1: ×2 → ≈36px de altura)
GRAVITY             = 900.0  px/s²
WALL_JUMP_PUSH      = 97.5   px/s
WALL_JUMP_VERTICAL  = -269.0 px/s   (V0.5 p.1; el enganche vertical usa JUMP_VELOCITY)
DASH_SPEED          = 240.0  px/s   (V0.5 p.2: SOLO 4 ejes cardinales; abajo prohibido)
DASH_DURATION       = 0.12   s
STOMP_BOUNCE        = -180.0 px/s   (V0.5 p.5; -254 manteniendo salto, encadenable)
LEDGE_SLIDE_SPEED   = 30.0   px/s   (V0.5 p.9)
DASH_COOLDOWN       = 0.6    s
DASH_INVULN_FRAMES  = 6      frames (ventana de invulnerabilidad)
COYOTE_TIME         = 0.08   s (permite saltar poco después de caer del borde)
JUMP_BUFFER_TIME    = 0.1    s (input buffer: guarda el salto si se presiona antes de tocar suelo)
```

#### Wall Jump — lógica detallada
- El personaje debe estar en contacto con una pared (`is_on_wall()`)
- Se distinguen dos tipos:
  - **Zig-zag:** El jugador presiona salto + dirección opuesta a la pared → `velocity.x = WALL_JUMP_PUSH * -wall_normal.x`, `velocity.y = JUMP_VELOCITY`
  - **Vertical:** El jugador presiona salto + ↑ → `velocity.x = 0` (o muy poco impulso), `velocity.y = WALL_JUMP_VERTICAL`
- Tras un wall jump hay un pequeño `wall_jump_lock` de 0.15s donde el jugador no puede re-agarrar la misma pared (evita subida infinita exploiting)

#### Dash — lógica detallada
- Dirección del dash: la última dirección de movimiento (`last_direction`) o la dirección apuntada
- Durante el dash: gravedad desactivada, colisiones con proyectiles desactivadas (invulnerabilidad)
- No se puede hacer dash mientras se está haciendo dash
- Visual: ghost trail (sprites fantasma en la estela del dash, alpha decreciente)
- Sonido: swoosh característico

#### Coyote Time y Jump Buffer
- **Coyote time:** Permite saltar durante `COYOTE_TIME` segundos después de salir de una plataforma. Hace el juego más justo y fluido.
- **Jump buffer:** Si el jugador presiona salto `JUMP_BUFFER_TIME` antes de aterrizar, el salto se ejecuta en cuanto toca el suelo. Elimina la frustración de saltos fallidos.

#### Feel del movimiento
- **Aceleración inmediata:** Sin rampa de velocidad. El personaje alcanza `WALK_SPEED` en un frame.
- **Frenado inmediato:** Al soltar la dirección, el personaje para en seco (no hay deslizamiento).
- **Caída rápida:** La gravedad es alta para que el arco del salto sea tenso y preciso.
- **Squash & Stretch:** Al aterrizar, el sprite se aplasta brevemente (2-3 frames). Al saltar, se estira.

---

## 4. CLASES DE PERSONAJE

### 4.1 Arquero

**Concepto:** Combatiente a distancia ágil. Controla el espacio con flechas. Frágil pero letal desde lejos.

**Visual:** Figura esbelta con capucha, arco largo élfico, quiver en la espalda. Colores: verde bosque y dorado. Expresión astuta.

#### Ataque 1 — Flecha Simple
- **Input:** X (tap)
- **Descripción:** Dispara una flecha en la dirección apuntada.
- **Velocidad proyectil:** 320 px/s (velocidad inicial)
- **Cooldown:** 0.35s (permite disparo rítmico sin spam)
- **Física:** Las flechas están sujetas a la gravedad (`PROJECTILE_GRAVITY = 400 px/s²`, menor que la gravedad del jugador para dar más alcance útil). La trayectoria es una parábola. Si apunta recto (←→), la flecha caerá gradualmente. Si apunta en diagonal hacia arriba (↗ ↖), la flecha sube y luego cae — permite disparos en arco sobre obstáculos.
- **Clavado en superficies:** Al impactar en una pared, suelo o plataforma sin golpear a nadie, la flecha queda clavada físicamente en esa superficie durante 8 segundos. Se puede clavar en el suelo después de una parábola, como en TowerFall.
- **Recogida:** El jugador puede recoger cualquier flecha clavada (propia o del rival) pasando por encima o tocándola. Ver sección de Sistema de Proyectiles.
- **Impacto en entidad:** Mata en un hit a cualquier jugador o monstruo.

#### Ataque 2 — Tiro en Cono (carga)
- **Input:** X (hold ≥ 0.5s, release)
- **Descripción:** Carga el arco y dispara 3 flechas en cono (centro + ±15° de separación). Las flechas tienen mayor velocidad inicial, por lo que la parábola es más tendida y el alcance efectivo mayor.
- **Velocidad proyectil:** 450 px/s inicial (la gravedad es la misma, pero la mayor velocidad aplana la trayectoria)
- **Se puede cargar y soltar en el aire:** Sí. El jugador puede iniciar la carga mientras salta o cae. La restricción de movimiento durante la carga aplica también en el aire (el control horizontal se reduce al 50%, la gravedad sigue actuando con normalidad). Esto permite disparos en cono desde arriba hacia abajo o en diagonal mientras se cae.
- **Visual de carga:** El arco se tensa, efecto de brillo en la cuerda, partículas de energía. En el aire, la animación de carga se combina con la pose de `fall` — el arquero carga el arco mientras cae, con el cuerpo ligeramente inclinado hacia la dirección de disparo.
- **Al soltarlo tarde (hold > 1.5s):** No hay penalización, el disparo ya está cargado al máximo desde los 0.5s
- **Restricción de movimiento durante carga:** Velocidad horizontal reducida al 50% (suelo y aire)

---

### 4.2 Guerrero

**Concepto:** Combatiente cuerpo a cuerpo explosivo. Controla el espacio con ataques de área y cargas. Necesita acercarse, pero cuando lo hace es devastador.

**Visual:** Figura robusta y baja, armadura de placas parcial (hombros grandes, sin casco o con yelmo abierto), espada ancha de fantasy. Colores: rojo carmesí y plata oxidada. Expresión feroz.

#### Ataque 1 — Golpe de Espada
- **Input:** X (tap)
- **Descripción:** Golpe de espada en la dirección apuntada (↑ ↓ ← →). Sin desplazamiento.
- **Alcance:** 2 "casillas" en la dirección apuntada. Si el guerrero ocupa 1 casilla, el daño cubre las 2 casillas inmediatamente delante: `[Guerrero][X][X]`. Esto se traduce en ≈ 28px de hitbox (2 × el ancho del personaje, ≈ 14px base).
- **Hitbox:** Rectángulo de 28×10px extendido desde el borde del personaje en la dirección apuntada. Para ataques verticales (↑ ↓): 10×28px desde la cabeza o los pies.
- **Duración del hitbox:** 3 frames (0.05s)
- **Cooldown:** 0.25s — permite combos rítmicos
- **Se puede ejecutar en el aire:** Sí. El ataque 1 funciona igual en suelo, salto, caída o wall slide.
- **Visual:** Flash de la espada con trail de luz, el arc de luz cubre los 2 casillas de alcance

#### Ataque 2 — Carga con Golpe
- **Input:** X (hold ≥ 0.4s, release)
- **Descripción:** El guerrero carga en la dirección apuntada con gran velocidad y golpea al final de la carga o al impactar con una entidad.
- **Velocidad de carga:** 500 px/s
- **Distancia máxima:** 120px (o hasta chocar con pared/enemigo)
- **Hitbox:** Todo el cuerpo durante la carga (puede matar a cualquier entidad que toque)
- **Se puede cargar y soltar en el aire:** Sí. El jugador puede iniciar la carga mientras salta o cae. Al soltar en el aire, la carga se ejecuta en la dirección apuntada sobreescribiendo la velocidad actual — si apunta hacia abajo (↓), el guerrero se lanza en picado; si apunta en diagonal (↘), la trayectoria es diagonal. La gravedad queda desactivada durante los 120px de carga (igual que en suelo).
- **Visual de carga en el aire:** En el aire, el guerrero adopta una postura de tensión máxima (encogido, espada atrás), con partículas de energía más intensas que en suelo. La animación `attack2_charge_air` es ligeramente diferente a la de suelo para transmitir que está suspendido a punto de explotar.
- **Post-carga:** Pequeño stun de 0.2s (el guerrero recupera compostura). Si la carga fue en el aire, el stun sucede en el punto de aterrizaje o impacto.
- **Restricción:** No se puede cambiar de dirección durante la carga

---

## 5. SISTEMA DE COMBATE

### Regla de oro: Un golpe, un kill
- No hay puntos de vida. Cualquier impacto letal mata instantáneamente.
- **Lo que mata:**
  - Flecha del arquero (cualquier dirección)
  - Golpe de espada del guerrero (dentro del hitbox)
  - Carga del guerrero (contacto durante la carga)
  - Saltar sobre un monstruo (stomp)
  - Proyectil o ataque de monstruo
- **Lo que no mata:**
  - Dash (ventana de invulnerabilidad — esquiva ataques)
  - Colisión de empuje con otra entidad sin ataque activo

### Muerte y respawn (Versus)
- Al morir, el personaje explota en partículas pixel art con sonido dramático
- En Versus: respawn tras 2 segundos en una de las zonas de spawn aleatorias
- Se contabilizan kills por ronda

### Muerte (Modo Historia)
- Al morir, pantalla de "YOU DIED" con opción de continuar desde el checkpoint del nivel
- Checkpoints: al entrar a cada nivel / tras matar la mitad de los enemigos en niveles con muchos enemigos

### Stomp (saltar sobre enemigos)
- Si el jugador cae sobre la hitbox superior de un monstruo, el monstruo muere
- El jugador recibe un pequeño rebote hacia arriba tras el stomp
- No funciona sobre monstruos voladores con hitbox superior protegida (tipo espinas arriba)

### Dirección de ataque
- El jugador puede apuntar en 8 direcciones con las teclas de dirección (independiente del movimiento)
- La última dirección presionada determina el ángulo de ataque
- Si no se presiona dirección, se ataca en la dirección en que mira el personaje

---

## 5b. SISTEMA DE PROYECTILES

> Esta sección cubre la física, recogida y universalidad de los proyectiles. Es un sistema transversal que afecta a todas las clases y monstruos.

### Física con gravedad
Todos los proyectiles lanzados por jugadores (y algunos de monstruos) obedecen la gravedad, igual que en TowerFall. **No viajan en línea recta.**

```
PROJECTILE_GRAVITY = 400.0  px/s²   (valor base; menos que la gravedad del jugador: 900)
# V0.4 p.9: las flechas usan grav 200 px/s², velocidad inicial 300 y cono 272 (ArrowStats.tres)
#          para una trayectoria más tendida y mayor alcance en horizontal.
# V0.2 p.6: atracción magnética sutil hacia combatientes (radio 30px, cono 60°).
# V0.2 p.10: impulso de impacto al cuerpo muerto (flecha 220, pedrusco 140).
```

- La trayectoria es una **parábola**. La velocidad inicial y el ángulo de disparo determinan el alcance y la altura del arco.
- Disparar hacia arriba permite tiros en arco que superan obstáculos y caen sobre enemigos.
- Disparar horizontal hace que la flecha caiga progresivamente — a corta distancia es precisa, a larga distancia hay que apuntar ligeramente hacia arriba para compensar.
- Los proyectiles de monstruos (proyectil espectral del Espectro Arquero, pedrusco del Troll) también usan gravedad, con sus propios valores de `PROJECTILE_GRAVITY` definidos en sus respectivos `Stats.tres`.

### Clavado en superficies
Cuando un proyectil de jugador impacta en una superficie sin haber golpeado a una entidad, queda **clavado físicamente** en esa superficie:
- Suelos, plataformas y paredes pueden recibir proyectiles clavados.
- El proyectil clavado permanece en la escena durante **8 segundos** y luego desaparece (con animación de fundido).
- Visualmente: el proyectil queda incrustado en la textura con el ángulo de impacto (no siempre recto — depende de la trayectoria al chocar).
- Los proyectiles clavados son **elementos físicos del nivel** — los jugadores deben evitar caminar sobre flechas enemigas clavadas en el suelo.

### Sistema de Recogida de Proyectiles
Los jugadores pueden recoger proyectiles clavados (propios o del rival) para reponer su munición.

- **¿Cómo se recoge?** El jugador pasa por encima de un proyectil clavado en el suelo o plataforma, o toca uno clavado en la pared (al hacer wall slide sobre él).
- **Efecto al recoger:** El proyectil desaparece con un pequeño efecto de partículas y el contador del jugador sube en 1.
- **Stock máximo:** 5 proyectiles por jugador.
- **Stock inicial:** 3 proyectiles al empezar cada ronda o al aparecer (respawn).

### Proyectiles Universales — Forma por Clase
**Todos los jugadores comparten el mismo sistema de proyectiles.** Lo que cambia es la representación visual: cada clase tiene su propio sprite de proyectil, pero las reglas físicas son idénticas.

| Clase | Sprite del proyectil | Sprite clavado |
|---|---|---|
| Arquero | Flecha con plumas | Flecha clavada en ángulo |
| Guerrero | Hacha arrojadiza | Hacha clavada en la superficie |

- Si en el futuro se añaden más clases, cada una tendrá su propio sprite de proyectil (cuchillo, kunai, hueso mágico, etc.), pero el comportamiento físico será el mismo.
- `ProjectileBase.gd` gestiona toda la física y lógica. Cada clase instancia un proyectil con un parámetro `projectile_sprite` que define qué sprite usar.
- Esto significa que un Guerrero puede recoger una flecha del Arquero: al recogerla, se convierte en un hacha en su inventario (cambia el sprite). La física y el daño son idénticos.

### Contador Visual de Proyectiles (HUD sobre el personaje)
Encima de cada jugador hay un contador de munición representado con **iconos pixel art** del proyectil de esa clase, no con números.

- **Arquero:** Se muestran hasta 5 flechas pequeñas en horizontal (iconos de ≈4px de alto).
- **Guerrero:** Se muestran hasta 5 hachas pequeñas en horizontal.
- Cada proyectil gastado hace que el icono correspondiente desaparezca (de derecha a izquierda).
- Cada proyectil recogido hace que un icono aparezca con una pequeña animación de pop-in.
- El contador se dibuja directamente sobre el personaje, sin panel de UI — está integrado en el espacio del juego.
- Cuando el jugador no tiene proyectiles (0), los iconos parpadean brevemente para indicar el estado vacío.

### Implicaciones de diseño
- **Gestión de recursos:** El jugador debe decidir cuándo disparar y cuándo recoger. Disparar a lo loco deja al jugador sin munición.
- **Proyectiles como trampa:** Las flechas clavadas en el suelo son obstáculos sutiles. El rival puede pisarlas y morir, por lo que hay que vigilar dónde caen.
- **Robo de proyectiles:** Recoger los proyectiles del rival es una táctica válida — especialmente útil cuando el adversario tiene muchos y tú pocos.

---

## 6. MODOS DE JUEGO

### 6.1 Menú Principal
- Logo del juego animado (pixel art)
- Opciones:
  - **HISTORIA** → Selección de personaje → Nivel 1
  - **VERSUS** → Selección de personaje (P1 y P2) → Selección de arena → Combate
  - **OPCIONES** → Volumen música, SFX, resolución, controles P1 y P2
  - **SALIR**
- Música de menú: tema épico-fantasy con melodía memorable

### 6.2 Modo Versus (PvP Local)
- 2 jugadores en la misma máquina
- Los controles de P1 y P2 son completamente configurables desde Opciones (ver sección 6.4).
- **Por defecto P1:** WASD para moverse, Q/E para ataque 1/2, Espacio para saltar, Shift para dash.
- **Por defecto P2:** Flechas para moverse, K/L para ataque 1/2, Enter para saltar, RShift para dash.
- **Con gamepad:** Detección automática. El primer gamepad conectado se asigna a P1 o P2 según configuración.
- **Formato:** Mejor de 5 rondas. Cada ronda se juega en la misma arena.
- **Selección de arena:** 3 arenas disponibles (las mismas del modo historia)
- **HUD:** Iconos de personaje en las esquinas superiores con contador de rondas ganadas
- **Pantalla de victoria:** Animación del personaje ganador, contador de rondas ganadas

### 6.4 Pantalla de Opciones — Configuración de Controles
La pantalla de opciones tiene una pestaña dedicada a controles, separada por jugador.

#### Estructura de la pantalla de controles
```
[CONTROLES]
  ┌─────────────────────────┬─────────────────────────┐
  │       JUGADOR 1         │       JUGADOR 2         │
  ├─────────────────────────┼─────────────────────────┤
  │ Mover izquierda: [A]    │ Mover izquierda: [←]   │
  │ Mover derecha:   [D]    │ Mover derecha:   [→]   │
  │ Saltar:          [Esp]  │ Saltar:          [Intr] │
  │ Ataque 1:        [Q]    │ Ataque 1:        [K]   │
  │ Ataque 2:        [E]    │ Ataque 2:        [L]   │
  │ Dash:            [Shft] │ Dash:            [RS]  │
  │ Apuntar ↑:       [W]    │ Apuntar ↑:       [↑]  │
  │ Apuntar ↓:       [S]    │ Apuntar ↓:       [↓]  │
  ├─────────────────────────┼─────────────────────────┤
  │ Dispositivo: [Teclado ▼]│ Dispositivo: [Teclado ▼]│
  └─────────────────────────┴─────────────────────────┘
  [RESTABLECER DEFECTO P1]  [RESTABLECER DEFECTO P2]
```

#### Funcionamiento del remapeo
- El jugador selecciona una acción con el cursor.
- Aparece un prompt: **"Presiona la tecla o botón para esta acción"**.
- El juego espera el siguiente input (teclado o gamepad) y lo asigna.
- Si la tecla ya está asignada a otra acción **del mismo jugador**, se intercambian automáticamente.
- Si la tecla está asignada a una acción **del otro jugador**, aparece un aviso: *"Esta tecla ya la usa el Jugador X. ¿Quieres reasignarla?"*
- ESC cancela el remapeo sin cambios.

#### Soporte de dispositivos por jugador
Cada jugador puede seleccionar su dispositivo independientemente:
- **Teclado** (por defecto)
- **Gamepad 1** (primer mando conectado)
- **Gamepad 2** (segundo mando conectado)

Esto permite cualquier combinación: dos teclados, teclado + mando, dos mandos, o incluso ambos jugadores en el mismo teclado con teclas bien separadas.

#### Persistencia
Los controles configurados se guardan en `user://input_config.cfg` (carpeta de usuario de Godot) y se cargan automáticamente al iniciar el juego. `InputManager.gd` es responsable de cargar, guardar y aplicar esta configuración en tiempo real.

### 6.3 Modo Historia (Solo Player)
- El jugador elige entre Arquero o Guerrero
- **3 niveles** con escenario estático y oleadas de monstruos
- Narrativa mínima: intro de pantalla con texto y pixel art ilustrado antes de cada nivel
- Al completar los 3 niveles: pantalla de créditos / ending

#### Flujo del Modo Historia
```
Intro narrativa Nivel 1
  → Combate Nivel 1 (Bosque Antiguo)
    → Oleada 1 (3-4 monstruos básicos)
    → Oleada 2 (5-6 monstruos con variedad)
    → Oleada 3 / Mini-boss (monstruo élite)
  → Pantalla de victoria Nivel 1
Intro narrativa Nivel 2
  → Combate Nivel 2 (Ruinas Voladoras)
    → Oleadas más complejas y monstruos más rápidos
  → Pantalla de victoria Nivel 2
Intro narrativa Nivel 3
  → Combate Nivel 3 (Torre del Caos)
    → Oleadas finales + monstruo jefe de fase final
  → Ending / Créditos
```

---

## 7. MONSTRUOS Y ENEMIGOS

> Todos los monstruos mueren con un solo impacto (flecha, espada, stomp). Su peligrosidad viene de su comportamiento, velocidad y tipo de ataque, no de su resistencia.

### 7.1 Goblin Saltarín *(tipo terrestre, básico)*
**Visual:** Pequeño goblin verde regordete con orejas enormes. Expresión de pánico perpetuo.  
**Movimiento:** Salta erráticamente en plataformas. Aterriza, espera 0.3s, vuelve a saltar.  
**Ataque:** Ninguno activo. Es peligroso **por colisión**: si el jugador lo toca (sin ser desde arriba), muere.  
**IA:** Detecta al jugador y salta hacia él. Si no lo detecta, patrol en la plataforma actual.  
**Stomp:** Sí, se puede matar saltando encima.  
**Dificultad:** ★☆☆

---

### 7.2 Espectro Arquero *(tipo volador, a distancia)*
**Visual:** Fantasma semitransparente con arco espectral. Flota suavemente, ojos brillantes. Colores: azul pálido y violeta.  
**Movimiento:** Vuela libremente por el nivel. Mantiene distancia del jugador. Si el jugador se acerca demasiado, retrocede.  
**Ataque:** Dispara un proyectil espectral en dirección al jugador cada 1.8s. El proyectil es más lento que una flecha normal (200 px/s) pero atraviesa plataformas (solo le detienen las paredes sólidas del borde del nivel).  
**IA:** Posiciona en zonas elevadas. Predice la posición del jugador (leve aim-ahead).  
**Stomp:** No — su hitbox superior está protegida (tiene una corona espinosa).  
**Debilidad:** Flecha directa, golpe de guerrero si se acerca.  
**Dificultad:** ★★☆

---

### 7.3 Troll de Piedra *(tipo terrestre, pesado)*
**Visual:** Criatura enorme de roca viva, con musgo y cristales incrustados. Lento pero amenazante. Colores: gris piedra y verde musgo. Ojos de lava.  
**Movimiento:** Camina lentamente por plataformas. No salta. Patrulla su plataforma de un extremo al otro.  
**Ataque:** Golpe de puño en un radio corto (60px) a ambos lados. Cooldown de 1.5s. Genera pequeñas partículas de roca al golpear el suelo.  
**Ataque especial:** Si el jugador está por encima de él, lanza un pedrusco hacia arriba (proyectil de área pequeña, velocidad media). Cooldown de 3s.  
**Stomp:** Sí — pero el Troll tiene hitbox grande, hace el stomp más fácil pero también más peligroso de intentar.  
**Dificultad:** ★★☆

---

### 7.4 Murciélago Sombra *(tipo volador, rápido y agresivo)*
**Visual:** Murciélago grande y estilizado, alas negras con bordes violetas, colmillos luminosos. Se mueve en looping rápido.  
**Movimiento:** Vuela en patrones circulares o en dive-bomb hacia el jugador. Alta velocidad (180 px/s).  
**Ataque:** Dive-bomb: cuando detecta al jugador debajo, se lanza en picado en línea recta. Si falla (el jugador se mueve), el murciélago se choca brevemente contra el suelo/plataforma y queda aturdido 0.5s (oportunidad de matar).  
**IA:** Circling → Detecta jugador → Dive-bomb → (miss: stun / hit: muerte del jugador).  
**Stomp:** Sí — su hitbox superior es vulnerable durante el aturdimiento post-dive.  
**Dificultad:** ★★★

---

### Tabla resumen de monstruos

| Monstruo | Vuelo | Ataque tipo | Stomp posible | Dificultad |
|---|---|---|---|---|
| Goblin Saltarín | No | Colisión | Sí | Baja |
| Espectro Arquero | Sí | Proyectil | No | Media |
| Troll de Piedra | No | Cuerpo a cuerpo + proyectil | Sí | Media |
| Murciélago Sombra | Sí | Dive-bomb | Sí (stun) | Alta |

---

## 8. NIVELES Y ESCENARIOS

> Los niveles son escenas estáticas (sin scroll). Las plataformas, paredes y suelos flotantes están fijos. El diseño favorece el uso del wall jump, las plataformas flotantes y los ángulos de ataque.

### 8.1 Nivel 1 — Bosque Antiguo
**Ambientación:** Ruinas de un templo en mitad de un bosque místico. Piedras cubiertas de musgo, ramas que cruzan la pantalla, luciérnagas.  
**Paleta:** Verdes profundos, ocre, dorado crepuscular.  
**Estructura:**
- Suelo central amplio
- 2 plataformas flotantes a media altura (simétricas)
- 1 plataforma alta central estrecha (ideal para arquero)
- 2 paredes verticales a los lados (wall jump friendly)
- Salida de monstruos: desde los laterales y desde arriba

**Enemigos:** Goblin Saltarín, Troll de Piedra  
**Dificultad:** Introductoria

---

### 8.2 Nivel 2 — Ruinas Voladoras
**Ambientación:** Fragmentos de una ciudad antigua flotando en el vacío. Plataformas pequeñas dispersas, arcos rotos, estatuas partidas.  
**Paleta:** Azul noche, gris piedra, destellos dorados de magia.  
**Estructura:**
- Sin suelo central (caída mortal si se cae al vacío — mata al jugador)
- 5-6 plataformas de tamaño variable a diferentes alturas
- Dos paredes en los extremos laterales (wall jump lateral)
- Poca anchura por plataforma — movimiento constante obligatorio

**Enemigos:** Espectro Arquero, Murciélago Sombra, Goblin Saltarín  
**Dificultad:** Media — las plataformas pequeñas y la caída mortal elevan la tensión

---

### 8.3 Nivel 3 — Torre del Caos
**Ambientación:** Interior de una torre mágica en desintegración. Escaleras rotas, plataformas que parecen gravitar, magia caótica en el fondo.  
**Paleta:** Rojo sangre, negro, destellos de energía violeta.  
**Estructura:**
- Diseño vertical: plataformas en cascada a múltiples alturas
- 3 plataformas centrales a distintas alturas
- Paredes en ambos lados con gaps para wall jump
- Zona superior más estrecha (zona de alta tensión)
- Zona inferior con suelo (zona de recuperación)

**Enemigos:** Todos los tipos, incluyendo combinaciones complejas  
**Dificultad:** Alta — diseñado para poner a prueba todas las habilidades

---

### Diseño de plataformas — Reglas de oro
1. Siempre debe haber una pared a cada lado que permita wall jump.
2. Ninguna zona del nivel debe ser inalcanzable con las mecánicas de movimiento base.
3. Las plataformas flotantes tienen `pass_through` desde abajo (se puede saltar a través desde abajo, pero se aterriza en ellas desde arriba).
4. Los bordes del nivel: lados = paredes sólidas. Arriba = techo sólido. Abajo = depende del nivel (suelo o vacío mortal).

---

## 9. ESTILO VISUAL PIXEL ART

### Resolución y escala
- **Resolución nativa:** 320×180 px (16:9)
- **Escala de display:** x4 (1280×720) o x6 (1920×1080) — escalado con `nearest neighbor` (sin antialiasing)
- **Tamaño de personajes:** ≈ 14×18 px (sprite base), con animaciones que pueden extenderse
  - *V0.2 p.8:* en engine las entidades se renderizan al **60%** (`ENTITY_SCALE = 0.6`) para encajar mejor con los niveles. Los tamaños de canvas de §9b siguen siendo la referencia de arte.

### Directrices de pixel art
- **Paleta limitada:** Máximo 32 colores activos en pantalla por escena (cohesión visual)
- **Outlines:** Todos los personajes y monstruos tienen outline de 1px en color oscuro
- **Contraste claro:** Fondo de nivel claramente diferenciado de los elementos interactivos
- **Animaciones fluidas:** Personajes con mínimo 4-6 frames por acción principal

### Principio de coherencia de personaje en animaciones
> **Regla de oro:** Cada animación es el mismo personaje en una situación diferente, no un personaje diferente. La silueta, proporciones, paleta de colores y "peso visual" deben ser reconocibles e idénticos en todos los estados. El arquero siempre parece ágil y ligero; el guerrero siempre parece pesado y potente — incluso cuando hacen la misma acción (saltar, caer).

Para garantizar esto, cada personaje tiene definidas las siguientes **anclas de diseño** que no cambian entre animaciones:
- **Silueta característica:** Arquero = capucha puntiaguda + arco visible. Guerrero = hombros anchos + espada a la vista.
- **Paleta fija:** Los colores base no cambian entre estados (no hay recolorado en animaciones).
- **Centro de masa visual:** El arquero es ligero y tiende a inclinarse hacia delante. El guerrero es estable y se planta con firmeza.
- **Expresión coherente:** Los ojos/cara mantienen la misma expresión base (astuta en el arquero, feroz en el guerrero). En estados extremos (muerte, carga máxima) la expresión puede intensificarse, pero dentro del mismo espectro.

---

### Animaciones del Arquero

El arquero transmite **agilidad, precisión y ligereza**. Sus movimientos son fluidos y elegantes, nunca torpes. Incluso en caída libre parece estar en control.

| Animación | Frames | Descripción de personalidad |
|---|---|---|
| `idle` | 4 | Respira suavemente. El arco cuelga a un lado con naturalidad. La capucha se mueve levemente. Ojos entornados, alerta tranquilo. |
| `run` | 6 | Carrera inclinada hacia delante, ligera. Los pies casi no tocan el suelo. El quiver rebota rítmicamente en la espalda. El arco se balancea al costado. |
| `jump` | 3 | Frame 1: encogimiento rápido (agacha las rodillas). Frame 2: extensión total hacia arriba, cuerpo estirado, arco hacia atrás. Frame 3: pose de ascenso, brazos semi-abiertos para equilibrio. |
| `fall` | 2 | Cuerpo ligeramente arqueado hacia abajo, capucha vuela hacia arriba. Expresión de concentración, no de pánico. |
| `wall_slide` | 3 | Se agarra a la pared con una mano (la que tiene el arco), la otra mano libre hacia atrás buscando equilibrio. El cuerpo se pega a la pared, rodilla doblada. Expresión de tensión y cálculo. |
| `attack1` | 4 | Frame 1: brazo atrás tensando la cuerda. Frame 2: tensión máxima, cuerpo girado. Frame 3: release, el arco vibra. Frame 4: recuperación natural (vuelta al idle). La cabeza siempre apunta a la dirección de disparo. |
| `attack1_air` | 4 | Igual que `attack1` pero el cuerpo flota — los pies no tienen suelo. La pose se adapta para que parezca que dispara mientras vuela, no que está de pie en el aire. |
| `attack2_charge` | 3 (loop) | Postura de concentración intensa. El arco se tensa progresivamente entre frames. Los dedos se crispan en la cuerda. Partículas de energía aparecen alrededor de la punta de la flecha. La expresión pasa de alerta a determinada. |
| `attack2_charge_air` | 3 (loop) | Como `attack2_charge` pero con las piernas ligeramente dobladas hacia abajo (suspendido). El cuerpo se inclina levemente en la dirección de disparo. |
| `attack2_release` | 3 | Liberación explosiva: el arco se dobla al máximo y las 3 flechas salen en cono. El cuerpo retrocede levemente por la inercia (recoil expresivo). |
| `dash` | 2 | Inclinación extrema hacia la dirección del dash. La capa/capucha vuela hacia atrás. Los pies no tocan el suelo. Expresión de velocidad pura. |
| `death` | 5 | Impacto → retroceso → el personaje se dobla → explota en partículas del color del arquero (verde + dorado). El arco sale volando antes de desaparecer. |

---

### Animaciones del Guerrero

El guerrero transmite **peso, potencia y determinación brutal**. Sus movimientos tienen inercia. Incluso el salto parece que pesa. El contraste con el arquero debe ser evidente en cada frame.

| Animación | Frames | Descripción de personalidad |
|---|---|---|
| `idle` | 4 | Respira pesado, el pecho sube y baja. La espada apoyada en el suelo o al hombro. Los pies bien plantados. Expresión de vigilancia feroz. Ocasionalmente gira la cabeza. |
| `run` | 6 | Carrera potente y contundente. Los hombros se mueven con la zancada. La armadura tintinea (visual: pequeñas partículas de polvo en los pies). La espada se balancea con el movimiento. El cuerpo no se inclina tanto hacia delante como el arquero. |
| `jump` | 3 | Frame 1: encogimiento con esfuerzo visible (las rodillas dobladas profundo). Frame 2: impulso hacia arriba, la espada se alza. Frame 3: pose de ascenso con los brazos abiertos, la espada hacia un lado. Se nota el peso. |
| `fall` | 2 | Cuerpo en postura de caída agresiva: espada apuntando hacia abajo, listo para clavar. Nada de miedo — el guerrero cae como si fuera intencional. |
| `wall_slide` | 3 | Se clava a la pared con fuerza — la mano libre golpea la pared para frenar. El cuerpo roza hacia abajo lentamente. Expresión de frustración controlada. Las chispas de la armadura contra la pared son un detalle visual bonito. |
| `attack1` | 4 | Frame 1: retroceso rápido del brazo con espada. Frame 2: slash explosivo en la dirección apuntada — el arco de la espada cubre las 2 casillas de alcance visualmente. Frame 3: la espada llega al final del swing. Frame 4: recuperación. La expresión es de rabia concentrada en todos los frames. |
| `attack1_air` | 4 | Igual que `attack1` pero con el cuerpo suspendido. El impulso del slash provoca un leve contramovimiento del cuerpo (reacción a la inercia). |
| `attack2_charge` | 3 (loop) | Postura de preparación: el guerrero se encoge hacia atrás como un resorte. La espada detrás del cuerpo o alzada. Chispas y partículas de energía aumentan con el tiempo de carga. La expresión evoluciona: tenso → determinado → furioso. |
| `attack2_charge_air` | 3 (loop) | Como `attack2_charge` pero con las piernas recogidas (en el aire). El cuerpo se comprime hacia la dirección de carga. Las partículas son más intensas — contraste con la quietud suspendida. |
| `attack2_release` | 5 | Explosión de movimiento: el guerrero se lanza en la dirección de carga con todo el cuerpo estirado. Frame 1-3: la carga. Frame 4: impacto o llegada al límite (la espada hace el golpe). Frame 5: stun post-carga (el guerrero se planta y recupera postura). |
| `dash` | 2 | Inclinación explosiva hacia la dirección del dash. Los hombros van por delante. La armadura deja un trail de metal. Menos elegante que el arquero — más como un embestida breve. |
| `death` | 5 | Impacto → retroceso → el guerrero cae de rodillas → explota en partículas (rojo carmesí + plateado). La espada cae y desaparece en el último frame. |

---

### Nota sobre `attack1_air` y `attack2_charge_air`
Godot gestiona esto con un parámetro de estado en el `AnimationTree`: el jugador tiene el mismo input de ataque en suelo y aire, pero el código pasa el estado `is_on_floor()` al árbol de animación para elegir la variante correcta. Las animaciones `_air` son siempre una adaptación de las de suelo — misma lectura de personaje, diferente postura de pies/piernas.

### Efectos visuales (VFX)
- **Dash trail:** Sprites fantasma semi-transparentes (3-4 copias, alpha decreciente)
- **Impacto de flecha:** Flash + partículas pequeñas
- **Golpe de espada:** Slash arc (línea de luz) que cubre visualmente las 2 casillas de alcance, partículas de chispas
- **Muerte:** Explosión de partículas del color del personaje
- **Stomp:** Pequeñas partículas que salen hacia los lados al aplastar un enemigo
- **Carga del guerrero:** Partículas de polvo/chispas en la estela (suelo) o partículas de energía flotantes (aire)
- **Proyectil en vuelo:** Rotación del sprite según la trayectoria (la flecha/hacha apunta siempre en la dirección de su vector de velocidad)

---

## 9b. DIRECCIÓN ARTÍSTICA Y LISTA COMPLETA DE ASSETS

> Esta sección es la guía de producción para todo el arte del juego. Cada asset listado debe ser creado siguiendo la misma dirección artística. **Ningún asset se considera "terminado" si no es coherente con el resto del juego visualmente.**

### Dirección artística unificada

**Estilo:** Pixel art fantasy vivo. Influencias: juegos SNES/GBA de acción (como Castlevania, Final Fantasy Tactics, The Legend of Zelda: A Link to the Past) combinadas con sensibilidad moderna de indie pixel art (Shovel Knight, Celeste).

**Palabras clave del estilo:** Épico pero accesible. Oscuro pero colorido. Personajes peculiares pero creíbles en su mundo. El arte debe sentirse como una ilustración de un libro de cuentos de fantasía, no como un clipart genérico de videojuego.

**Reglas transversales de arte:**
- Outlines de 1px en todos los personajes, monstruos y elementos interactivos. Los fondos NO tienen outline (se distinguen por contraste de paleta).
- Sombreado en 2-3 tonos por color (nunca degradados suaves — siempre pixel art duro).
- Las sombras caen siempre en la misma dirección en todos los assets de una misma escena.
- Animaciones con al menos un frame de "anticipación" antes de acciones explosivas (squash antes del jump, retroceso antes del slash).
- Los colores del fondo son siempre más desaturados que los de los personajes para que estos destaquen.

---

### ASSETS DE PERSONAJES JUGABLES

#### Arquero — Lista completa de sprites
Tamaño base del sprite: 14×18px. El canvas puede extenderse para animaciones con objetos o movimientos amplios (ej: arco extendido = 22×18px).

| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `archer_idle` (4f) | 14×18 | Sprite base en reposo |
| `archer_run` (6f) | 16×18 | Carrera ligera |
| `archer_jump` (3f) | 14×20 | Salto (encogimiento + extensión + ascenso) |
| `archer_fall` (2f) | 14×20 | Caída libre |
| `archer_wall_slide` (3f) | 16×18 | Agarre a pared |
| `archer_dash` (2f) | 18×14 | Dash horizontal (canvas más ancho, menos alto) |
| `archer_attack1` (4f) | 22×18 | Disparo simple (arco extendido) |
| `archer_attack1_air` (4f) | 22×18 | Disparo simple en el aire |
| `archer_attack2_charge` (3f, loop) | 22×18 | Carga del arco |
| `archer_attack2_charge_air` (3f, loop) | 22×18 | Carga del arco en el aire |
| `archer_attack2_release` (3f) | 24×18 | Disparo en cono (3 flechas) |
| `archer_death` (5f) | 20×20 | Muerte con explosión de partículas |
| `archer_portrait` | 32×32 | Retrato para selección de personaje y HUD |
| `archer_icon` | 8×8 | Icono pequeño para HUD (contador de rondas Versus) |

#### Guerrero — Lista completa de sprites
Tamaño base del sprite: 16×18px (más ancho que el arquero por los hombros). Canvas puede extenderse para ataques.

| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `warrior_idle` (4f) | 16×18 | Sprite base en reposo |
| `warrior_run` (6f) | 18×18 | Carrera potente |
| `warrior_jump` (3f) | 16×20 | Salto con peso |
| `warrior_fall` (2f) | 16×20 | Caída agresiva |
| `warrior_wall_slide` (3f) | 18×18 | Agarre a pared (chispas de armadura) |
| `warrior_dash` (2f) | 20×14 | Dash (más ancho por los hombros) |
| `warrior_attack1` (4f) | 28×18 | Slash (canvas extendido 2 casillas) |
| `warrior_attack1_air` (4f) | 28×18 | Slash en el aire |
| `warrior_attack2_charge` (3f, loop) | 18×18 | Carga comprimiéndose |
| `warrior_attack2_charge_air` (3f, loop) | 18×18 | Carga en el aire |
| `warrior_attack2_release` (5f) | 28×18 | Embestida |
| `warrior_death` (5f) | 22×20 | Muerte con explosión |
| `warrior_portrait` | 32×32 | Retrato para selección y HUD |
| `warrior_icon` | 8×8 | Icono pequeño para HUD |

---

### ASSETS DE MONSTRUOS

Todos los monstruos tienen outline, sombreado pixel art y paleta coherente con el nivel en que aparecen.

#### Goblin Saltarín
| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `goblin_idle` (3f) | 10×12 | Nervioso, ojos moviéndose |
| `goblin_jump` (2f) | 10×14 | Salto errático |
| `goblin_fall` (2f) | 10×14 | Caída en pánico |
| `goblin_land` (2f) | 12×10 | Aterrizaje aplastado (squash) |
| `goblin_death` (4f) | 14×14 | Explosión verde de partículas |

#### Espectro Arquero
| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `specter_idle` (4f, loop) | 14×18 | Flotación oscilante, semi-transparente |
| `specter_move` (4f, loop) | 14×18 | Deslizamiento volador |
| `specter_attack` (5f) | 20×18 | Tensado del arco espectral + disparo |
| `specter_retreat` (3f) | 14×18 | Retrocede al acercarse el jugador |
| `specter_death` (5f) | 18×18 | Se desintegra en partículas azules/violeta |

#### Troll de Piedra
| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `troll_idle` (3f) | 20×22 | Respiración pesada, rocas se desprenden |
| `troll_walk` (4f) | 22×22 | Caminar lento, el suelo tiembla |
| `troll_attack_punch` (5f) | 28×22 | Golpe de puño lateral |
| `troll_attack_throw` (5f) | 22×22 | Lanzamiento del pedrusco hacia arriba |
| `troll_death` (6f) | 26×26 | Se rompe en fragmentos de piedra |

#### Murciélago Sombra
| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `bat_circle` (4f, loop) | 16×12 | Vuelo circular normal |
| `bat_dive_prepare` (2f) | 14×16 | Se pliega antes del picado |
| `bat_dive` (2f) | 10×20 | Picado en línea recta (canvas vertical) |
| `bat_stun` (3f, loop) | 16×12 | Aturdido en el suelo, ojos en espiral |
| `bat_death` (4f) | 18×14 | Explosión violeta de partículas |

---

### ASSETS DE PROYECTILES

| Asset | Tamaño | Descripción |
|---|---|---|
| `arrow_flying` (2f) | 8×3 | Flecha en vuelo (rotación dinámica según trayectoria) |
| `arrow_stuck` | 8×3 | Flecha clavada (sin animación, orientada según ángulo de impacto) |
| `arrow_icon_hud` | 4×6 | Icono de flecha para el contador sobre el personaje |
| `hatchet_flying` (3f) | 7×7 | Hacha girando en vuelo |
| `hatchet_stuck` | 7×7 | Hacha clavada en superficie |
| `hatchet_icon_hud` | 5×5 | Icono de hacha para el contador |
| `spectral_bolt` (3f, loop) | 6×6 | Proyectil del Espectro (partículas orbitando) |
| `rock_flying` (2f) | 8×8 | Pedrusco rotando |

---

### VFX — EFECTOS VISUALES

Todos los VFX son spritesheets con ciclo corto (3-6 frames, sin loop salvo indicación).

| Asset | Tamaño canvas | Descripción |
|---|---|---|
| `vfx_arrow_impact` (4f) | 10×10 | Impacto de flecha en superficie |
| `vfx_sword_slash` (4f) | 28×10 | Arc de luz del slash del guerrero (2 casillas de ancho) |
| `vfx_dash_ghost` | igual que el sprite del personaje | Sprite semi-transparente (se instancia 3-4 veces en el trail) |
| `vfx_stomp` (3f) | 14×6 | Partículas en los lados al aplastar un enemigo |
| `vfx_land_dust` (3f) | 12×4 | Polvo al aterrizar |
| `vfx_charge_particles` (3f, loop) | 10×10 | Partículas de carga del ataque 2 |
| `vfx_projectile_pickup` (3f) | 8×8 | Pop al recoger un proyectil |
| `vfx_wall_spark` (3f) | 6×6 | Chispas del Guerrero en wall slide |

---

### ASSETS DE NIVELES — TILESETS Y FONDOS

Cada nivel tiene su propio tileset y su fondo. Los tilesets siguen la paleta del nivel. Las plataformas y el suelo deben ser claramente distinguibles del fondo.

#### Nivel 1 — Bosque Antiguo
| Asset | Descripción |
|---|---|
| `tileset_forest` | Tiles de piedra con musgo, raíces, bordes orgánicos. Tile base 8×8px. Mínimo: suelo, plataforma, pared izquierda, pared derecha, esquinas. |
| `bg_forest_layer1` | Fondo lejano: cielo crepuscular, silueta de árboles gigantes (sin detalle) |
| `bg_forest_layer2` | Fondo medio: ruinas difusas, ramas con luciérnagas |
| `bg_forest_layer3` | Fondo cercano: vegetación detallada, columnas rotas |
| `prop_forest_*` | Props decorativos no interactivos: musgo colgante, hongos, estatua rota, vasija |

#### Nivel 2 — Ruinas Voladoras
| Asset | Descripción |
|---|---|
| `tileset_ruins` | Tiles de piedra gris-azulada, bordes rotos, con destellos dorados incrustados. Tile base 8×8px. |
| `bg_ruins_layer1` | Fondo: cielo nocturno profundo con nebulosas |
| `bg_ruins_layer2` | Fondo medio: fragmentos de ciudad flotando a lo lejos (sin detalle) |
| `bg_ruins_layer3` | Fondo cercano: arcos rotos, estatuas fragmentadas |
| `prop_ruins_*` | Props: antorcha mágica, cristal antiguo, bannner rasgado |

#### Nivel 3 — Torre del Caos
| Asset | Descripción |
|---|---|
| `tileset_tower` | Tiles de piedra oscura con grietas de energía violeta. Tile base 8×8px. |
| `bg_tower_layer1` | Fondo: interior de la torre en llamas mágicas |
| `bg_tower_layer2` | Fondo medio: columnas derrumbándose, energía caótica |
| `bg_tower_layer3` | Fondo cercano: escaleras rotas, runas brillantes en las paredes |
| `prop_tower_*` | Props: runas flotantes, fragmentos de piedra en suspensión |

---

### ASSETS DE UI Y MENÚS

La UI sigue el mismo estilo pixel art del juego: bordes en pixel, tipografía pixelada, colores coherentes con la paleta fantasy.

| Asset | Tamaño | Descripción |
|---|---|---|
| `logo_main` | 160×40 | Logo "MY TOWER FALL" animado (4-6f), con letras de piedra y efectos de energía |
| `ui_button_idle` | 64×12 | Botón de menú en reposo |
| `ui_button_hover` | 64×12 | Botón con hover (borde brillante) |
| `ui_button_pressed` | 64×12 | Botón presionado (hundido 1px) |
| `ui_panel_frame` | tileable | Marco pixel art para paneles (esquinas + bordes) |
| `ui_dialog_box` | tileable | Caja de diálogo estilo RPG (para intros de nivel) |
| `ui_arrow_cursor` | 6×10 | Cursor/flecha de selección en menús |
| `ui_round_icon_p1` | 12×12 | Icono de ronda ganada P1 |
| `ui_round_icon_p2` | 12×12 | Icono de ronda ganada P2 |
| `ui_round_empty` | 12×12 | Icono de ronda disponible (sin ganar) |
| `ui_portrait_frame` | 36×36 | Marco para retratos de personaje en selección |
| `ui_vs_screen_bg` | 320×180 | Fondo de la pantalla de selección Versus |
| `ui_victory_banner` | 200×40 | Banner de victoria al ganar una ronda/partida |

#### Pantallas de intro de historia (por nivel)
| Asset | Tamaño | Descripción |
|---|---|---|
| `intro_level1_bg` | 320×180 | Ilustración pixel art del Bosque Antiguo (escena estática, alta densidad de detalle) |
| `intro_level2_bg` | 320×180 | Ilustración pixel art de las Ruinas Voladoras |
| `intro_level3_bg` | 320×180 | Ilustración pixel art de la Torre del Caos |

#### Pantalla de selección de personaje
| Asset | Tamaño | Descripción |
|---|---|---|
| `char_select_bg` | 320×180 | Fondo neutro con elementos fantasy (no tan elaborado como los intros) |
| `char_select_archer_art` | 48×56 | Artwork ampliado del Arquero (pose heroica, mucho más detallado que el sprite de juego) |
| `char_select_warrior_art` | 52×56 | Artwork ampliado del Guerrero |

---

### Checklist de coherencia artística (antes de dar un asset por terminado)

Antes de considerar cualquier sprite o asset listo para integración en Godot, debe pasar este checklist:

- [ ] ¿La paleta usa los colores correctos del personaje/nivel sin colores extra no aprobados?
- [ ] ¿El outline de 1px está presente y es consistente?
- [ ] ¿El sombreado usa máximo 3 tonos por color?
- [ ] ¿La silueta es reconocible y coherente con los otros sprites del mismo personaje?
- [ ] ¿La animación tiene al menos 1 frame de anticipación en acciones explosivas?
- [ ] ¿El personaje en esta animación "parece" el mismo personaje que en `idle`?
- [ ] ¿El tamaño del canvas es el correcto según la tabla de assets?
- [ ] ¿El sprite funciona sobre los tres fondos de nivel distintos (contraste suficiente)?

### Música y SFX
- **Estilo musical:** Fantasy épico con influencias de 8/16-bit y orquestal pixel
- **Pistas:**
  - Menú principal: tema épico memorable
  - Bosque Antiguo: ambiental y misterioso
  - Ruinas Voladoras: tenso y etéreo
  - Torre del Caos: frenético y épico
  - Versus: riff rock/chiptune dinámico
- **SFX clave:** Salto, doble salto, dash (swoosh), flecha (disparo + impacto), golpe espada, muerte, stomp, cada tipo de monstruo tiene su propio set de sonidos

---

## 10. MENÚ PRINCIPAL Y UI

### Pantalla de inicio
```
[LOGO "MY TOWER FALL" — animado]
        |
   [HISTORIA]
   [VERSUS]
   [OPCIONES]
   [SALIR]
```

### HUD durante el juego
- **Modo Historia:** Nada en pantalla (juego limpio). Solo un pequeño indicador de oleada en una esquina.
- **Modo Versus:** Iconos de los personajes en las esquinas superiores con contador de rondas ganadas.
- **Contador de proyectiles (ambos modos):** Iconos pixel art del proyectil de la clase flotando encima del personaje. Hasta 5 iconos. Sin panel de UI — integrado en el espacio del juego. Ver sección 5b para detalles completos.

### Pantalla de Selección de Personaje
- Muestra los dos personajes disponibles con su artwork pixel art
- Descripción breve de cada clase
- P1 y P2 eligen de forma independiente (pueden elegir la misma clase)

### Pantallas de Historia (intro de nivel)
- Fondo ilustrado en pixel art con la ambientación del nivel
- Texto narrativo breve (2-4 líneas) en una caja de diálogo estilo RPG clásico
- Música de ambientación
- "Presiona cualquier tecla para comenzar"

---

## 11. ESTRUCTURA DE CARPETAS DEL PROYECTO

```
my_tower_fall/
├── project.godot
├── CHANGELOG.md              ← Registro de versiones y cambios
├── BUGS.md                   ← Registro de bugs conocidos
├── DOCUMENTO_MAESTRO.md      ← Este documento
│
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   │   ├── archer/       ← spritesheet + frames individuales
│   │   │   └── warrior/
│   │   ├── monsters/
│   │   │   ├── goblin/
│   │   │   ├── specter/
│   │   │   ├── troll/
│   │   │   └── bat/
│   │   ├── projectiles/      ← flechas/hachas clavadas y en vuelo, proyectil espectral, pedrusco
│   │   ├── vfx/              ← partículas, trails, flashes
│   │   └── ui/               ← botones, frames, iconos, logo
│   ├── tilesets/
│   │   ├── forest/
│   │   ├── ruins/
│   │   └── tower/
│   ├── backgrounds/          ← fondos de los niveles (PNG estáticos)
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
│
├── scenes/
│   ├── ui/
│   │   ├── MainMenu.tscn
│   │   ├── CharacterSelect.tscn
│   │   ├── PauseMenu.tscn
│   │   ├── VictoryScreen.tscn
│   │   └── HUD.tscn
│   ├── levels/
│   │   ├── Level_01_Forest.tscn
│   │   ├── Level_02_Ruins.tscn
│   │   └── Level_03_Tower.tscn
│   ├── characters/
│   │   ├── Archer.tscn
│   │   └── Warrior.tscn
│   ├── monsters/
│   │   ├── GoblinJumper.tscn
│   │   ├── SpecterArcher.tscn
│   │   ├── StoneTroll.tscn
│   │   └── ShadowBat.tscn
│   └── projectiles/
│       ├── Arrow.tscn
│       ├── SpectralBolt.tscn
│       └── Rock.tscn
│
├── scripts/
│   ├── autoloads/
│   │   ├── GameManager.gd
│   │   ├── SceneManager.gd
│   │   ├── InputManager.gd
│   │   ├── AudioManager.gd
│   │   ├── DebugManager.gd
│   │   └── VersionManager.gd
│   ├── characters/
│   │   ├── PlayerBase.gd        ← Clase base con movimiento
│   │   ├── ArcherPlayer.gd      ← Extiende PlayerBase, ataques del arquero
│   │   └── WarriorPlayer.gd     ← Extiende PlayerBase, ataques del guerrero
│   ├── monsters/
│   │   ├── MonsterBase.gd       ← Clase base: detección, muerte, stomp
│   │   ├── GoblinJumper.gd
│   │   ├── SpecterArcher.gd
│   │   ├── StoneTroll.gd
│   │   └── ShadowBat.gd
│   ├── projectiles/
│   │   ├── ProjectileBase.gd
│   │   ├── Arrow.gd
│   │   ├── SpectralBolt.gd
│   │   └── Rock.gd
│   ├── levels/
│   │   ├── LevelBase.gd         ← Lógica de oleadas, checkpoints, victoria
│   │   ├── Level01.gd
│   │   ├── Level02.gd
│   │   └── Level03.gd
│   └── ui/
│       ├── MainMenu.gd
│       ├── CharacterSelect.gd
│       ├── HUD.gd
│       ├── OptionsMenu.gd           ← Pantalla de opciones (audio + controles)
│       └── ControlsRemapper.gd     ← Lógica de remapeo interactivo de teclas
│
└── resources/
    ├── PlayerStats.tres         ← Recurso con constantes de movimiento del jugador
    ├── MonsterStats/
    │   ├── GoblinStats.tres
    │   ├── SpecterStats.tres
    │   ├── TrollStats.tres
    │   └── BatStats.tres
    ├── InputMappings.tres       ← Configuración por defecto de controles P1 y P2
    └── ProjectileStats/
        ├── ArrowStats.tres      ← Velocidad, gravedad, sprite de flecha
        └── HatchetStats.tres    ← Velocidad, gravedad, sprite de hacha
```

---

## 12. PLAN DE DESARROLLO POR FASES

### FASE 0 — Setup del proyecto *(estimado: 1 sesión)*
- [ ] Crear proyecto Godot 4 con configuración base
- [ ] Configurar resolución nativa 320×180, escalado nearest-neighbor
- [ ] Crear estructura de carpetas completa
- [ ] Configurar autoloads (GameManager, SceneManager, etc.)
- [ ] Crear `CHANGELOG.md` y `BUGS.md`
- [ ] Configurar sistema de input base (acciones en InputMap de Godot para P1 y P2)
- [ ] `InputManager.gd`: carga de `user://input_config.cfg` al inicio, guardado al cambiar controles

### FASE 1 — Movimiento del jugador *(estimado: 2-3 sesiones)*
- [ ] `PlayerBase.gd`: movimiento horizontal, gravedad, salto básico
- [ ] Coyote time y jump buffer
- [ ] Wall jump zig-zag y vertical
- [ ] Dash con invulnerabilidad
- [ ] Dirección de apuntado (8 direcciones)
- [ ] Squash & stretch en salto/aterrizaje
- [ ] Debug overlay: mostrar velocidad, estado, colisiones
- [ ] **Prueba:** El movimiento se siente fluido y preciso antes de continuar

### FASE 2 — Clases y ataques *(estimado: 2-3 sesiones)*
- [ ] `ProjectileBase.gd`: física con gravedad (`PROJECTILE_GRAVITY`), clavado en superficies, timer de desaparición
- [ ] `ArcherPlayer.gd`: Ataque 1 (flecha con parábola), Ataque 2 (carga + 3 flechas)
- [ ] `WarriorPlayer.gd`: Ataque 1 (golpe), Ataque 2 (carga), proyectil = hacha arrojadiza
- [ ] Sistema de recogida de proyectiles: detección de overlap, incremento de contador
- [ ] Contador visual de proyectiles sobre el personaje (iconos pixel art, máx. 5)
- [ ] Stock inicial de 3 proyectiles al spawn, máximo 5
- [ ] Sistema de hitboxes de ataque
- [ ] Sistema de muerte por impacto (kill en un hit)
- [ ] Animaciones básicas de placeholder (rectángulos con color)

### FASE 3 — Monstruos *(estimado: 3 sesiones)*
- [ ] `MonsterBase.gd`: muerte, stomp detection, señales
- [ ] `GoblinJumper.gd`: patrol + jump hacia jugador + kill por colisión
- [ ] `SpecterArcher.gd`: vuelo + disparo + posicionamiento
- [ ] `StoneTroll.gd`: patrol + golpe + lanzar roca
- [ ] `ShadowBat.gd`: circling + dive-bomb + stun on miss
- [ ] Sistema de oleadas en `LevelBase.gd`

### FASE 4 — Niveles y escenarios *(estimado: 2 sesiones)*
- [ ] Tileset base para los 3 niveles (placeholders geométricos primero)
- [ ] `Level_01_Forest.tscn`: layout de plataformas
- [ ] `Level_02_Ruins.tscn`: layout con caída mortal
- [ ] `Level_03_Tower.tscn`: layout vertical
- [ ] Spawn points para monstruos y jugadores
- [ ] Lógica de oleadas por nivel

### FASE 5 — Modos de juego y opciones *(estimado: 2-3 sesiones)*
- [ ] `MainMenu.tscn`: navegación entre modos
- [ ] `CharacterSelect.tscn`: selección de clase
- [ ] Modo Historia: flujo completo intro → nivel → victoria
- [ ] Modo Versus: rondas, contador de kills, mejor de 5
- [ ] `OptionsMenu.tscn`: pestañas de Audio y Controles
- [ ] `ControlsRemapper.gd`: prompt de captura de input, gestión de conflictos entre P1 y P2, botón de restablecer defecto
- [ ] Selector de dispositivo por jugador (teclado / gamepad 1 / gamepad 2)
- [ ] Persistencia de controles en `user://input_config.cfg`

### FASE 6 — Pixel Art y VFX *(estimado: 8-12 sesiones de arte — no subestimar)*
> Todo el arte se produce en orden: personajes jugables → monstruos → proyectiles y VFX → tilesets → fondos → UI. Cada asset pasa el checklist de coherencia artística de la sección 9b antes de integrarse.

- [ ] **Dirección artística base:** Definir paleta maestra del juego (32 colores activos) y documento de referencia visual antes de dibujar cualquier sprite
- [ ] **Arquero — sprites completos:** idle, run, jump, fall, wall_slide, dash, attack1, attack1_air, attack2_charge, attack2_charge_air, attack2_release, death, portrait (32×32), icon (8×8)
- [ ] **Guerrero — sprites completos:** idle, run, jump, fall, wall_slide, dash, attack1, attack1_air, attack2_charge, attack2_charge_air, attack2_release, death, portrait (32×32), icon (8×8)
- [ ] **Goblin Saltarín:** idle, jump, fall, land, death
- [ ] **Espectro Arquero:** idle (float), move, attack, retreat, death
- [ ] **Troll de Piedra:** idle, walk, attack_punch, attack_throw, death
- [ ] **Murciélago Sombra:** circle, dive_prepare, dive, stun, death
- [ ] **Proyectiles:** arrow_flying (2f), arrow_stuck, arrow_icon_hud, hatchet_flying (3f), hatchet_stuck, hatchet_icon_hud, spectral_bolt, rock_flying
- [ ] **VFX:** arrow_impact, sword_slash (28px wide), dash_ghost, stomp, land_dust, charge_particles, projectile_pickup, wall_spark
- [ ] **Tileset Bosque Antiguo:** tiles de suelo, plataforma, pared + props decorativos
- [ ] **Tileset Ruinas Voladoras:** tiles + props
- [ ] **Tileset Torre del Caos:** tiles + props
- [ ] **Fondos Nivel 1:** 3 capas (parallax)
- [ ] **Fondos Nivel 2:** 3 capas
- [ ] **Fondos Nivel 3:** 3 capas
- [ ] **UI completa:** logo animado, botones (idle/hover/pressed), panel_frame, dialog_box, cursor, iconos de ronda, portrait_frame, vs_screen_bg, victory_banner
- [ ] **Pantallas de intro:** 3 ilustraciones de fondo (320×180) — una por nivel
- [ ] **Pantalla de selección de personaje:** bg + artwork ampliado Arquero y Guerrero
- [ ] **Verificación final:** todos los assets pasan el checklist de coherencia artística de la sección 9b

### FASE 7 — Audio *(estimado: 1-2 sesiones)*
- [ ] Integrar música por escena en `AudioManager`
- [ ] SFX: todos los sonidos de acciones
- [ ] Pantalla de opciones: sliders de volumen

### FASE 8 — Polish y balance *(estimado: 2 sesiones)*
- [ ] Ajuste fino de parámetros de movimiento (`PlayerStats`)
- [ ] Ajuste de dificultad de monstruos por nivel
- [ ] Pantallas de intro narrativa de cada nivel
- [ ] Game feel: cámara con leve shake en golpes/muertes
- [ ] Pruebas de calidad: movimiento, combate, IA

### FASE 9 — Build e instalador *(estimado: 1 sesión)*
- [ ] Export a Windows (.exe)
- [ ] Crear instalador con Inno Setup o NSIS
- [ ] Iconos de la aplicación
- [ ] Prueba de instalación limpia en máquina sin Godot

---

## 13. SISTEMA DE VERSIONES Y DEBUG

### Versionado Semántico
Se usa **SemVer**: `MAJOR.MINOR.PATCH`
- `MAJOR`: Cambios incompatibles o reestructuraciones grandes
- `MINOR`: Nuevas funcionalidades
- `PATCH`: Bugfixes y ajustes menores

**Versión actual:** `0.1.0` (planificación)

### Formato de entrada en CHANGELOG.md
```markdown
## [0.2.0] — 2026-XX-XX
### Añadido
- Sistema de movimiento del jugador completo
- Wall jump zig-zag y vertical
### Cambiado
- Velocidad de dash ajustada de 450 a 400 px/s
### Corregido
- Fix: el coyote time no se reseteaba al hacer wall jump
```

### DebugManager — Overlay de desarrollo
El overlay se activa con `F1` en cualquier escena. Muestra:
- FPS actual
- Velocidad y estado del jugador (`idle/run/jump/fall/wall/dash/attack`)
- Hitboxes visibles (toggle)
- Posición X,Y del personaje
- Estado del FSM de cada monstruo en pantalla
- Versión del juego en esquina inferior derecha (siempre visible)

### Flags de debug en `DebugManager.gd`
```gdscript
var GODMODE       = false  # El jugador no muere
var SHOW_HITBOXES = false  # Visualiza hitboxes
var SKIP_INTROS   = false  # Salta pantallas de intro de nivel
var INFINITE_DASH = false  # Sin cooldown de dash
```

---

## 14. REGISTRO DE CAMBIOS Y ERRORES

### CHANGELOG.md (estructura)
Ver `CHANGELOG.md` en la raíz del proyecto.

### BUGS.md (estructura)
Cada bug registrado tiene:
```
ID: BUG-001
Estado: ABIERTO / CERRADO
Severidad: CRÍTICO / ALTO / MEDIO / BAJO
Descripción: Qué pasa exactamente
Reproducción: Pasos para reproducirlo
Causa raíz: (si se conoce)
Fix aplicado: (si está cerrado)
Fecha apertura / cierre:
```

### Criterios de severidad
| Severidad | Descripción |
|---|---|
| CRÍTICO | El juego crashea o es injugable |
| ALTO | Una mecánica core no funciona correctamente |
| MEDIO | Comportamiento inesperado pero el juego es jugable |
| BAJO | Visual o audio incorrecto, sin impacto en gameplay |

---

## NOTAS FINALES PARA CLAUDE CODE

Cuando implementes este juego, sigue estas prioridades en orden estricto:

1. **Primero el movimiento. Nada más importa si el movimiento no se siente bien.** Dedica el tiempo necesario a `PlayerBase.gd` hasta que saltar, hacer wall jump y dash sean satisfactorios. Usa parámetros en `PlayerStats.tres` para poder ajustar sin tocar código.

2. **Un hit, un kill desde el principio.** No hagas prototipos con barras de vida. La mecánica de un golpe debe estar desde la primera prueba de monstruos.

3. **Mantén el CHANGELOG y el BUGS.md actualizados en cada sesión.** Antes de cada sesión de desarrollo, revisa los bugs abiertos. Al terminar, actualiza el changelog.

4. **Nunca mezcles fases.** No empieces el pixel art definitivo antes de que el gameplay sea sólido. No hagas el modo Historia antes de que el Versus funcione (el Versus valida todo el gameplay core).

5. **Testea el movimiento con formas básicas primero** (rectángulos de colores). El pixel art viene después, nunca antes de que el feel sea correcto.

6. **El debug overlay es obligatorio desde la Fase 1.** Sin visibilidad del estado interno, los bugs son imposibles de diagnosticar.

---

*Documento creado el 2026-06-23. Mantener actualizado conforme evolucione el proyecto.*
