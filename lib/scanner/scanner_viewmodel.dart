import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/section_filter.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';
import 'package:sched_scan/schedule/schedule_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ScannerViewModel extends ChangeNotifier {
  /// [clock] reads the current time for the freshness row; tests inject
  /// their own so the 15-minute window is not tied to the wall clock.
  ScannerViewModel({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  // final _parser = ScheduleParser();

  final DateTime Function() _clock;

  String? _recognizedText;
  String? get recognizedText => _recognizedText;

  /// Every parsed PDF entry in table order, free slots included; empty for
  /// image scans and for PDFs whose text could not be split into rows (the
  /// raw text then stands in). This, not the section lists, is the signal
  /// that the parse worked: a document whose slots are all free still counts.
  List<ScheduleEntry> _entries = const [];
  List<ScheduleEntry> get entries => _entries;

  /// The scanned slots grouped by block — `Bloque A` … `Bloque K`,
  /// alphabetical and only the blocks that actually occur — rebuilt from
  /// [entries] with the current [sortMode] and [sortOrder] on every scan
  /// and every sort change, and with the `Libres` mark on every change to
  /// it: free slots are out by default, and so is any room left with
  /// nothing but free ones. Rooms with no block letter keep their own
  /// single section after the blocks.
  List<EntrySection> _sectionsByBlock = const [];
  List<EntrySection> get sectionsByBlock => _sectionsByBlock;

  /// The primary key of the sort (see [SortMode]); the default, and what a
  /// new scan resets to.
  SortMode _sortMode = SortMode.timeThenRoom;
  SortMode get sortMode => _sortMode;

  /// Which end the time ordering starts from (see [SortOrder]); the default,
  /// and what a new scan resets to.
  SortOrder _sortOrder = SortOrder.ascending;
  SortOrder get sortOrder => _sortOrder;

  /// Switches the sort and rebuilds [sectionsByBlock] with it. The top-level
  /// section titles never change between modes, so the filter row's selection
  /// survives the switch untouched.
  void setSort(SortMode mode, SortOrder order) {
    if (mode == _sortMode && order == _sortOrder) return;
    _sortMode = mode;
    _sortOrder = order;
    _sectionsByBlock = _buildSections();
    notifyListeners();
  }

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
  /// filter marks keep out. A room (or a whole section) left without a card
  /// goes with them.
  List<EntrySection> get visibleSectionsByBlock {
    if (_selectedSections.isEmpty) return const [];
    final visible = <EntrySection>[];
    // No mark set: the selection renders as it stands, sections included.
    if (_marks.isEmpty) {
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

  /// [section] without the cards the marks keep out, or null when nothing
  /// survived — only reached while at least one row is marked, never for
  /// the untouched list above. Per entry, not per sub-heading: in time
  /// order the keys of `rooms` are start times, and a time group can hold
  /// several room kinds.
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

  /// One card against all three rows: a compute lab that is not free and
  /// not stale, as far as each row's own mark asks for.
  bool _passes(ScheduleEntry slot, DateTime now) =>
      passesMark(
        _marks[FilterRow.computeLab] ?? TypeMark.none,
        isComputeLab(slot.room),
      ) &&
      passesMark(_marks[FilterRow.libres] ?? TypeMark.none, slot.isFree) &&
      passesMark(
        _marks[FilterRow.last15] ?? TypeMark.none,
        !isStale(slot.start, now),
      );

  /// Adds [title] to the selection or takes it out again — deselecting the
  /// last one empties the selection, which brings the prompt back in place
  /// of the cards.
  void toggleSection(String title) {
    if (!_selectedSections.remove(title)) {
      _selectedSections.add(title);
    }
    notifyListeners();
  }

  /// The mark on each of the three filter rows — [defaultFilterMarks]
  /// after every scan: like the selection and the sort, the filters are
  /// per scan.
  final Map<FilterRow, TypeMark> _marks = Map.of(defaultFilterMarks);

  /// The `Filtros` tab: the three rows, the mark on each, and [cycleFilter]
  /// to advance one.
  ScanFilters get filters =>
      ScanFilters(marks: Map.unmodifiable(_marks), cycle: cycleFilter);

  /// Advances one row: none → include → exclude → none. A row back at
  /// [TypeMark.none] drops out of the marks entirely. The `Libres` row
  /// also decides which entries exist as cards at all, so it rebuilds
  /// [sectionsByBlock] — the chips follow it, the other rows only narrow
  /// what they show.
  void cycleFilter(FilterRow row) {
    final next = (_marks[row] ?? TypeMark.none).next;
    if (next == TypeMark.none) {
      _marks.remove(row);
    } else {
      _marks[row] = next;
    }
    if (row == FilterRow.libres) {
      _sectionsByBlock = _buildSections();
    }
    notifyListeners();
  }

  /// Whether the filters are what emptied the card list: a block is
  /// selected, but every card in the selection was marked out — a compute
  /// lab include over a lab-less block, the freshness window over a stale
  /// one. The view then says so instead of asking for another block.
  bool get typeFilteredOut =>
      _selectedSections.isNotEmpty && visibleSectionsByBlock.isEmpty;

  /// Swaps in a fresh scan's entries and rebuilds the sections with them. A
  /// new scan starts over: the filter row empties (so the prompt shows until
  /// a chip is chosen), the marks go back to [defaultFilterMarks], and the
  /// sort goes back to time-then-room, ascending.
  void _applyEntries(List<ScheduleEntry> entries) {
    _entries = entries;
    _selectedSections = {};
    _marks
      ..clear()
      ..addAll(defaultFilterMarks);
    _sortMode = SortMode.timeThenRoom;
    _sortOrder = SortOrder.ascending;
    _sectionsByBlock = _buildSections();
  }

  /// The entries of [_entries] the `Libres` mark keeps — booked slots by
  /// default — in table order, grouped the way the current
  /// [sortMode]/[sortOrder] asks for.
  List<EntrySection> _buildSections() => _byBlock(
    [
      for (final entry in _entries)
        if (passesMark(_marks[FilterRow.libres] ?? TypeMark.none, entry.isFree))
          entry,
    ],
    mode: _sortMode,
    order: _sortOrder,
  );

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> scan(ScheduleSource? source) async {
    if (source == null) return;

    _isScanning = true;
    notifyListeners();

    try {
      _recognizedText = switch (source) {
        ScheduleImage(:final file) => await _scanImage(file),
        SchedulePdf(:final file) => await _scanPdf(file),
      };
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<String> _scanImage(XFile file) async {
    _applyEntries(const []);

    final input = InputImage.fromFilePath(file.path);
    final result = await _textRecognizer.processImage(input);
    return result.text;
  }

  Future<String> _scanPdf(XFile file) async {
    _applyEntries(const []);

    final bytes = await file.readAsBytes();
    // The extraction and the parse are the expensive part, so they run off
    // the UI thread; the grouping below is cheap and needs the viewmodel's
    // current sort, so it happens here.
    final result = await compute(_parsePdfInBackground, bytes);

    _applyEntries(result.entries);

    return result.text;
  }

  static List<ScheduleLine> _toScheduleLines(PdfTextExtractor extractor) {
    return [
      for (final line in extractor.extractTextLines())
        ScheduleLine(
          pageIndex: line.pageIndex,
          words: [
            for (final word in line.wordCollection)
              if (word.text.trim().isNotEmpty)
                ScheduleWord(
                  text: word.text.trim(),
                  left: word.bounds.left,
                  top: word.bounds.top,
                  right: word.bounds.right,
                  bottom: word.bounds.bottom,
                ),
          ],
        ),
    ];
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
  final document = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(document);

    final entries = ScheduleParser().parse(
      ScannerViewModel._toScheduleLines(extractor),
    );

    return _PdfScanResult(text: extractor.extractText(), entries: entries);
  } finally {
    document.dispose();
  }
}
