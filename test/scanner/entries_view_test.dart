import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/entries_view.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

void main() {
  testWidgets('renders a section header per room with its cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntriesView(
          entriesByRoom: {
            'AULA A-101': const [
              ScheduleEntry(
                room: 'AULA A-101',
                pageIndex: 0,
                start: '08:00',
                end: '10:00',
                course: 'MATEMÁTICA',
                section: '3',
              ),
            ],
            'J-109 (ESTUDIO FOTOGRÁFICO)': const [
              ScheduleEntry(
                room: 'J-109 (ESTUDIO FOTOGRÁFICO)',
                pageIndex: 0,
                status: 'RESERVA ONLINE',
                start: '12:00',
                end: '14:00',
                person: 'ANA GARCÍA LÓPEZ',
              ),
            ],
          },
        ),
      ),
    );

    expect(find.text('AULA A-101'), findsOneWidget);
    expect(find.text('MATEMÁTICA'), findsOneWidget);
    expect(find.text('SEC 3'), findsOneWidget);
    expect(find.text('J-109 (ESTUDIO FOTOGRÁFICO)'), findsOneWidget);
    expect(find.text('ANA GARCÍA LÓPEZ'), findsOneWidget);
    expect(find.text('08:00 – 10:00'), findsOneWidget);
    expect(find.textContaining('No slots booked'), findsNothing);
  });

  testWidgets('says so when every room turned out to be free', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EntriesView(entriesByRoom: {})),
    );

    expect(find.text('No slots booked — every room is free.'), findsOneWidget);
  });
}
