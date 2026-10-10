import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

/// Opens the menu: a modal bottom sheet that slides in from the bottom
/// over a dimmed scrim, leaving the card list readable behind it. Its
/// header is a two-tab bar — `Orden` for the sort criteria, `Filtros` for
/// the filter rows — so only one of the two groups is on screen at a
/// time. Everything applies the moment it is tapped and the sheet stays
/// open so the list can be compared while choosing; tap the scrim or drag
/// the sheet away to dismiss.
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

/// The menu: a [TabBar] header over one body at a time — the [SortMode]
/// rows under `Orden`, the three [FilterRow]s under `Filtros` — reading
/// the current choice from [viewModel] and writing it back through
/// [ScannerViewModel.setSort] and [ScannerViewModel.cycleFilter], so the
/// choices never live here. The tab index is the only state the widget
/// keeps: transient UI state, `Orden` first because that is what the
/// `Ordenar` button means.
class SortMenu extends StatefulWidget {
  const SortMenu({super.key, required this.viewModel});

  final ScannerViewModel viewModel;

  @override
  State<SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<SortMenu>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// One criterion: tinted and arrowed while it is the one in effect, plain
  /// otherwise. Tapping the row that is already in effect flips the
  /// direction; tapping the other one switches to it and leaves the
  /// direction alone.
  Widget _row(BuildContext context, SortMode mode) {
    final theme = Theme.of(context);
    final active = widget.viewModel.sortMode == mode;
    final descending = widget.viewModel.sortOrder == SortOrder.descending;

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
          widget.viewModel.setSort(
            mode,
            descending ? SortOrder.ascending : SortOrder.descending,
          );
        } else {
          widget.viewModel.setSort(mode, widget.viewModel.sortOrder);
        }
      },
    );
  }

  static String _labelOf(SortMode mode) => switch (mode) {
    SortMode.roomThenTime => 'Por sala y hora',
    SortMode.timeThenRoom => 'Por hora y sala',
  };

  /// One filter row: tinted and ticked while marked in, red-crossed while
  /// marked out, plain when it filters nothing. Every tap advances that
  /// row's own mark, so the row is both the state and the control.
  Widget _filterRow(BuildContext context, ScanFilters filters, FilterRow row) {
    final theme = Theme.of(context);
    final state = filters.stateOf(row);

    return ListTile(
      key: ValueKey('filter-${row.name}'),
      selected: state == TypeMark.include,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        row.label,
        style: switch (state) {
          TypeMark.exclude => TextStyle(color: theme.colorScheme.error),
          _ => null,
        },
      ),
      trailing: switch (state) {
        TypeMark.include => Icon(Icons.check, color: theme.colorScheme.primary),
        TypeMark.exclude => Icon(Icons.close, color: theme.colorScheme.error),
        TypeMark.none => null,
      },
      onTap: () => filters.cycle(row),
    );
  }

  /// The tab currently under the header — and nothing of the other one:
  /// the body is swapped, not stacked.
  Widget _body(BuildContext context) {
    final children = switch (_tab.index) {
      0 => [for (final mode in SortMode.values) _row(context, mode)],
      _ => _filterRows(context),
    };

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          spacing: 4,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _filterRows(BuildContext context) {
    final theme = Theme.of(context);
    final filters = widget.viewModel.filters;

    return [
      Text(
        'Un toque incluye, dos excluye, tres limpia.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      for (final row in FilterRow.values) _filterRow(context, filters, row),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            // Content-sized, but capped: a long font scale must not grow
            // the sheet towards a full screen.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  controller: _tab,
                  tabs: const [
                    Tab(text: 'Orden'),
                    Tab(text: 'Filtros'),
                  ],
                ),
                Flexible(
                  child: AnimatedBuilder(
                    animation: _tab,
                    builder: (context, _) => _body(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
