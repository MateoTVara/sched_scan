import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

/// Parsed schedule entries grouped by room: a section header per room with
/// that room's slots as cards underneath, already ordered by start time.
class EntriesView extends StatelessWidget {
  const EntriesView({super.key, required this.entriesByRoom});

  final Map<String, List<ScheduleEntry>> entriesByRoom;

  @override
  Widget build(BuildContext context) {
    final sections = entriesByRoom.entries.toList(growable: false);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                section.key,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (final entry in section.value) EntryCard(entry: entry),
          ],
        );
      },
    );
  }
}
