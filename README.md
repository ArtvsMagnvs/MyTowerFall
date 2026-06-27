# Niide: El Círculo Dárico — (v0.8.1)

> *(Antes "My Tower Fall"; renombrado en V0.3. La carpeta del proyecto conserva el nombre antiguo para no romper rutas.)*

> **Novedades V0.5.1 (v0.8.1):** correcciones de auditoría — proyectiles ahora son `CharacterBody2D` (sin atravesar paredes/tunneling); **stomp reescrito con RayCast** (fiable al 100%); el Espectro no atraviesa geometría ni vibra en los bordes; plataformas flotantes **sólidas por todos los lados**; **Murciélago** vuela en línea recta con rebote y dash en 8 direcciones (ya no en círculo). Diseño: **UI de menús nítida** (stretch canvas_items + tema), y los **controles de P1/P2 navegan los menús**. Ver `Docs/CHANGELOG.md`.

> **Novedades V0.5 (v0.8.0):** salto ×2 (más aéreo); dash solo en 4 ejes cardinales; **stomp reescrito** y fiable (jugador↔monstruo y PvP, con rebote encadenable manteniendo salto, el dash esquiva, el Espectro no es stompeable); **Murciélago rediseñado** (patrulla + dash en 8 direcciones con aviso previo, no atraviesa geometría); **atracción de flechas** gravitacional reescrita; **ledge grab** ahora requiere mantener la dirección (desliza si la sueltas) y se engancha exacto al borde; Slime más lento; el Espectro ya no atraviesa paredes; damping de caída al cruzar suelo/techo por wrapping. Ver `Docs/CHANGELOG.md`.

> **Novedades V0.4 (v0.7.0):** **screen wrapping** estilo TowerFall (sales por un borde y entras por el otro, con medio cuerpo en cada lado); **área de juego 240×180** con paneles HUD laterales de 40px; movimiento y salto −35% (juego más táctico); **dash hacia arriba** restaurado; **zig-zag de pared alternando paredes** sin tocar suelo; flechas −20% y sin atravesar geometría; el **Espectro** dispara menos y a menor rango; el **Troll persigue** y su golpe ya es visible; **Goblin Saltarín renombrado a Slime** (camina, salta solo para atacar); **3 niveles rediseñados** simétricos con zonas de wrapping. Ver `CHANGELOG.md`.

> **Novedades V0.3 (v0.6.0):** renombrado a **Niide: El Círculo Dárico**; salto +15% y movimiento general −25%; dash solo horizontal y más corto; flechas más lentas con atracción más fuerte y que se **clavan en cadáveres y en el suelo**; contacto lateral con enemigos ya no mata (solo su ataque activo); stomp fiable sobre goblins en el aire; Troll con pedrusco lento y telegrafiado; enganche vertical en pared limitado a uno por vuelo; nueva mecánica **ledge grab**; **4 vidas en Modo Historia** con respawn al cadáver; **nombres de monstruos** en pantalla; goblins que caminan y solo saltan para atacar. Ver `CHANGELOG.md`.

> **Novedades V0.2 (v0.5.0):** personajes al 60%, salto más bajo (la verticalidad ahora
> depende del dash y de los **enganches verticales encadenables** en pared), zig-zag limitado
> a uno por vuelo, colisión entre jugadores, **stomp PvP**, **4 vidas con respawn** (bola de
> energía + onda expansiva), flechas con más alcance, atracción magnética sutil, **impacto con
> impulso al cuerpo** (estilo TowerFall) y flechas recogibles del cadáver. El Arquero apunta
> manteniendo Ataque 1 (queda estático) y dispara al soltar. Ver `CHANGELOG.md` para el detalle.


Juego de plataformas de acción 2D estilo *TowerFall*: **un golpe = una muerte**.
Implementado en **Godot 4.7 (GDScript)**. Este MVP cubre todo el gameplay core con
arte placeholder geométrico, tal y como prioriza el `DOCUMENTO_MAESTRO.md`
(*"testea el movimiento con formas básicas primero, el pixel art viene después"*).

## Cómo ejecutar

1. Instala/abre **Godot 4.7** (ya instalado en este equipo vía winget).
2. Opción A — Editor: abre Godot, *Importar* → selecciona `project.godot` de esta carpeta y pulsa *Ejecutar* (F5).
3. Opción B — Línea de comandos (ruta del binario en este equipo):

```
& "C:\Users\Alejandro\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe" --path "C:\Users\Alejandro\Desktop\My Tower Fall"
```

## Controles por defecto

| Acción | Jugador 1 | Jugador 2 |
|---|---|---|
| Mover / apuntar izq-der | A / D | ← / → |
| Apuntar arriba-abajo | W / S | ↑ / ↓ |
| Saltar | Espacio | Enter |
| Dash | Shift izq. | `/` |
| Ataque 1 | Q | K |
| Ataque 2 (carga) | E | L |

Todo es **remapeable** en Opciones → Controles (se guarda en `user://input_config.cfg`).
Navegación de menús: flechas + Enter, o ratón.

### Teclas de debug
`F1` overlay · `F2` hitboxes · `F3` godmode · `F4` dash infinito.

## Contenido del MVP

- **Movimiento** completo: salto, coyote time, jump buffer, wall jump (zig-zag/vertical), dash con invulnerabilidad, apuntado 8 dir, squash & stretch.
- **Clases**: Arquero (flecha parabólica + cono cargado) y Guerrero (espada 2 casillas + carga).
- **Proyectiles universales**: gravedad parabólica, clavado 8s, recogida, contador de munición.
- **Monstruos**: Goblin, Espectro Arquero, Troll de Piedra, Murciélago Sombra (IA propia).
- **Niveles**: Bosque Antiguo, Ruinas Voladoras (caída mortal), Torre del Caos.
- **Modos**: Versus local al mejor de 5 · Historia (3 niveles con oleadas, intros y ending).
- **Opciones**: audio + remapeo de controles por jugador con resolución de conflictos.

## Verificación

Pruebas automáticas headless en `tests/` (ejecutables pasando la escena como argumento):

- `SmokeTest.tscn` — gravedad/colisión y kill por proyectil. **PASS**
- `IntegrationTest.tscn` — flujo completo de una partida Versus (rondas, respawn, fin). **PASS**
- `MonsterTest.tscn` — IA de los 4 monstruos sin fallos. **PASS**

```
& "<godot.exe>" --headless --path "<proyecto>" tests/SmokeTest.tscn
```

## Desviaciones conocidas respecto al documento (MVP)

- **Arte**: placeholders geométricos. La Fase 6 (pixel art completo) queda pendiente.
- **Audio**: `AudioManager` tiene la API lista pero aún no hay assets de sonido (silencioso).
- **Guerrero**: melee puro (sin munición). El hacha arrojadiza universal está soportada en
  `ProjectileBase` (parámetro de sprite) pero no enlazada a un input, ya que §4.2 lo define como melee.
- **Dash P2** por defecto en `/` en vez de RShift (ver `BUGS.md` BUG-002).
- **Gamepad**: detección y disposición por defecto; el remapeo persistente cubre teclado.
- **Build/instalador** (Fase 9): no incluido en este MVP; el proyecto está listo para exportar a Windows.

## Estructura

`scripts/` (autoloads, characters, monsters, projectiles, levels, ui) ·
`scenes/` (ui, levels, characters, monsters) · `resources/` (PlayerStats) · `tests/`.
