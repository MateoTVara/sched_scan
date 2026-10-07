import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

/// Opens the sort menu: a modal bottom sheet that slides in from the bottom
/// over a dimmed scrim, leaving the card list readable behind it. The rows
/// are the criteria themselves — tapping the active one flips its direction,
/// tapping the other one takes the criterion over with the direction as it
/// is. The sheet stays open so the list can be compared while choosing;
/// drag the handle or tap outside to dismiss.
Future<void> showSortMenu(BuildContext context, ScannerViewModel viewModel) {
  return showModalBottomSheet<void>(
    context: context,
    // Content-sized rather than the default ninth of the screen, which a
    // large font scale could still overflow.
    isScrollControlled: true,
    // showDragHandle: true,
    barrierColor: Colors.black54,
    builder: (context) => SortMenu(viewModel: viewModel),
  );
}

/// The menu: one row per [SortMode], reading the current choice from
/// [viewModel] and writing it back through [ScannerViewModel.setSort], so
/// the sheet itself holds no state.
class SortMenu extends StatelessWidget {
  const SortMenu({super.key, required this.viewModel});

  final ScannerViewModel viewModel;

  static String _labelOf(SortMode mode) => switch (mode) {
    SortMode.roomThenTime => 'Por sala y hora',
    SortMode.timeThenRoom => 'Por hora y sala',
  };

  /// One criterion: tinted and arrowed while it is the one in effect, plain
  /// otherwise. Tapping the row that is already in effect flips the
  /// direction; tapping the other one switches to it and leaves the
  /// direction alone.
  Widget _row(BuildContext context, SortMode mode) {
    final theme = Theme.of(context);
    final active = viewModel.sortMode == mode;
    final descending = viewModel.sortOrder == SortOrder.descending;

    return ListTile(
      key: ValueKey('sort-$mode'),
      selected: active,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      title: Text(_labelOf(mode)),
      trailing: active
          ? Tooltip(
              message: descending ? 'Descendente' : 'Ascendente',
              child: Icon(
                descending ? Icons.arrow_downward : Icons.arrow_upward,
                color: theme.colorScheme.primary,
              ),
            )
          : null,
      onTap: () {
        if (active) {
          viewModel.setSort(
            mode,
            descending ? SortOrder.ascending : SortOrder.descending,
          );
        } else {
          viewModel.setSort(mode, viewModel.sortOrder);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                spacing: 4,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ordenar', style: theme.textTheme.titleLarge),
                  for (final mode in SortMode.values) _row(context, mode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
