import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The store over an empty (or [seed]ed) in-memory preferences — the
/// platform side mocked out, the rest of the real implementation.
Future<SharedPrefsSettingsStore> _store([
  Map<String, Object> seed = const {},
]) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(seed);
  return SharedPrefsSettingsStore(await SharedPreferences.getInstance());
}

/// A choice with every field off the defaults, so a round trip has
/// something of each to bring back.
const _everywhere = ScanSettings(
  sortMode: SortMode.roomThenTime,
  sortOrder: SortOrder.descending,
  roomType: RoomTypeChoice.rooms,
  view: ViewChoice.soon,
  state: StateChoice.free,
);

void main() {
  test('a fresh install stores nothing — read comes back null', () async {
    final store = await _store();

    expect(store.read(), isNull);
  });

  test('what is written is what is read back, field for field', () async {
    final store = await _store();

    await store.write(_everywhere);

    expect(store.read(), _everywhere);
    expect(store.read()!.roomType, RoomTypeChoice.rooms);
    expect(store.read()!.view, ViewChoice.soon);
    expect(store.read()!.state, StateChoice.free);
  });

  test('the defaults round-trip like any other choice', () async {
    final store = await _store();

    await store.write(ScanSettings.defaults);

    expect(store.read(), ScanSettings.defaults);
  });

  test('the old mark keys are no choice of ours: ignored and swept', () async {
    // Leftovers from the four-row era seed the store: they neither stand
    // in for a choice on read…
    final store = await _store({
      'filter_computeLab': 'include',
      'filter_libres': 'exclude',
      'filter_last15': 'include',
    });

    expect(store.read(), isNull);

    // …nor survive a write.
    await store.write(ScanSettings.defaults);
    expect(store.read(), ScanSettings.defaults);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.startsWith('filter_')), isEmpty);
  });

  test('unreadable stored values fall back to their defaults', () async {
    // An enum name this version no longer knows — a renamed value from a
    // future or past release — must not fail the launch.
    final store = await _store({
      'sort_mode': 'no-such-mode',
      'sort_order': 'no-such-order',
      'room_type': 'no-such-room-type',
      'view': 'no-such-view',
      'state': 'no-such-state',
    });

    expect(store.read(), ScanSettings.defaults);
  });

  test('an unknown value falls back on its own, not for the rest', () async {
    final store = await _store({
      'sort_mode': SortMode.roomThenTime.name,
      'room_type': 'no-such-room-type',
    });

    final settings = store.read()!;
    expect(settings.sortMode, SortMode.roomThenTime);
    expect(settings.sortOrder, ScanSettings.defaults.sortOrder);
    expect(settings.roomType, ScanSettings.defaults.roomType);
    expect(settings.view, ScanSettings.defaults.view);
    expect(settings.state, ScanSettings.defaults.state);
  });
}
