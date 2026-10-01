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

    final prompt = find.text('Selecciona un archivo.');
    final noText = find.text('No se reconoció texto');
    expect(prompt, findsOneWidget);
    expect(noText, findsOneWidget);

    // The two lines stay stacked in order...
    expect(
      tester.getTopLeft(prompt).dy,
      lessThan(tester.getTopLeft(noText).dy),
    );

    // ...centred horizontally...
    expect(tester.getCenter(prompt).dx, moreOrLessEquals(400));
    expect(tester.getCenter(noText).dx, moreOrLessEquals(400));

    // ...and the pair as a whole sits at the vertical centre of the
    // 600px-tall test viewport (not pinned to the top).
    final pairMidpoint =
        (tester.getTopLeft(prompt).dy + tester.getBottomLeft(noText).dy) / 2;
    expect(pairMidpoint, moreOrLessEquals(300, epsilon: 1));
  });
}
