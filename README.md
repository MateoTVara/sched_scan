# Schedule Scanner

[Español](README.es.md)

Read a schedule on screen instead of squinting at it: pick a schedule as a
**PDF**, and its text layer is extracted and *geometrically parsed* into
structured entries — every booked slot becomes a card.

The cards are grouped by block (`Bloque A` … `Bloque K`), alphabetical and only
the blocks that occur; rooms with no block letter keep their own section after
them. Headings are sticky: a block heading holds the top while its section is on
screen and is pushed away when it ends, with the room or time heading beneath it
coming next. Free (`LIBRE`) slots become no card while *Ocupación* keeps bookings
only — *Solo ocupadas*, its default.

A floating bar of chips narrows the list: it scrolls away going down and floats
back in at any height going up. Nothing is selected to start with, so the list
opens on a `Selecciona un bloque.` prompt; picking a block (letter chip) or a
blockless room (name chip) shows it, and a schedule with nothing booked says
`Sin reservas: todas las aulas están libres.` instead. A selection that the
filters empty says `Ninguna aula coincide con el filtro.`. The selection is per
scan — a new scan starts over with nothing picked.

## The menu

A `sort` button in the AppBar (it appears once something has been scanned)
slides a menu in from the bottom over the dimmed screen. Its header tabs between
*Presets* and *Filtros*.

### Presets

One tap applies a whole choice — sort and all three filter sections — and the
sheet stays open, so the list changes right behind it. The row in effect is
ticked; when the combination no longer matches any preset, the `Personalizado`
row takes the tick instead (it applies nothing — it jumps to *Filtros*, where
the combination is mixed).

| Preset | What it shows | Choice |
| --- | --- | --- |
| *Laboratorios por empezar* | Aún no empiezan o empezaron hace menos de 10 min | `Solo laboratorios` · `Inicios próximos` · `Solo ocupadas` · `Por hora y aula` ↑ |
| *Aulas libres ahora* | Aulas sin clase en este momento, por aula y hora | `Solo aulas` · `Ahora` · `Solo libres` · `Por aula y hora` ↑ |
| *Laboratorios libres ahora* | Laboratorios sin clase en este momento, por aula y hora | `Solo laboratorios` · `Ahora` · `Solo libres` · `Por aula y hora` ↑ |
| *Horario del día* | Todas las clases del día, por hora y aula | `Todos los espacios` · `Todo el día` · `Solo ocupadas` · `Por hora y aula` ↑ |

*Laboratorios por empezar* is what a fresh install starts from, and it is the
whole `ScanSettings.defaults` snapshot — so picking it is also the way back to
the defaults.

### Filtros

Under the `Orden` heading sit the two sort criteria, one row each: *Por aula y
hora* keeps each block's sub-headings as room names with the times inside them,
*Por hora y aula* (the default) regroups a block by start time so its
sub-headings become the times (`08:00`, `10:00`, …) and each card names its own
room. The row in effect carries an arrow (`↑` ascending, `↓` descending):
tapping it flips the direction, tapping the other one switches criterion with
the direction as it is. Only the times move: blocks stay `A … K` and rooms keep
their table order either way.

Below come three single-choice sections — one choice each, so a combination
that could empty the list by itself is not on offer:

- **`Tipo de espacio`** — *Todos los espacios* (the default) / *Solo aulas* /
  *Solo laboratorios*. The labs are matched on the `<letter>-<digits>` room code:
  every room of block B, plus C-203, C-204, C-303, C-304 and J-108, J-205,
  J-206, J-210 … J-215. The printed descriptor in parentheses is not consulted —
  the list is the campus's, not the PDF's.
- **`Momento`** — *Todo el día* / *Ahora* / *Inicios próximos* (the default):
  - *Ahora* keeps the sessions running at the clock — started at or before it,
    not yet closed. A slot with no printed end runs from its start on; one with
    no start never shows; a range like `22:00 – 06:00` is read as running over
    midnight.
  - *Inicios próximos* keeps every start still ahead that day, plus the ones
    that began within the last ten minutes (at 10:05, a 20:00 start shows, a
    10:00 one still shows, a 09:54 one does not). The end time is not consulted
    — this is a start-time view.
- **`Ocupación`** — *Libres y ocupadas* / *Solo libres* / *Solo ocupadas* (the
  default): the free slots, the booked ones, or both. This is the only section
  that changes *which* cards exist, so the chips follow it — a room left with no
  cards leaves the list too.

The two per-card choices narrow the cards *inside* the selected sections: the
chips pick sections, the choices filter what is in them.

## Persistence

The sort and the three filter choices are app-level: they survive scans and app
restarts, and they are stored the moment they change. The chip selection is not
— it points at the document on screen, so every scan starts with nothing picked.
Which preset is in effect is derived from the choice, never stored.

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

The PDF text layer is read with `pdf_graphics` + `pdf_document` — both
**Apache-2.0**, pure Dart, no commercial package in the dependency tree — and
the same code path serves every platform (the web build included). The whole UI
is in Spanish; only the app title stays in English.

## Architecture

Feature-first folders under `lib/`, each a small MVVM pair of `ChangeNotifier`
viewmodel + view — no Riverpod/Bloc/Provider:

```
lib/
  main.dart       # app root; bootstraps the settings store, owns and disposes the viewmodels
  scanner/        # scan dispatch, card list, filter bar, sort menu, persisted settings
  schedule/       # picking, the pure-Dart PDF text layer + parser, models, opening prompt
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

Tests mirror `lib/` under `test/`: viewmodel unit tests over
`test/fixtures/sample_01.pdf` … `sample_05.pdf` (parser round-trip, sorting,
filtering, persistence), pure model tests for the presets and the filter rules
(room codes, the `Ahora` and `Inicios próximos` windows), and widget tests for
the card list, the sticky headings, the chip bar and its three empty states,
and the two-tab menu.
