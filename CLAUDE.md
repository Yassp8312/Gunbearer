# Gunbearer

Shooter de fiesta en 3D hecho en **Godot 4.5 (GDScript)**. Segundo juego de la serie de Yassper Design (el primero fue MAAI). Autor: Jorge (GitHub `Yassp8312`).

**La idea en una línea:** solo un jugador tiene el Lanzador, y tenerlo te convierte en el blanco de todos.

## Rumbo: juego competitivo

El 12 de noviembre de 2026 Jorge dijo que quiere que Gunbearer se convierta en un juego competitivo. El alcance acordado es **por etapas: primero competitivo entre amigos en red local** (gratis y con la red actual); el salto a online con clasificación se decide después, cuando lo primero esté sólido. Cada decisión nueva debe respetar esto:

- **Juego limpio antes que adorno:** todos los personajes tienen el mismo tamaño de impacto. Desde el 12 de noviembre de 2026, por decisión de Jorge, los personajes se agrupan en **clases** con reglas distintas; cada clase tiene una ventaja **y un costo**, y ninguna debe ser la mejor en todo. No añadas una ventaja sin su costo.
- **Legibilidad:** tiene que verse al instante quién es quién y quién lleva el Lanzador.
- **Arenas justas:** simétricas, sin puntos de reaparición con ventaja.
- **Nada de azar que decida partidas** sin que Jorge lo apruebe.
- **Ojo con la red actual:** cada cliente manda su propia posición, así que hoy un cliente tramposo podría moverse como quiera. Sirve entre amigos; para online competitivo habría que pasar el movimiento al host o a un servidor.

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
- **Clases** (los 20 personajes se reparten entre 6; números en `Tuning.CLASSES`, sin probar todavía con gente): Artillero (7 bolas, recarga 2 s), Velocista (2 dash, más cortos), Ladrón (roba a 1,9 m, 1,5 s aturdido si le roban), Blindado (3 s de inmunidad, corre al 93 %), Saltarín (salta más y gira mejor en el aire, dash cada 4 s), Tirador (bolas más rápidas y rectas, solo 3).

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
project.godot          Autoloads: Tuning, Sfx, Music, Settings, Net. Ventana 1280x720.
scenes/menu.tscn       Nodo raíz "Menu" con scripts/menu.gd
scenes/main.tscn       Nodo raíz "Main" (Node3D) con scripts/main.gd  -> la partida
autoload/tuning.gd     TODOS los números del juego y los presets de dificultad
autoload/sfx.gd        Sonidos generados por código (no hay archivos de audio)
autoload/music.gd      Música por código: un secuenciador que dispara notas cortas (menú y partida)
autoload/settings.gd   Opciones: controles reasignables (acciones gb_*), sensibilidad, volumen, pantalla completa
autoload/net.gd        Red: ENet, sala de espera, búsqueda UDP y todos los RPC
scripts/ui.gd          Estilo único de la interfaz: colores, tamaños, botones, paneles
scripts/arenas.gd      Los campos de juego (El Parque, El Muelle, La Torre)
scripts/menu.gd        Menú, perfil del jugador, sala de espera, opciones y créditos (UI por código)
scripts/main.gd        La partida: arena, jugadores, cámara, eventos, efectos
scripts/match.gd       Estado de la partida: portador, puntos, tiempo, robos, impactos
scripts/player.gd      Un jugador (humano local, remoto o bot)
scripts/character.gd   Cuerpo visible del jugador: modelo, animaciones, tinte, Lanzador
scripts/props.gd       Piezas que visten la arena (vallas, neumáticos, contenedores...), por código
assets/logo.png        Logo del juego (menú y README) y assets/icono.png (icono de la ventana). Los generó Jorge con IA
assets/kenney_mini/    Personajes y objetos "Mini Characters" de Kenney (CC0)
assets/_zips/          Descargas originales. Fuera de git y de Godot (.gdignore)
scripts/bot.gd         Cerebro de un bot (RefCounted)
scripts/ball.gd        Bola de pintura
scripts/hud.gd         Interfaz de la partida (CanvasLayer por código)
```

**Convención importante:** casi todo se construye por código (arena, jugadores, UI, materiales). Las escenas `.tscn` solo tienen el nodo raíz con su script. Los únicos assets son los modelos de `assets/kenney_mini/`; si faltan, los personajes vuelven a ser cápsulas de colores.

### Arte de los personajes

- `character.gd` no sabe de reglas ni de red. `player.gd` le dice el estado con `play("idle" | "armed_idle" | "run" | "jump" | "fall" | "dash" | "stun" | "dead")`, y le pide `set_tint`, `paint`, `glow` y `make_weapon`.
- El diccionario `PACKS` de `character.gd` dice qué modelos hay y cómo se llama cada animación. Para cambiar de pack o añadir personajes, se toca solo ahí.
- Cada jugador recibe un personaje distinto según su `slot`, teñido con su color. El modelo se escala solo a 1,75 m y se gira para mirar a -Z.
- El portador lleva el brazo derecho en la pose de `holding-right` mientras el resto del cuerpo sigue su animación (se impone tras cada paso con `mixer_applied`).
- Se descartó la Universal Animation Library de Quaternius: su versión gratuita solo corre hacia adelante y el maniquí no pega con el tono.
- Para revisar el arte sin jugar: `--showcam` (cámara frente al portador) y `--shot=RUTA` (guarda capturas a los 7, 10 y 13 s). Con `--autopilot` no se captura el mouse.

### Arte de la arena

- Tema: parque de paintball de juguete. **Todo se hace por código con formas simples** en `props.gd`: las herramientas de IA para generar 3D no dejan descargar sin pagar, así que Jorge no va a traer modelos.
- `main._box(pos, tamaño, color, rotación, pieza)` crea la caja de choque; si se le pasa una pieza (`"fence"`, `"tires"`, `"container"`, `"stage"`, `"crate"`, `"ramp"`, `"wall"`), `props.gd` dibuja el adorno encima y la caja queda solo para dar sombra. **El choque es siempre la caja**: ninguna pieza cambia por dónde se pasa ni dónde pega una bola.
- El color que se pasa es el acento de la zona (tapa de la valla, neumático de arriba), para orientarse en el mapa.
- `PropsScript.scenery()` pone las marcas del suelo, los focos y los árboles de fuera. No tienen choque y nada de adorno va dentro de la zona de juego.
- Las piezas comparten mallas y materiales y no proyectan sombra. Medido en la PC de Jorge (Intel Iris Xe, 1280×720): unos 350 dibujos por cuadro y entre 70 y 115 fps.
- `--showcam=top` da una vista general de la arena para las capturas.

### Interfaz, perfil, controles y campos

- **Un solo estilo:** todo color, tamaño de letra, botón o panel sale de `scripts/ui.gd`. No se ponen colores ni tamaños sueltos en las pantallas. Jorge pidió que la interfaz sea coherente y cuidada en el detalle.
- **Perfil:** `Net.my_name` y `Net.my_char` (índice de personaje). Viajan en `c_hello` y quedan en cada entrada de `Net.roster` como `"char"`. Dos jugadores pueden llevar el mismo personaje (decisión de Jorge). Los bots reciben personajes que nadie eligió.
- **Controles:** el juego nunca pregunta por una tecla, sino por una acción (`Input.is_action_pressed("gb_jump")`). Las acciones y sus teclas de fábrica están en `Settings.ACTIONS`. Los textos que nombran teclas usan `Settings.key_name()`. Esc, Q, Enter y B son fijas.
- **Campos:** `Net.arena` es lo elegido en el menú (-1 = aleatorio) y `Net.arena_now` el de la partida en curso, que viaja en `s_start`. Las reglas para que un campo sea justo están al principio de `scripts/arenas.gd`.
- **Volver a la sala:** al terminar, el host pulsa B y `Net.back_to_lobby()` (RPC `s_back`) manda a todos al menú con la conexión abierta; `menu.gd` muestra la sala si `Net.mode` es host o client. Ahí puede entrar gente nueva.
- **Clases:** `Tuning.CLASSES` y `Tuning.CHAR_CLASS` (qué clase es cada personaje). El juego pide cada número con `player.stat("magazine")` en vez de `Tuning.magazine`, y así sale ya ajustado por la clase. Para una clase nueva o un ajuste de balance se toca solo `tuning.gd`. El menú muestra la ventaja y el costo en la tarjeta del jugador.
- **Música:** `Music.play("menu" | "match" | "")` y `Music.urgent` (acelera en los últimos 10 s). Suena por el bus `Music`, con su volumen en Opciones. Está compuesta por código y nadie la ha oído todavía más que Jorge: si no convence, las canciones son los patrones de `SONGS` en `music.gd`. Al cerrar con una nota sonando, Godot a veces avisa de un `AudioStreamWAV` sin liberar; es inofensivo.
- **Estadísticas:** `stat_steals`, `stat_shots`, `stat_best_streak` y `stat_time` en cada jugador; cada PC las cuenta con los eventos que recibe.
- **settings.cfg** lo escriben `Net.save_cfg` y `Settings.save`; los dos cargan el archivo antes de guardar para no pisarse.
- Atajos de prueba nuevos: `--screen=options|credits|solo` abre esa pantalla, `--char=N`, `--arena=N`, `--backlobby`, `--shot-at=S`.
- **Créditos** (pantalla del menú y README): idea original y dirección, Jorge Ricardo Cintra Rad; programación, Jorge y Jesús Luis Pérez Martínez (Jesús es programador, no artista); arte, Kenney (Mini Characters, CC0); motor, Godot.

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

- Sala: `c_hello` (cliente → host), `s_lobby`, `s_reject`, `s_start`, `s_back` (host → todos), `c_ready` (cliente → host al cargar la escena).
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

- Git: rama `main`, remoto `origin` = `https://github.com/Yassp8312/Gunbearer` (público). En esta PC no hay `gh`: los repos se crean desde la web.
- Los bots no usan malla de navegación: persiguen en línea recta y saltan o rodean cuando se atascan.
- Dificultad normal: Jorge dijo que está "un poco difícil pero bien". No la bajes sin preguntar.
- Si cambias `project.godot` con el editor abierto, Godot pregunta si recarga desde el disco: hay que decir que sí.
- La primera vez que se crea una partida, Windows pregunta por el firewall.

## Qué sigue, en orden

1. Que Jorge juegue la red a mano (dos ventanas, y mejor aún dos PC) y arreglar lo que note.
2. Interfaz, lo que queda: el HUD de la partida (marcador, avisos, munición) todavía no usa `ui.gd`; y las opciones no se pueden abrir desde la pausa, solo desde el menú principal.
3. Arte, lo que queda: accesorios de personaje (el pack de Kenney trae gafas, gafas de sol y mascarilla; el resto se haría por código) y un Lanzador propio.
4. Revisar el azar con ojo competitivo: primer portador y puntos de reaparición.
5. Exportar a `.exe` para pasárselo a los amigos.
6. Para después: power-ups, más arenas, mandos, online por internet.

## Estilo de código

- GDScript con **tabuladores**.
- Tipos explícitos en variables locales y parámetros simples (`var d: float = ...`).
- Las referencias entre scripts (`game`, `match_state`, `brain`, jugadores) van **sin tipo**, para evitar dependencias circulares.
- Comentarios y textos del juego en español.
- Para balancear, cambia números en `autoload/tuning.gd`, no en el resto del código.
