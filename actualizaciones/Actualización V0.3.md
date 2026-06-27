# ACTUALIZACIÓN V0.3 — INSTRUCCIONES PARA CLAUDE CODE
**Juego:** Niide: El Círculo Dárico  
**Fecha:** 2026-06-24  
**Basado en:** Feedback de pruebas + referencia a mecánicas de TowerFall Ascension original  
**Prioridad:** Implementar todos los puntos antes de continuar con nuevas funcionalidades

---

## CONTEXTO DE REFERENCIA: TOWERFALL ASCENSION

Antes de implementar, leer y entender los siguientes comportamientos del TowerFall original que son relevantes para esta actualización:

**Flechas:** Las flechas tienen gravedad y además se inclinan ligeramente hacia los enemigos cercanos a su trayectoria — no es autoaim, es una desviación sutil. Las flechas se clavan en superficies y en cuerpos, y el impacto desplaza el cuerpo en la dirección de la flecha.

**Stomp:** Saltar sobre un enemigo lo mata. El estado del enemigo importa: en TowerFall, los enemigos tienen una fase "pasiva" en la que el contacto lateral no mata al jugador, y una fase "activa/ataque" en la que sí. El stomp funciona **siempre** desde arriba, independientemente del estado.

**Ledge grab:** El jugador puede agarrarse al borde de una plataforma si salta hacia ella y mantiene la dirección hacia la pared/borde. El personaje queda colgado del borde.

**Enemigos tipo Slime:** Se mueven andando, y solo saltan cuando atacan. No saltan para desplazarse.

**Colisión lateral con enemigos:** La colisión lateral sin ataque activo no es letal en TowerFall. Solo mueres si el enemigo está en animación de ataque y te toca. Esto es clave para el punto 8 de esta actualización.

---

## 1. CAMBIO DE NOMBRE DEL JUEGO
**Archivos afectados:** `project.godot`, `MainMenu.tscn`, `MainMenu.gd`, pantallas de intro, cualquier string que diga "My Tower Fall"

**Cambio:**
- **Título principal:** `Niide`
- **Subtítulo:** `El Círculo Dárico`
- Formato completo: `Niide: El Círculo Dárico`

**Instrucciones:**
- En `project.godot`: cambiar `config/name` a `"Niide"`.
- En el logo del menú principal (`MainMenu.tscn`): el nodo de título debe mostrar `NIIDE` en grande y debajo `El Círculo Dárico` en texto más pequeño (aproximadamente la mitad de tamaño que el título).
- Buscar con grep todas las ocurrencias de `"My Tower Fall"` y `"my_tower_fall"` en todos los archivos `.gd` y `.tscn` y reemplazarlas.
- El nombre del directorio del proyecto no necesita cambiarse para no romper rutas existentes.

---

## 2. AJUSTE DE ALTURA DE SALTO (+15%)
**Archivos afectados:** `PlayerStats.tres`

**Contexto:** En V0.2 se redujo el salto un 50% (de -340 a -170). Ahora se sube un 15% sobre ese valor.

**Cambio:**
```
# Valor actual (tras V0.2):
JUMP_VELOCITY = -170.0
WALL_JUMP_VERTICAL = -180.0

# Nuevo valor (+15%):
JUMP_VELOCITY = -195.0       # -170 * 1.15 = -195.5, redondeado
WALL_JUMP_VERTICAL = -207.0  # -180 * 1.15 = -207, redondeado
```

Verificar tras el cambio que todas las plataformas de los 3 niveles siguen siendo alcanzables con el nuevo valor.

---

## 3. RALENTIZAR EL MOVIMIENTO GENERAL UN 25%
**Archivos afectados:** `PlayerStats.tres`

Aplicar un factor de 0.75 a todos los valores de velocidad de movimiento del jugador. La gravedad NO se reduce (cambiarla afectaría la física de los proyectiles y el feel del salto de forma no deseada).

```
# Valores actuales → nuevos valores (×0.75):
WALK_SPEED         = 160.0  →  120.0
WALL_JUMP_PUSH     = 200.0  →  150.0
DASH_SPEED         = 400.0  →  300.0
```

El `DASH_DURATION` no cambia (0.12s). Al reducir la velocidad del dash, la distancia recorrida cae proporcionalmente — esto cumple también con el punto 7 (dash lateral 20% más corto) de forma natural, aunque el punto 7 añade una restricción adicional de dirección que se detalla allí.

**Nota:** Los valores de velocidad de los monstruos también deben revisarse para que no queden desproporcionados respecto al jugador. Ver punto 16 (comportamiento de monstruos).

---

## 4. FLECHAS VISIBLES EN TODO MOMENTO — CLAVADAS EN CADÁVER Y EN SUELO
**Archivos afectados:** `Arrow.gd`, `ProjectileBase.gd`, `PlayerBase.gd`, `MonsterBase.gd`

**Problema:** Las flechas desaparecen al impactar enemigos. Deben ser visibles siempre: clavadas en el cadáver mientras este existe, y clavadas en el suelo/superficie donde cayó el cadáver al desaparecer este.

**Implementación completa — leer entera antes de codificar:**

### Fase 1: Impacto en entidad
Al detectar impacto con un jugador o monstruo:
1. La flecha NO se destruye (`queue_free()`). En cambio, pasa al estado `STUCK_IN_BODY`.
2. Desactivar `CollisionShape2D` de la flecha (ya no puede matar).
3. Desactivar `velocity` y `proj_gravity` — la flecha deja de moverse por sus propias fuerzas.
4. Hacer `reparent(target_entity)` para que la flecha sea hija del nodo del cadáver. Guardar el `offset` relativo a la posición del cadáver para que viaje con él.
5. El `Sprite2D` de la flecha permanece visible con su ángulo de impacto (el ángulo se calcula de `velocity.normalized()` en el momento del impacto, antes de desactivar la velocidad).

### Fase 2: El cadáver con la flecha clavada viaja con el impulso de muerte
El cuerpo muerto recibe el impulso de la flecha (ver punto del impulso en V0.2). La flecha viaja pegada al cuerpo en todo momento, como si estuviera físicamente incrustada.

### Fase 3: Cuando el cadáver desaparece (timer ~2.5s)
Cuando el nodo del cadáver va a hacer `queue_free()`:
1. Antes de destruirse, el cadáver llama a `_drop_stuck_arrows()`.
2. `_drop_stuck_arrows()` itera sobre sus nodos hijos, encuentra todas las flechas en estado `STUCK_IN_BODY`, y:
   a. Las hace `reparent(get_tree().current_scene)` — se convierten en hijos de la escena raíz.
   b. Cambian su estado a `STUCK_IN_SURFACE`.
   c. Su posición `global_position` queda fijada donde estaban cuando el cadáver desapareció.
   d. Se activa el `CollisionShape2D` de recogida (el hitbox de pickup).
3. El cadáver se destruye. Las flechas quedan en la escena, clavadas en el suelo (o en la pared donde impactó el cuerpo), visibles y recogibles.
4. Las flechas en estado `STUCK_IN_SURFACE` desaparecen tras su timer normal de 8s, con efecto de fade out.

### Visual del ángulo de la flecha clavada en el suelo
Si la flecha impactó en un enemigo volando horizontalmente y el cadáver cayó al suelo, la flecha queda en el suelo con el ángulo que tenía al momento del impacto, no vertical. Es decir, puede quedar tumbada en diagonal, clavada en el suelo. Esto es correcto y da el look visual de TowerFall.

---

## 5. STOMP EN MONSTRUOS SALTADORES — DIAGNÓSTICO Y FIX
**Archivos afectados:** `GoblinJumper.gd`, `MonsterBase.gd`

**Diagnóstico del problema:**  
En TowerFall, el contacto lateral con un enemigo no es siempre letal. Los enemigos tienen dos estados: **pasivo** (el contacto no hace daño al jugador) y **ataque activo** (el contacto desde el lado o abajo mata al jugador). El stomp desde arriba funciona en **ambos estados**.

El bug reportado — que el stomp al Goblin Saltarín solo funciona cuando está en el suelo — probablemente ocurre porque:
- La `CollisionShape2D` de stomp (hitbox superior) del Goblin solo está activa en ciertos estados (por ejemplo, solo en `idle` o `land`), no durante el salto.
- O bien la hitbox del Goblin durante el salto es demasiado pequeña / está mal posicionada.

**Fix:**
1. En `GoblinJumper.gd`, asegurarse de que el `Area2D` de hitbox superior (la que detecta el stomp) está **siempre activo**, independientemente del estado del Goblin (saltando, en suelo, cayendo).
2. La hitbox superior del Goblin debe cubrir la parte de arriba del sprite en todos los frames de animación. Usar una `CollisionShape2D` de tipo `RectangleShape2D` que cubra los 2-3 px superiores del sprite. No debe depender de la animación activa.
3. En `MonsterBase.gd`, el método `_check_stomp_hit(body)` (o equivalente) solo debe mirar si el cuerpo que colisiona entra por arriba del monstruo — **nunca** verificar el estado de animación del monstruo para permitir o denegar el stomp.

**Respecto a si el salto es el ataque:**  
Sí, en el diseño actual el Goblin es peligroso por colisión. Pero según el punto 8 de esta actualización (ver abajo), la colisión lateral NO debe matar al jugador. Solo el contacto desde abajo (el jugador se mete bajo el Goblin mientras este cae) debe ser letal. El stomp desde arriba siempre mata al Goblin. Esto es coherente con TowerFall.

**Cambio de comportamiento del Goblin (ver también punto 14):** El Goblin ahora camina para moverse y solo salta para atacar. Esto hace que el stomp sea más justo porque el Goblin no está en el aire de forma aleatoria.

---

## 6. TROLL DE PIEDRA — PROYECTIL DEMASIADO RÁPIDO Y DIFÍCIL DE ESQUIVAR
**Archivos afectados:** `StoneTroll.gd`, `TrollStats.tres`, `Rock.gd`

**Problemas identificados:**
- El Troll dispara el pedrusco con demasiada frecuencia (cooldown muy corto).
- La velocidad del proyectil es tan alta que es difícil de ver y casi imposible de esquivar.
- A veces el proyectil no es visible (posiblemente relacionado con el tamaño del sprite o el frame rate).

**Fix:**

### Parámetros del proyectil (en `TrollStats.tres` / `Rock.gd`):
```
# Velocidad del pedrusco:
ROCK_INITIAL_SPEED = 160.0   # Reducido desde el valor actual. Debe ser visiblemente más lento que una flecha.

# Cooldown entre disparos:
ROCK_ATTACK_COOLDOWN = 4.0   # mínimo 4 segundos entre lanzamientos

# Tamaño del sprite: revisar que rock_flying tiene al menos 8×8px y que el Sprite2D
# tiene escala correcta en la escena. Si el sprite es menor de 6×6px en pantalla, aumentar.
```

### Comportamiento mejorado:
- El Troll debe hacer una **animación de preparación visible** antes de lanzar (`attack_throw` frames 1-2 = windup de 0.4s). Esto avisa al jugador de que viene un proyectil y da tiempo de reacción.
- El pedrusco debe tener una trayectoria parabólica clara (proj_gravity más baja que las flechas para que suba bien antes de caer, como un lanzamiento de morterete): `ROCK_PROJ_GRAVITY = 180.0`.
- Si el jugador no está por encima del Troll (`player.global_position.y >= troll.global_position.y`), el Troll no lanza el pedrusco — solo ataca con puño si el jugador está a su lado.

---

## 7. ELIMINAR DASH VERTICAL + REDUCIR DISTANCIA DEL DASH LATERAL
**Archivos afectados:** `PlayerBase.gd`, `PlayerStats.tres`

### Eliminar dash vertical (arriba y abajo):
- En `PlayerBase.gd`, en la función que calcula la dirección del dash (`_get_dash_direction()`):
  - Si `aim_direction.y != 0` y `aim_direction.x == 0` → **no ejecutar el dash** (ignorar el input completamente).
  - Si `aim_direction` es diagonal (componente horizontal Y vertical) → usar solo el componente horizontal: `dash_direction = Vector2(sign(aim_direction.x), 0)`.
- El dash solo puede ser horizontal: izquierda o derecha. Nunca hacia arriba ni hacia abajo.

### Distancia del dash lateral (−20% adicional sobre el −25% de velocidad general):
El punto 3 ya redujo `DASH_SPEED` de 400 a 300 (−25%). Ahora aplicar un −20% adicional solo al dash:
```
# Tras punto 3:
DASH_SPEED = 300.0

# Tras este punto (−20% adicional):
DASH_SPEED = 240.0
```
El `DASH_DURATION` permanece en 0.12s. Distancia efectiva del dash: 240 × 0.12 = **28.8px**. Esto es aproximadamente 2 "casillas" de ancho (≈ 14px × 2), un dash corto y preciso.

---

## 8. COLISIÓN LATERAL CON ENEMIGOS NO DEBE MATAR AL JUGADOR
**Archivos afectados:** `MonsterBase.gd`, `GoblinJumper.gd`, `StoneTroll.gd`, `ShadowBat.gd`, `SpecterArcher.gd`

**Referencia TowerFall:** En TowerFall Ascension, los enemigos tienen un estado pasivo en el que el contacto lateral no es letal. Solo mueres si el enemigo está en su animación de ataque activo y te toca. Esto es fundamental para que el juego sea justo.

**Implementación:**

### En `MonsterBase.gd`:
Añadir una variable de estado: `is_attack_active: bool = false`.

La colisión con el jugador solo causa daño si `is_attack_active == true`.

```gdscript
func _on_body_entered(body):
    if body.is_in_group("players"):
        if is_attack_active:
            body.die()       # el jugador muere
        else:
            _apply_side_bump(body)   # rebote suave, sin daño
```

### `_apply_side_bump(player)`:
```gdscript
func _apply_side_bump(player):
    var bump_direction = (player.global_position - global_position).normalized()
    # Solo componente horizontal del rebote:
    player.velocity.x += bump_direction.x * 60.0   # impulso pequeño
    # NO modifica velocity.y — no lanza al jugador hacia arriba ni abajo
```

### Cuándo está `is_attack_active`:
Cada monstruo activa/desactiva este flag en sus propias animaciones:

| Monstruo | `is_attack_active = true` durante... |
|---|---|
| Goblin Saltarín | Los frames de caída cuando viene desde arriba (caída sobre el jugador, NO el salto de ataque — ver punto 14) |
| Espectro Arquero | Los frames de la animación `specter_attack` (mientras dispara) |
| Troll de Piedra | Los frames de `troll_attack_punch` (frames 2-4 del swing) y `troll_attack_throw` (no, el peligro es el proyectil) |
| Murciélago Sombra | Durante toda la animación `bat_dive` (el picado completo) |

### El stomp no se ve afectado por este flag:
El stomp (desde arriba) siempre mata, independientemente de `is_attack_active`. El flag solo controla la colisión lateral y desde abajo.

---

## 9. ENGANCHE VERTICAL EN PARED — LIMITAR A UNO POR VUELO
**Archivos afectados:** `PlayerBase.gd`

**Problema:** El enganche vertical (salto ↑ desde pared, implementado en V0.2 punto 14) se puede repetir indefinidamente, subiendo todo el mapa.

**Fix:**

Añadir un flag separado `_wall_hang_used: bool = false`, independiente del `_wall_jump_used` del zig-zag.

```gdscript
# Al ejecutar el enganche vertical:
if is_on_wall() and jump_pressed and aim_direction == Vector2.UP:
    if not _wall_hang_used:
        _wall_hang_used = true
        _execute_wall_hang_jump()

# Al tocar el suelo:
func _on_landed():
    _wall_jump_used = false
    _wall_hang_used = false   # resetear ambos al aterrizar
```

**Altura del enganche vertical:**
El enganche vertical debe usar exactamente `JUMP_VELOCITY` (el salto normal), no `WALL_JUMP_VERTICAL`:
```
velocity.y = JUMP_VELOCITY   # -195.0 tras el punto 2
velocity.x = 0               # sin impulso horizontal
```
Esto lo hace igual de alto que un salto normal, ni más ni menos.

**Resumen del sistema completo de wall jump tras este fix:**
- **Zig-zag** (dirección opuesta a la pared): 1 por vuelo, resetea al tocar suelo. Impulso diagonal.
- **Enganche vertical** (dirección ↑): 1 por vuelo, resetea al tocar suelo. Salto vertical = salto normal.
- No pueden encadenarse entre sí: si ya usaste el zig-zag, no puedes hacer enganche vertical en ese mismo vuelo, y viceversa. Ambos flags se resetean juntos al aterrizar.

---

## 10. NUEVA MECÁNICA: LEDGE GRAB (AGARRARSE AL BORDE)
**Archivos afectados:** `PlayerBase.gd`, `PlayerStats.tres`, añadir animación `archer_ledge_grab` y `warrior_ledge_grab`

**Referencia TowerFall:** En TowerFall Ascension, el jugador puede agarrarse a cualquier borde de plataforma. Esta es una mecánica de posicionamiento muy importante: permite colgarse de un borde para esperar, esquivar, y luego saltar o escalar. El jugador puede colgarse del borde con el cuerpo por debajo y la plataforma por encima.

### Condiciones de activación del Ledge Grab:
El ledge grab se activa cuando **todos** estos se cumplen simultáneamente:
1. El jugador está en el aire (no `is_on_floor()`).
2. El jugador está moviéndose hacia abajo o en horizontal (no en la fase ascendente de un salto — `velocity.y >= 0`).
3. El borde de colisión del jugador roza la esquina superior de una plataforma o pared.
4. El jugador está manteniendo presionada la dirección hacia esa pared/esquina.

### Detección de la esquina:
En Godot 4, esto se detecta con un `RayCast2D` corto situado en el hombro del personaje (a la altura del cuello, no de los pies). Si el raycast lateral toca una superficie y el raycast vertical justo encima del jugador no toca nada (hay espacio), hay una esquina de ledge agarrable.

```
Diagrama:
         ████████   ← plataforma
    →[P]            ← jugador en el aire rozando el borde, manteniendo →
```
El jugador se "cuelga" del borde: la parte superior de su hitbox queda a la altura de la superficie de la plataforma.

### Estado `LEDGE_HANG`:
Al activarse:
- `velocity = Vector2.ZERO` — el jugador queda estático.
- Gravedad desactivada mientras dure el estado.
- Animación: pose de colgado (usar `wall_slide` o crear `ledge_grab` — ambas clases deben tener este sprite).
- El jugador puede:
  - **Saltar (arriba):** Salta desde el borde con `JUMP_VELOCITY`. Sale por arriba de la plataforma. → Vuelve a estado `JUMP`.
  - **Soltar (abajo o dirección opuesta):** Suelta el borde y cae. → Vuelve a estado `FALL`.
  - **No puede atacar mientras cuelga.** (Igual que en TowerFall.)
- Si el jugador no da ningún input durante **3 segundos**, se suelta automáticamente (evita quedarse pegado).

### Integración con el FSM del jugador:
Añadir `LEDGE_HANG` como estado explícito en el `StateMachine` del `PlayerBase`. Transiciones:
```
FALL → LEDGE_HANG   (al detectar esquina + dirección hacia ella)
LEDGE_HANG → JUMP   (input de salto)
LEDGE_HANG → FALL   (input de soltar o timeout)
```

---

## 11. AUMENTAR FUERZA DE ATRACCIÓN DE FLECHAS HACIA ENEMIGOS
**Archivos afectados:** `Arrow.gd`

**Cambio:** Aumentar `ARROW_ATTRACTION_STRENGTH` de 180.0 a **300.0**.

Esto hace la atracción más perceptible — no es autoaim, pero las flechas que pasan cerca de un enemigo tendrán más probabilidad de redirigirse ligeramente hacia él. El jugador lo notará como que "casi siempre impacta cuando apunta bien".

Mantener las demás condiciones de la implementación del V0.2 (radio de 30px, cono de 60° delante de la flecha, desactivar atracción en los últimos 4px).

Ajuste adicional: Aumentar el **radio de detección** de 30px a **40px** para que la atracción se inicie un poco antes.

---

## 12. REDUCIR VELOCIDAD DE LAS FLECHAS UN 25%
**Archivos afectados:** `ArrowStats.tres`

```
# Valores tras V0.2:
ARROW_INITIAL_SPEED = 500.0

# Nuevo valor (−25%):
ARROW_INITIAL_SPEED = 375.0

# El ataque 2 (cono cargado) también se reduce:
ARROW_CHARGED_SPEED = 450.0 → 337.0   (redondeado a 340.0)
```

La `proj_gravity` no cambia (250.0). Al reducir la velocidad inicial, el arco se hace más pronunciado (las flechas caen antes), lo que da más peso a la puntería y hace el juego más estratégico.

Verificar tras el cambio que una flecha disparada horizontalmente desde el centro sigue siendo útil a corta-media distancia antes de caer. Si cae demasiado pronto, reducir `proj_gravity` a 200.0.

---

## 13. SISTEMA DE VIDAS EN MODO HISTORIA + AJUSTES AL RESPAWN
**Archivos afectados:** `PlayerBase.gd`, `HUD.tscn`, `HUD.gd`, `LevelBase.gd`, `StoryMode.gd`

### Aplicar las 4 vidas al Modo Historia:
El sistema de vidas implementado en V0.2 para Versus se aplica también al Modo Historia. Las diferencias:
- En Historia hay un solo jugador, así que el HUD muestra solo las vidas de P1 (esquina superior izquierda).
- Al llegar a 0 vidas en Historia → Game Over → pantalla de "HAS CAÍDO" con opción de reiniciar el nivel.
- Las vidas se reponen al completar un nivel (empiezas cada nivel con 4 vidas).

### Ralentizar el proceso de revivir un 50%:
```
# Duración actual del viaje del cristal al punto de spawn:
RESPAWN_TRAVEL_DURATION = 0.6s

# Nuevo valor (+50% más lento):
RESPAWN_TRAVEL_DURATION = 0.9s

# Duración de la invulnerabilidad post-spawn (el parpadeo):
SPAWN_INVULN_DURATION = 1.0s → 1.5s   (también ralentizado)
```

### El cristal viaja al cuerpo muerto, no al punto de spawn:
**Este es el cambio más importante del punto.** Actualmente el cristal del HUD viaja a la posición de spawn predefinida. El nuevo comportamiento:

1. Al morir el jugador, guardar `corpse_global_position` (la posición donde quedó el cadáver).
2. El cristal (bola de energía) parte del HUD y viaja a `corpse_global_position`.
3. Al llegar al cadáver, el cadáver desaparece (si no lo había hecho ya) y el jugador respawnea **en esa misma posición** con el efecto de onda expansiva.
4. Si el cadáver ya desapareció antes de que llegue el cristal (el timer del cadáver expiró), el cristal continúa hacia la última posición conocida del cadáver y el jugador aparece allí igualmente.
5. Si la posición del cadáver está en el vacío (Nivel 2, caída mortal): el jugador reaparece en el spawn point más cercano al borde del vacío. Esto evita que respawnee en el vacío y muera de nuevo instantáneamente.

---

## 14. NOMBRES DE MONSTRUOS VISIBLES EN PANTALLA (DEBUG + PRODUCCIÓN)
**Archivos afectados:** `MonsterBase.gd`, escenas de cada monstruo

### Implementación:
- Añadir un `Label` como nodo hijo en cada escena de monstruo, posicionado encima del sprite.
- El `Label` muestra el nombre del monstruo (hardcoded en cada escena: `"Goblin Saltarín"`, `"Espectro Arquero"`, `"Troll de Piedra"`, `"Murciélago Sombra"`).
- Tamaño de fuente muy pequeño (usar la fuente pixel del juego, tamaño 4-5px en resolución nativa).
- Color: blanco con outline negro de 1px para legibilidad sobre cualquier fondo.
- El `Label` es siempre visible (no solo en debug). Sirve para identificar monstruos durante el testing y da personalidad al juego.
- Posición: 2-3px por encima del borde superior del sprite del monstruo.
- En `MonsterBase.gd`, exponer una variable `export var monster_name: String = ""` que cada subclase asigna en `_ready()` y que se pasa al `Label`.

---

## 15. GOBLINS SALTARINES — CAMBIO DE COMPORTAMIENTO: CAMINAR, SALTAR PARA ATACAR
**Archivos afectados:** `GoblinJumper.gd`, `GoblinStats.tres`

**Referencia TowerFall:** Los Slimes de TowerFall se mueven andando y solo saltan cuando atacan. No saltan para desplazarse.

**Nuevo comportamiento del Goblin Saltarín:**

### FSM rediseñada:
```
Estados: PATROL → CHASE → ATTACK_JUMP → LAND → (vuelta a CHASE o PATROL)
```

### PATROL (sin jugador detectado):
- El Goblin camina de un extremo al otro de su plataforma a velocidad lenta (`GOBLIN_PATROL_SPEED = 30.0 px/s`).
- Al llegar al borde de la plataforma, se gira y camina en dirección opuesta.
- Animación: `goblin_walk` (si no existe, crear una de 4 frames — pasos cortos y rápidos, expresión distraída).
- No salta en ningún momento durante el patrol.

### CHASE (jugador detectado, en radio de 80px horizontal):
- El Goblin camina hacia el jugador a velocidad mayor (`GOBLIN_CHASE_SPEED = 60.0 px/s`).
- Animación: `goblin_walk` (más rápido).
- Si el jugador está en una plataforma diferente a la del Goblin → transición a `ATTACK_JUMP`.
- Si el jugador está en la misma plataforma y a menos de 20px → transición a `ATTACK_JUMP`.

### ATTACK_JUMP (el salto ES el ataque):
- El Goblin hace una pequeña anticipación (0.2s, animación `goblin_jump` frame 1 — encogimiento).
- Luego salta hacia la posición del jugador: calcula la trayectoria para llegar a donde está el jugador (misma lógica que el salto actual pero dirigido).
- `is_attack_active = true` durante **toda la fase de caída** (desde el punto más alto del salto hasta aterrizar).
- `is_attack_active = false` durante la fase de subida (al saltar, el Goblin no es letal — solo en la caída).
- Esto hace que el jugador pueda esquivar el salto moviéndose mientras el Goblin sube, pero si está debajo cuando cae, muere.
- Animación de subida: `goblin_jump`. Animación de caída: `goblin_fall`.

### LAND:
- Al aterrizar: animación `goblin_land` (aplastamiento).
- `is_attack_active = false`.
- Pequeña pausa de 0.4s.
- Si el jugador sigue cerca → `ATTACK_JUMP`. Si no → `CHASE` o `PATROL`.

### Stomp:
- El stomp funciona en cualquier estado del Goblin, incluyendo durante `ATTACK_JUMP`. Esto es correcto y esperado.
- Durante la **subida** del salto (`is_attack_active = false`), el jugador puede pisarle sin peligro.
- Durante la **caída** (`is_attack_active = true`), si el jugador le pisa desde arriba = stomp (el jugador mata al Goblin). Si el Goblin cae sobre el jugador = el jugador muere.

---

## 16. REVISIÓN GENERAL DE IA Y BALANCE DE MONSTRUOS
**Archivos afectados:** `GoblinJumper.gd`, `SpecterArcher.gd`, `StoneTroll.gd`, `ShadowBat.gd`, todos los `*Stats.tres`

Esta sección formaliza el comportamiento correcto de cada monstruo, incluyendo los cambios de esta actualización y los que ya deberían funcionar de versiones anteriores. Tomar esto como la **especificación autoritativa** del comportamiento de cada monstruo.

---

### GOBLIN SALTARÍN — Especificación definitiva
(Ver punto 15 para el FSM completo)

| Parámetro | Valor |
|---|---|
| Tamaño | 10×12px (tras reducción 40% del V0.2) |
| Patrol speed | 30 px/s |
| Chase speed | 60 px/s |
| Detection radius | 80px horizontal |
| Jump force | -200 px/s (vertical) + impulso hacia el jugador |
| `is_attack_active` | Solo durante la caída del salto de ataque |
| Stomp | Siempre posible desde arriba |
| Contacto lateral | Rebote suave sin daño (punto 8) |
| Nombre display | "Goblin Saltarín" |

**Problemas a verificar y corregir:**
- La IA no debe quedar atascada en bordes de plataforma. Al llegar al borde, girarse inmediatamente.
- El salto de ataque debe apuntar al jugador en el momento del salto, no seguirle durante el vuelo (el Goblin no tiene misiles teledirigidos).

---

### ESPECTRO ARQUERO — Especificación definitiva

| Parámetro | Valor |
|---|---|
| Tamaño | 14×18px (tras reducción 40%) |
| Velocidad de vuelo | 70 px/s |
| Distancia preferida al jugador | 90-120px |
| Cadencia de disparo | Cada 2.5s |
| Velocidad del proyectil espectral | 160 px/s |
| `proj_gravity` del proyectil | 0 (atraviesa plataformas, vuelo recto) |
| `is_attack_active` | Durante `specter_attack` frames 2-5 |
| Stomp | No (corona espinosa en la hitbox superior) |
| Contacto lateral | Rebote suave sin daño |
| Nombre display | "Espectro" |

**Comportamiento:**
- Se posiciona en zonas elevadas preferentemente.
- Si el jugador se acerca a menos de 50px, retrocede activamente.
- Dispara con leve aim-ahead (predice 0.3s de movimiento del jugador al calcular el ángulo).
- Si no tiene línea de visión al jugador (obstruida por plataformas), espera y reposiciona.

**Problemas a verificar:**
- El proyectil espectral debe ser visible. Asegurarse de que `spectral_bolt` tiene tamaño correcto (mínimo 6×6px en pantalla) y que su animación de loop está activa.
- La cadencia de 2.5s debe contar desde que el proyectil anterior impacta o desaparece, no desde que se disparó — esto evita que dispare mientras el anterior sigue en vuelo.

---

### TROLL DE PIEDRA — Especificación definitiva

| Parámetro | Valor |
|---|---|
| Tamaño | 20×22px (tras reducción 40%) |
| Velocidad de patrol | 20 px/s |
| Rango del puñetazo | 40px a ambos lados |
| Cooldown del puñetazo | 2.0s |
| Cooldown del pedrusco | 5.0s |
| Velocidad del pedrusco | 160 px/s |
| `proj_gravity` del pedrusco | 180 px/s² |
| Condición para lanzar pedrusco | El jugador está por encima (`player.y < troll.y - 10`) |
| `is_attack_active` | Durante frames 2-4 de `troll_attack_punch` |
| Stomp | Sí |
| Nombre display | "Troll" |

**Comportamiento:**
- Patrulla su plataforma sin abandonarla nunca (no salta a otras plataformas).
- Al detectar al jugador en su plataforma a rango de puñetazo: ejecuta `attack_punch`.
- Al detectar al jugador por encima: ejecuta `attack_throw` con animación de windup visible (0.4s).
- No hace ambos ataques a la vez.

**Windup del pedrusco** (importante para la jugabilidad — ver punto 6):
- Frame 1 (`attack_throw`): el Troll mira hacia arriba, el brazo se levanta. (0.2s)
- Frame 2: el pedrusco aparece en la mano, brillando. (0.2s)
- Frame 3: lanzamiento. El pedrusco sale disparado.
- El jugador tiene 0.4s para reaccionar desde que ve el windup hasta que el proyectil sale.

---

### MURCIÉLAGO SOMBRA — Especificación definitiva

| Parámetro | Valor |
|---|---|
| Tamaño | 16×12px (tras reducción 40%) |
| Velocidad de vuelo circular | 120 px/s |
| Radio del patrón circular | 50px |
| Velocidad del dive-bomb | 280 px/s |
| Duración del stun post-dive | 0.6s |
| Detection range para dive | 100px vertical debajo del murciélago |
| `is_attack_active` | Durante toda la animación `bat_dive` |
| Stomp | Sí, pero solo durante `bat_stun` |
| Contacto lateral (fuera del dive) | Rebote suave sin daño |
| Nombre display | "Murciélago" |

**Comportamiento:**
- Fase circular: vuela en círculo alrededor de su punto de spawn original.
- Condición de dive: el jugador está dentro del `detection range` vertical y el murciélago está por encima.
- Durante el dive: vuela en línea recta hacia la posición donde estaba el jugador **al inicio del dive** (no te-seeking).
- Si el dive impacta suelo/plataforma sin golpear al jugador: entra en `bat_stun`.
- Si impacta al jugador: el jugador muere. El murciélago regresa a la fase circular.
- **No puede hacer dive dos veces seguidas sin volver a la fase circular:** tras cada dive (hit o miss), siempre vuelve a circular durante mínimo 1.5s antes de poder hacer otro dive.

**Problemas a verificar:**
- El murciélago debe ser visible durante el dive. Si se mueve demasiado rápido, considerar reducir `bat_dive` speed a 240 px/s.
- El `bat_stun` debe ser un estado claramente visible (ojos en espiral, inmóvil) para que el jugador sepa cuándo puede pisarlo.

---

## ORDEN DE IMPLEMENTACIÓN RECOMENDADO

```
Prioridad 1 — Cambios de parámetros (rápidos, sin código nuevo):
  → Punto 1  (nombre del juego)
  → Punto 2  (altura salto +15%)
  → Punto 3  (velocidad general −25%)
  → Punto 7  (dash lateral, eliminar vertical)
  → Punto 12 (velocidad flechas −25%)
  → Punto 11 (atracción flechas más fuerte)

Prioridad 2 — Fixes de bugs críticos de gameplay:
  → Punto 5  (stomp goblins — hitbox siempre activa)
  → Punto 8  (colisión lateral no mata)
  → Punto 9  (enganche vertical — 1 por vuelo)
  → Punto 6  (troll: proyectil más lento + windup)

Prioridad 3 — Mecánicas existentes a corregir:
  → Punto 4  (flechas visibles siempre — clavadas en cadáver y en suelo)
  → Punto 13 (vidas en Historia + cristal viaja al cadáver)
  → Punto 15 (goblins caminan, saltan para atacar)

Prioridad 4 — Nuevas mecánicas:
  → Punto 10 (ledge grab)

Prioridad 5 — UI y presentación:
  → Punto 14 (nombres de monstruos)
  → Punto 16 (revisión general IA — verificar y corregir usando las specs)
```

---

## AL TERMINAR ESTA ACTUALIZACIÓN

- Actualizar `CHANGELOG.md` con versión `0.4.0` (o `0.3.1` si se considera hotfix).
- Registrar en `BUGS.md` los bugs que se cierran con esta actualización (puntos 4, 5, 6, 8, 9).
- Actualizar los valores de parámetros definitivos en `DOCUMENTO_MAESTRO.md` (sección 3 — parámetros base) con los nuevos valores de velocidad, salto y dash.
- Verificar en los 3 niveles que todos los monstruos se comportan según sus especificaciones de la sección 16.
