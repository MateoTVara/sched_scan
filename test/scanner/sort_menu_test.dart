import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
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

    // The sheet is up over a dimmed scrim with its two-tab header; Orden —
    // where the `Ordenar` button points — opens first, listing both
    // criteria: the default one in effect, arrowed upwards, the other plain.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Orden'), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Por sala y hora'), findsOneWidget);
    expect(find.text('Por hora y sala'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byTooltip('Ascendente'), findsOneWidget);
    // The other tab's body is not built until its tab is asked for.
    expect(
      find.text('Un toque incluye, dos excluye, tres limpia.'),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color == Colors.black54,
      ),
      findsWidgets,
    );

    // Tapping the criterion that is already in effect flips its direction.
    await tester.tap(_row(SortMode.timeThenRoom));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byTooltip('Descendente'), findsOneWidget);

    // The sheet stays open for the next choice.
    expect(find.byType(TabBar), findsOneWidget);

    // Tapping the other criterion takes it over with the direction as it
    // is — arrow and all.
    await tester.tap(_row(SortMode.roomThenTime));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);

    // And the row now in effect flips it back.
    await tester.tap(_row(SortMode.roomThenTime));
    await tester.pump();

    expect(viewModel.sortOrder, SortOrder.ascending);
    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    // Tapping the dimmed part of the screen dismisses the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.ascending);
  });

  testWidgets('the filter rows cycle include → close → none → include', (
    tester,
  ) async {
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

    // Orden opens first — where the `Ordenar` button points — so the
    // three filter rows wait on their own tab.
    expect(find.text('Por sala y hora'), findsOneWidget);
    expect(find.text('Por hora y sala'), findsOneWidget);
    expect(
      find.text('Un toque incluye, dos excluye, tres limpia.'),
      findsNothing,
    );

    // Over on Filtros: the fixed rows, each in its default state — labs
    // and window ticked, Libres crossed — and no sign of the criteria's
    // rows: one body at a time.
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(
      find.text('Un toque incluye, dos excluye, tres limpia.'),
      findsOneWidget,
    );
    expect(find.text('Por sala y hora'), findsNothing);
    for (final row in FilterRow.values) {
      expect(find.byKey(ValueKey('filter-${row.name}')), findsOneWidget);
      expect(find.text(row.label), findsOneWidget);
    }
    expect(viewModel.filters.marks, defaultFilterMarks);

    final labs = find.byKey(ValueKey('filter-computeLab'));
    final free = find.byKey(ValueKey('filter-libres'));
    final window = find.byKey(ValueKey('filter-last15'));
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: free, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: window, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    // One tap on the labs row walks it include → exclude: the tick turns
    // into a cross, in the viewmodel and on screen.
    await tester.tap(labs);
    await tester.pump();

    expect(viewModel.filters.stateOf(FilterRow.computeLab), TypeMark.exclude);
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.check)),
      findsNothing,
    );

    // The mark belongs to the viewmodel: a tab away keeps it — while the
    // icons go with the body that carries them — and a tab back brings
    // the cross right where it was.
    await tester.tap(find.text('Orden'));
    await tester.pumpAndSettle();

    expect(find.text('Por sala y hora'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(viewModel.filters.stateOf(FilterRow.computeLab), TypeMark.exclude);

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );

    // A second tap takes the cross off — none, the row with no icon at
    // all — while the rows never tapped keep theirs.
    await tester.tap(labs);
    await tester.pump();

    expect(viewModel.filters.stateOf(FilterRow.computeLab), TypeMark.none);
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.close)),
      findsNothing,
    );
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    expect(
      find.descendant(of: free, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: window, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    // A third walks it back to the default include — sheet still open
    // for the next.
    await tester.tap(labs);
    await tester.pump();

    expect(viewModel.filters.stateOf(FilterRow.computeLab), TypeMark.include);
    expect(
      find.descendant(of: labs, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
    expect(viewModel.filters.marks, defaultFilterMarks);
  });
}
