import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/section_filter.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/settings_store.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/pdf_text_layer.dart';
import 'package:sched_scan/schedule/schedule_parser.dart';

class ScannerViewModel extends ChangeNotifier {
  /// [clock] reads the current time for the `Ahora` and
  /// `Inicios próximos` views and [settings] hands back the persisted
  /// choice once, synchronously, at construction — so the app opens
  /// already wearing it; tests inject their own so neither the clock nor
  /// the storage is tied to the wall clock or the platform.
  factory ScannerViewModel({
    DateTime Function()? clock,
    SettingsStore? settings,
  }) {
    // Read once, up front: the fields have to see the same snapshot.
    final stored = settings?.read();
    return ScannerViewModel._(clock: clock, store: settings, stored: stored);
  }

  ScannerViewModel._({
    DateTime Function()? clock,
    SettingsStore? store,
    ScanSettings? stored,
  }) : _clock = clock ?? DateTime.now,
       _settings = store,
       _choice = stored ?? ScanSettings.defaults;

  final DateTime Function() _clock;

  /// Where the choice is written back on every change; none in tests that
  /// do not care, and nothing is stored then.
  final SettingsStore? _settings;

  String? _recognizedText;
  String? get recognizedText => _recognizedText;

  /// Every parsed PDF entry in table order, free slots included; empty for
  /// PDFs whose text could not be split into rows (the raw text then
  /// stands in). This, not the section lists, is the signal that the parse
  /// worked: a document whose slots are all free still counts.
  List<ScheduleEntry> _entries = const [];
  List<ScheduleEntry> get entries => _entries;

  /// The scanned slots grouped by block — `Bloque A` … `Bloque K`,
  /// alphabetical and only the blocks that actually occur — rebuilt from
  /// [entries] with the current choice on every scan, every sort change
  /// and every change to [state]: the `Ocupación` choice decides which
  /// slots are cards at all (`Solo ocupadas` by default, so free slots
  /// are out, and so is any room left with nothing but free ones). Rooms
  /// with no block letter keep their own single section after the blocks.
  List<EntrySection> _sectionsByBlock = const [];
  List<EntrySection> get sectionsByBlock => _sectionsByBlock;

  /// The whole current choice — sort and the three filter sections — the
  /// persisted value, [ScanSettings.defaults] on a fresh install. Every
  /// setter below goes through [_adoptChoice]; nothing else writes it.
  ScanSettings _choice;
  ScanSettings get choice => _choice;

  /// The primary key of the sort (see [SortMode]).
  SortMode get sortMode => _choice.sortMode;

  /// Which end the time ordering starts from (see [SortOrder]).
  SortOrder get sortOrder => _choice.sortOrder;

  /// The `Tipo de espacio` section's choice.
  RoomTypeChoice get roomType => _choice.roomType;

  /// The `Momento` section's choice.
  ViewChoice get view => _choice.view;

  /// The `Ocupación` section's choice.
  StateChoice get state => _choice.state;

  /// The preset in effect, or null while the combination is a custom one
  /// — derived from the choice, never stored (see [applyPreset]).
  Preset? get activePreset => presetMatching(_choice);

  /// Switches the sort, keeping the filter choices.
  void setSort(SortMode mode, SortOrder order) =>
      _adoptChoice(_choice.copyWith(sortMode: mode, sortOrder: order));

  /// Puts the `Tipo de espacio` section on [choice] — rebuilding
  /// [sectionsByBlock] with it, like every other choice change.
  void setRoomType(RoomTypeChoice choice) =>
      _adoptChoice(_choice.copyWith(roomType: choice));

  /// Puts the `Momento` section on [choice].
  void setView(ViewChoice choice) =>
      _adoptChoice(_choice.copyWith(view: choice));

  /// Puts the `Ocupación` section on [choice] — this one alone decides which
  /// entries exist as cards, so the rebuild it triggers reshapes
  /// [sectionsByBlock] and, with it, the chips.
  void setState(StateChoice choice) =>
      _adoptChoice(_choice.copyWith(state: choice));

  /// Applies a preset in one tap: sort and all three sections at once —
  /// the way back to the defaults too, since a fresh install starts on the
  /// `Laboratorios por empezar` preset. The chip selection is left alone:
  /// [clearSelection] is the way to empty that.
  void applyPreset(Preset preset) => _adoptChoice(preset.settings);

  /// Takes on [next] — the sections rebuilt with it (the [state] choice
  /// decides which slots are cards, the sort how they are grouped), the
  /// choice written back, and nothing at all when it is the choice
  /// already in effect.
  void _adoptChoice(ScanSettings next) {
    if (next == _choice) return;
    _choice = next;
    _sectionsByBlock = _buildSections();
    _persist();
    notifyListeners();
  }

  /// Writes the current choice back, if anywhere — the chips' selection
  /// is per scan and never stored. Fire and forget: the write is a
  /// platform-side map update, nothing the UI waits on.
  void _persist() => _settings?.write(_choice);

  /// The titles of [_sectionsByBlock] picked in the filter row. Empty means
  /// nothing is picked: [visibleSectionsByBlock] then comes back empty and
  /// the view shows its "Selecciona un bloque." prompt — the initial state,
  /// and what a new scan resets to.
  Set<String> _selectedSections = {};

  /// The filter row over [sectionsByBlock]: the same sections, the current
  /// selection, and [toggleSection] to flip one.
  SectionFilter get sectionFilter => SectionFilter(
    sections: _sectionsByBlock,
    selected: Set.unmodifiable(_selectedSections),
    toggle: toggleSection,
  );

  /// What the card list renders: no section while nothing is selected — the
  /// view then shows its "Selecciona un bloque" prompt — and the selected
  /// ones once a chip has been picked, each stripped of the cards the
  /// `Tipo de espacio` and `Momento` choices keep out (`Ocupación` was
  /// already applied when the sections were built). A room (or a whole
  /// section) left without a card goes with them.
  List<EntrySection> get visibleSectionsByBlock {
    if (_selectedSections.isEmpty) return const [];
    final visible = <EntrySection>[];
    // Nothing to narrow with: the selection renders as it stands,
    // sections included.
    if (_choice.roomType == RoomTypeChoice.all &&
        _choice.view == ViewChoice.all) {
      for (final section in _sectionsByBlock) {
        if (_selectedSections.contains(section.title)) visible.add(section);
      }
      return visible;
    }
    final now = _clock();
    for (final section in _sectionsByBlock) {
      if (!_selectedSections.contains(section.title)) continue;
      final filtered = _passesFilters(section, now);
      if (filtered != null) visible.add(filtered);
    }
    return visible;
  }

  /// [section] without the cards the choices keep out, or null when
  /// nothing survived — only reached while at least one of them narrows,
  /// never for the untouched list above. Per entry, not per sub-heading:
  /// in time order the keys of `rooms` are start times, and a time group
  /// can hold several room kinds.
  EntrySection? _passesFilters(EntrySection section, DateTime now) {
    if (section.rooms.isEmpty) {
      final entries = [
        for (final slot in section.entries)
          if (_passes(slot, now)) slot,
      ];
      if (entries.isEmpty) return null;
      return EntrySection(section.title, entries: entries);
    }
    final rooms = <String, List<ScheduleEntry>>{};
    for (final group in section.rooms.entries) {
      final slots = [
        for (final slot in group.value)
          if (_passes(slot, now)) slot,
      ];
      if (slots.isNotEmpty) rooms[group.key] = slots;
    }
    if (rooms.isEmpty) return null;
    return EntrySection(section.title, rooms: rooms);
  }

  /// One card against the two per-entry choices: a room of the picked
  /// kind, in the part of the day the `Momento` choice asks for.
  bool _passes(ScheduleEntry slot, DateTime now) =>
      passesRoomType(_choice.roomType, room: slot.room) &&
      passesView(_choice.view, start: slot.start, end: slot.end, now: now);

  /// Adds [title] to the selection or takes it out again — deselecting the
  /// last one empties the selection, which brings the prompt back in place
  /// of the cards.
  void toggleSection(String title) {
    if (!_selectedSections.remove(title)) {
      _selectedSections.add(title);
    }
    notifyListeners();
  }

  /// Whether any chip is picked — the app bar's clear button follows it.
  bool get hasSelection => _selectedSections.isNotEmpty;

  /// Empties the chip selection in one go — every card goes back behind
  /// the "Selecciona un bloque." prompt, the same as deselecting the picks
  /// one by one.
  void clearSelection() {
    _selectedSections.clear();
    notifyListeners();
  }

  /// The `Filtros` tab as the menu sees it: the three choices and a
  /// setter for each — the choice itself lives in [_choice].
  ScanFilters get filters => ScanFilters(
    roomType: _choice.roomType,
    view: _choice.view,
    state: _choice.state,
    setRoomType: setRoomType,
    setView: setView,
    setState: setState,
  );

  /// Whether the filters are what emptied the card list: a block is
  /// selected, but every card in the selection was kept out — a lab-less
  /// block under `Solo laboratorios`, a room with nothing underway under
  /// `Ahora`, one with nothing opening soon under `Inicios próximos`.
  /// The view then says so instead of asking for another block.
  bool get typeFilteredOut =>
      _selectedSections.isNotEmpty && visibleSectionsByBlock.isEmpty;

  /// Swaps in a fresh scan's entries and rebuilds the sections with them,
  /// under the choice as it stands — that is persisted now (see
  /// [_persist]) and outlives the scan. What a new scan *does* start over
  /// is the filter row: the selection empties, so the prompt shows until
  /// a chip is chosen.
  void _applyEntries(List<ScheduleEntry> entries) {
    _entries = entries;
    _selectedSections = {};
    _sectionsByBlock = _buildSections();
  }

  /// The entries of [_entries] the `Ocupación` choice keeps — booked slots
  /// by default — in table order, grouped the way the current sort asks
  /// for. This is the one choice that decides which slots are cards at
  /// all; the other two narrow the list later, per entry.
  List<EntrySection> _buildSections() => _byBlock(
    [
      for (final entry in _entries)
        if (passesState(_choice.state, isFree: entry.isFree)) entry,
    ],
    mode: _choice.sortMode,
    order: _choice.sortOrder,
  );

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Reads [file]'s text layer off the UI thread and turns it into cards.
  /// The parse is the expensive part, so it runs in [compute]; the
  /// grouping below is cheap and needs the viewmodel's current choice, so
  /// it happens here.
  Future<void> scan(XFile? file) async {
    if (file == null) return;

    _isScanning = true;
    notifyListeners();

    try {
      _applyEntries(const []);

      final bytes = await file.readAsBytes();
      final result = await compute(_parsePdfInBackground, bytes);

      _applyEntries(result.entries);
      _recognizedText = result.text;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// The block a room belongs to: the `<letter>-<digit>` code printed in its
  /// name — `AULA A-203` → `A`, `J-110A (…)` → `J`, `MÚLTIPLE C-202` → `C`.
  /// The code has to start a word, so a hyphen inside one (`TALLER-2`) is not
  /// a block. A room with no code (`LOSA DEPORTIVA`) belongs to none.
  static final RegExp _blockCode = RegExp(r'(?:^|\s)([A-Z])-\d');

  static String? _blockOf(String room) => _blockCode.firstMatch(room)?.group(1);

  /// The sub-heading cards without a printed time group under — always the
  /// last one of their block or room, whatever the direction.
  static const String _noTimeHeading = 'Sin hora';

  /// Blocks first, alphabetical and only the ones that occur; then the rooms
  /// with no block letter, each keeping its own single heading. [mode] picks
  /// what a block's sub-headings are (room names or start times) and [order]
  /// which end the time ordering starts from — never the order of the blocks
  /// themselves, nor of the rooms inside one.
  static List<EntrySection> _byBlock(
    List<ScheduleEntry> slots, {
    required SortMode mode,
    required SortOrder order,
  }) {
    final blocks = <String, Map<String, List<ScheduleEntry>>>{};
    final loose = <String, List<ScheduleEntry>>{};
    for (final entry in slots) {
      final block = _blockOf(entry.room);
      if (block == null) {
        loose.putIfAbsent(entry.room, () => []).add(entry);
      } else {
        (blocks[block] ??= {}).putIfAbsent(entry.room, () => []).add(entry);
      }
    }

    final present = blocks.keys.toList()..sort();
    return [
      for (final block in present)
        EntrySection(
          'Bloque $block',
          rooms: switch (mode) {
            // One sub-heading per room, in table order.
            SortMode.roomThenTime => {
              for (final room in blocks[block]!.entries)
                room.key: _sortedByStart(room.value, order),
            },
            // One sub-heading per start time, the rooms it covers still in
            // table order inside the group.
            SortMode.timeThenRoom => _groupByStart(blocks[block]!, order),
          },
        ),
      for (final room in loose.entries)
        EntrySection(room.key, entries: _sortedByStart(room.value, order)),
    ];
  }

  /// One run of cards in start-time order, entries without a printed time
  /// last whatever [order] is — `HH:MM` compares correctly as a string.
  static List<ScheduleEntry> _sortedByStart(
    List<ScheduleEntry> slots,
    SortOrder order,
  ) {
    final sign = order == SortOrder.ascending ? 1 : -1;
    return [...slots]..sort((a, b) {
      final start = a.start;
      final otherStart = b.start;
      if (start == null && otherStart == null) return 0;
      if (start == null) return 1;
      if (otherStart == null) return -1;
      return sign * start.compareTo(otherStart);
    });
  }

  /// A block's rooms regrouped by start time for [SortMode.timeThenRoom]:
  /// every card starting at the same hour lands under one sub-heading, in
  /// table order; the sub-headings themselves follow [order], and the cards
  /// with no printed time stay last in both directions.
  static Map<String, List<ScheduleEntry>> _groupByStart(
    Map<String, List<ScheduleEntry>> rooms,
    SortOrder order,
  ) {
    final groups = <String, List<ScheduleEntry>>{};
    for (final slots in rooms.values) {
      for (final entry in slots) {
        (groups[entry.start ?? _noTimeHeading] ??= []).add(entry);
      }
    }

    var times = [
      for (final time in groups.keys)
        if (time != _noTimeHeading) time,
    ]..sort();
    if (order == SortOrder.descending) {
      times = times.reversed.toList();
    }
    if (groups.containsKey(_noTimeHeading)) {
      times.add(_noTimeHeading);
    }

    return {for (final time in times) time: groups[time]!};
  }
}

/// What the isolate hands back: the raw text layer and every parsed entry,
/// free slots included. The grouping into sections happens on the main
/// isolate instead — it is cheap, and it depends on the current sort.
class _PdfScanResult {
  const _PdfScanResult({required this.text, required this.entries});

  final String text;
  final List<ScheduleEntry> entries;
}

_PdfScanResult _parsePdfInBackground(Uint8List bytes) {
  final layer = readPdfTextLayer(bytes);
  final entries = ScheduleParser().parse(layer.lines);
  return _PdfScanResult(text: layer.text, entries: entries);
}
