import 'package:sched_scan/schedule/models/schedule_entry.dart';

/// A heading over a run of cards, one level deep or two.
///
/// One level — [entries] sit directly under [title] — is a room in the
/// "group by room" layout, and in "group by block" it is how a room without a
/// block letter is kept exactly as it appears in the other layout.
///
/// Two levels — [rooms] holds one heading per room — is a block: [title] is
/// `Bloque A` and the rooms beneath it are that block's aulas.
///
/// Never both at once: one of the two fields is always empty.
class EntrySection {
  const EntrySection(
    this.title, {
    this.entries = const [],
    this.rooms = const {},
  });

  /// Heading text: `Bloque A`, or a room name such as `AULA A-203`.
  final String title;

  /// Cards directly under [title], already ordered by start time.
  final List<ScheduleEntry> entries;

  /// Cards grouped under a sub-heading per room, for a block's rooms.
  final Map<String, List<ScheduleEntry>> rooms;

  /// Total cards in this section, block heading or not.
  int get entryCount =>
      entries.length +
      rooms.values.fold(0, (total, room) => total + room.length);
}
