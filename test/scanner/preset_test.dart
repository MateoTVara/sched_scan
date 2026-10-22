import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/settings_store.dart';

void main() {
  test('the three presets on offer, in the order the menu lists them', () {
    expect(
      [for (final preset in presets) preset.name],
      [
        'Aulas libres ahora',
        'Laboratorios libres ahora',
        'Laboratorios por empezar',
      ],
    );
    // Each row carries the one line that says what it shows.
    for (final preset in presets) {
      expect(preset.description, isNotEmpty, reason: preset.name);
    }
  });

  test('each preset is a whole choice, time-first and ascending', () {
    for (final preset in presets) {
      expect(preset.settings.sortMode, SortMode.timeThenRoom);
      expect(preset.settings.sortOrder, SortOrder.ascending);
    }

    expect(presets[0].settings.roomType, RoomTypeChoice.rooms);
    expect(presets[0].settings.view, ViewChoice.now);
    expect(presets[0].settings.state, StateChoice.free);

    expect(presets[1].settings.roomType, RoomTypeChoice.labs);
    expect(presets[1].settings.view, ViewChoice.now);
    expect(presets[1].settings.state, StateChoice.free);

    expect(presets[2].settings.roomType, RoomTypeChoice.labs);
    expect(presets[2].settings.view, ViewChoice.soon);
    expect(presets[2].settings.state, StateChoice.busy);
  });

  test('presetMatching names the preset a choice is, or nothing', () {
    for (final preset in presets) {
      expect(presetMatching(preset.settings), same(preset));
    }

    // The defaults ask for none of them — the `Personalizado` state.
    expect(presetMatching(ScanSettings.defaults), isNull);

    // One field off an otherwise matching preset is custom as well.
    final flipped = presets[0].settings.copyWith(
      sortOrder: SortOrder.descending,
    );
    expect(presetMatching(flipped), isNull);
  });
}
