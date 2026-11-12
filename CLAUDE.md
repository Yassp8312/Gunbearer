# Gunbearer

Shooter de fiesta en 3D hecho en **Godot 4.5 (GDScript)**. Segundo juego de la serie de Yassper Design (el primero fue MAAI). Autor: Jorge (GitHub `Yassp8312`).

**La idea en una línea:** solo un jugador tiene el Lanzador, y tenerlo te convierte en el blanco de todos.

## Cómo trabajar con Jorge

- Háblale en español, directo y en confianza. Llámalo Jorge.
- Antes de programar algo grande, define con él la arquitectura y un plan. Los arreglos pequeños, hazlos directo.
- Prefiere herramientas gratuitas o de costo mínimo.
- En su PC se trabaja en el disco **D:**. El C: está casi lleno: no instales ni generes nada ahí.
- Es un proyecto público: mantén el enlace pequeño a Jorge Coffee (`https://jorge-coffee.onrender.com/`) en el menú, la pausa, la pantalla final y el README.
- El plan de uso es Pro y se gasta rápido: evita exploraciones largas, lee solo los archivos que hagan falta.

## Reglas del juego (acordadas con Jorge)

- Un solo Lanzador por partida. El portador dispara bolas de pintura; cada eliminación da 1 punto.
- Los demás van desarmados. Si tocan al portador (radio 1,5 m), le roban el Lanzador al instante.
- El nuevo portador tiene 2 s de inmunidad al robo. El que lo perdió queda aturdido 1 s.
- El portador corre al 82 % de la velocidad normal y tiene 5 bolas, con 1,5 s de recarga.
- Todos tienen dash (Shift) con 3 s de enfriamiento.
- El eliminado sale volando pintado y reaparece a los 3 s, lejos del portador, con 1,2 s de escudo.
- La partida dura 3 minutos. Gana quien tenga más puntos.
- Tono: gracioso y caótico. Cámara en tercera persona sobre el hombro, controles de shooter.
- De 2 a 8 jugadores. Solo PC. Red local (no online por ahora) y modo contra bots.

**Controles:** WASD, mouse, clic izquierdo dispara, clic derecho apunta fino, Espacio salta, Shift dash, R recarga, Esc pausa/menú, Q sale al menú (con el menú abierto o al terminar), Enter lanza otra ronda (solo quien manda).

## Cómo ejecutarlo

- Godot está en `D:\Trabajo\Motores\Godot\Godot_v4.5-stable_win64.exe`. Mira si al lado hay un `..._console.exe`: ese muestra los errores en la terminal.
- Proyecto: esta carpeta (`project.godot`). Escena principal: `res://scenes/menu.tscn`.
- Para probar la red en una sola PC hacen falta dos copias del juego: lánzalas por línea de comandos (`--path .`) o desde el editor con *Depurar → Personalizar instancias de ejecución* (2 instancias). El cliente se une con la IP `127.0.0.1`.
- No hay tests automáticos. La verificación es correr el juego y mirar la consola.
- **Prueba de red sin manos:** hay atajos de línea de comandos (van después de `--`, están documentados en `Net._read_test_args`). Con `--headless` no abre ventana ni captura el mouse. Ejemplo, en dos terminales:
  - Host: `Godot_console.exe --headless --path . -- --host --name=Anfi --bots=2 --match=25 --autopilot --netlog --rematch --quit-after=75`
  - Cliente: `Godot_console.exe --headless --path . -- --join=auto --name=Invi --autopilot --netlog --leave-after=45 --quit-after=65`
  - `--netlog` imprime cada evento y las posiciones cada 5 s: los dos registros deben coincidir. Con atajos de prueba activos no se guarda `settings.cfg`.

## Estructura

```
project.godot          Autoloads: Tuning, Sfx, Net. Ventana 1280x720.
scenes/menu.tscn       Nodo raíz "Menu" con scripts/menu.gd
scenes/main.tscn       Nodo raíz "Main" (Node3D) con scripts/main.gd  -> la partida
autoload/tuning.gd     TODOS los números del juego y los presets de dificultad
autoload/sfx.gd        Sonidos generados por código (no hay archivos de audio)
autoload/net.gd        Red: ENet, sala de espera, búsqueda UDP y todos los RPC
scripts/menu.gd        Menú principal y sala de espera (UI por código)
scripts/main.gd        La partida: arena, jugadores, cámara, eventos, efectos
scripts/match.gd       Estado de la partida: portador, puntos, tiempo, robos, impactos
scripts/player.gd      Un jugador (humano local, remoto o bot)
scripts/bot.gd         Cerebro de un bot (RefCounted)
scripts/ball.gd        Bola de pintura
scripts/hud.gd         Interfaz de la partida (CanvasLayer por código)
```

**Convención importante:** casi todo se construye por código (arena, jugadores, UI, materiales). Las escenas `.tscn` solo tienen el nodo raíz con su script. No hay assets: los personajes son cápsulas de colores.

## Arquitectura

### Quién manda

`main.gd` tiene tres banderas que deciden todo:

- `authority`: esta PC decide (es el host, o juegas solo, o es la demo del menú).
- `online`: hay red de por medio (`Net.mode` es `"host"` o `"client"`).
- `demo`: partida de puros bots que corre de fondo en el menú, sin HUD ni sonido.

Modelo de red: **cada jugador mueve su propio muñeco** y manda su posición; **el host decide todos los eventos** (robos, impactos, puntos, reapariciones, fin). Los bots corren en el host.

### Jugadores

- `Net.roster` es un Array de `{"peer": int, "name": String}`. El índice es el `slot`. `peer` 0 = bot, 1 = host.
- `player.is_local`: lo simula esta PC (tu humano, o un bot si `authority`). Si no es local, solo interpola hacia `net_pos` / `net_yaw`.
- Humanos y bots comparten el mismo código: el teclado (`_read_human`) o el bot (`brain.think`) llenan las mismas variables `in_move`, `in_jump`, `in_dash`, `in_shoot`, `in_reload`, `aim_point`.

### Eventos

Quien manda llama a `main.emit_event(kind, args)`: lo aplica en local con `apply_event` y, si hay red, lo manda a todos con `Net.send_event`. Los clientes solo ejecutan `apply_event`.

| Evento | Args | Qué hace |
|---|---|---|
| `EV_START` 0 | `[slot_portador]` | Empieza la cuenta atrás |
| `EV_GIVE` 1 | `[slot_nuevo, slot_anterior]` | Robo del Lanzador |
| `EV_BALL` 2 | `[id, slot_tirador, origen, dir]` | Aparece una bola |
| `EV_ELIM` 3 | `[slot_víctima, slot_tirador, dir, id_bola]` | Eliminación y punto |
| `EV_RESPAWN` 4 | `[slot, posición]` | Reaparición |
| `EV_END` 5 | `[puntos]` | Fin de la partida |
| `EV_TAKEOVER` 6 | `[slot]` | Un jugador se fue: lo lleva un bot |

### Mensajes de red (todos en `autoload/net.gd`)

Todos los RPC viven en el autoload `Net`, **no** en los nodos de la partida, a propósito: así nunca llegan a un nodo que todavía no existe en otra PC. `Net` los reenvía a `Net.game` si hay partida cargada.

- Sala: `c_hello` (cliente → host), `s_lobby`, `s_reject`, `s_start` (host → todos), `c_ready` (cliente → host al cargar la escena).
- Partida: `x_state` (posición, 30 Hz, sin garantía), `c_shoot` (cliente pide disparar), `s_event` (eventos, fiable), `s_sync` (estado, tiempo y puntos 4 veces por segundo, para corregir desfases).
- Puertos: **24570** ENet (juego), **24571** UDP (el host anuncia la partida cada segundo; los clientes escuchan).
- El host espera a que todos manden `c_ready` (o 8 s) antes de `EV_START`.
- Si el host se cae, los clientes vuelven al menú con un aviso.

### Estados de `match.gd`

`WAITING` 0 → `COUNTDOWN` 1 → `PLAYING` 2 → `ENDED` 3. Úsalos con `is_waiting()`, `is_counting()`, `is_playing()`, `is_ended()`.

### Física y capas

- Capa 1: mundo (StaticBody3D). Capa 2: jugadores. Los jugadores solo chocan con el mundo, no entre sí.
- Los toques y los impactos se calculan por distancia en `match.gd`, no con el motor de físicas.
- Las bolas se mueven a mano con raycasts contra la capa 1.

## Estado actual (12 de noviembre de 2026)

### Hecho y probado corriendo en Godot (0 errores en consola)

- Menú principal con la demo de bots de fondo.
- Partida contra bots desde el menú: cantidad de bots (1 a 7) y dificultad (fácil, normal, difícil).
- Todas las reglas, HUD, pausa, pantalla final.
- Pulido: salpicaduras, estela del dash, anillo al robar, rachas ("¡DOBLE!", "¡TRIPLE!", "¡IMPARABLE!"), cuatro trampolines y dos torres en la arena.
- Una partida creada como host con bots de relleno arrancó y corrió.

### Red: probada el 12 de noviembre de 2026 con dos copias en una PC (sin ventana, con pilotos automáticos)

Host y cliente en `127.0.0.1`, 0 errores en ambas consolas, eventos y puntos idénticos en los dos registros:

- Búsqueda automática por UDP, sala, `s_start`, `c_ready`, posiciones sincronizadas.
- Robo y disparo desde el cliente (`c_shoot`), impactos, reapariciones, fin de partida.
- Otra ronda lanzada por el host.
- Cliente que sale al menú o cierra el juego: lo reemplaza un bot (`EV_TAKEOVER`). Al cerrar la ventana, `Net` cierra la conexión para que el host se entere al instante.

### Todavía SIN probar

- **Jugar la red a mano, con ventanas**: cámara, HUD y sensación de retraso vistos desde el cliente.
- **Dos PC distintas en la misma red** (firewall de Windows, búsqueda por broadcast real).
- Las teclas Q y Enter pulsadas a mano (la salida y la otra ronda se probaron llamando al mismo código, no con el teclado).

### Detalles a tener en cuenta

- Git: inicializado, rama `main`, sin remoto todavía.
- Los bots no usan malla de navegación: persiguen en línea recta y saltan o rodean cuando se atascan.
- Dificultad normal: Jorge dijo que está "un poco difícil pero bien". No la bajes sin preguntar.
- Si cambias `project.godot` con el editor abierto, Godot pregunta si recarga desde el disco: hay que decir que sí.
- La primera vez que se crea una partida, Windows pregunta por el firewall.

## Qué sigue, en orden

1. Que Jorge juegue la red a mano (dos ventanas, y mejor aún dos PC) y arreglar lo que note.
2. Subir el proyecto a GitHub como `Yassp8312/Gunbearer`.
3. Arte: un solo cuerpo base con esqueleto y animaciones, y que los jugadores se diferencien por color y accesorios (sombreros, gafas, mochilas). Jorge quiere generar modelos con IA; la idea acordada es usar la IA para los accesorios y objetos sin animación, y Mixamo para el esqueleto del cuerpo base.
4. Para después: power-ups, más arenas, mandos, online por internet.

## Estilo de código

- GDScript con **tabuladores**.
- Tipos explícitos en variables locales y parámetros simples (`var d: float = ...`).
- Las referencias entre scripts (`game`, `match_state`, `brain`, jugadores) van **sin tipo**, para evitar dependencias circulares.
- Comentarios y textos del juego en español.
- Para balancear, cambia números en `autoload/tuning.gd`, no en el resto del código.
