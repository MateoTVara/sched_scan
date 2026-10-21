import 'package:sched_scan/schedule/models/schedule_word.dart';

/// One horizontal run of text on one page of the schedule PDF.
///
/// The parser is handed these instead of a flat word soup because the PDF's
/// text layer groups words by font and baseline: `FISIOPATOLOGÍA Y` (cell at
/// x≈167) and `FISIOPATOLOGÍA Y SEMIOLOGÍA SEC:` (cell at x≈131) sit on
/// overlapping y-ranges but belong to two different table cells. Only the
/// PDF's own line grouping tells them apart — regrouping by y-overlap would
/// merge them.
class ScheduleLine {
  const ScheduleLine({required this.pageIndex, required this.words});

  /// 0-based page this line appears on.
  final int pageIndex;

  /// Words left to right, as the text layer emits them: possibly one
  /// fragment per character, with whitespace fragments between words.
  /// `ScheduleParser` stitches them back into whole words before it reads
  /// anything (see `ScheduleParser.stitchGap`).
  final List<ScheduleWord> words;

  /// Words joined with a single space; used to spot page chrome such as the
  /// `AULA / HORA` header row or the `N de M` page counter — on a stitched
  /// line only, since a raw fragment line reads `A U L A / H O R A`.
  String get text => words.map((w) => w.text).join(' ');
}
