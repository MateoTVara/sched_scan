import 'package:flutter/material.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

/// One schedule slot rendered as a card: what is running in the room, who
/// booked it, and between which hours.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry});

  final ScheduleEntry entry;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || entry.status != null)
              Row(
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
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _Badge(label: 'Sec. ${entry.section}'),
                    ),
                  if (entry.status != null)
                    Padding(
                      padding: EdgeInsets.only(left: title == null ? 0 : 8),
                      child: _StatusChip(status: entry.status!),
                    ),
                ],
              ),
            if (program != null && program != title)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  program,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            if (entry.person != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(entry.person!, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
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
