import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/schedule/schedule_view.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

void main() {
  testWidgets('the initial prompt is centred in the viewport as one block', (
    tester,
  ) async {
    final viewModel = ScheduleViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(slivers: [ScheduleView(viewModel: viewModel)]),
      ),
    );

    // The prompt is the only line, shown as a single block...
    final prompt = find.text('Selecciona un archivo.');
    expect(prompt, findsOneWidget);
    expect(find.text('No se reconoció texto'), findsNothing);

    // ...centred horizontally...
    expect(tester.getCenter(prompt).dx, moreOrLessEquals(400));

    // ...and at the vertical centre of the 600px-tall test viewport (not
    // pinned to the top).
    expect(tester.getCenter(prompt).dy, moreOrLessEquals(300, epsilon: 1));
  });
}
