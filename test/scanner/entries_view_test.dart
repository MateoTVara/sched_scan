import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/scanner/entries_view.dart';
import 'package:sched_scan/scanner/models/section_filter.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

const _bookedInA = ScheduleEntry(
  room: 'AULA A-101',
  pageIndex: 0,
  start: '08:00',
  end: '10:00',
  course: 'MATEMÁTICA',
  section: '3',
);

const _bookedInJ = ScheduleEntry(
  room: 'J-109 (ESTUDIO FOTOGRÁFICO)',
  pageIndex: 0,
  status: 'RESERVA ONLINE',
  start: '12:00',
  end: '14:00',
  person: 'ANA GARCÍA LÓPEZ',
);

const _bookedInLosa = ScheduleEntry(
  room: 'LOSA DEPORTIVA',
  pageIndex: 0,
  status: 'RESERVA ONLINE',
  start: '14:00',
  end: '16:00',
  person: 'BENDEZU CHAPIAMA ALFREDO',
);

/// One booked slot per course, distinct so a heading never matches a card.
ScheduleEntry _slot(
  String room,
  String course, {
  String start = '08:00',
  String end = '10:00',
}) => ScheduleEntry(
  room: room,
  pageIndex: 0,
  start: start,
  end: end,
  course: course,
);

/// Two blocks and a blockless room, every room tall enough that scrolling
/// through it pins and unpins its heading.
List<EntrySection> _stickySections() => [
  EntrySection(
    'Bloque A',
    rooms: {
      'AULA A-101': [for (var i = 0; i < 8; i++) _slot('AULA A-101', 'A-$i')],
      'AULA A-102': [for (var i = 0; i < 8; i++) _slot('AULA A-102', 'B-$i')],
    },
  ),
  EntrySection(
    'Bloque B',
    rooms: {
      'B-201': [for (var i = 0; i < 8; i++) _slot('B-201', 'C-$i')],
    },
  ),
  EntrySection(
    'LOSA DEPORTIVA',
    entries: [for (var i = 0; i < 8; i++) _slot('LOSA DEPORTIVA', 'D-$i')],
  ),
];

/// The top of a heading's box — the `ColoredBox` that gives it an opaque
/// background while stuck to the viewport.
double _headingTop(WidgetTester tester, String text) => tester
    .getTopLeft(
      find.descendant(
        of: find.byKey(ValueKey('heading-$text')),
        matching: find.byType(ColoredBox),
      ),
    )
    .dy;

/// EntriesView wired the way `ScannerView` wires it: the visible list is
/// derived from the one pick, and tapping a chip moves it.
class _FilterHost extends StatefulWidget {
  const _FilterHost(this.sections);

  final List<EntrySection> sections;

  @override
  State<_FilterHost> createState() => _FilterHostState();
}

class _FilterHostState extends State<_FilterHost> {
  // Nothing picked at first: like the viewmodel, an empty row leaves the
  // card list empty and the prompt takes its place.
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        EntriesView(
          hasBookings: true,
          sections: [
            for (final section in widget.sections)
              if (_selected == section.title) section,
          ],
          filter: SectionFilter(
            sections: widget.sections,
            selected: _selected,
            select: (title) => setState(() {
              _selected = _selected == title ? null : title;
            }),
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('renders a blockless room as its own heading with its cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
              hasBookings: true,
              sections: [
                EntrySection('AULA A-101', entries: const [_bookedInA]),
                EntrySection(
                  'J-109 (ESTUDIO FOTOGRÁFICO)',
                  entries: const [_bookedInJ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('AULA A-101'), findsOneWidget);
    expect(find.text('MATEMÁTICA'), findsOneWidget);
    expect(find.text('Sec. 3'), findsOneWidget);
    expect(find.text('J-109 (ESTUDIO FOTOGRÁFICO)'), findsOneWidget);
    expect(find.text('ANA GARCÍA LÓPEZ'), findsOneWidget);
    expect(find.text('08:00 – 10:00'), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(2));
    // Blockless rooms sit alone — no block heading above them.
    expect(find.textContaining('Bloque '), findsNothing);
    expect(find.textContaining('Sin reservas'), findsNothing);
  });

  testWidgets('renders a block as its room headings, with no block heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
              hasBookings: true,
              sections: [
                EntrySection(
                  'Bloque A',
                  rooms: {
                    'AULA A-101': const [_bookedInA],
                    'AULA A-102': const [_bookedInJ],
                  },
                ),
                // A room with no block letter keeps its own single heading.
                EntrySection('LOSA DEPORTIVA', entries: const [_bookedInLosa]),
              ],
            ),
          ],
        ),
      ),
    );

    // The block itself gets no heading — the picked chip already names it.
    expect(find.text('Bloque A'), findsNothing);
    expect(find.text('AULA A-101'), findsOneWidget);
    expect(find.text('AULA A-102'), findsOneWidget);
    expect(find.text('LOSA DEPORTIVA'), findsOneWidget);
    expect(find.text('MATEMÁTICA'), findsOneWidget);
    expect(find.text('ANA GARCÍA LÓPEZ'), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(3));
    // Room mode needs no room line on the cards: the heading covers it.
    expect(find.byIcon(Icons.meeting_room), findsNothing);
  });

  testWidgets('a block sorted by time shows start times where the room '
      'names go', (tester) async {
    final sections = [
      EntrySection(
        'Bloque A',
        rooms: {
          '08:00': [_slot('AULA A-101', 'A-1'), _slot('AULA A-102', 'B-1')],
          '10:00': [
            _slot('AULA A-101', 'A-2', start: '10:00', end: '12:00'),
            _slot('AULA A-102', 'B-2', start: '10:00', end: '12:00'),
          ],
        },
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
              hasBookings: true,
              sections: sections,
              showRoom: true,
              filter: SectionFilter(
                sections: sections,
                selected: 'Bloque A',
                select: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    // One sub-heading per start time under the bar — and no block heading,
    // since the chip already names the block…
    expect(find.text('Bloque A'), findsNothing);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(4));

    // …so no room name is a heading any more, but every card names its own
    // room instead.
    expect(find.text('AULA A-101'), findsNWidgets(2));
    expect(find.text('AULA A-102'), findsNWidgets(2));
    expect(find.byIcon(Icons.meeting_room), findsNWidgets(4));

    // The block still chips as its letter, not as one of the times.
    final chip = find.byKey(const ValueKey('filter-Bloque A'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('A')), findsOneWidget);
  });

  testWidgets('a blockless room keeps its name in the heading only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
              hasBookings: true,
              showRoom: true,
              sections: [
                EntrySection('LOSA DEPORTIVA', entries: const [_bookedInLosa]),
              ],
            ),
          ],
        ),
      ),
    );

    // The heading *is* the room, so the card under it stays quiet even when
    // the rest of the list is sorted by time.
    expect(find.text('LOSA DEPORTIVA'), findsOneWidget);
    expect(find.byIcon(Icons.meeting_room), findsNothing);
    expect(find.byType(EntryCard), findsOneWidget);
  });

  testWidgets('says so when every room turned out to be free', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [EntriesView(hasBookings: false, sections: [])],
        ),
      ),
    );

    expect(
      find.text('Sin reservas: todas las aulas están libres.'),
      findsOneWidget,
    );
    expect(find.text('Selecciona un bloque.'), findsNothing);
  });

  testWidgets('asks for a block when the parse had bookings but none is '
      'selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [EntriesView(hasBookings: true, sections: [])],
        ),
      ),
    );

    expect(find.text('Selecciona un bloque.'), findsOneWidget);
    expect(find.textContaining('Sin reservas'), findsNothing);
  });

  testWidgets('says so when the filter marks emptied the pick', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(hasBookings: true, typeFiltered: true, sections: []),
          ],
        ),
      ),
    );

    expect(find.text('Ninguna aula coincide con el filtro.'), findsOneWidget);
    expect(find.text('Selecciona un bloque.'), findsNothing);
    expect(find.textContaining('Sin reservas'), findsNothing);
  });

  testWidgets('headings stick while their section is on screen and leave '
      'with it', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            EntriesView(hasBookings: true, sections: _stickySections()),
          ],
        ),
      ),
    );

    // With nothing scrolled every heading is in flow, so its box's top is
    // its content offset — the section regions to scroll through. A block
    // has no heading of its own any more, so its first room marks its start.
    double flow(String text) => _headingTop(tester, text);
    final roomA1 = flow('AULA A-101'); // Bloque A starts at 0
    final roomA2 = flow('AULA A-102');
    final roomB = flow('B-201'); // Bloque B starts here
    final loose = flow('LOSA DEPORTIVA');

    /// Where a heading's top lands once scrolled, null when it is no longer
    /// painted (pushed off or culled).
    double? top(String text) {
      final box = find.byKey(ValueKey('heading-$text'));
      if (box.evaluate().isEmpty) return null;
      return _headingTop(tester, text);
    }

    /// A heading that has been pushed away with its section: gone, or above
    /// the top of the viewport.
    Matcher gone() => anyOf(isNull, lessThan(0.0));

    Future<void> scroll(double offset) async {
      controller.jumpTo(offset);
      await tester.pump();
    }

    // Midway through AULA A-101's cards: the current room sticks, the next
    // room waits in the flow below it.
    await scroll(roomA1 + (roomA2 - roomA1) / 2);
    expect(top('AULA A-101'), moreOrLessEquals(0));
    expect(top('AULA A-102'), greaterThan(0));

    // Midway through AULA A-102: the room heading swaps and the finished
    // room's heading leaves with it. Bloque B has not arrived at the top yet.
    await scroll(roomA2 + (roomB - roomA2) / 2);
    expect(top('AULA A-102'), moreOrLessEquals(0));
    expect(top('AULA A-101'), gone());
    expect(top('B-201'), isNot(moreOrLessEquals(0)));

    // Midway through Bloque B: block A's last heading has left too — no pile
    // of old headings — and only B's own room sticks.
    await scroll(roomB + (loose - roomB) / 2);
    expect(top('B-201'), moreOrLessEquals(0));
    expect(top('AULA A-102'), gone());
    expect(top('LOSA DEPORTIVA'), isNot(moreOrLessEquals(0)));

    // At the very bottom the blockless room sticks alone.
    await scroll(controller.position.maxScrollExtent);
    expect(top('LOSA DEPORTIVA'), moreOrLessEquals(0));
    expect(top('B-201'), gone());

    // Throughout, at most one heading holds the top — headings never
    // accumulate the way bare pinned slivers would.
    final viewport = tester.getSize(find.byType(CustomScrollView)).height;
    final holding = [
      for (final text in [
        'AULA A-101',
        'AULA A-102',
        'B-201',
        'LOSA DEPORTIVA',
      ])
        if (top(text) case final y? when y >= 0 && y < viewport) text,
    ];
    expect(holding.length, lessThanOrEqualTo(1));
  });

  testWidgets('renders one filter chip per section: block letters and room '
      'names', (tester) async {
    final sections = _stickySections();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
              hasBookings: true,
              sections: sections,
              filter: SectionFilter(
                sections: sections,
                // One pick lights one chip; the list above is what the
                // sections parameter hands in.
                selected: 'Bloque A',
                select: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    final chipA = find.byKey(const ValueKey('filter-Bloque A'));
    final chipB = find.byKey(const ValueKey('filter-Bloque B'));
    final chipLosa = find.byKey(const ValueKey('filter-LOSA DEPORTIVA'));
    expect(chipA, findsOneWidget);
    expect(chipB, findsOneWidget);
    expect(chipLosa, findsOneWidget);

    // A block chips its letter, a blockless room its full name; nothing
    // spells the block out in full any more — the picked chip names it.
    expect(
      find.descendant(of: chipA, matching: find.text('A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chipB, matching: find.text('B')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chipLosa, matching: find.text('LOSA DEPORTIVA')),
      findsOneWidget,
    );
    expect(find.textContaining('Bloque '), findsNothing);
  });

  testWidgets('a chip picks its section, another replaces it and the pick '
      'itself asks for another', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _FilterHost(_stickySections())));

    final chip = find.byKey(const ValueKey('filter-Bloque A'));
    final chipB = find.byKey(const ValueKey('filter-Bloque B'));
    // Nothing selected to start with: no cards, the prompt stands in for
    // the list, and the chips sit outlined.
    expect(find.text('Selecciona un bloque.'), findsOneWidget);
    expect(find.text('AULA A-101'), findsNothing); // no cards yet
    expect(find.byType(EntryCard), findsNothing);
    expect(chip, findsOneWidget);
    expect(tester.widget<Material>(chip).color, Colors.transparent);

    // Picking a chip narrows the list to just that section — and turns the
    // prompt off...
    await tester.tap(chip);
    await tester.pump();

    expect(find.text('Selecciona un bloque.'), findsNothing);
    expect(find.text('AULA A-101'), findsOneWidget);
    expect(find.text('B-201'), findsNothing); // only A's section is listed
    expect(find.byType(EntryCard), findsWidgets); // A's cards, lazily built
    expect(tester.widget<Material>(chip).color, isNot(Colors.transparent));

    // ...another chip moves the pick instead of adding to it...
    await tester.tap(chipB);
    await tester.pump();

    expect(find.text('B-201'), findsOneWidget);
    expect(find.text('AULA A-101'), findsNothing);
    expect(tester.widget<Material>(chipB).color, isNot(Colors.transparent));
    expect(tester.widget<Material>(chip).color, Colors.transparent);

    // ...and tapping the pick again empties the row, which brings the
    // prompt back rather than every section.
    await tester.tap(chipB);
    await tester.pump();

    expect(find.text('Selecciona un bloque.'), findsOneWidget);
    expect(find.text('B-201'), findsNothing);
    expect(find.byType(EntryCard), findsNothing);
    expect(chipB, findsOneWidget);
    expect(tester.widget<Material>(chipB).color, Colors.transparent);
  });

  testWidgets('the filter bar hides scrolling down and floats back in '
      'when scrolling up', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final sections = _stickySections();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            EntriesView(
              hasBookings: true,
              sections: sections,
              filter: SectionFilter(
                sections: sections,
                // One chip lit; the sections above are what it shows on
                // screen to scroll through.
                selected: 'Bloque A',
                select: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    final bar = find.byKey(const ValueKey('filter-bar'));

    // At rest the bar sits at the top and the first heading in flow below
    // it — never underneath it.
    expect(bar.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(bar).dy, moreOrLessEquals(0));
    final barBottom = tester.getBottomLeft(bar).dy;
    expect(barBottom, greaterThan(0));
    expect(_headingTop(tester, 'AULA A-101'), greaterThanOrEqualTo(barBottom));

    // Scrolling down: the bar scrolls away with the content and the pinned
    // heading takes the top for itself.
    controller.jumpTo(300);
    await tester.pump();
    expect(bar.hitTestable(), findsNothing);
    expect(_headingTop(tester, 'AULA A-101'), moreOrLessEquals(0));

    // Scrolling back up at depth: the bar floats back in over the cards
    // without waiting for the top...
    await tester.timedDrag(
      find.byType(CustomScrollView),
      const Offset(0, 60),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(controller.position.pixels, greaterThan(60)); // still deep
    expect(bar.hitTestable(), findsOneWidget);
    // ...at the top of the viewport...
    expect(tester.getTopLeft(bar).dy, moreOrLessEquals(0));
    // ...with the pinned heading below it instead of covering it.
    expect(
      _headingTop(tester, 'AULA A-101'),
      greaterThanOrEqualTo(tester.getBottomLeft(bar).dy),
    );
  });
}
