/// One slot of the schedule: a room booked (or free) for a time range.
class ScheduleEntry {
  const ScheduleEntry({
    required this.room,
    required this.pageIndex,
    this.status,
    this.start,
    this.end,
    this.course,
    this.section,
    this.cycle,
    this.program,
    this.person,
    this.notes = const [],
  });

  /// Room name as printed in the left column, e.g.
  /// `J-101 (LABORATORIO PLANTA DE TRATAMIENTO Y ENVASADO DE AGUA DE MESA)`.
  final String room;

  /// `LIBRE`, `RESERVA ONLINE`, `RESERVA LABORATORIO`, or `null`.
  final String? status;

  /// `HH:MM` bounds of the slot; either may be missing on sparse cells.
  final String? start;
  final String? end;

  final String? course;
  final String? section;
  final String? cycle;

  /// Academic programme in parentheses, e.g.
  /// `(TECNOLOGÍA MÉDICA EN TERAPIA FÍSICA Y REHABILITACIÓN)`.
  final String? program;

  /// Docente or reserving person, e.g. `PELAEZ PALACIO LILIANA EDITH`.
  final String? person;

  /// Free-form extras printed after the time range, e.g. `Recuperación`.
  final List<String> notes;

  /// Page the entry was found on (0-based), for stable ordering.
  final int pageIndex;

  bool get isFree => status == 'LIBRE';

  /// `07:00 – 22:45`, `07:00`, or `—` when no range was printed.
  String get timeLabel {
    if (start == null) return '—';
    return end == null ? start! : '$start – $end';
  }
}
