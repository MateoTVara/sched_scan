# Schedule Scanner

[English](README.md)

Lee un horario en pantalla en lugar de forzar la vista:

- **PDF — la ruta soportada.** Su capa de texto se extrae y la *parsea
  geométricamente* en entradas estructuradas: cada hueco reservado se vuelve
  una tarjeta, y los huecos libres (`LIBRE`) se descartan.
- **Imagen — todavía no usable.** OCR en el dispositivo (Google ML Kit); un
  escaneo de imagen solo muestra texto plano, y ML Kit solo viene para
  Android/iOS. Ver [Notas de plataforma y licencia](#notas-de-plataforma-y-licencia).

Las tarjetas se agrupan por bloque (`Bloque A` … `Bloque K`) con encabezados
fijos (sticky): el encabezado del bloque abarca sus aulas, el de cada aula se
fija mientras sus tarjetas están a la vista, y los horarios de cada aula van
ordenados por hora de inicio. Una barra flotante de chips filtra la lista: al
bajar se oculta con el contenido y al subir reaparece a cualquier altura. Al
inicio nada está seleccionado, así que la lista arranca con un aviso
`Selecciona un bloque.` y solo muestra los bloques (chip con la letra) o las
aulas sin bloque (chip con el nombre) que elijas — al deseleccionar el último
vuelve el aviso, y un horario sin reservas muestra
`Sin reservas: todas las aulas están libres.` Toda la interfaz está en
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
  scanner/     # despacho del escaneo (ML Kit o parser), lista de tarjetas, filtro
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
`test/fixtures/sample.pdf`) y pruebas de widget para la lista de tarjetas,
los encabezados fijos, la barra de filtros, los dos estados vacíos y el
prompt inicial. La rama de imágenes pasa por ML Kit, que no tiene
implementación en el host, así que no se prueba con unidad.
