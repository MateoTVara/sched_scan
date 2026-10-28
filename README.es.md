# Schedule Scanner

[English](README.md)

Lee un horario en pantalla en lugar de forzar la vista: elige un horario en
**PDF** y su capa de texto se extrae y se *parsea geométricamente* en entradas
estructuradas — cada hueco reservado se vuelve una tarjeta.

Las tarjetas se agrupan por bloque (`Bloque A` … `Bloque K`), alfabéticamente y
solo los bloques que aparecen; las aulas sin letra de bloque conservan su propia
sección después. Los encabezados son fijos (sticky): el del bloque ocupa la parte
superior mientras su sección está a la vista y se va empujado al terminar, con el
subtítulo de aula u hora justo debajo. Los huecos libres (`LIBRE`) no se vuelven
tarjeta mientras *Ocupación* deje solo las reservas — *Solo ocupadas*, su defecto.

Una barra flotante de chips filtra la lista: al bajar se oculta con el contenido y
al subir reaparece a cualquier altura. Al inicio nada está seleccionado, así que
la lista arranca con un aviso `Selecciona un bloque.`; al elegir un bloque (chip
con la letra) o un aula sin bloque (chip con el nombre) aparece su contenido, y un
horario sin reservas muestra `Sin reservas: todas las aulas están libres.` en su
lugar. Una selección que los filtros vacían muestra
`Ninguna aula coincide con el filtro.`. La selección es de cada escaneo: uno
nuevo empieza sin nada elegido.

## El menú

Un botón `sort` en la AppBar (aparece cuando ya hay algo escaneado) desliza un
menú desde el borde inferior sobre la pantalla atenuada. Su encabezado alterna
entre *Presets* y *Filtros*.

### Presets

Un toque aplica una elección completa — orden y las tres secciones de filtros — y
la hoja sigue abierta, así que la lista cambia justo detrás. La fila en vigor
lleva la marca; cuando la combinación ya no coincide con ningún preset, la marca
pasa a `Personalizado` (no aplica nada: salta a *Filtros*, donde se mezcla la
combinación).

| Preset | Qué muestra | Elección |
| --- | --- | --- |
| *Laboratorios por empezar* | Aún no empiezan o empezaron hace menos de 10 min | `Solo laboratorios` · `Inicios próximos` · `Solo ocupadas` · `Por hora y aula` ↑ |
| *Aulas libres ahora* | Aulas sin clase en este momento, por aula y hora | `Solo aulas` · `Ahora` · `Solo libres` · `Por aula y hora` ↑ |
| *Laboratorios libres ahora* | Laboratorios sin clase en este momento, por aula y hora | `Solo laboratorios` · `Ahora` · `Solo libres` · `Por aula y hora` ↑ |
| *Horario del día* | Todas las clases del día, por hora y aula | `Todos los espacios` · `Todo el día` · `Solo ocupadas` · `Por hora y aula` ↑ |

*Laboratorios por empezar* es lo que trae una instalación nueva, y es la
instantánea completa de `ScanSettings.defaults`: elegirlo es también la forma de
volver a los valores predeterminados.

### Filtros

Bajo el encabezado `Orden` están los dos criterios de orden, una fila cada uno:
*Por aula y hora* mantiene los subtítulos de cada bloque como nombres de aula con
las horas dentro, *Por hora y aula* (el defecto) reagrupa el bloque por hora de
inicio para que sus subtítulos sean las horas (`08:00`, `10:00`, …) y cada
tarjeta muestre su propia aula. La fila en vigor lleva una flecha (`↑`
ascendente, `↓` descendente): tocarla invierte la dirección, tocar la otra cambia
de criterio con la dirección tal cual. Solo se mueven las horas: los bloques
siguen en `A … K` y las aulas conservan su orden de tabla en ambos casos.

Debajo vienen tres secciones de elección única — una opción por sección, así que
una combinación que por sí sola pudiera vaciar la lista no se ofrece:

- **`Tipo de espacio`** — *Todos los espacios* (el defecto) / *Solo aulas* /
  *Solo laboratorios*. Los laboratorios se reconocen por el código
  `<letra>-<dígitos>` del aula: todo el bloque B, más C-203, C-204, C-303, C-304
  y J-108, J-205, J-206, J-210 … J-215. El descriptor entre paréntesis no se
  consulta — la lista es la del campus, no la del PDF.
- **`Momento`** — *Todo el día* / *Ahora* / *Inicios próximos* (el defecto):
  - *Ahora* deja las sesiones en curso a la hora actual — ya empezadas y
    todavía sin cerrar. Un hueco sin hora de fin impresa corre desde su inicio;
    uno sin inicio nunca aparece; un rango como `22:00 – 06:00` se lee como
    pasado de medianoche.
  - *Inicios próximos* deja todo inicio que aún está por llegar ese día, más los
    que empezaron hace menos de diez minutos (a las 10:05, un inicio de 20:00
    aparece, uno de 10:00 sigue apareciendo, uno de 09:54 ya no). La hora de fin
    no se consulta — es una vista por hora de inicio.
- **`Ocupación`** — *Libres y ocupadas* / *Solo libres* / *Solo ocupadas* (el
  defecto): los huecos libres, los reservados, o ambos. Es la única sección que
  cambia *qué* tarjetas existen, así que los chips la siguen — un aula que se
  queda sin tarjetas sale también de la lista.

Las dos opciones por tarjeta estrechan las tarjetas *dentro* de las secciones
elegidas: los chips eligen secciones, las opciones filtran lo que hay en ellas.

## Persistencia

El orden y las tres opciones de filtro son de la app: sobreviven a los escaneos y
a los reinicios, y se guardan en el momento en que cambian. La selección de chips
no: apunta al documento en pantalla, así que cada escaneo empieza sin nada
elegido. Qué preset está en vigor se deriva de la elección, nunca se guarda.

## Primeros pasos

La cadena de herramientas va envuelta en Nix — [instálalo](https://nixos.org/download/),
y luego:

```sh
nix develop           # Flutter, JDK 21, Android SDK 36, just, yj
flutter run -d linux  # ejecutar en escritorio
```

Para una sesión de desarrollo con editor, shell y `flutter run` en tmux:

```sh
./launch.sh
```

## Compilación

```sh
just build        # Linux (por defecto)
just build web    # web
just check        # todas las comprobaciones de la flake (compila ambos)
```

Nix solo compila los destinos `linux` y `web`; los scaffolds de
Android/iOS/macOS/Windows existen para `flutter run` desde el shell de
desarrollo.

## Comandos

| Tarea | Comando |
| --- | --- |
| Ver recetas | `just` |
| Shell de desarrollo | `nix develop` |
| Añadir dependencia | `just add <paquete>` (alias `just a`) |
| Formatear | `just format` (alias `just f`) |
| Verificar (todas las comprobaciones) | `just check` (alias `just c`) |
| Compilar | `just build [linux\|web]` (alias `just b`) |
| Sincronizar el lockfile de Nix | `just sync-lock` (alias `just s`) |
| Ejecutar la app | `flutter run -d linux` |
| Sesión de desarrollo (tmux) | `./launch.sh` |
| Pruebas | `flutter test` |
| Analizar | `flutter analyze` |

### La regla del lockfile

`nix/package.nix` lee **`pubspec.lock.json`**, no `pubspec.lock`. Tras un
`flutter pub get` / `pub upgrade` directo, ejecuta `just sync-lock` — si no,
la compilación de Nix usa un conjunto de dependencias obsoleto.
`just add`, `just check` y `just build` lo hacen por ti.

## Notas de plataforma y licencia

La capa de texto del PDF se lee con `pdf_graphics` + `pdf_document` — ambos
**Apache-2.0**, Dart puro, sin paquetes comerciales en el árbol de dependencias
— y la misma ruta de código sirve para todas las plataformas (la compilación web
incluida). Toda la interfaz está en español; solo el título de la app se queda
en inglés.

## Arquitectura

Carpetas por feature bajo `lib/`, cada una con un dúo MVVM de viewmodel + vista
(`ChangeNotifier`) — sin Riverpod/Bloc/Provider:

```
lib/
  main.dart       # raíz de la app; prepara el almacén de ajustes, crea y destruye los viewmodels
  scanner/        # despacho del escaneo, lista de tarjetas, barra de filtros, menú de orden, ajustes persistidos
  schedule/       # selección de archivos, capa de texto y parser de PDF (Dart puro), modelos, prompt
```

`ScheduleParser` convierte la geometría de las palabras del PDF en registros
`ScheduleEntry` — Dart puro, sin Flutter — y `ScannerViewModel` los agrupa en
las secciones que dibuja la lista. La lectura y el parseo corren en un isolate
en segundo plano (`compute`), así que un horario largo nunca bloquea la UI. El
cuerpo es un único `CustomScrollView`: cada vista emite slivers, con encabezados
fijos de `sliver_tools`.

## Pruebas

```sh
flutter test
```

Las pruebas reflejan `lib/` bajo `test/`: pruebas unitarias de los viewmodels
sobre `test/fixtures/sample_01.pdf` … `sample_05.pdf` (ida y vuelta del parser,
orden, filtros, persistencia), pruebas puras de los modelos de presets y de las
reglas de filtro (códigos de aula, las ventanas de `Ahora` e `Inicios
próximos`), y pruebas de widget para la lista de tarjetas, los encabezados
fijos, la barra de chips y sus tres estados vacíos, y el menú de dos pestañas.
