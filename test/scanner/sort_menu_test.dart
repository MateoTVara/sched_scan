import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/scanner/sort_menu.dart';

/// Never disposed: closing the ML Kit recognizer reaches a plugin that does
/// not exist on the host, and no OCR runs in these tests to allocate one.
ScannerViewModel _viewModel() => ScannerViewModel();

/// The row of the criterion, keyed the way `SortMenu` keys it.
Finder _row(SortMode mode) => find.byKey(ValueKey('sort-$mode'));

void main() {
  testWidgets('lists the criteria, flips the active one and switches with '
      'its direction intact', (tester) async {
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showSortMenu(context, viewModel),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // The sheet is up over a dimmed scrim with the two criteria listed —
    // the default one in effect, arrowed upwards, the other one plain.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Ordenar'), findsOneWidget);
    expect(find.text('Por sala y hora'), findsOneWidget);
    expect(find.text('Por hora y sala'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byTooltip('Ascendente'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color == Colors.black54,
      ),
      findsWidgets,
    );

    // Tapping the criterion that is already in effect flips its direction.
    await tester.tap(_row(SortMode.roomThenTime));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byTooltip('Descendente'), findsOneWidget);

    // The sheet stays open for the next choice.
    expect(find.text('Ordenar'), findsOneWidget);

    // Tapping the other criterion takes it over with the direction as it
    // is — arrow and all.
    await tester.tap(_row(SortMode.timeThenRoom));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('Ordenar'), findsOneWidget);

    // And the row now in effect flips it back.
    await tester.tap(_row(SortMode.timeThenRoom));
    await tester.pump();

    expect(viewModel.sortOrder, SortOrder.ascending);
    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    // Tapping the dimmed part of the screen dismisses the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Ordenar'), findsNothing);
    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.ascending);
  });
}
