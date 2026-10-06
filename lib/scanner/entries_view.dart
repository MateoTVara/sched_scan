import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/scanner/models/section_filter.dart';
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
/// With a [filter], a floating chip row comes first: one chip per section
/// (a block's letter, a blockless room's full name) puts that section into
/// the selection or takes it out. Nothing starts selected — an empty
/// selection leaves the card list empty, so [hasBookings] decides which
/// message stands in for it — and a selection narrows the list to its
/// sections; deselecting the last one brings the message back. The row
/// scrolls away with the content and floats back in over the cards — at
/// any height — when scrolling up; the pinned headings respect its paint
/// extent as overlap, so they never cover it.
///
/// Free (`LIBRE`) slots never reach this view — they are dropped when the
/// entries are grouped — so an empty [sections] list means either that
/// nothing is booked anywhere or that nothing is selected yet; the
/// [hasBookings] flag is what tells the two apart.
class EntriesView extends StatelessWidget {
  const EntriesView({
    super.key,
    required this.sections,
    required this.hasBookings,
    this.filter,
  });

  /// The sections to show as cards — already narrowed to the filter.
  final List<EntrySection> sections;

  /// Whether the *unfiltered* scan had any sections at all. Tells the two
  /// empty states apart: with `hasBookings == false` nothing is booked
  /// anywhere; with `hasBookings == true` the list is empty only because
  /// no block is selected.
  final bool hasBookings;

  /// The filter row over every section; when null no filter bar is drawn
  /// (an unfiltered list).
  final SectionFilter? filter;

  @override
  Widget build(BuildContext context) {
    final filter = this.filter;

    return MultiSliver(
      children: [
        if (filter != null && filter.sections.isNotEmpty)
          _filterBar(context, filter),
        if (sections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                hasBookings
                    ? 'Selecciona un bloque.'
                    : 'Sin reservas: todas las aulas están libres.',
              ),
            ),
          )
        else
          for (final section in sections) _section(context, section),
      ],
    );
  }

  /// The chips row as a floating header: it hides while scrolling down and
  /// floats back in over the cards when scrolling up, at any depth. Being
  /// the first child, its paint extent is handed to the sections after it
  /// as `overlap`, so a pinned heading lands right below the bar instead of
  /// on top of it.
  static Widget _filterBar(BuildContext context, SectionFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    return SliverFloatingHeader(
      child: DecoratedBox(
        key: const ValueKey('filter-bar'),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final section in filter.sections) ...[
                  _chip(context, section, filter),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One section's chip: a block shows just its letter (`Bloque A` → `A`), a
  /// blockless room its full name. A selected chip takes the theme's primary
  /// colour, an unselected one is outlined against the background.
  static Widget _chip(
    BuildContext context,
    EntrySection section,
    SectionFilter filter,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = filter.isSelected(section.title);
    final label = section.rooms.isNotEmpty
        ? section.title.replaceFirst('Bloque ', '')
        : section.title;
    return Material(
      key: ValueKey('filter-${section.title}'),
      color: selected ? scheme.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => filter.toggle(section.title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
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
