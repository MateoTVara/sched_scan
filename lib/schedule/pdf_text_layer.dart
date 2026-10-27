/// The PDF text layer, read with `pdf_graphics` (pure Dart, works on every
/// platform including the web build).
///
/// This is the seam [ScannerViewModel] scans through: [readPdfTextLayer]
/// hands `ScheduleParser` its word-level input alongside the raw text the
/// fallback message checks, in one walk of the document. Everything here
/// runs inside the `compute` isolate — `PdfDocument.open` is synchronous,
/// allocation-free from the caller's side, and needs no disposal (the
/// document lives and dies with the isolate).
library;

import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';

/// Runs whose baseline (page-space y of the em origin, y-up) differ by at
/// most this many points continue the current printed line.
///
/// Lines are broken **in draw order**: a line ends the moment its baseline
/// moves, the rule the parser's tolerances were calibrated against (the
/// syncfusion extractor this replaced did the same — an integer y change
/// while walking glyphs in rendering order). The parser leans on the text
/// layer's own line grouping to tell table cells apart, and clustering by y
/// across the whole page would instead merge cells that share a baseline but
/// sit in different table columns. Adjacent table rows sit 2.5pt+ apart, so
/// the gap between two printed lines never fits inside this tolerance.
const double _lineEps = 0.5;

/// Gap above which two words on one line get a whitespace fragment between
/// them.
///
/// Fragments of a single word never sit more than
/// `ScheduleParser.stitchGap / 2` apart; two real words never come closer
/// than 0.75pt (measured across the fixtures — see
/// `ScheduleParser.stitchGap`), so anything above this is a word boundary
/// the parser must not stitch across.
const double _wordGap = 0.25;

class _Run {
  _Run(
    this.text,
    this.transform,
    this.ascent,
    this.descent,
    this.width,
    this.charOffsets,
  );

  final String text;
  final PdfMatrix transform;
  final double ascent;
  final double descent;
  final double width;
  final List<double>? charOffsets;

  /// Em offset of character boundary [index], falling back to an even split
  /// across [width] when the run carried no metrics.
  double emX(int index) {
    final offsets = charOffsets;
    if (offsets != null) return offsets[index];
    return width * index / text.length;
  }
}

class _Line {
  _Line(this.baseline);

  final double baseline;
  final List<_Run> runs = [];
}

/// The document's text layer in one walk: [PdfTextLayer.lines] holds one
/// [ScheduleLine] per printed line of every page (words left to right with
/// whitespace fragments between them — the parser stitches them back, see
/// `ScheduleParser.stitchGap` — in content order) and [PdfTextLayer.text]
/// the raw text, every page joined with newlines.
PdfTextLayer readPdfTextLayer(Uint8List bytes) {
  final document = PdfDocument.open(bytes);
  final lines = <ScheduleLine>[];
  final text = StringBuffer();
  for (var pageIndex = 0; pageIndex < document.pageCount; pageIndex++) {
    if (pageIndex > 0) text.write('\n');
    final pageText = PdfTextExtractor.extract(document, pageIndex);
    text.write(pageText.text);
    final pageHeight = document.page(pageIndex).mediaBox.top;

    _Line? current;
    for (final run in pageText.runs) {
      if (run.text.isEmpty) continue;
      final baseline = run.transform.transformY(0, 0);
      if (current == null || (current.baseline - baseline).abs() > _lineEps) {
        if (current != null) {
          lines.add(_lineOf(current, pageHeight, pageIndex));
        }
        current = _Line(baseline);
      }
      current.runs.add(
        _Run(
          run.text,
          run.transform,
          run.ascent,
          run.descent,
          run.width,
          run.charOffsets,
        ),
      );
    }
    if (current != null) {
      lines.add(_lineOf(current, pageHeight, pageIndex));
    }
  }
  return PdfTextLayer(lines: lines, text: text.toString());
}

/// What one walk of the document hands back: the parser's word-level input
/// and the raw text layer, both read off the same page runs.
class PdfTextLayer {
  const PdfTextLayer({required this.lines, required this.text});

  final List<ScheduleLine> lines;
  final String text;
}

/// One printed line: every run split at spaces, segments walked left to
/// right, and a whitespace fragment inserted wherever two words sit more than
/// [_wordGap] apart — including across runs (a `Tm` jump prints no space
/// glyph, only a gap) and across cells of the same row.
ScheduleLine _lineOf(_Line cluster, double pageHeight, int pageIndex) {
  final segments = <_Segment>[];
  for (final run in cluster.runs) {
    var start = 0;
    for (var i = 0; i <= run.text.length; i++) {
      final atEnd = i == run.text.length;
      if (atEnd || run.text[i] == ' ') {
        if (i > start) {
          segments.add(_Segment(run: run, from: start, to: i, isSpace: false));
        }
        if (!atEnd) {
          segments.add(_Segment(run: run, from: i, to: i + 1, isSpace: true));
        }
        start = i + 1;
      }
    }
  }

  // Page-space box of every segment, then left to right.
  final boxed = <(_Segment, ScheduleWord)>[
    for (final segment in segments) (segment, _wordOf(segment, pageHeight)),
  ]..sort((a, b) => a.$2.left.compareTo(b.$2.left));

  final words = <ScheduleWord>[];
  for (var i = 0; i < boxed.length; i++) {
    final word = boxed[i].$2;
    final previous = words.isNotEmpty ? words.last : null;
    if (previous != null &&
        !boxed[i].$1.isSpace &&
        word.left - previous.right > _wordGap) {
      // A gap no space glyph covers: synthesise the fragment, or the parser
      // would stitch two words into one.
      words.add(
        ScheduleWord(
          text: '',
          left: previous.right,
          top: word.top,
          right: word.left,
          bottom: word.bottom,
        ),
      );
    }
    words.add(word);
  }
  return ScheduleLine(pageIndex: pageIndex, words: words);
}

class _Segment {
  _Segment({
    required this.run,
    required this.from,
    required this.to,
    required this.isSpace,
  });

  final _Run run;
  final int from;
  final int to;
  final bool isSpace;
}

/// The segment's box in y-down page coordinates: the four corners of
/// `[emX(from)..emX(to)] × [descent..ascent]` through the run's transform —
/// the same construction `pdf_graphics` uses for `PdfExtractedRun.bounds` —
/// flipped from PDF user space (bottom-left, y-up) to the top-left y-down
/// space [ScheduleWord] lives in.
ScheduleWord _wordOf(_Segment segment, double pageHeight) {
  final run = segment.run;
  final x0 = run.emX(segment.from);
  final x1 = run.emX(segment.to);
  final transform = run.transform;

  var left = double.infinity;
  var right = double.negativeInfinity;
  var topUp = double.negativeInfinity;
  var bottomUp = double.infinity;
  for (final (x, y) in [
    (x0, run.descent),
    (x1, run.descent),
    (x1, run.ascent),
    (x0, run.ascent),
  ]) {
    final px = transform.transformX(x, y);
    final py = transform.transformY(x, y);
    if (px < left) left = px;
    if (px > right) right = px;
    if (py > topUp) topUp = py;
    if (py < bottomUp) bottomUp = py;
  }

  return ScheduleWord(
    text: run.text.substring(segment.from, segment.to).trim(),
    left: left,
    top: pageHeight - topUp,
    right: right,
    bottom: pageHeight - bottomUp,
  );
}
