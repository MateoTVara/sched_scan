import 'dart:math' as math;

import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';

/// Turns the geometric text of a `DISTRIBUCIÓN DE AMBIENTES` PDF into
/// structured [ScheduleEntry] records.
///
/// The PDF is a table: a narrow room column on the left, and for every room a
/// row of absolutely positioned cells further right. Reading order alone is
/// useless — a room label and the first cell of its row land on the same text
/// line — so every decision is made from geometry:
///
/// 1. page chrome is dropped (title, URL footer, `N de M` counter,
///    `AULA / HORA` header row, `Buscar...`),
/// 2. the room column ends where the first time anchor starts (x ≈ 79.9pt on
///    every page of the sample). No word straddles that line, so words on the
///    left are room labels and words on the right are cell content,
/// 3. label words are stacked into visual lines, then into rooms: two label
///    lines belong to the same room when they sit at most
///    [_roomLineGap] apart *or* the room name so far has an unclosed `(`.
///    The paren rule exists because labels wrap with varying line heights
///    (a 4.7pt gap can still be inside one name) and page breaks cut names in
///    half,
/// 4. each room owns the horizontal band from its top down to the next room's
///    top on the same page; every cell line is assigned to the band that
///    contains its y,
/// 5. inside a band, cell lines are grouped by centre-x within
///    [_cellCenterTolerance] — lines of one cell are centre-aligned to well
///    under a point while neighbouring cells are tens of points apart,
/// 6. each group of lines is read into one [ScheduleEntry].
class ScheduleParser {
  /// Two label lines belong to the same room when the gap between them is at
  /// most this many points.
  ///
  /// Measured on the sample PDF: label lines inside one room are 0.5–1.0pt
  /// apart and a new room starts 1.5pt or more below the previous one, with
  /// nothing in between. Larger gaps are settled by the unclosed-paren rule.
  static const double roomLineGap = 1.0;

  /// Horizontal tolerance for grouping a row's cell lines into one cell.
  ///
  /// Every line of a cell is centre-aligned to well under a point; the
  /// closest two cells ever get is far above this.
  static const double cellCenterTolerance = 2.0;

  /// A cell's first line is printed on exactly the same baseline as its room
  /// label, and the two coordinates only differ by float noise (2.5e-7 on the
  /// sample), so a line this close to a band's top is allowed to claim that
  /// band instead of the one above.
  ///
  /// Measured on the sample: the closest a line that *belongs* to a band ever
  /// gets to the next band's top is 3pt, and the smallest genuine offset
  /// inside a band is 0.1pt — so 1pt sits comfortably between the two.
  static const double bandTolerance = 1.0;

  /// Boilerplate that must never be read as a room label or a cell.
  static final RegExp _pageCounter = RegExp(r'^\d+ de \d+');
  static final RegExp _timeAnchor = RegExp(r'^\d{1,2}:\d{2}$');

  /// Cell vocabulary.
  static final RegExp _status = RegExp(r'^(LIBRE|RESERVA[A-Z ]*)$');
  static final RegExp _timeRange = RegExp(
    r'^De:\s*(\d{1,2}:\d{2})(?:\s+a\s+(\d{1,2}:\d{2}))?$',
  );
  static final RegExp _timeContinuation = RegExp(r'^a\s+(\d{1,2}:\d{2})$');
  static final RegExp _cycle = RegExp(r'^CICLO:\s*(\d+)$');
  static final RegExp _bareSection = RegExp(r'^\d+$');
  static final RegExp _note = RegExp(
    r'^(Recuperación.*|Fecha de referencia:.*)$',
  );
  static final RegExp _emptyPlaceholder = RegExp(r'^\(\s*-\s*\)$');

  /// Reads every entry of the document, in table order.
  List<ScheduleEntry> parse(List<ScheduleLine> lines) {
    final pages = <int, List<ScheduleLine>>{};
    for (final line in lines) {
      if (line.words.isEmpty) continue;
      pages.putIfAbsent(line.pageIndex, () => []).add(line);
    }

    final order = pages.keys.toList()..sort();
    final bandsByPage = <int, List<_Band>>{};
    final cellsByPage = <int, List<_CellLine>>{};

    for (final page in order) {
      final pageLines = pages[page]!;
      // Read from the page chrome before dropping it: the room column's edge
      // is defined by the time anchors in the `AULA / HORA` header row.
      final boundary = _roomBoundary(pageLines);
      if (boundary == null) continue;

      final labelWords = <ScheduleWord>[];
      final cellLines = <_CellLine>[];
      for (final line in pageLines) {
        if (_isChrome(line)) continue;
        final labels = <ScheduleWord>[];
        final cells = <ScheduleWord>[];
        for (final word in line.words) {
          if (word.left < boundary) {
            labels.add(word);
          } else {
            cells.add(word);
          }
        }
        labelWords.addAll(labels);
        if (cells.isNotEmpty) {
          cellLines.add(_CellLine(pageIndex: page, words: cells));
        }
      }

      final rooms = _roomBlocks(labelWords);
      if (rooms.isEmpty) continue;

      bandsByPage[page] = [
        for (var i = 0; i < rooms.length; i++)
          _Band(pageIndex: page, top: rooms[i].top, label: rooms[i].text),
      ];
      cellsByPage[page] = cellLines;
    }

    final bands = <_Band>[for (final page in order) ...?bandsByPage[page]];
    _continueNamesAcrossPages(bands);

    // Cells are read only once every page knows its bands, because a cell can
    // straddle a page break: the course and programme sit at the bottom of one
    // page while the docente and time range continue in the same column at the
    // top of the next, above that page's first room label.
    for (var i = 0; i < order.length; i++) {
      final page = order[i];
      final pageBands = bandsByPage[page];
      final pageCells = cellsByPage[page];
      if (pageBands == null || pageBands.isEmpty || pageCells == null) continue;

      List<_Band>? previous;
      for (var j = i - 1; j >= 0; j--) {
        final earlier = bandsByPage[order[j]];
        if (earlier != null && earlier.isNotEmpty) {
          previous = earlier;
          break;
        }
      }

      final firstTop = pageBands.first.top;
      for (final cell in pageCells) {
        if (cell.top < firstTop - bandTolerance &&
            previous != null &&
            previous.isNotEmpty) {
          previous.last.cells.add(cell);
        } else {
          _bandFor(pageBands, cell.top).cells.add(cell);
        }
      }
    }

    return [for (final band in bands) ..._entriesOf(band)];
  }

  // ---------------------------------------------------------------- chrome

  static bool _isChrome(ScheduleLine line) {
    final text = line.text;
    if (text.isEmpty) return true;
    // The running title and the `N de M HH:MM` counter are printed against
    // the very edge of the sheet; nothing inside the table starts there.
    if (line.words.map((w) => w.left).reduce(math.min) < 10) return true;
    if (text.startsWith('AULA / HORA')) return true;
    if (text.startsWith('Buscar')) return true;
    if (text.startsWith('DISTRIBUCIÓN DE AMBIENTES')) return true;
    return _pageCounter.hasMatch(text);
  }

  /// x of the first time anchor in the `AULA / HORA` header row — the left
  /// edge of the table's time area, and therefore the right edge of the room
  /// column. Identical (79.9) on every page of the sample.
  static double? _roomBoundary(List<ScheduleLine> lines) {
    for (final line in lines) {
      if (!line.text.startsWith('AULA / HORA')) continue;
      for (final word in line.words) {
        if (_timeAnchor.hasMatch(word.text)) return word.left;
      }
    }
    return null;
  }

  // ----------------------------------------------------------- room labels

  static List<_RoomBlock> _roomBlocks(List<ScheduleWord> words) {
    final lines = _visualLines(words);
    final blocks = <_RoomBlock>[];
    for (final line in lines) {
      final current = blocks.isEmpty ? null : blocks.last;
      if (current != null &&
          (line.top - current.bottom <= roomLineGap || current.isOpen)) {
        current.absorb(line);
      } else {
        blocks.add(_RoomBlock(line));
      }
    }
    return blocks;
  }

  /// Stacks words into rows of text: a word continues the current row while
  /// its top still overlaps that row's bottom.
  static List<_LabelLine> _visualLines(List<ScheduleWord> words) {
    final sorted = [...words]
      ..sort((a, b) {
        final byTop = a.top.compareTo(b.top);
        return byTop != 0 ? byTop : a.left.compareTo(b.left);
      });

    final rows = <_LabelLine>[];
    for (final word in sorted) {
      if (rows.isNotEmpty && word.top < rows.last.bottom) {
        rows.last.add(word);
      } else {
        rows.add(_LabelLine()..add(word));
      }
    }
    return rows;
  }

  /// Glues a room name that a page break cut in half: when a name still has an
  /// unclosed `(` it continues as the first name of the next page. Only across
  /// a break — a label line can never be left open on its own page, because
  /// `_roomBlocks` keeps absorbing until the paren closes.
  static void _continueNamesAcrossPages(List<_Band> bands) {
    for (var i = 0; i + 1 < bands.length; i++) {
      if (bands[i + 1].pageIndex <= bands[i].pageIndex) continue;
      if (!_isOpen(bands[i].label)) continue;
      final merged = '${bands[i].label} ${bands[i + 1].label}';
      bands[i].label = merged;
      bands[i + 1].label = merged;
    }
  }

  // ------------------------------------------------------------------ cells

  /// The band whose top is the closest one at or just above [y] — with a
  /// tolerance, because a cell's first line and its room label share a
  /// baseline; the page's first band catches anything printed above its own
  /// label.
  static _Band _bandFor(List<_Band> bands, double y) {
    for (var i = bands.length - 1; i >= 0; i--) {
      if (bands[i].top <= y + bandTolerance) return bands[i];
    }
    return bands.first;
  }

  static List<ScheduleEntry> _entriesOf(_Band band) {
    if (band.cells.isEmpty) return const [];

    // Centres are compared across pages: a continuation cell keeps the column
    // it started in, and its lines are then ordered by page before y — the two
    // pages' coordinates are not comparable.
    final byCenter = [...band.cells]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));
    final cells = <List<_CellLine>>[];
    for (final line in byCenter) {
      final current = cells.isEmpty ? null : cells.last;
      if (current != null &&
          line.centerX - current.last.centerX <= cellCenterTolerance) {
        current.add(line);
      } else {
        cells.add([line]);
      }
    }

    final entries = <ScheduleEntry>[];
    for (final cell in cells) {
      cell.sort((a, b) {
        if (a.pageIndex != b.pageIndex) {
          return a.pageIndex.compareTo(b.pageIndex);
        }
        return a.top.compareTo(b.top);
      });
      final entry = _readCell(
        room: band.label,
        pageIndex: band.pageIndex,
        lines: [for (final line in cell) line.text],
      );
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  /// Reads one cell — a stack of short, centre-aligned lines — into an entry.
  static ScheduleEntry? _readCell({
    required String room,
    required int pageIndex,
    required List<String> lines,
  }) {
    final text = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (text.isEmpty) return null;

    var index = 0;
    String? status;
    if (_status.hasMatch(text.first)) {
      status = text.first;
      index = 1;
    }

    // The course title runs over several lines and ends with `SEC: n`; the
    // section itself occasionally wraps onto a line of its own.
    String? course;
    String? section;
    var secAt = -1;
    for (var i = index; i < text.length; i++) {
      if (text[i].contains('SEC:')) {
        secAt = i;
        break;
      }
    }
    if (secAt >= 0) {
      final title = <String>[for (var i = index; i < secAt; i++) text[i]];
      final cut = text[secAt].indexOf('SEC:');
      final head = text[secAt].substring(0, cut).trim();
      if (head.isNotEmpty) title.add(head);
      if (title.isNotEmpty) course = title.join(' ');

      final tail = text[secAt].substring(cut + 4).trim();
      if (tail.isNotEmpty) {
        section = tail;
        index = secAt + 1;
      } else if (secAt + 1 < text.length &&
          _bareSection.hasMatch(text[secAt + 1])) {
        section = text[secAt + 1];
        index = secAt + 2;
      } else {
        index = secAt + 1;
      }
    }

    String? start;
    String? end;
    String? cycle;
    String? program;
    String? person;
    final notes = <String>[];
    final remainder = <String>[];
    final afterProgram = <String>[];
    final programLines = <String>[];
    var inProgram = false;
    // Set once the programme block starts, so that lines can be told apart by
    // which side of it they sit on: the event title comes first, the docente
    // last.
    var programStarted = false;
    // Set when the cell's title slot holds the PDF's `(-)` placeholder, i.e.
    // when the cell has no course at all and what follows is the docente.
    var sawPlaceholder = false;

    for (var i = index; i < text.length; i++) {
      final line = text[i];

      final time = _timeRange.firstMatch(line);
      if (time != null) {
        inProgram = false;
        start = time.group(1);
        end = time.group(2);
        // A narrow cell wraps `De: 07:00 a 07:15` onto two lines.
        if (end == null && i + 1 < text.length) {
          final continuation = _timeContinuation.firstMatch(text[i + 1]);
          if (continuation != null) {
            end = continuation.group(1);
            i++;
          }
        }
        continue;
      }

      final ciclo = _cycle.firstMatch(line);
      if (ciclo != null) {
        inProgram = false;
        cycle = ciclo.group(1);
        continue;
      }

      if (_note.hasMatch(line)) {
        inProgram = false;
        notes.add(line);
        continue;
      }

      // `(-)` is the placeholder the PDF prints for "nothing here".
      if (_emptyPlaceholder.hasMatch(line)) {
        sawPlaceholder = true;
        continue;
      }

      if (line.startsWith('(') || inProgram) {
        programStarted = true;
        programLines.add(line);
        program = programLines.join(' ');
        inProgram = !_isBalanced(program);
        continue;
      }

      remainder.add(line);
      if (programStarted) afterProgram.add(line);
    }

    if (remainder.isNotEmpty) {
      final reserving = status != null && status.startsWith('RESERVA');
      if (course == null && !reserving) {
        final docente = afterProgram.join(' ');
        if (docente.isNotEmpty) {
          // The programme block separates an event's title from its docente.
          person = docente;
          final head = remainder.sublist(
            0,
            remainder.length - afterProgram.length,
          );
          if (head.isNotEmpty) course = head.join(' ');
        } else if (sawPlaceholder) {
          // The title slot held `(-)`, so only the docente can follow it.
          person = remainder.join(' ');
        } else if (remainder.length > 1) {
          // No programme to separate them: the last line is the docente.
          person = remainder.removeLast();
          course = remainder.join(' ');
        } else {
          course = remainder.single;
        }
      } else {
        person = remainder.join(' ');
      }
    }

    if (status == null &&
        course == null &&
        person == null &&
        program == null &&
        notes.isEmpty) {
      return null;
    }

    return ScheduleEntry(
      room: room,
      pageIndex: pageIndex,
      status: status,
      start: start,
      end: end,
      course: course,
      section: section,
      cycle: cycle,
      program: program,
      person: person,
      notes: notes,
    );
  }
}

bool _isBalanced(String text) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')') depth--;
  }
  return depth == 0;
}

/// A name still waiting for its closing paren, i.e. one that continues on the
/// next line — or on the next page.
bool _isOpen(String text) => text.contains('(') && !_isBalanced(text);

// --------------------------------------------------------------------- types

class _LabelLine {
  double top = 0;
  double bottom = 0;
  final words = <ScheduleWord>[];
  var _empty = true;

  void add(ScheduleWord word) {
    if (_empty) {
      _empty = false;
      top = word.top;
      bottom = word.bottom;
    } else {
      top = math.min(top, word.top);
      bottom = math.max(bottom, word.bottom);
    }
    words.add(word);
  }

  String get text {
    final sorted = [...words]..sort((a, b) => a.left.compareTo(b.left));
    return sorted.map((w) => w.text).join(' ');
  }
}

class _RoomBlock {
  _RoomBlock(_LabelLine line) : top = line.top {
    absorb(line);
  }

  final double top;
  final lines = <String>[];
  double _bottom = 0;

  double get bottom => _bottom;

  void absorb(_LabelLine line) {
    lines.add(line.text);
    _bottom = math.max(_bottom, line.bottom);
  }

  String get text => lines.join(' ');
  bool get isOpen => _isOpen(text);
}

class _CellLine {
  _CellLine({required this.pageIndex, required List<ScheduleWord> words})
    : words = [...words]..sort((a, b) => a.left.compareTo(b.left));

  /// Page the lines were printed on. A cell that straddles a page break holds
  /// lines from two pages, and their y coordinates are not comparable across
  /// pages, so ordering has to be by page first.
  final int pageIndex;
  final List<ScheduleWord> words;

  late final double top = words.map((w) => w.top).reduce(math.min);

  late final double centerX = (() {
    final left = words.map((w) => w.left).reduce(math.min);
    final right = words.map((w) => w.right).reduce(math.max);
    return (left + right) / 2;
  })();

  String get text => words.map((w) => w.text).join(' ');
}

class _Band {
  _Band({required this.pageIndex, required this.top, required this.label});

  final int pageIndex;
  final double top;
  String label;
  final cells = <_CellLine>[];
}
