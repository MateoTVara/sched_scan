import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

/// Opens the menu: a modal bottom sheet that slides in from the bottom
/// over a dimmed scrim, leaving the card list readable behind it. Its
/// header is a two-tab bar — `Presets` for the one-tap combinations,
/// `Filtros` for the sort and the three filter sections — so only one of
/// the two groups is on screen at a time. Everything applies the moment
/// it is tapped and the sheet stays open so the list can be compared
/// while choosing; tap the scrim or drag the sheet away to dismiss.
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

/// The menu: a [TabBar] header over one body at a time — the presets with
/// their `Personalizado` row under `Presets`, the `Orden` sort criteria
/// and the three radio-style filter sections under `Filtros` — reading
/// the current choice from [viewModel] and writing it back through
/// [ScannerViewModel.applyPreset], [ScannerViewModel.setSort] and the
/// [ScanFilters] setters, so the choices never live here. The tab index is
/// the only state the widget keeps: transient UI state, `Presets` first
/// because that is what a glance reaches for.
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

  /// One preset: titled, described, ticked while it is the combination
  /// in effect ([ScannerViewModel.activePreset]). One tap applies it and
  /// the sheet stays open, so the list changes right behind it.
  Widget _presetRow(BuildContext context, Preset preset) {
    final theme = Theme.of(context);
    final active = widget.viewModel.activePreset == preset;

    return ListTile(
      key: ValueKey('preset-${preset.name}'),
      selected: active,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      title: Text(preset.name),
      subtitle: Text(
        preset.description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: active
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () => widget.viewModel.applyPreset(preset),
    );
  }

  /// The `Personalizado` row: tinted and ticked whenever the current
  /// combination matches no preset — the state a hand-mixed choice is in —
  /// and the way over to it: one tap swaps to the `Filtros` tab, where it
  /// is mixed. It applies nothing itself, because there is nothing to
  /// apply; it only names where the choice stands.
  Widget _customRow(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.viewModel.activePreset == null;

    return ListTile(
      key: const ValueKey('preset-custom'),
      selected: active,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Personalizado'),
      subtitle: Text(
        'Mezcla hecha a mano, en la pestaña Filtros',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: active
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () => _tab.animateTo(1),
    );
  }

  /// One sort criterion: tinted and arrowed while it is the one in effect, plain
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
    SortMode.roomThenTime => 'Por aula y hora',
    SortMode.timeThenRoom => 'Por hora y aula',
  };

  /// One option of a filter section: tinted and ticked while it is the
  /// choice in effect, plain otherwise — radio-style, so one tap
  /// *selects* [onSelect]'s option and tapping the one already in effect
  /// changes nothing.
  Widget _choiceRow(
    BuildContext context, {
    required String section,
    required String name,
    required String label,
    required bool active,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      key: ValueKey('choice-$section-$name'),
      selected: active,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      title: Text(label),
      trailing: active
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: onSelect,
    );
  }

  /// One section heading over its option rows.
  Widget _sectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  /// The tab currently under the header — and nothing of the other one:
  /// the body is swapped, not stacked.
  Widget _body(BuildContext context) {
    final children = switch (_tab.index) {
      0 => _presetRows(context),
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

  /// The presets in their shipped order, the `Personalizado` row closing
  /// the list — the one that lights up when none of them is in effect.
  List<Widget> _presetRows(BuildContext context) => [
    for (final preset in presets) _presetRow(context, preset),
    _customRow(context),
  ];

  /// The `Filtros` tab: the sort criteria under `Orden`, then one
  /// radio-style row per option under each filter section. The old
  /// one-tap-includes hint is gone with the marks — a row is simply the
  /// choice it shows.
  List<Widget> _filterRows(BuildContext context) {
    final filters = widget.viewModel.filters;

    return [
      _sectionTitle(context, 'Orden'),
      for (final mode in SortMode.values) _row(context, mode),
      _sectionTitle(context, 'Tipo de espacio'),
      for (final choice in RoomTypeChoice.values)
        _choiceRow(
          context,
          section: 'roomType',
          name: choice.name,
          label: choice.label,
          active: filters.roomType == choice,
          onSelect: () => filters.setRoomType(choice),
        ),
      _sectionTitle(context, 'Momento'),
      for (final choice in ViewChoice.values)
        _choiceRow(
          context,
          section: 'view',
          name: choice.name,
          label: choice.label,
          active: filters.view == choice,
          onSelect: () => filters.setView(choice),
        ),
      _sectionTitle(context, 'Ocupación'),
      for (final choice in StateChoice.values)
        _choiceRow(
          context,
          section: 'state',
          name: choice.name,
          label: choice.label,
          active: filters.state == choice,
          onSelect: () => filters.setState(choice),
        ),
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
                    Tab(text: 'Presets'),
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
