// import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/scanner/models/section_filter.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';
import 'package:sched_scan/schedule/schedule_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ScannerViewModel extends ChangeNotifier {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  // final _parser = ScheduleParser();

  String? _recognizedText;
  String? get recognizedText => _recognizedText;

  /// Every parsed PDF entry in table order, free slots included; empty for
  /// image scans and for PDFs whose text could not be split into rows (the
  /// raw text then stands in). This, not the section lists, is the signal
  /// that the parse worked: a document whose slots are all free still counts.
  List<ScheduleEntry> _entries = const [];
  List<ScheduleEntry> get entries => _entries;

  /// The booked slots grouped by block — `Bloque A` … `Bloque K`, alphabetical
  /// and only the blocks that actually occur — each holding a section per room
  /// in table order, cards sorted by start time. [ScheduleEntry.isFree] slots
  /// are dropped, and so is any room left with nothing but free ones. Rooms
  /// with no block letter keep their own single section after the blocks.
  List<EntrySection> _sectionsByBlock = const [];
  List<EntrySection> get sectionsByBlock => _sectionsByBlock;

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
  /// ones once a chip has been picked.
  List<EntrySection> get visibleSectionsByBlock => _selectedSections.isEmpty
      ? const []
      : [
          for (final section in _sectionsByBlock)
            if (_selectedSections.contains(section.title)) section,
        ];

  /// Adds [title] to the selection or takes it out again — deselecting the
  /// last one empties the selection, which brings the prompt back in place
  /// of the cards.
  void toggleSection(String title) {
    if (!_selectedSections.remove(title)) {
      _selectedSections.add(title);
    }
    notifyListeners();
  }

  /// Replaces the sections and empties the selection: a new scan starts
  /// over with no pick, so the prompt shows until a chip is chosen.
  void _setSections(List<EntrySection> sections) {
    _sectionsByBlock = sections;
    _selectedSections = {};
  }

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
    _entries = const [];
    _setSections(const []);

    final input = InputImage.fromFilePath(file.path);
    final result = await _textRecognizer.processImage(input);
    return result.text;
  }

  Future<String> _scanPdf(XFile file) async {
    _entries = const [];
    _setSections(const []);

    final bytes = await file.readAsBytes();
    final result = await compute(_parsePdfInBackground, bytes);

    _entries = result.entries;
    _setSections(result.sections);

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

  /// Blocks first, alphabetical and only the ones that occur, each holding its
  /// rooms in table order; then the rooms with no block letter, each keeping
  /// its own single heading.
  static List<EntrySection> _byBlock(List<ScheduleEntry> booked) {
    final blocks = <String, Map<String, List<ScheduleEntry>>>{};
    final loose = <String, List<ScheduleEntry>>{};
    for (final entry in booked) {
      final block = _blockOf(entry.room);
      if (block == null) {
        loose.putIfAbsent(entry.room, () => []).add(entry);
      } else {
        (blocks[block] ??= {}).putIfAbsent(entry.room, () => []).add(entry);
      }
    }
    for (final rooms in blocks.values) {
      for (final slots in rooms.values) {
        _sortByStart(slots);
      }
    }
    for (final slots in loose.values) {
      _sortByStart(slots);
    }

    final present = blocks.keys.toList()..sort();
    return [
      for (final block in present)
        EntrySection('Bloque $block', rooms: blocks[block]!),
      for (final room in loose.entries)
        EntrySection(room.key, entries: room.value),
    ];
  }

  /// Puts one room's slots in start-time order, entries without a printed time
  /// last. `HH:MM` compares correctly as a string.
  static void _sortByStart(List<ScheduleEntry> slots) {
    slots.sort((a, b) {
      final start = a.start;
      final otherStart = b.start;
      if (start == null && otherStart == null) return 0;
      if (start == null) return 1;
      if (otherStart == null) return -1;
      return start.compareTo(otherStart);
    });
  }
}

class _PdfScanResult {
  const _PdfScanResult({
    required this.text,
    required this.entries,
    required this.sections,
  });

  final String text;
  final List<ScheduleEntry> entries;
  final List<EntrySection> sections;
}

_PdfScanResult _parsePdfInBackground(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(document);

    final entries = ScheduleParser().parse(
      ScannerViewModel._toScheduleLines(extractor),
    );

    final sections = entries.isEmpty
        ? const <EntrySection>[]
        : ScannerViewModel._byBlock([
            for (final entry in entries)
              if (!entry.isFree) entry,
          ]);

    return _PdfScanResult(
      text: extractor.extractText(),
      entries: entries,
      sections: sections,
    );
  } finally {
    document.dispose();
  }
}
