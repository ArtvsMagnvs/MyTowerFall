# ACTUALIZACIÓN V0.8.6 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico
**Fecha:** 2026-06-27
**Versión destino:** 0.8.6
**Prerrequisito:** Leer CLAUDE.md antes de empezar. Aplicar sobre v0.8.5.

---

## RESUMEN EJECUTIVO

Esta actualización corrige 3 problemas en la IA de monstruos. El núcleo es un mecanismo anti-stuck universal: ningún monstruo debe quedarse inmóvil intentando alcanzar al jugador en una posición inalcanzable. Los puntos 2 y 3 son ajustes quirúrgicos al ShadowBat.

---

## ÍNDICE

- **Punto 1** — Anti-stuck: todos los monstruos deben seguir circulando cuando el jugador es inalcanzable
- **Punto 2** — ShadowBat: reducir el tiempo de PREPARING_DASH un 25%
- **Punto 3** — Verificar y reforzar el chequeo de línea de visión antes del dash

---

# PUNTO 1 — ANTI-STUCK: CIRCULACIÓN GARANTIZADA

## Descripción del problema

Los monstruos se bloquean indefinidamente cuando el jugador está en una posición que no pueden alcanzar (plataformas elevadas, ángulos con geometría interpuesta). Se quedan quietos mirando al objetivo sin poder hacer nada. La solución es un mecanismo anti-stuck que detecta la inmovilidad prolongada y fuerza al monstruo a retomar su patrón de movimiento garantizado.

## Principio de diseño

**Circulación natural:** Al forzar el movimiento continuo, el screen wrapping del nivel garantiza que los monstruos eventualmente circulen por todas las zonas del mapa y vuelvan a encontrarse con el jugador. No se necesita pathfinding complejo: basta con que los monstruos sigan moviéndose.

**Límite de diseño aceptado:** Los monstruos con movilidad reducida (Slime) no pueden alcanzar plataformas elevadas. Es comportamiento esperado por diseño. El fix solo evita que se queden inmóviles; no cambia su movilidad máxima.

---

## 1A — Slime (monstruo terrestre)

**Archivo:** `scripts/monsters/Slime.gd`

### Variables nuevas

| Variable | Tipo | Valor inicial | Descripción |
|---|---|---|---|
| `_stuck_timer` | `float` | `0.0` | Acumula el tiempo que el Slime lleva sin desplazarse horizontalmente en estado CHASE |

### Umbrales

| Constante | Valor | Descripción |
|---|---|---|
| `STUCK_SPEED_THRESHOLD` | `8.0` px/s | Si `abs(velocity.x) < 8.0` mientras está en el suelo y en CHASE, se considera atascado |
| `STUCK_TIME_THRESHOLD` | `0.6` s | Tiempo máximo atascado antes de transicionar a PATROL |

### Lógica en el estado CHASE (cada frame)

1. Si `is_on_floor()` y `abs(velocity.x) < STUCK_SPEED_THRESHOLD`: acumular `_stuck_timer += delta`
2. En cualquier otro caso: resetear `_stuck_timer = 0.0`
3. Si `_stuck_timer >= STUCK_TIME_THRESHOLD`: transicionar a estado PATROL y resetear `_stuck_timer = 0.0`

El `_stuck_timer` NO se acumula durante el estado LAND (pausa de aterrizaje tras salto). Solo aplica en CHASE.

---

## 1B — StoneTroll (monstruo terrestre)

**Archivo:** `scripts/monsters/StoneTroll.gd`

### Variables nuevas

| Variable | Tipo | Valor inicial | Descripción |
|---|---|---|---|
| `_stuck_timer` | `float` | `0.0` | Acumula tiempo sin desplazamiento horizontal en estado CHASE |

### Umbrales

| Constante | Valor | Descripción |
|---|---|---|
| `STUCK_SPEED_THRESHOLD` | `8.0` px/s | Umbral de velocidad horizontal para considerar el Troll atascado |
| `STUCK_TIME_THRESHOLD` | `0.6` s | Tiempo máximo antes de transicionar a PATROL |

### Lógica en el estado CHASE (cada frame)

Idéntica a la del Slime (1A):

1. Si `is_on_floor()` y `abs(velocity.x) < STUCK_SPEED_THRESHOLD`: acumular `_stuck_timer += delta`
2. En cualquier otro caso: resetear `_stuck_timer = 0.0`
3. Si `_stuck_timer >= STUCK_TIME_THRESHOLD`: transicionar a PATROL, resetear `_stuck_timer = 0.0`

**Importante:** El `_stuck_timer` NO se acumula durante `punch_windup` ni durante el estado `LAND`. Solo aplica en CHASE. El Troll en `punch_windup` está quieto intencionalmente — no debe interrumpirse.

---

## 1C — ShadowBat (monstruo volador)

**Archivo:** `scripts/monsters/ShadowBat.gd`

El ShadowBat vuela y puede quedarse atascado en rincones o contra geometría mientras intenta acercarse al jugador en estado TRACKING.

### Variables nuevas

| Variable | Tipo | Valor inicial | Descripción |
|---|---|---|---|
| `_stuck_timer` | `float` | `0.0` | Acumula tiempo sin moverse significativamente en TRACKING |
| `_unstuck_dir` | `Vector2` | `Vector2.ZERO` | Dirección de desbloqueo temporal |
| `_unstuck_timer` | `float` | `0.0` | Temporizador del movimiento de desbloqueo activo |

### Umbrales

| Constante | Valor | Descripción |
|---|---|---|
| `STUCK_SPEED_THRESHOLD` | `15.0` px/s | Si `velocity.length() < 15.0`, el Bat se considera atascado |
| `STUCK_TIME_THRESHOLD` | `0.6` s | Tiempo máximo en TRACKING sin moverse antes de activar desbloqueo |
| `UNSTUCK_DURATION` | `0.4` s | Duración del movimiento de desbloqueo |
| `UNSTUCK_SPEED` | `60.0` px/s | Velocidad durante el movimiento de desbloqueo |

### Lógica en el estado TRACKING (cada frame)

**Detección:**
1. Si `velocity.length() < STUCK_SPEED_THRESHOLD`: acumular `_stuck_timer += delta`; si no, resetear `_stuck_timer = 0.0`
2. Si `_stuck_timer >= STUCK_TIME_THRESHOLD`:
   - Calcular `_unstuck_dir`: rotar el vector hacia el jugador 90° o -90° (aleatorio al 50%)
   - Normalizar `_unstuck_dir`
   - Resetear `_stuck_timer = 0.0`
   - Iniciar `_unstuck_timer = UNSTUCK_DURATION`

**Movimiento de desbloqueo** (mientras `_unstuck_timer > 0.0`):
- Aplicar velocidad = `_unstuck_dir × UNSTUCK_SPEED`
- Decrementar `_unstuck_timer -= delta`
- Cuando `_unstuck_timer <= 0.0`: retomar el comportamiento TRACKING normal

El movimiento de desbloqueo NO debe transicionar a PREPARING_DASH ni activar el LoS check — es solo movimiento puro de reposicionamiento.

---

## 1D — SpecterArcher (monstruo volador de distancia)

**Archivo:** `scripts/monsters/SpecterArcher.gd`

El Espectro puede quedar atrapado en rincones cuando intenta mantener su distancia preferida al jugador.

### Variables nuevas

| Variable | Tipo | Valor inicial | Descripción |
|---|---|---|---|
| `_stuck_timer` | `float` | `0.0` | Acumula tiempo sin moverse significativamente |

### Umbrales

| Constante | Valor | Descripción |
|---|---|---|
| `STUCK_SPEED_THRESHOLD` | `10.0` px/s | Umbral de velocidad para considerar el Espectro atascado |
| `STUCK_TIME_THRESHOLD` | `0.5` s | Tiempo máximo sin moverse |
| `UNSTUCK_DURATION` | `0.3` s | Duración del movimiento de desbloqueo |
| `UNSTUCK_SPEED` | `40.0` px/s | Velocidad del movimiento de desbloqueo |

### Lógica de desbloqueo

Misma estructura que el ShadowBat (1C):
1. Acumular `_stuck_timer` cuando `velocity.length() < STUCK_SPEED_THRESHOLD`
2. Al alcanzar `STUCK_TIME_THRESHOLD`: mover en dirección perpendicular al jugador durante `UNSTUCK_DURATION` a `UNSTUCK_SPEED`
3. Retomar comportamiento normal de mantenimiento de distancia

---

## Tabla de verificación — Punto 1

| Prueba | Resultado esperado |
|---|---|
| Slime en suelo con jugador en plataforma elevada | Tras 0.6s de inactividad, el Slime retoma PATROL y sigue moviéndose |
| Troll bloqueado contra pared sin poder alcanzar al jugador | Tras 0.6s, el Troll retoma PATROL |
| Troll en `punch_windup` | No se interrumpe; el `_stuck_timer` no acumula en ese estado |
| ShadowBat atascado en rincón intentando alcanzar al jugador | Tras 0.6s, el Bat se mueve perpendicularmente y retoma la persecución |
| SpecterArcher bloqueado contra geometría | Tras 0.5s, se desplaza y retoma su patrón de distancia |
| Cualquier monstruo persiguiendo activamente con velocidad normal | `_stuck_timer` no se acumula; comportamiento sin cambios |

---

# PUNTO 2 — SHADOWBAT: REDUCIR TIEMPO DE PREPARING_DASH UN 25%

**Archivo:** `scripts/monsters/ShadowBat.gd`

### Cambio de parámetro

| Constante | Valor actual (v0.8.5) | Valor nuevo | Cálculo |
|---|---|---|---|
| Duración del estado `PREPARING_DASH` | `0.2` s | `0.15` s | `0.2 × 0.75 = 0.15` |

En el código, esta duración puede estar declarada como una constante con nombre similar a `PREPARING_DASH_T`, `PREPARE_TIME`, o aplicada directamente como valor en la transición de estado. Buscar el literal `0.2` en el contexto del estado `PREPARING_DASH` y cambiarlo a `0.15`.

### Verificación

| Prueba | Resultado esperado |
|---|---|
| Observar el Bat justo antes de un dash | La pausa de preparación es visualmente más corta que antes |
| Posibilidad de esquivar el dash | El dash sigue siendo esquivable con reflejos normales |

---

# PUNTO 3 — VERIFICAR Y REFORZAR EL LoS CHECK ANTES DEL DASH

**Contexto:** V0.8.2 C-4 especificó añadir un `RayCast2D` de línea de visión en el ShadowBat que comprueba si hay geometría entre el Bat y el jugador antes de iniciar `PREPARING_DASH`. El usuario reporta que el Bat sigue iniciando el dash aunque haya obstáculos interpuestos, lo que indica que el check no funciona correctamente o no fue implementado según la especificación.

**Archivo:** `scripts/monsters/ShadowBat.gd`

## Especificación completa y definitiva

### El nodo RayCast2D de LoS

| Propiedad | Valor requerido |
|---|---|
| Nombre | `_los_ray` |
| `enabled` | `true` |
| `collision_mask` | `L_WORLD = 1` únicamente — solo geometría del mundo, NO jugadores ni monstruos |
| Posición local | `(0, 0)` — origen en el centro del cuerpo del Bat |
| `target_position` | Vector dinámico, se calcula cada vez que se comprueba |

### Cuándo se comprueba

La comprobación de LoS ocurre **en la transición de TRACKING a PREPARING_DASH**, no durante el dash en sí. El momento exacto: cuando se cumple la condición de ángulo válido y el cooldown de dash está listo.

### Lógica exacta de la comprobación

Antes de transicionar a `PREPARING_DASH`, ejecutar en este orden:

1. Calcular el vector desde `global_position` hasta `_player.global_position`
2. Asignar ese vector a `_los_ray.target_position`
3. Llamar `_los_ray.force_raycast_update()`
4. Evaluar el resultado:
   - `_los_ray.is_colliding() == true` → hay geometría bloqueando → **no transicionar**; quedarse en TRACKING
   - `_los_ray.is_colliding() == false` → línea de visión libre → **transicionar a PREPARING_DASH**

### Orden de comprobaciones en la transición

Para evitar trabajo innecesario, las condiciones deben evaluarse en este orden (de más barata a más cara):

1. ¿El cooldown de dash está listo? Si no → no dash
2. ¿El ángulo hacia el jugador es una de las 8 direcciones válidas? Si no → no dash
3. ¿La línea de visión está libre? (`force_raycast_update` + `is_colliding`) → Si no → no dash
4. Todas las condiciones OK → transicionar a PREPARING_DASH

### Verificación de que el nodo existe

Antes de implementar, revisar si el nodo `_los_ray` ya existe en la escena `scenes/monsters/ShadowBat.tscn` y en el script con `@onready var _los_ray`. Si existe, verificar que sus propiedades coinciden con la tabla de arriba. Si no existe, crearlo.

### Aplicabilidad a otros monstruos

| Monstruo | ¿Tiene ataque de carga/dash? | ¿Aplica LoS check? |
|---|---|---|
| Slime | Sí (salto de ataque) | No — el salto es de corto alcance; la geometría no es relevante a esa escala |
| StoneTroll | Sí (puñetazo de 40px) | No — rango tan corto que la geometría no puede interponerse |
| SpecterArcher | No (dispara proyectiles) | No aplica en esta actualización |
| ShadowBat | Sí (dash de 28.8px a alta velocidad) | **Sí — es el único que requiere el check** |

### Tabla de verificación

| Prueba | Resultado esperado |
|---|---|
| Bat a un lado de una pared, jugador al otro | El Bat NO inicia el dash; permanece en TRACKING buscando ángulo libre |
| Bat en la misma sala que el jugador, sin obstáculos | El Bat inicia el dash con normalidad |
| Bat en posición con LoS parcialmente bloqueada | El Bat espera hasta encontrar un ángulo despejado |

---

## ORDEN DE IMPLEMENTACIÓN

```
Punto 2 — ShadowBat PREPARING_DASH duration (5 min):
  ShadowBat.gd: cambiar duración de 0.2 → 0.15 s

Punto 3 — LoS check ShadowBat (20 min):
  ShadowBat.gd: verificar existencia de _los_ray con los parámetros correctos
               reimplementar si no funciona según la especificación de este documento

Punto 1A — Slime anti-stuck (15 min):
  Slime.gd: añadir _stuck_timer; lógica en estado CHASE

Punto 1B — StoneTroll anti-stuck (15 min):
  StoneTroll.gd: añadir _stuck_timer; lógica en CHASE (excluir punch_windup)

Punto 1C — ShadowBat anti-stuck (20 min):
  ShadowBat.gd: añadir _stuck_timer, _unstuck_dir, _unstuck_timer; lógica en TRACKING

Punto 1D — SpecterArcher anti-stuck (15 min):
  SpecterArcher.gd: añadir _stuck_timer; lógica de desbloqueo perpendicular

Total estimado: ~90 min
```

---

## TABLA DE VERIFICACIÓN FINAL V0.8.6

| # | Prueba | Criterio de éxito |
|---|---|---|
| 1a | Slime con jugador en plataforma elevada e inalcanzable | Tras 0.6s, Slime retoma PATROL y continúa circulando |
| 1b | Troll bloqueado sin poder alcanzar al jugador | Tras 0.6s, Troll retoma PATROL |
| 1c | Troll en `punch_windup` (quieto intencionalmente) | No se interrumpe el windup |
| 1d | ShadowBat atascado en rincón | Tras 0.6s, se mueve perpendicularmente y retoma persecución |
| 1e | SpecterArcher bloqueado contra geometría | Tras 0.5s, se desplaza y retoma patrón normal |
| 2a | Observar pausa de preparación del Bat antes del dash | Visualmente más corta que en v0.8.5 |
| 3a | Bat con pared entre él y el jugador | No inicia el dash; queda en TRACKING |
| 3b | Bat con línea de visión libre al jugador | Inicia el dash con normalidad |

---

## ARCHIVOS MODIFICADOS EN ESTA ACTUALIZACIÓN

| Archivo | Puntos que lo modifican |
|---|---|
| `scripts/monsters/Slime.gd` | Punto 1A |
| `scripts/monsters/StoneTroll.gd` | Punto 1B |
| `scripts/monsters/ShadowBat.gd` | Puntos 1C, 2 y 3 |
| `scripts/monsters/SpecterArcher.gd` | Punto 1D |

**Ningún otro archivo debe modificarse.**
