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

void main() {
  testWidgets('renders a section header per room with its cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntriesView(
          sections: [
            EntrySection('AULA A-101', entries: const [_bookedInA]),
            EntrySection(
              'J-109 (ESTUDIO FOTOGRÁFICO)',
              entries: const [_bookedInJ],
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
    // Room mode has no block headings.
    expect(find.textContaining('Bloque '), findsNothing);
    expect(find.textContaining('Sin reservas'), findsNothing);
  });

  testWidgets('renders a block heading over a heading per room', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntriesView(
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
    await tester.pumpWidget(const MaterialApp(home: EntriesView(sections: [])));

    expect(
      find.text('Sin reservas: todas las aulas están libres.'),
      findsOneWidget,
    );
  });
}
