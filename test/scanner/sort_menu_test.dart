import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/scanner/settings_store.dart';
import 'package:sched_scan/scanner/sort_menu.dart';

/// The viewmodel owns no platform resource, so nothing here disposes it.
ScannerViewModel _viewModel() => ScannerViewModel();

/// Opens the sheet over [viewModel] on a tall surface, so the whole
/// `Filtros` body — four sections' worth of rows — fits without
/// scrolling and every row can be tapped where it lies.
Future<void> _openMenu(WidgetTester tester, ScannerViewModel viewModel) async {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
}

/// The row of the criterion, keyed the way `SortMenu` keys it.
Finder _row(SortMode mode) => find.byKey(ValueKey('sort-$mode'));

/// One preset row, keyed by its name.
Finder _preset(String name) => find.byKey(ValueKey('preset-$name'));

/// The `Personalizado` row.
Finder _custom() => find.byKey(const ValueKey('preset-custom'));

/// One radio option of a filter section: [section] is `roomType`, `view`
/// or `state`, [name] the enum value's.
Finder _choice(String section, String name) =>
    find.byKey(ValueKey('choice-$section-$name'));

/// Whether the row carries the tick — the radio sections' state mark.
bool _ticked(WidgetTester tester, Finder row) => find
    .descendant(of: row, matching: find.byIcon(Icons.check))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('opens on Presets: the four rows, the lit default and no '
      'filters yet', (tester) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);

    // The sheet is up over a dimmed scrim with its two-tab header,
    // Presets first — and the whole combination list is there.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
    for (final preset in presets) {
      expect(_preset(preset.name), findsOneWidget);
      expect(find.text(preset.description), findsOneWidget);
      // The defaults are exactly the first preset's choice, so that one
      // opens already lit — tinted and ticked — and the rest dark.
      final lit = identical(preset, presets[0]);
      expect(
        tester.widget<ListTile>(_preset(preset.name)).selected,
        lit,
        reason: preset.name,
      );
      expect(_ticked(tester, _preset(preset.name)), lit, reason: preset.name);
    }
    expect(_custom(), findsOneWidget);
    // `Personalizado` is the odd one out: nothing of the choice is off
    // the presets, so it stands dark and unticked.
    expect(tester.widget<ListTile>(_custom()).selected, isFalse);
    expect(_ticked(tester, _custom()), isFalse);

    // The other tab's body is not built until its tab is asked for.
    expect(_row(SortMode.timeThenRoom), findsNothing);
    expect(_choice('roomType', 'labs'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color == Colors.black54,
      ),
      findsWidgets,
    );
  });

  testWidgets('one tap applies a preset, lights it and keeps the sheet up', (
    tester,
  ) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);

    // The menu opens with the default preset already lit, so one tap on
    // another one has to move the whole choice off it…
    expect(viewModel.activePreset, presets[0]);

    await tester.tap(_preset(presets[1].name));
    await tester.pump();

    // The whole choice — sort and the three sections — lands at once,
    // and the row takes the tick the default preset just lost.
    expect(viewModel.choice, presets[1].settings);
    expect(viewModel.activePreset, presets[1]);
    expect(viewModel.roomType, RoomTypeChoice.rooms);
    expect(viewModel.view, ViewChoice.now);
    expect(viewModel.state, StateChoice.free);
    expect(_ticked(tester, _preset(presets[1].name)), isTrue);
    expect(tester.widget<ListTile>(_preset(presets[1].name)).selected, isTrue);
    expect(_ticked(tester, _preset(presets[0].name)), isFalse);
    expect(_ticked(tester, _custom()), isFalse);
    expect(tester.widget<ListTile>(_custom()).selected, isFalse);

    // The sheet stays open for the next choice.
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(_preset(presets[2].name));
    await tester.pump();

    expect(viewModel.choice, presets[2].settings);
    expect(viewModel.activePreset, presets[2]);
    expect(_ticked(tester, _preset(presets[2].name)), isTrue);
    expect(_ticked(tester, _preset(presets[1].name)), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('Personalizado applies nothing and jumps to Filtros', (
    tester,
  ) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);

    await tester.tap(_custom());
    await tester.pumpAndSettle();

    // The tab swapped, and the choice underneath did not move an inch —
    // the row only names where the combination stands.
    expect(viewModel.choice, ScanSettings.defaults);
    expect(_custom(), findsNothing);
    expect(_preset(presets[0].name), findsNothing);
    // The sort criteria and the four section titles of the Filtros tab.
    expect(find.text('Orden'), findsOneWidget);
    expect(find.text('Tipo de espacio'), findsOneWidget);
    expect(find.text('Momento'), findsOneWidget);
    expect(find.text('Ocupación'), findsOneWidget);
    expect(_row(SortMode.timeThenRoom), findsOneWidget);
    expect(_row(SortMode.roomThenTime), findsOneWidget);
  });

  testWidgets('Filtros lists the criteria and the radio sections', (
    tester,
  ) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    // Both criteria: the default one in effect, arrowed upwards, the
    // other plain.
    expect(_row(SortMode.timeThenRoom), findsOneWidget);
    expect(_row(SortMode.roomThenTime), findsOneWidget);
    expect(
      find.descendant(
        of: _row(SortMode.timeThenRoom),
        matching: find.byIcon(Icons.arrow_upward),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byTooltip('Ascendente'), findsOneWidget);

    // Every option of every section, one tick per section — exactly the
    // defaults: labs, starting soon, booked only.
    for (final choice in RoomTypeChoice.values) {
      expect(_choice('roomType', choice.name), findsOneWidget);
      expect(
        _ticked(tester, _choice('roomType', choice.name)),
        choice == RoomTypeChoice.labs,
      );
    }
    for (final choice in ViewChoice.values) {
      expect(_choice('view', choice.name), findsOneWidget);
      expect(
        _ticked(tester, _choice('view', choice.name)),
        choice == ViewChoice.soon,
      );
    }
    for (final choice in StateChoice.values) {
      expect(_choice('state', choice.name), findsOneWidget);
      expect(
        _ticked(tester, _choice('state', choice.name)),
        choice == StateChoice.busy,
      );
    }
    // The old one-tap hint went with the marks.
    expect(
      find.text('Un toque incluye, dos excluye, tres limpia.'),
      findsNothing,
    );
  });

  testWidgets('tapping the criterion in effect flips its direction, the '
      'other one switches over', (tester) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    // Tapping the criterion that is already in effect flips its direction.
    await tester.tap(_row(SortMode.timeThenRoom));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(
      find.descendant(
        of: _row(SortMode.timeThenRoom),
        matching: find.byIcon(Icons.arrow_downward),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Descendente'), findsOneWidget);

    // Tapping the other criterion takes it over with the direction as it
    // is — arrow and all.
    await tester.tap(_row(SortMode.roomThenTime));
    await tester.pump();

    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    // And the row now in effect flips it back.
    await tester.tap(_row(SortMode.roomThenTime));
    await tester.pump();

    expect(viewModel.sortOrder, SortOrder.ascending);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('picking an option moves the tick, and picking it twice '
      'changes nothing', (tester) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    // Radio-style: one tap *selects* the option, in the viewmodel and on
    // screen — the tick leaves the row it was on.
    await tester.tap(_choice('roomType', 'all'));
    await tester.pump();

    expect(viewModel.roomType, RoomTypeChoice.all);
    expect(_ticked(tester, _choice('roomType', 'all')), isTrue);
    expect(_ticked(tester, _choice('roomType', 'labs')), isFalse);

    await tester.tap(_choice('view', 'now'));
    await tester.pump();

    expect(viewModel.view, ViewChoice.now);
    expect(_ticked(tester, _choice('view', 'now')), isTrue);
    expect(_ticked(tester, _choice('view', 'all')), isFalse);

    await tester.tap(_choice('state', 'free'));
    await tester.pump();

    expect(viewModel.state, StateChoice.free);
    expect(_ticked(tester, _choice('state', 'free')), isTrue);
    expect(_ticked(tester, _choice('state', 'busy')), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);

    // The row already in effect is a no-op — there is no third state to
    // cycle into.
    await tester.tap(_choice('roomType', 'all'));
    await tester.pump();

    expect(viewModel.roomType, RoomTypeChoice.all);
    expect(_ticked(tester, _choice('roomType', 'all')), isTrue);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('a choice survives a tab away and back, the tick going '
      'with its body', (tester) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    await tester.tap(_choice('state', 'free'));
    await tester.pump();

    expect(viewModel.state, StateChoice.free);

    // A tab away: the tick goes with the body it was drawn in, the
    // choice stays in the viewmodel.
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();

    expect(_choice('state', 'free'), findsNothing);
    expect(_ticked(tester, _custom()), isTrue);
    expect(viewModel.state, StateChoice.free);
    // Off every preset, so `Personalizado` is still the lit one.
    expect(tester.widget<ListTile>(_custom()).selected, isTrue);

    // And a tab back brings the tick right where it was.
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(_ticked(tester, _choice('state', 'free')), isTrue);
    expect(_ticked(tester, _choice('state', 'busy')), isFalse);
    expect(viewModel.state, StateChoice.free);
  });

  testWidgets('tapping the dimmed part of the screen dismisses the sheet', (
    tester,
  ) async {
    final viewModel = _viewModel();

    await _openMenu(tester, viewModel);
    await tester.tap(_preset(presets[0].name));
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    // What was chosen while the sheet was up stays chosen.
    expect(viewModel.choice, presets[0].settings);
  });
}
