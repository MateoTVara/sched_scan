import 'package:flutter/foundation.dart';

/// The three states a filter row can be in. One tap on the row advances to
/// the next one, [none] included: untouched filters nothing, [include]
/// narrows the list to what the row matches, [exclude] drops what it
/// matches.
enum TypeMark {
  none,
  include,
  exclude;

  /// The state one tap further along: none → include → exclude → none.
  TypeMark get next => switch (this) {
    TypeMark.none => TypeMark.include,
    TypeMark.include => TypeMark.exclude,
    TypeMark.exclude => TypeMark.none,
  };
}

/// The four fixed rows of the menu's `Filtros` tab — the same on every
/// scan, unlike the sections they filter.
enum FilterRow {
  /// The computing labs of campus, as [isComputeLab] knows them.
  computeLab('Laboratorio de Cómputo'),

  /// The `LIBRE` slots — free sessions, which get no card by default.
  libres('Libres'),

  /// The freshness window: sessions started more than [freshnessWindow]
  /// ago are stale, and stale sessions are hidden while this row is marked
  /// in.
  last15('Últimos 15 min'),

  /// The session running right now: only cards whose printed range covers
  /// the clock — [isOngoing] — survive while this row is marked in, so a
  /// room with nothing underway drops out of the list.
  now('Ahora');

  const FilterRow(this.label);

  /// The row as the menu prints it.
  final String label;
}

/// What every scan starts from: the compute labs in, the free slots out,
/// the stale sessions out, the now row untouched — it is opt-in, a tap
/// away from the full schedule.
const Map<FilterRow, TypeMark> defaultFilterMarks = {
  FilterRow.computeLab: TypeMark.include,
  FilterRow.libres: TypeMark.exclude,
  FilterRow.last15: TypeMark.include,
};

/// How far back the freshness row looks: a session whose start time is
/// more than this before "now" is stale.
const Duration freshnessWindow = Duration(minutes: 15);

/// A row marked [TypeMark.include] keeps what matches and one marked
/// [TypeMark.exclude] drops it; [TypeMark.none] keeps everything.
bool passesMark(TypeMark mark, bool matches) => switch (mark) {
  TypeMark.none => true,
  TypeMark.include => matches,
  TypeMark.exclude => !matches,
};

/// Whether a room is one of campus's computing labs, matched on the
/// `<letter>-<digits>` code printed in its name (`B-101 (…)`,
/// `MÚLTIPLE C-202`): every room of block B, then C-203, C-204, C-303,
/// C-304 and J-108, J-205, J-206, J-210 … J-215. Nothing else counts —
/// the descriptor in parentheses is not consulted.
bool isComputeLab(String room) {
  final code = RegExp(r'(?:^|\s)([A-Z])-(\d+)').firstMatch(room);
  if (code == null) return false;
  final block = code.group(1)!;
  final number = int.parse(code.group(2)!);
  return switch (block) {
    'B' => true,
    'C' => const {203, 204, 303, 304}.contains(number),
    'J' =>
      number == 108 ||
          number == 205 ||
          number == 206 ||
          (number >= 210 && number <= 215),
    _ => false,
  };
}

/// Whether a session that started at [start] (`HH:MM`) is stale at [now]:
/// more than [freshnessWindow] in the past. A session that began at 09:30
/// is stale at 10:05, one that began at 10:00 is not, one still to come
/// never is — and no printed time means nothing to age.
bool isStale(String? start, DateTime now) {
  final minutes = _minutesOf(start);
  if (minutes == null) return false;
  return now.hour * 60 + now.minute - minutes > freshnessWindow.inMinutes;
}

/// Whether a session is underway at [now]: its printed range covers the
/// clock — it started at or before [now] and, when an end was printed,
/// has not closed yet. Both ends count, so a session is current through
/// its closing minute, like the freshness row's inclusive boundary. A
/// slot with no printed end is open-ended and runs from its start on; no
/// printed start means nothing to run from, so its card never shows as
/// current — and neither does one still to come.
bool isOngoing(String? start, String? end, DateTime now) {
  final began = _minutesOf(start);
  if (began == null) return false;
  final closes = _minutesOf(end);
  // A range that closes before it opens runs over midnight: a clock read
  // before its start is then the next day's, so shift it a day to compare.
  final wraps = closes != null && closes < began;
  var minutes = now.hour * 60 + now.minute;
  if (wraps && minutes < began) minutes += 24 * 60;
  if (minutes < began) return false;
  return closes == null || minutes <= (wraps ? closes + 24 * 60 : closes);
}

int? _minutesOf(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

/// The `Filtros` tab as the menu sees it: the mark on each row and [cycle]
/// to advance one — the state itself lives in the viewmodel, this is only
/// its read-only shape, like `SectionFilter`.
class ScanFilters {
  const ScanFilters({required this.marks, required this.cycle});

  /// Row → its mark; a row absent from the map is [TypeMark.none].
  final Map<FilterRow, TypeMark> marks;

  /// Advances one row: none → include → exclude → none.
  final ValueChanged<FilterRow> cycle;

  /// The mark [row] currently carries.
  TypeMark stateOf(FilterRow row) => marks[row] ?? TypeMark.none;
}
