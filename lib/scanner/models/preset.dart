import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/settings_store.dart';

/// One tap on the menu's `Presets` tab: a name, one line saying what it
/// shows, and the whole choice ([ScanSettings]) it applies — sort and
/// filters together. A preset is exactly a settings value, so which one
/// is in effect is derived from the current choice, never stored itself
/// (see [presetMatching]).
class Preset {
  const Preset({
    required this.name,
    required this.description,
    required this.settings,
  });

  /// The row as the menu prints it.
  final String name;

  /// One line under the name, saying what the preset shows.
  final String description;

  /// What one tap sets: sort, order and the three filter choices.
  final ScanSettings settings;
}

/// The presets on offer, in the order the menu lists them: the two free-
/// now views first, then the labs about to start. Each is time-then-room
/// ascending — a preset is a glance, and a glance reads in time order.
const List<Preset> presets = [
  Preset(
    name: 'Aulas libres ahora',
    description: 'Aulas sin clase en este momento',
    settings: ScanSettings(
      sortMode: SortMode.timeThenRoom,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.rooms,
      view: ViewChoice.now,
      state: StateChoice.free,
    ),
  ),
  Preset(
    name: 'Laboratorios libres ahora',
    description: 'Laboratorios sin clase en este momento',
    settings: ScanSettings(
      sortMode: SortMode.timeThenRoom,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.labs,
      view: ViewChoice.now,
      state: StateChoice.free,
    ),
  ),
  Preset(
    name: 'Laboratorios por empezar',
    description: 'Clases de laboratorio que empiezan en los próximos 15 min',
    settings: ScanSettings(
      sortMode: SortMode.timeThenRoom,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.labs,
      view: ViewChoice.soon,
      state: StateChoice.busy,
    ),
  ),
];

/// The preset [current] asks for exactly, or null while the combination
/// is a custom one — what the menu's `Personalizado` row stands for.
Preset? presetMatching(ScanSettings current) {
  for (final preset in presets) {
    if (preset.settings == current) return preset;
  }
  return null;
}
