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

void main() {
  test('a fresh install stores nothing — read comes back null', () async {
    final store = await _store();

    expect(store.read(), isNull);
  });

  test('what is written is what is read back, row for row', () async {
    final store = await _store();

    await store.write(
      const ScanSettings(
        sortMode: SortMode.roomThenTime,
        sortOrder: SortOrder.descending,
        marks: {
          FilterRow.computeLab: TypeMark.exclude,
          FilterRow.last15: TypeMark.exclude,
        },
      ),
    );

    final read = store.read();
    expect(read, isNotNull);
    expect(read!.sortMode, SortMode.roomThenTime);
    expect(read.sortOrder, SortOrder.descending);
    // Only the two marked rows; the absent ones are none, the same
    // convention the viewmodel's marks keep.
    expect(read.marks, {
      FilterRow.computeLab: TypeMark.exclude,
      FilterRow.last15: TypeMark.exclude,
    });
  });

  test('a row written back as none leaves no key behind', () async {
    final store = await _store();
    await store.write(
      const ScanSettings(
        sortMode: SortMode.roomThenTime,
        sortOrder: SortOrder.ascending,
        marks: {FilterRow.libres: TypeMark.include},
      ),
    );
    expect(store.read()!.marks[FilterRow.libres], TypeMark.include);

    await store.write(ScanSettings.defaults);

    final read = store.read()!;
    expect(read.marks, defaultFilterMarks);
    expect(read.sortMode, SortMode.timeThenRoom);
    expect(read.sortOrder, SortOrder.ascending);
  });

  test('the defaults round-trip like any other choice', () async {
    final store = await _store();

    await store.write(ScanSettings.defaults);

    final read = store.read();
    expect(read, isNotNull);
    expect(read!.sortMode, ScanSettings.defaults.sortMode);
    expect(read.sortOrder, ScanSettings.defaults.sortOrder);
    expect(read.marks, defaultFilterMarks);
  });

  test('unreadable stored values fall back to the defaults', () async {
    final store = await _store({
      'sort_mode': 'bySize',
      'sort_order': 'sideways',
      'filter_libres': 'maybe',
    });

    final read = store.read();
    expect(read, isNotNull);
    expect(read!.sortMode, SortMode.timeThenRoom);
    expect(read.sortOrder, SortOrder.ascending);
    expect(read.marks, isEmpty);
  });
}
