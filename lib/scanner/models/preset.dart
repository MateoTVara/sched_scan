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

/// The presets on offer, in the order the menu lists them: the labs still
/// to start first — the app's default choice, so a fresh install opens
/// already under it — then the two free-now views, then the whole booked
/// day. A preset carries its own sort: the upcoming list and the day view
/// read in time order, the free-now lists group by room first.
const List<Preset> presets = [
  Preset(
    name: 'Laboratorios por empezar',
    description: 'Aún no empiezan o empezaron hace menos de 10 min',
    settings: ScanSettings(
      sortMode: SortMode.timeThenRoom,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.labs,
      view: ViewChoice.soon,
      state: StateChoice.busy,
    ),
  ),
  Preset(
    name: 'Aulas libres ahora',
    description: 'Aulas sin clase en este momento, por aula y hora',
    settings: ScanSettings(
      sortMode: SortMode.roomThenTime,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.rooms,
      view: ViewChoice.now,
      state: StateChoice.free,
    ),
  ),
  Preset(
    name: 'Laboratorios libres ahora',
    description: 'Laboratorios sin clase en este momento, por aula y hora',
    settings: ScanSettings(
      sortMode: SortMode.roomThenTime,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.labs,
      view: ViewChoice.now,
      state: StateChoice.free,
    ),
  ),
  Preset(
    name: 'Horario del día',
    description: 'Todas las clases del día, por hora y aula',
    settings: ScanSettings(
      sortMode: SortMode.timeThenRoom,
      sortOrder: SortOrder.ascending,
      roomType: RoomTypeChoice.all,
      view: ViewChoice.all,
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
