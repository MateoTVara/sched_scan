import 'package:shared_preferences/shared_preferences.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';

/// Sort and filter marks as one value — what the scanner viewmodel keeps
/// between scans and app restarts. A row absent from [marks] is
/// [TypeMark.none], the same convention `_marks` keeps.
class ScanSettings {
  const ScanSettings({
    required this.sortMode,
    required this.sortOrder,
    required this.marks,
  });

  /// What a fresh install starts from, and what
  /// `ScannerViewModel.restoreDefaults` gives back.
  static const defaults = ScanSettings(
    sortMode: SortMode.timeThenRoom,
    sortOrder: SortOrder.ascending,
    marks: defaultFilterMarks,
  );

  final SortMode sortMode;
  final SortOrder sortOrder;

  /// Only the rows carrying a mark; the rest are [TypeMark.none].
  final Map<FilterRow, TypeMark> marks;
}

/// Where the viewmodel reads its sort and marks from once, synchronously,
/// at construction ([read] — the platform side is loaded before the app
/// starts), and writes them back on every change ([write], fire and
/// forget). Kept abstract so tests never reach the plugin.
abstract class SettingsStore {
  /// The stored choice, or null while nothing has been stored yet — the
  /// defaults then stand.
  ScanSettings? read();

  Future<void> write(ScanSettings settings);
}

/// The store over [SharedPreferences]: enum values by name, one extra key
/// per filter row, and no key at all for a row back at [TypeMark.none] —
/// so `read` hands back exactly what was written, row for row.
class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore(this._prefs);

  static const _sortModeKey = 'sort_mode';
  static const _sortOrderKey = 'sort_order';
  static const _filterPrefix = 'filter_';

  final SharedPreferences _prefs;

  /// Anything unreadable — a value this version no longer knows — falls
  /// back to its default rather than failing the launch.
  @override
  ScanSettings? read() {
    if (!_prefs.containsKey(_sortModeKey) &&
        !_prefs.containsKey(_sortOrderKey)) {
      return null; // nothing stored yet: the defaults stand
    }
    return ScanSettings(
      sortMode:
          SortMode.values.asNameMap()[_prefs.getString(_sortModeKey)] ??
          SortMode.timeThenRoom,
      sortOrder:
          SortOrder.values.asNameMap()[_prefs.getString(_sortOrderKey)] ??
          SortOrder.ascending,
      marks: {
        for (final row in FilterRow.values)
          if (_markOf(row) != null) row: _markOf(row)!,
      },
    );
  }

  @override
  Future<void> write(ScanSettings settings) async {
    await _prefs.setString(_sortModeKey, settings.sortMode.name);
    await _prefs.setString(_sortOrderKey, settings.sortOrder.name);
    for (final row in FilterRow.values) {
      final key = '$_filterPrefix${row.name}';
      final mark = settings.marks[row] ?? TypeMark.none;
      if (mark == TypeMark.none) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, mark.name);
      }
    }
  }

  /// The row's stored mark, or null when it carries none.
  TypeMark? _markOf(FilterRow row) => TypeMark.values
      .asNameMap()[_prefs.getString('$_filterPrefix${row.name}')];
}
