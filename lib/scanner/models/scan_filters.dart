import 'package:flutter/foundation.dart';

/// Which rooms the list shows — the menu's `Tipo de aula` section.
///
/// The campus splits into its computing labs ([isComputeLab]) and every
/// other room; [all] is both. One choice per section, so a combination
/// that could empty the list by itself (labs *and* aulas) is not on
/// offer.
enum RoomTypeChoice {
  /// Every room, labs included.
  all('Todas las aulas'),

  /// Only the campus's computing labs.
  labs('Laboratorios'),

  /// Every room that is not a compute lab.
  rooms('Solo aulas');

  const RoomTypeChoice(this.label);

  /// The choice as the menu prints it.
  final String label;

  /// The choice after this one, wrapping back to [all] — the order the
  /// menu lists the rows in.
  RoomTypeChoice get next => values[(index + 1) % values.length];
}

/// What the list shows of the day — the menu's `Qué ver` section.
enum ViewChoice {
  /// Whatever the other choices keep, whole day included.
  all('Todo'),

  /// Only the sessions running right now ([isOngoing]).
  now('Ahora'),

  /// Only the sessions starting within the next [upcomingWindow].
  soon('A punto de comenzar');

  const ViewChoice(this.label);

  /// The choice as the menu prints it.
  final String label;

  /// The choice after this one, wrapping back to [all] — the order the
  /// menu lists the rows in.
  ViewChoice get next => values[(index + 1) % values.length];
}

/// Free or booked — the menu's `Estado` section.
enum StateChoice {
  /// The free and the booked slots alike.
  all('Libres y ocupadas'),

  /// Only the `LIBRE` slots.
  free('Solo libres'),

  /// Only the booked ones.
  busy('Solo ocupadas');

  const StateChoice(this.label);

  /// The choice as the menu prints it.
  final String label;

  /// The choice after this one, wrapping back to [all] — the order the
  /// menu lists the rows in.
  StateChoice get next => values[(index + 1) % values.length];
}

/// How far ahead the [ViewChoice.soon] view looks: a session starting
/// within this many minutes from the clock is about to begin.
const Duration upcomingWindow = Duration(minutes: 15);

/// Whether a room is one of the campus's computing labs, matched on the
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

/// Whether a session is underway at [now]: its printed range covers the
/// clock — it started at or before [now] and, when an end was printed,
/// has not closed yet. Both ends count, so a session is current through
/// its closing minute. A slot with no printed end is open-ended and runs
/// from its start on; no printed start means nothing to run from, so its
/// card never shows as current — and neither does one still to come.
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

/// Whether a session starts within the next [upcomingWindow] at [now] —
/// strictly in the future (one already underway is [isOngoing]'s, not
/// this) and no further than fifteen minutes out. No printed time, or no
/// parseable one, never counts.
bool isImminent(String? start, DateTime now) {
  final begins = _minutesOf(start);
  if (begins == null) return false;
  final delta = begins - (now.hour * 60 + now.minute);
  return delta > 0 && delta <= upcomingWindow.inMinutes;
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

/// Whether a room survives the `Tipo de aula` choice.
bool passesRoomType(RoomTypeChoice choice, {required String room}) =>
    switch (choice) {
      RoomTypeChoice.all => true,
      RoomTypeChoice.labs => isComputeLab(room),
      RoomTypeChoice.rooms => !isComputeLab(room),
    };

/// Whether a slot survives the `Qué ver` choice at [now].
bool passesView(
  ViewChoice choice, {
  required String? start,
  required String? end,
  required DateTime now,
}) => switch (choice) {
  ViewChoice.all => true,
  ViewChoice.now => isOngoing(start, end, now),
  ViewChoice.soon => isImminent(start, now),
};

/// Whether a slot survives the `Estado` choice.
bool passesState(StateChoice choice, {required bool isFree}) =>
    switch (choice) {
      StateChoice.all => true,
      StateChoice.free => isFree,
      StateChoice.busy => !isFree,
    };

/// The menu's `Filtros` tab as the menu sees it: the three choices and a
/// setter for each — the state itself lives in the viewmodel, this is
/// only its read-only shape, like `SectionFilter`. The rows are radio-
/// style: tapping one *selects* it, so the setters take the value.
class ScanFilters {
  const ScanFilters({
    required this.roomType,
    required this.view,
    required this.state,
    required this.setRoomType,
    required this.setView,
    required this.setState,
  });

  final RoomTypeChoice roomType;
  final ViewChoice view;
  final StateChoice state;

  /// Puts the `Tipo de aula` section on [RoomTypeChoice] — a no-op when
  /// it is the choice already in effect.
  final ValueChanged<RoomTypeChoice> setRoomType;

  /// Puts the `Qué ver` section on [ViewChoice].
  final ValueChanged<ViewChoice> setView;

  /// Puts the `Estado` section on [StateChoice].
  final ValueChanged<StateChoice> setState;
}
