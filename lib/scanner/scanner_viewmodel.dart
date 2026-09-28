import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';
import 'package:sched_scan/schedule/schedule_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ScannerViewModel extends ChangeNotifier {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _parser = ScheduleParser();

  String? _recognizedText;
  String? get recognizedText => _recognizedText;

  /// Every parsed PDF entry in table order, free slots included; empty for
  /// image scans and for PDFs whose text could not be split into rows (the
  /// raw text then stands in). This, not [entriesByRoom], is the signal that
  /// the parse worked: a document whose slots are all free still counts.
  List<ScheduleEntry> _entries = const [];
  List<ScheduleEntry> get entries => _entries;

  /// The booked slots grouped by room — [ScheduleEntry.isFree] slots are
  /// dropped, and so is any room left with nothing but free ones. Sections
  /// keep table order, entries inside a section are sorted by start time.
  Map<String, List<ScheduleEntry>> _entriesByRoom = const {};
  Map<String, List<ScheduleEntry>> get entriesByRoom => _entriesByRoom;

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
    _entriesByRoom = const {};

    final input = InputImage.fromFilePath(file.path);
    final result = await _textRecognizer.processImage(input);
    return result.text;
  }

  Future<String> _scanPdf(XFile file) async {
    _entries = const [];
    _entriesByRoom = const {};

    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final entries = _parser.parse(_toScheduleLines(extractor));
      if (entries.isNotEmpty) {
        _entries = entries;
        _entriesByRoom = _groupByRoom(entries);
      }
      return extractor.extractText();
    } finally {
      document.dispose();
    }
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

  /// Groups the slots worth showing: free rooms are dropped outright, and a
  /// room whose slots are all free disappears from the map. Table order is
  /// kept because a plain `Map` preserves insertion order.
  static Map<String, List<ScheduleEntry>> _groupByRoom(
    List<ScheduleEntry> entries,
  ) {
    final grouped = <String, List<ScheduleEntry>>{};
    for (final entry in entries) {
      if (entry.isFree) continue;
      grouped.putIfAbsent(entry.room, () => []).add(entry);
    }
    for (final section in grouped.values) {
      section.sort((a, b) {
        final start = a.start;
        final otherStart = b.start;
        if (start == null && otherStart == null) return 0;
        if (start == null) return 1;
        if (otherStart == null) return -1;
        return start.compareTo(otherStart);
      });
    }
    return grouped;
  }
}
