import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/entry_card.dart';
import 'package:sched_scan/scanner/entries_view.dart';
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
ScheduleEntry _slot(String room, String course) => ScheduleEntry(
  room: room,
  pageIndex: 0,
  start: '08:00',
  end: '10:00',
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

void main() {
  testWidgets('renders a blockless room as its own heading with its cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
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

  testWidgets('renders a block heading over a heading per room', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            EntriesView(
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

    expect(find.text('Bloque A'), findsOneWidget);
    expect(find.text('AULA A-101'), findsOneWidget);
    expect(find.text('AULA A-102'), findsOneWidget);
    expect(find.text('LOSA DEPORTIVA'), findsOneWidget);
    expect(find.text('MATEMÁTICA'), findsOneWidget);
    expect(find.text('ANA GARCÍA LÓPEZ'), findsOneWidget);
    expect(find.byType(EntryCard), findsNWidgets(3));
  });

  testWidgets('says so when every room turned out to be free', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(slivers: [EntriesView(sections: [])]),
      ),
    );

    expect(
      find.text('Sin reservas: todas las aulas están libres.'),
      findsOneWidget,
    );
  });

  testWidgets('headings stick while their section is on screen and leave '
      'with it', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [EntriesView(sections: _stickySections())],
        ),
      ),
    );

    // With nothing scrolled every heading is in flow, so its box's top is
    // its content offset — the section regions to scroll through, and each
    // heading's own height.
    double flow(String text) => _headingTop(tester, text);
    final blockAH = flow('AULA A-101'); // 'Bloque A' starts at 0
    final roomA1 = flow('AULA A-101');
    final roomA2 = flow('AULA A-102');
    final blockB = flow('Bloque B');
    final blockBH = flow('B-201') - blockB;
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

    // Midway through AULA A-101's cards: the block and the current room
    // stick, the next room waits in the flow below them.
    await scroll((roomA1 + roomA2) / 2);
    expect(top('Bloque A'), moreOrLessEquals(0));
    expect(top('AULA A-101'), moreOrLessEquals(blockAH));
    expect(top('AULA A-102'), greaterThan(blockAH));

    // Midway through AULA A-102: the block stays, the room heading swaps,
    // and the finished room's heading leaves with it. Bloque B has not
    // arrived at the top yet.
    await scroll((roomA2 + blockB) / 2);
    expect(top('Bloque A'), moreOrLessEquals(0));
    expect(top('AULA A-102'), moreOrLessEquals(blockAH));
    expect(top('AULA A-101'), gone());
    expect(top('Bloque B'), isNot(moreOrLessEquals(0)));

    // Midway through Bloque B: the whole of block A has left — no pile of
    // old headings — and only block B's own pair sticks.
    await scroll((blockB + loose) / 2);
    expect(top('Bloque B'), moreOrLessEquals(0));
    expect(top('B-201'), moreOrLessEquals(blockBH));
    expect(top('Bloque A'), gone());
    expect(top('AULA A-102'), gone());
    expect(top('LOSA DEPORTIVA'), isNot(moreOrLessEquals(0)));

    // At the very bottom the blockless room sticks alone.
    await scroll(controller.position.maxScrollExtent);
    expect(top('LOSA DEPORTIVA'), moreOrLessEquals(0));
    expect(top('Bloque B'), gone());
    expect(top('B-201'), gone());

    // Throughout, at most a block and its current room hold the top —
    // headings never accumulate the way bare pinned slivers would.
    final viewport = tester.getSize(find.byType(CustomScrollView)).height;
    final holding = [
      for (final text in [
        'Bloque A',
        'Bloque B',
        'AULA A-101',
        'AULA A-102',
        'B-201',
        'LOSA DEPORTIVA',
      ])
        if (top(text) case final y? when y >= 0 && y < viewport) text,
    ];
    expect(holding.length, lessThanOrEqualTo(2));
  });
}
