import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';

/// The parsed schedule as cards under their headings: one heading per room in
/// the "by room" layout, or a block heading over a heading per room in the
/// "by block" layout. Cards are already ordered by start time.
///
/// Free (`LIBRE`) slots never reach this view — they are dropped when the
/// entries are grouped — so an empty list means nothing is booked anywhere,
/// which gets a message rather than a blank page.
class EntriesView extends StatelessWidget {
  const EntriesView({super.key, required this.sections});

  final List<EntrySection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sin reservas: todas las aulas están libres.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, section.title, level: 0),
            for (final entry in section.entries) EntryCard(entry: entry),
            for (final room in section.rooms.entries) ...[
              _heading(context, room.key, level: 1),
              for (final entry in room.value) EntryCard(entry: entry),
            ],
          ],
        );
      },
    );
  }

  /// A block heading sits loose and large at level 0; the rooms it groups sit
  /// tighter and smaller underneath.
  static Widget _heading(
    BuildContext context,
    String text, {
    required int level,
  }) {
    final theme = Theme.of(context);
    final style = level == 0
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleSmall;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, level == 0 ? 20 : 12, 16, 8),
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
