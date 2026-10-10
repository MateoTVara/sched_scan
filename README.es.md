# Schedule Scanner

[English](README.md)

Lee un horario en pantalla en lugar de forzar la vista:

- **PDF — la ruta soportada.** Su capa de texto se extrae y la *parsea
  geométricamente* en entradas estructuradas: cada hueco reservado se vuelve
  una tarjeta, y los huecos libres (`LIBRE`) no se vuelven tarjeta mientras
  la fila *Libres* los excluye (su defecto).
- **Imagen — todavía no usable.** OCR en el dispositivo (Google ML Kit); un
  escaneo de imagen solo muestra texto plano, y ML Kit solo viene para
  Android/iOS. Ver [Notas de plataforma y licencia](#notas-de-plataforma-y-licencia).

Las tarjetas se agrupan por bloque (`Bloque A` … `Bloque K`) con encabezados
fijos (sticky): el encabezado del bloque abarca sus subtítulos (las horas por
defecto, los nombres de aula en *Por sala y hora*), cada subtítulo se fija
mientras sus tarjetas están a la vista, y en orden por hora cada tarjeta
muestra su propia aula. Una barra flotante de chips filtra la lista: al
bajar se oculta con el contenido y al subir reaparece a cualquier altura. Al
inicio nada está seleccionado, así que la lista arranca con un aviso
`Selecciona un bloque.` y solo muestra los bloques (chip con la letra) o las
aulas sin bloque (chip con el nombre) que elijas — al deseleccionar el último
vuelve el aviso, y un horario sin reservas muestra
`Sin reservas: todas las aulas están libres.`

Un botón `sort` en la AppBar (aparece cuando ya hay algo escaneado) desliza
un menú desde el borde inferior sobre la pantalla atenudida. Su encabezado
alterna entre *Orden* y *Filtros*. *Orden* lista los
dos criterios directamente — *Por sala y hora* mantiene los subtítulos de cada
bloque como nombres de aula con las horas dentro, *Por hora y sala* (el
defecto) reagrupa
el bloque por hora de inicio para que sus subtítulos sean las horas
(`08:00`, `10:00`, …) y cada tarjeta muestre su propia aula. El criterio en
vigencia lleva una flecha (`↑` ascendente, `↓` descendente): tocarlo invierte
la dirección, tocar el otro cambia de criterio con la dirección tal cual. Solo
se mueven las horas: los bloques siguen en
`A … K` y las aulas conservan su orden de tabla.

*Filtros* trae tres filas fijas, cada toque ciclando su fila entre nada → ✓
incluida → ✕ excluida y de vuelta: *Laboratorio de Cómputo* (los laboratorios
de cómputo del campus — todo el bloque B más C-203/204/303/304 y
J-108/205/206/210–215, casados por el código del aula), *Libres* (los huecos
libres solo se vuelven tarjeta con ✓ — excluida por defecto, así que los
chips listan exactamente las aulas con reservas) y *Últimos 15 min* (una
sesión empezada hace más de un cuarto de hora se oculta — a las 10:05 la
tarjeta de 09:30 desaparece, la de 10:00 se queda; las horas posteriores no
envejecen). Las filas se combinan con los chips de arriba — una selección
vaciada por el filtro muestra `Ninguna aula coincide con el filtro.`. La app
arranca con los defectos: reservas de laboratorios de cómputo frescas en
orden por hora. El orden y las marcas vuelven a sus defectos con el
siguiente escaneo.

Toda la interfaz está en
español, y la app arranca en modo PDF — un conmutador imagen/PDF está en la
AppBar para el día en que la imagen funcione.

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

- **La entrada por imagen todavía no es usable.** El OCR pasa por Google ML
  Kit, que solo trae implementaciones para **Android/iOS** — así que en las
  compilaciones de Linux/web no funciona nada — y aunque el OCR corra, un
  escaneo de imagen solo produce texto plano: el parser, las tarjetas, las
  secciones y el filtro son solo para PDF. La app arranca en modo PDF, y esa
  es la ruta que funciona.
- `syncfusion_flutter_pdf` es un paquete **comercial** — la licencia gratuita
  de comunidad de Syncfusion puede cubrirte. `read_pdf_text` (MIT, solo
  Android/iOS) es la alternativa directa si la licencia importa.

## Arquitectura

Carpetas por feature bajo `lib/`, cada una con un dúo MVVM de viewmodel +
vista (`ChangeNotifier`) — sin Riverpod/Bloc/Provider:

```
lib/
  main.dart    # raíz de la app; crea y destruye los viewmodels
  scanner/     # despacho del escaneo (ML Kit o parser), lista de tarjetas, filtros, menú de orden y las tres filas
  schedule/    # selección de archivos, parser de PDF (Dart puro), modelos, prompt
```

`ScheduleParser` convierte la geometría de las palabras del PDF en registros
`ScheduleEntry` — Dart puro, sin Flutter — y `ScannerViewModel` los agrupa en
las secciones que dibuja la lista. La lectura y el parseo corren en un
isolate en segundo plano (`compute`), así que un horario largo nunca bloquea
la UI. El cuerpo es un único `CustomScrollView`: cada vista emite slivers,
con encabezados fijos de `sliver_tools`.

## Pruebas

```sh
flutter test
```

Las pruebas reflejan `lib/` bajo `test/`: pruebas unitarias de los
viewmodels (incluida una ida y vuelta del parser sobre
`test/fixtures/sample.pdf`), pruebas puras del modelo de filtros (códigos de
aula, la ventana de 15 minutos), y
pruebas de widget para la lista de tarjetas,
los encabezados fijos, la barra de filtros, los tres estados vacíos, el menú
de orden con sus tres filas de filtro, y el prompt inicial. La rama de imágenes
pasa por ML Kit, que no
tiene implementación en el host, así que no se prueba con unidad.
