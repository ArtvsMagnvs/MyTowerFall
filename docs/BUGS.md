# BUGS — Niide: El Círculo Dárico

Registro de bugs conocidos. Actualizar en cada sesión de desarrollo.

---

## Bugs activos

---
ID: BUG-002
Estado: ABIERTO
Severidad: BAJO
Descripción: El dash por defecto del Jugador 2 está mapeado a la tecla "/" en lugar de RShift.
Reproducción:
  1. Abrir Opciones → Controles.
  2. Observar el binding de Dash del Jugador 2.
Causa raíz: Godot empareja acciones por keycode físico sin distinguir LShift/RShift cuando
  ambos comparten teclado; usar Shift para ambos jugadores provocaría dash simultáneo.
Fix aplicado: Pendiente. Workaround: el usuario puede remapearlo manualmente desde Opciones.
Fecha apertura: 2026-06-23
Fecha cierre:
---

---
## Bugs cerrados

---
ID: BUG-036  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-28 (V0.8.7.2)
Descripción: Los monstruos (Troll, Slime, Murciélago) entraban en un bucle "clavado-cíclico" cuando
  el jugador estaba sobre una plataforma/estructura con geometría en medio: caminaban unos px hacia
  el jugador, chocaban con la base de la plataforma, unstuck 1.5s, re-perseguían, chocaban, etc.
  El anti-stuck de V0.8.7 (progreso+LoS) resolvía el "clavado indefinido" pero no este bucle.
  Adicionalmente el Murciélago, con unstuck perpendicular, no salía de debajo de la plataforma
  cuando el jugador estaba en vertical (el perpendicular quedaba horizontal).
Causa raíz: la lógica anti-stuck solo aplicaba el unstuck cuando se detectaba el atasco físico
  (progreso cero); no había un gate de LoS en la decisión de "perseguir", solo en la de "atacar".
  Resultado: si el monstruo avanzaba un poco antes de chocar, el anti-stuck nunca se disparaba
  y el bucle persistía.
Fix: Solución 1 — `STUCK_PATROL_T` 1.5 → 2.5s (Slime, Troll), `UNSTUCK_DURATION` 0.3/0.4 → 0.6s
  (Espectro, Murciélago). Solución 2 — nuevo gate de LoS en CHASE/TRACKING: si el monstruo
  acumula >0.5s sin LoS al jugador, sale del estado y vuelve a PATROL/FLYING; no re-engage hasta
  tener LoS directa. Murciélago extra: unstuck vertical cuando el jugador está sobre todo
  arriba/abajo. Aplicado también a Slime (mismo bucle) y al disparo del Espectro (disparaba a
  través de paredes). Verificado: V086bTest actualizado (E/F/G PASS), suite completa sin regresiones.
---
ID: BUG-035  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-27 (V0.8.7)
Descripción: El Murciélago se quedaba "clavado" cargando el dash cuando había una plataforma entre él y el jugador.
Causa raíz: el LoS comprobaba el ángulo EXACTO al jugador, pero el dash va en dirección snappeada a 8; si diferían, el dash chocaba contra la plataforma (bucle PREPARING→DASHING→RECOVERING).
Fix: antes de PREPARING_DASH se exige LoS limpia al jugador Y camino del dash (dir snappeada, ≈29px) despejado (`path_blocked`). Verificado: V086bTest (F/G).
---
ID: BUG-034  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-27 (V0.8.7)
Descripción: Troll y Murciélago se quedaban clavados oscilando en el sitio bajo/sobre un jugador inalcanzable con plataforma/suelo en medio (el anti-stuck por velocidad de V0.8.6 no lo detectaba: velocidad alta, avance neto ~0).
Fix: anti-stuck por PROGRESO real (desplazamiento neto en ventana) + gate de línea de visión (`is_stuck_no_los` en MonsterBase); solo circula si no avanza Y no ve al jugador (geometría en medio). Verificado: V086bTest (E) y V086Test.
---
ID: BUG-033  ·  Estado: CERRADO  ·  Severidad: CRÍTICO  ·  Cierre: 2026-06-26 (V0.8.5)
Descripción: El juego se congelaba/crasheaba al pulsar WASD o flechas en los menús (persistía pese a varios intentos).
Causa raíz (reproducida en headless): `UIInputBridge` sintetizaba acciones `ui_*` con `Input.parse_input_event`, que re-entraba en su propio `_input` mientras `is_action_just_pressed` seguía siendo true el mismo frame → recursión infinita → corrupción del motor.
Fix: `UIInputBridge` reescrito para mover el foco con la API de `Control` (`find_next/prev_valid_focus`+`grab_focus`) y detección de flanco en `_process`, sin `parse_input_event`. Verificado: V084uiTest (navegación de un paso, sin cuelgue).
---
ID: BUG-032  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-26 (V0.8.5)
Descripción: El wall slide continuaba "en el aire" al acabar el lateral de una pared/plataforma (persistía pese a BUG-026/031).
Causa raíz (reproducida en headless): el `_wall_slide_ray` estaba en el CENTRO del cuerpo; el slide seguía hasta que el centro pasaba el borde, dejando los pies ~5px deslizando en el aire.
Fix: rayo anclado a la altura de los PIES; el slide se corta cuando los pies dejan el lateral (verificado: rebase ≤1.5px). Además el ledge slide cae si el lateral ya no está al lado. Verificado: V084Test.
---
ID: BUG-031  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-26 (V0.8.4)
Descripción: El wall slide seguía "deslizando por el aire" tras acabar la pared (BUG-026 no se resolvió del todo: la condición dependía de `is_on_wall_only()`, que Godot reporta con retraso).
Fix: el wall slide lo gobierna SOLO el `_wall_slide_ray`, lanzado fresco cada frame hacia el lado pulsado; sin pared a ≤8px → cae con gravedad normal de inmediato. Verificado: V083fixTest (al soltar el input, vy pasa de 60 a 225).
---
ID: BUG-030  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-26 (V0.8.4)
Descripción: El stomp no mataba a los monstruos en muchos casos reales (caída descentrada o monstruo en movimiento): el cuerpo sólido (B-1) desviaba al jugador antes de que el rayo central de stomp se evaluara.
Fix: detección de stomp por las colisiones reales de `move_and_slide` (`get_slide_collision`, normal hacia arriba) en vez de un rayo central; el rayo de 6px queda como red de seguridad. Verificado: V083fixTest (descentrado ±3 en Slime, +5 en Troll, Slime con IA activa).
---
ID: BUG-029  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-26 (V0.8.3 P3)
Descripción: El stomp fallaba a veces con el Troll (el más grande) a velocidades de caída altas.
Fix: longitud del `_stomp_ray` 3px → 6px (sigue < 10px, no atraviesa plataformas). La "Causa A" del documento (StompHitbox en el .tscn) no aplica: el stomp detecta el cuerpo (L_STOMP_BODY), no un Area2D. Verificado: V083Test (stomp_kills_troll).
---
ID: BUG-028  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-26 (V0.8.3 P1)
Descripción: Regresión de V0.8.2 B-1: el jugador ya no atravesaba a monstruos/otros jugadores durante el dash (los cuerpos sólidos lo bloqueaban).
Fix: al entrar en DASH se retiran `L_PLAYER_BODY|L_MONSTER_SOLID` de la `collision_mask` y se restauran al salir. Verificado: V083Test (dash_through_slime).
---
ID: BUG-027  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-26 (V0.8.2 B-2/C-3)
Descripción: El Troll moría "espontáneamente" cuando el jugador aterrizaba en una plataforma situada encima de él (el rayo de stomp atravesaba la plataforma).
Fix: `_stomp_ray` incluye `L_WORLD` (se detiene en la geometría) y se acorta a 3px fijos. Verificado: V082Test (stomp_not_through_platform).
---
ID: BUG-026  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-26 (V0.8.2 B-4)
Descripción: El wall slide continuaba flotando en el aire al pasar el borde inferior de una plataforma flotante fina.
Fix: nuevo `_wall_slide_ray` (8px, L_WORLD); el wall slide exige contacto real de pared o transiciona a FALL.
---
ID: BUG-025  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-26 (V0.8.2 B-3)
Descripción: El stomp mataba unos pixels antes del contacto visual ("zona fantasma" por longitud/origen del rayo).
Fix: `_stomp_ray` con origen en el pie y longitud fija de 3px (posible gracias a B-1, monstruos sólidos).
---
ID: BUG-024  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-26 (V0.8.2 B-1)
Descripción: El jugador atravesaba físicamente a los monstruos (no tenían cuerpo sólido).
Fix: bit `L_MONSTER_SOLID=512` + `solid_body` en MonsterBase; Slime/Troll/Murciélago bloquean al jugador; el Espectro queda atravesable. Verificado: V082Test (solid_slime_blocks / specter_passthrough).
---
ID: BUG-023  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5.1 BUG-1)
Descripción: Las flechas (Area2D + movimiento manual) atravesaban paredes por tunneling a alta velocidad.
Fix: ProjectileBase pasa a CharacterBody2D con move_and_collide; golpea cuerpos de mundo/jugador/monstruo. Verificado con flecha a 600px/s (V051Test).
---
ID: BUG-022  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5.1 BUG-3)
Descripción: El stomp por overlap de Area2D fallaba en contactos sub-frame y aproximaciones rápidas.
Fix: RayCast2D hacia abajo que detecta CUERPOS stompables (L_STOMP_BODY), con hit_from_inside y longitud dinámica. Determinista. Verificado (V03/V05/Stomp).
---
ID: BUG-021  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5.1 CAMBIO-10)
Descripción: Las plataformas flotantes eran one-way (atravesables desde abajo), violando la regla universal.
Fix: plataformas sólidas por todos los lados. Verificado (V051Test: el jugador no cruza por debajo).
---
ID: BUG-020  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5 p.5)
Descripción: El stomp fallaba de forma intermitente en varios casos (aire/suelo, PvP).
Fix: reimplementación determinista con Area2D de pie + StompHitbox por capas y `receive_stomp()`. Verificado en V05Test (3 casos) y StompTest.
---
ID: BUG-019  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5 p.7)
Descripción: El Espectro Arquero atravesaba la geometría del escenario.
Fix: el Espectro deja de ignorar el mundo (colisiona con move_and_slide y máscara Layer 1).
---
ID: BUG-018  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-25 (V0.5)
Descripción: Parse error en ShadowBat.gd (`round` infería Variant y `snapped` colisiona con función nativa) que colgaba MonsterTest al cargarse en runtime.
Fix: tipado explícito con `roundf` y renombrado de la variable.
---
ID: BUG-017  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-24 (V0.4 p.7)
Descripción: El proyectil del Espectro atravesaba plataformas y suelos.
Fix: ningún proyectil atraviesa geometría; el espectral se disipa al chocar, las flechas se clavan. Verificado en boot de niveles y MonsterTest.
---
ID: BUG-016  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-24 (V0.4 p.1a)
Descripción: El Troll tenía un "ataque invisible" que golpeaba a distancia.
Fix: el puñetazo ahora es visible (VFX) y su hitbox solo está activo durante sus frames; sin daño por contacto pasivo (is_attack_active).
---
ID: BUG-015  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-24 (V0.4 p.2)
Descripción: Los monstruos no podían caer de plataformas (giro forzado en el borde).
Fix: eliminada la detección de borde; los monstruos persiguen al jugador y caen.
---
ID: BUG-014  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-24 (V0.3 p.8)
Descripción: El contacto lateral con un enemigo pasivo mataba al jugador injustamente.
Fix: `is_attack_active` en MonsterBase; el contacto solo mata durante el ataque activo, si no rebote suave. Verificado en V03Test.
---
ID: BUG-013  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-24 (V0.3 p.5)
Descripción: El stomp al Goblin solo funcionaba con el Goblin en el suelo, no en el aire.
Fix: hitbox de stomp geométrica siempre activa, sin depender del estado/animación. Verificado en V03Test (stomp sobre goblin AIRBORNE).
---
ID: BUG-012  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-24 (V0.3 p.6)
Descripción: El pedrusco del Troll era demasiado rápido/frecuente e imposible de esquivar.
Fix: velocidad 160, gravedad 180 (parábola), cooldown 5s, windup visible 0.4s y solo si el jugador está encima.
---
ID: BUG-011  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-24 (V0.3 p.9)
Descripción: El enganche vertical en pared se repetía infinitamente subiendo todo el mapa.
Fix: flag `_wall_hang_used` (uno por vuelo) sin encadenarse con el zig-zag; reset al aterrizar.
---
ID: BUG-010  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-24 (V0.3 p.4)
Descripción: Las flechas desaparecían al impactar en una entidad.
Fix: la flecha queda clavada en el cadáver y, al desvanecerse este, cae clavada al suelo (recogible 8s). Verificado en V03Test.
---
ID: BUG-009  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-23
Descripción: Wall jump zig-zag permitía escalar la pantalla en bucle.
Fix: Flag `_wall_jump_used`; un solo zig-zag por vuelo, se resetea al tocar suelo (V0.2 p.13).
---
ID: BUG-008  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-23
Descripción: Las flechas en línea recta caían demasiado pronto (poco alcance).
Fix: `ArrowStats.tres` con initial_speed 500 y proj_gravity 250 (V0.2 p.5).
---
ID: BUG-007  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-23
Descripción: Las flechas desaparecían al impactar en una entidad (no recogibles).
Fix: El cuerpo muerto (`Corpse`) conserva la flecha y es recogible (V0.2 p.9/10).
---
ID: BUG-006  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-23
Descripción: Los dos jugadores se traspasaban (sin colisión física).
Fix: Capa `L_PLAYER_BODY` en el cuerpo y máscara mutua (V0.2 p.4).
---
ID: BUG-005  ·  Estado: CERRADO  ·  Severidad: ALTO  ·  Cierre: 2026-06-23
Descripción: El stomp no mataba en Versus (sí a monstruos en Historia).
Fix: Área de stomp superior en `PlayerBase` + `_check_stomp_players()` (V0.2 p.3).
---
ID: BUG-004  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-23
Descripción: El Arquero caminaba al apuntar con las flechas y disparaba al pulsar.
Fix: `aim_lock` (estático al apuntar) y disparo al soltar el botón (V0.2 p.2A/2B).
---
ID: BUG-003  ·  Estado: CERRADO  ·  Severidad: MEDIO  ·  Cierre: 2026-06-23
Descripción: Las plataformas flotantes se atravesaban desde abajo.
Fix: Plataformas sólidas por todos los lados (one_way desactivado) (V0.2 p.1).
---
ID: BUG-001
Estado: CERRADO
Severidad: CRÍTICO
Descripción: Todos los scripts dependientes fallaban al compilar; el juego no arrancaba.
Reproducción:
  1. Ejecutar el proyecto.
  2. ProjectileBase declaraba `var gravity`, que colisiona con la propiedad nativa de Area2D.
Causa raíz: Nombre de variable reservado por la clase base nativa (Area2D.gravity).
Fix aplicado: Renombrada a `proj_gravity` y actualizadas todas las referencias
  (ProjectileBase, MonsterBase). Verificado con SmokeTest/IntegrationTest headless.
Fecha apertura: 2026-06-23
Fecha cierre: 2026-06-23
---

---

## Plantilla de registro

```
---
ID: BUG-XXX
Estado: ABIERTO
Severidad: CRÍTICO / ALTO / MEDIO / BAJO
Descripción:
Reproducción:
  1.
  2.
  3.
Causa raíz:
Fix aplicado:
Fecha apertura: AAAA-MM-DD
Fecha cierre:
---
```
