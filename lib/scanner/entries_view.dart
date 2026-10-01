import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// The parsed schedule as cards under their headings, sticky like a CSS
/// `position: sticky` list: a heading pins to the top of the viewport while
/// its section is on screen and is pushed away when the section ends, so
/// headings never pile up.
///
/// A block section nests two levels — the `Bloque` heading spans every room
/// below it, and each room's heading sticks beneath it while that room's
/// cards are current. A room with no block letter gets a single section with
/// a heading of its own. Cards are already ordered by start time.
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
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin reservas: todas las aulas están libres.'),
        ),
      );
    }

    return MultiSliver(
      children: [for (final section in sections) _section(context, section)],
    );
  }

  /// One section as a group whose pinned heading is contained to the
  /// section's own extent: `pushPinnedChildren` pushes it off towards the
  /// leading edge once the section has scrolled past.
  static Widget _section(BuildContext context, EntrySection section) {
    if (section.rooms.isEmpty) {
      // A blockless room: its own heading over its cards, sticky over them
      // only.
      return MultiSliver(
        pushPinnedChildren: true,
        children: [
          _header(context, section.title, level: 0),
          _cards(section.entries),
        ],
      );
    }

    // A block: its heading spans every room beneath it, each room grouped in
    // turn so its heading sticks under the block's while its cards are on
    // screen.
    return MultiSliver(
      pushPinnedChildren: true,
      children: [
        _header(context, section.title, level: 0),
        for (final room in section.rooms.entries)
          MultiSliver(
            pushPinnedChildren: true,
            children: [
              _header(context, room.key, level: 1),
              _cards(room.value),
            ],
          ),
      ],
    );
  }

  static Widget _cards(List<ScheduleEntry> entries) => SliverList.builder(
    itemCount: entries.length,
    itemBuilder: (context, index) => EntryCard(entry: entries[index]),
  );

  /// A pinned heading: level 0 sits loose and large (a block, or a lone room
  /// with no block letter); the rooms a block groups sit tighter and smaller
  /// underneath. The background keeps cards from showing through while the
  /// heading is stuck to the top.
  static Widget _header(
    BuildContext context,
    String text, {
    required int level,
  }) {
    final theme = Theme.of(context);
    final style = level == 0
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleSmall;
    return SliverPinnedHeader(
      key: ValueKey('heading-$text'),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, level == 0 ? 20 : 12, 16, 8),
          child: Text(
            text,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
