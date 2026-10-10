# Schedule Scanner

[Español](README.es.md)

Read a schedule on screen instead of squinting at it:

- **PDF — the supported path.** The text layer is extracted and
  *geometrically parsed* into structured entries: every booked slot becomes a
  card, and free (`LIBRE`) slots get none while the *Libres* filter excludes
  them (its default).
- **Image — not usable yet.** On-device OCR (Google ML Kit); an image scan
  only ever shows raw text, and ML Kit ships Android/iOS implementations
  only. See [Platform & license notes](#platform--license-notes).

The cards are grouped by block (`Bloque A` … `Bloque K`) with sticky
headings — a block heading spans its sub-headings (the start times by
default, the room names under *Por sala y hora*), each sticks while its cards
are current, and in time order every card names its own room. A
floating filter bar of chips narrows the list: it scrolls away going down and
floats back in at any height going up. Nothing is selected to start with, so
the list opens on a `Selecciona un bloque.` prompt and shows only the blocks
(letter chip) or blockless rooms (name chip) you pick — dropping the last pick
brings the prompt back, and a schedule with nothing booked says
`Sin reservas: todas las aulas están libres.` instead.

A `sort` button in the AppBar (it appears once something has been scanned)
slides a menu in from the bottom over the dimmed screen. Its header tabs
between *Orden* and *Filtros*. *Orden* lists the
two criteria directly — *Por sala y hora* keeps each block's sub-headings as
room names with the times inside them, *Por hora y sala* (the default)
regroups a block by
start time so its sub-headings become the times (`08:00`, `10:00`, …) and
each card names its own room. The criterion in effect carries an arrow
(`↑` ascending, `↓` descending): tapping it flips the direction, tapping the
other one switches criterion with the direction as it is. Only the times
move: blocks stay `A … K` and rooms keep their table order.

*Filtros* carries three fixed rows, each tap cycling that row through
nothing → ✓ included → ✕ excluded and back: *Laboratorio de Cómputo* (the
campus's computing labs — every block-B room plus C-203/204/303/304 and
J-108/205/206/210–215, matched on the room code), *Libres* (free slots
become cards only while it is ✓ — excluded by default, so the chips list
exactly the booked rooms), and *Últimos 15 min* (a session started more than
a quarter of an hour ago is hidden — at 10:05 the 09:30 card is gone, the
10:00 one stays; later starts never age). The rows compose with the chips
above — a selection the filter empties says
`Ninguna aula coincide con el filtro.`. The app opens on the defaults: fresh
compute-lab bookings in time order. Sort and marks both go back to their
defaults with the next scan.

The whole UI is in Spanish, and the app opens in PDF mode — an image/PDF
toggle sits in the AppBar for the day image input works.

## Getting started

The toolchain is wrapped in Nix — [install it](https://nixos.org/download/),
then:

```sh
nix develop           # Flutter, JDK 21, Android SDK 36, just, yj
flutter run -d linux  # run on the desktop
```

For a dev session with an editor, a shell, and `flutter run` in tmux:

```sh
./launch.sh
```

## Building

```sh
just build        # Linux (default)
just build web    # web
just check        # every flake check (builds both targets)
```

Nix only builds the `linux` and `web` targets; the Android/iOS/macOS/Windows
scaffolds exist for `flutter run` from the dev shell.

## Commands

| Task | Command |
| --- | --- |
| List recipes | `just` |
| Dev shell | `nix develop` |
| Add a dependency | `just add <package>` (alias `just a`) |
| Format | `just format` (alias `just f`) |
| Verify (all flake checks) | `just check` (alias `just c`) |
| Build | `just build [linux\|web]` (alias `just b`) |
| Sync the Nix lockfile | `just sync-lock` (alias `just s`) |
| Run the app | `flutter run -d linux` |
| Dev session (tmux) | `./launch.sh` |
| Tests | `flutter test` |
| Analyze | `flutter analyze` |

### The lockfile rule

`nix/package.nix` reads **`pubspec.lock.json`**, not `pubspec.lock`. After any
bare `flutter pub get` / `pub upgrade`, run `just sync-lock` — otherwise the
Nix build uses a stale dependency set. `just add`, `just check`, and
`just build` do this for you.

## Platform & license notes

- **Image input is not usable yet.** OCR goes through Google ML Kit, which
  ships **Android/iOS implementations only** — so nothing works in the
  Linux/web builds — and even where OCR runs, an image scan only produces
  raw text: the parser, cards, sections, and filter are PDF-only. The app
  opens in PDF mode, and that is the path that works.
- `syncfusion_flutter_pdf` is a **commercial package** — the free Syncfusion
  community license may cover you. `read_pdf_text` (MIT, Android/iOS only) is
  the drop-in alternative if licensing matters.

## Architecture

Feature-first folders under `lib/`, each a small MVVM pair of `ChangeNotifier`
viewmodel + view — no Riverpod/Bloc/Provider:

```
lib/
  main.dart    # app root; owns and disposes the viewmodels
  scanner/     # scan dispatch (ML Kit or parser), card list, filter bar, sort menu + filter rows
  schedule/    # picking, the pure-Dart PDF parser, models, opening prompt
```

`ScheduleParser` turns word-level PDF geometry into `ScheduleEntry` records —
pure Dart, no Flutter — and `ScannerViewModel` groups them into the sections
the card list renders. The read-and-parse runs in a background isolate
(`compute`), so a long schedule never blocks the UI. The body is a single
`CustomScrollView`: every view emits slivers, with sticky headings from
`sliver_tools`.

## Tests

```sh
flutter test
```

Tests mirror `lib/` under `test/`: viewmodel unit tests (including a parser
round-trip over `test/fixtures/sample.pdf`), pure tests for the filter model
(room codes, the 15-minute window), and widget tests for the card
list, the sticky headings, the filter bar, the three empty states, the sort
menu and its three filter rows, and the opening prompt. The image branch goes
through ML Kit, which has
no host implementation, so it isn't unit-tested.
