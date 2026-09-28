/// A single word with its position on a page of the schedule PDF.
///
/// Coordinates are PDF points, y growing downwards, on a 612x792 page.
///
/// The parser works on words rather than flat text because the PDF merges a
/// whole table row into one line (e.g. `AULA DE ENSAYO 01 LIBRE`), so reading
/// order alone cannot tell a room label from a cell.
class ScheduleWord {
  const ScheduleWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}
