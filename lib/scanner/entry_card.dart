import 'package:flutter/material.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

/// One schedule slot rendered as a card: what is running in the room, who
/// booked it, and between which hours. The room is not spelled out by
/// default — the heading above the card covers it — unless [showRoom] asks
/// for a line of its own.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, this.showRoom = false});

  final ScheduleEntry entry;

  /// Whether to name the room on the card itself: on when a block's
  /// sub-headings are start times instead of room names (the
  /// `SortMode.timeThenRoom` sort), where the heading no longer says which
  /// room the card belongs to.
  final bool showRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = entry.course;
    final program = entry.program;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 4,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRoom)
              Row(
                spacing: 4,
                children: [
                  Icon(
                    Icons.meeting_room,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  Expanded(
                    child: Text(
                      entry.room,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            if (title != null || entry.status != null)
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (entry.section != null)
                    _Badge(label: 'Sec. ${entry.section}'),
                  if (entry.status != null) _StatusChip(status: entry.status!),
                ],
              ),
            if (program != null && program != title)
              Text(
                program,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (entry.person != null)
              Text(entry.person!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              spacing: 4,
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                Text(
                  entry.timeLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (entry.cycle != null)
                  Text(
                    'Ciclo ${entry.cycle}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            for (final note in entry.notes)
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _Badge(label: status, background: _background);
  }

  Color get _background => switch (status) {
    'LIBRE' => Colors.green.shade700,
    'RESERVA ONLINE' => Colors.orange.shade800,
    'RESERVA LABORATORIO' => Colors.blue.shade700,
    _ => Colors.blueGrey.shade600,
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.background});

  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final color = background;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: color == null
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
