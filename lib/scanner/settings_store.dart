import 'package:shared_preferences/shared_preferences.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';

/// Sort and filter choices as one value — what the scanner viewmodel keeps
/// between scans and app restarts, and what a preset on the menu's
/// `Presets` tab carries. Every field is single-choice; there is nothing
/// to default per key.
class ScanSettings {
  const ScanSettings({
    required this.sortMode,
    required this.sortOrder,
    required this.roomType,
    required this.view,
    required this.state,
  });

  /// What a fresh install starts from, and what
  /// `ScannerViewModel.restoreDefaults` gives back: the labs starting
  /// soon, booked slots only, earliest first — the `Laboratorios por
  /// empezar` preset's choice, so a fresh install opens already under a
  /// named preset. Written out as a literal rather than read off
  /// `presets[0]`: `preset.dart` imports this library, and the other way
  /// round would be a cycle — `preset_test` pins the two together.
  static const defaults = ScanSettings(
    sortMode: SortMode.timeThenRoom,
    sortOrder: SortOrder.ascending,
    roomType: RoomTypeChoice.labs,
    view: ViewChoice.soon,
    state: StateChoice.busy,
  );

  final SortMode sortMode;
  final SortOrder sortOrder;
  final RoomTypeChoice roomType;
  final ViewChoice view;
  final StateChoice state;

  /// A copy of this value with the given fields replaced.
  ScanSettings copyWith({
    SortMode? sortMode,
    SortOrder? sortOrder,
    RoomTypeChoice? roomType,
    ViewChoice? view,
    StateChoice? state,
  }) => ScanSettings(
    sortMode: sortMode ?? this.sortMode,
    sortOrder: sortOrder ?? this.sortOrder,
    roomType: roomType ?? this.roomType,
    view: view ?? this.view,
    state: state ?? this.state,
  );

  /// Two snapshots are equal when they ask for the same list — the
  /// comparison a preset match and every no-op setter check are made on.
  @override
  bool operator ==(Object other) =>
      other is ScanSettings &&
      other.sortMode == sortMode &&
      other.sortOrder == sortOrder &&
      other.roomType == roomType &&
      other.view == view &&
      other.state == state;

  @override
  int get hashCode => Object.hash(sortMode, sortOrder, roomType, view, state);
}

/// Where the viewmodel reads its choices from once, synchronously, at
/// construction ([read] — the platform side is loaded before the app
/// starts), and writes them back on every change ([write], fire and
/// forget). Kept abstract so tests never reach the plugin.
abstract class SettingsStore {
  /// The stored choice, or null while nothing has been stored yet — the
  /// defaults then stand.
  ScanSettings? read();

  Future<void> write(ScanSettings settings);
}

/// The store over [SharedPreferences]: one key per choice, enum values by
/// name, and anything unreadable — a value this version no longer knows —
/// falling back to its default rather than failing the launch.
class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore(this._prefs);

  static const _sortModeKey = 'sort_mode';
  static const _sortOrderKey = 'sort_order';
  static const _roomTypeKey = 'room_type';
  static const _viewKey = 'view';
  static const _stateKey = 'state';

  /// The keys the four mark rows used before the menu became
  /// single-choice; every write takes them along so no dead value lingers.
  static const _legacyFilterKeys = [
    'filter_computeLab',
    'filter_libres',
    'filter_last15',
    'filter_now',
  ];

  final SharedPreferences _prefs;

  @override
  ScanSettings? read() {
    if (!_prefs.containsKey(_sortModeKey) &&
        !_prefs.containsKey(_sortOrderKey) &&
        !_prefs.containsKey(_roomTypeKey) &&
        !_prefs.containsKey(_viewKey) &&
        !_prefs.containsKey(_stateKey)) {
      return null; // nothing stored yet: the defaults stand
    }
    return ScanSettings(
      sortMode:
          SortMode.values.asNameMap()[_prefs.getString(_sortModeKey)] ??
          ScanSettings.defaults.sortMode,
      sortOrder:
          SortOrder.values.asNameMap()[_prefs.getString(_sortOrderKey)] ??
          ScanSettings.defaults.sortOrder,
      roomType:
          RoomTypeChoice.values.asNameMap()[_prefs.getString(_roomTypeKey)] ??
          ScanSettings.defaults.roomType,
      view:
          ViewChoice.values.asNameMap()[_prefs.getString(_viewKey)] ??
          ScanSettings.defaults.view,
      state:
          StateChoice.values.asNameMap()[_prefs.getString(_stateKey)] ??
          ScanSettings.defaults.state,
    );
  }

  @override
  Future<void> write(ScanSettings settings) async {
    await _prefs.setString(_sortModeKey, settings.sortMode.name);
    await _prefs.setString(_sortOrderKey, settings.sortOrder.name);
    await _prefs.setString(_roomTypeKey, settings.roomType.name);
    await _prefs.setString(_viewKey, settings.view.name);
    await _prefs.setString(_stateKey, settings.state.name);
    for (final key in _legacyFilterKeys) {
      await _prefs.remove(key);
    }
  }
}
