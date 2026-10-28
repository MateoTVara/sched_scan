import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/settings_store.dart';

void main() {
  test('the four presets on offer, in the order the menu lists them', () {
    expect(
      [for (final preset in presets) preset.name],
      [
        'Laboratorios por empezar',
        'Aulas libres ahora',
        'Laboratorios libres ahora',
        'Horario del día',
      ],
    );
    // Each row carries the one line that says what it shows.
    for (final preset in presets) {
      expect(preset.description, isNotEmpty, reason: preset.name);
    }
  });

  test('each preset is a whole choice, with its own sort', () {
    for (final preset in presets) {
      expect(preset.settings.sortOrder, SortOrder.ascending);
    }

    // The upcoming labs and the whole day read in time order…
    expect(presets[0].settings.sortMode, SortMode.timeThenRoom);
    expect(presets[0].settings.roomType, RoomTypeChoice.labs);
    expect(presets[0].settings.view, ViewChoice.soon);
    expect(presets[0].settings.state, StateChoice.busy);

    // …the two free-now lists group by room first.
    expect(presets[1].settings.sortMode, SortMode.roomThenTime);
    expect(presets[1].settings.roomType, RoomTypeChoice.rooms);
    expect(presets[1].settings.view, ViewChoice.now);
    expect(presets[1].settings.state, StateChoice.free);

    expect(presets[2].settings.sortMode, SortMode.roomThenTime);
    expect(presets[2].settings.roomType, RoomTypeChoice.labs);
    expect(presets[2].settings.view, ViewChoice.now);
    expect(presets[2].settings.state, StateChoice.free);

    expect(presets[3].settings.sortMode, SortMode.timeThenRoom);
    expect(presets[3].settings.roomType, RoomTypeChoice.all);
    expect(presets[3].settings.view, ViewChoice.all);
    expect(presets[3].settings.state, StateChoice.busy);
  });

  test('the defaults are the first preset, word for word', () {
    // `ScanSettings.defaults` is a literal — `preset.dart` imports
    // `settings_store.dart`, so the other way round would be a cycle —
    // which is why this pair is pinned here.
    expect(ScanSettings.defaults, presets[0].settings);
    expect(presetMatching(ScanSettings.defaults), same(presets[0]));
  });

  test('presetMatching names the preset a choice is, or nothing', () {
    for (final preset in presets) {
      expect(presetMatching(preset.settings), same(preset));
    }

    // One field off an otherwise matching preset is custom as well.
    final flipped = presets[1].settings.copyWith(
      sortOrder: SortOrder.descending,
    );
    expect(presetMatching(flipped), isNull);

    // As is a choice no preset ships: every room all day, free only.
    expect(
      presetMatching(presets[3].settings.copyWith(state: StateChoice.free)),
      isNull,
    );
  });
}
