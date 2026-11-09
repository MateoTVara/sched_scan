/// The block a room belongs to, or null when the campus map does not know it.
///
/// Most rooms carry a `<letter>-<digits>` code in their name — `AULA A-203` →
/// `A`, `J-110A (…)` → `J`, `MÚLTIPLE C-202` → `C`. The code has to start a
/// word, so a hyphen inside one (`TALLER-2`) is not a block. Rooms without a
/// code are looked up by name: the sports facilities under `POLIDEPORTIVO`,
/// and the television/radio rooms and auditorium that share an academic
/// building.
String? blockOf(String room) {
  final code = _blockCode.firstMatch(room);
  if (code != null) return code.group(1);
  return _namedBlocks[_normalize(room)];
}

/// The `<letter>-<digits>` code printed at the start of a room name.
final RegExp _blockCode = RegExp(r'(?:^|\s)([A-Z])-\d');

/// Rooms without a code, keyed by [String] normalized name.
const Map<String, String> _namedBlocks = {
  // Sports facilities.
  'AULA DE ENSAYO 01': 'POLIDEPORTIVO',
  'AULA DE ENSAYO 02': 'POLIDEPORTIVO',
  'AULA DE ENSAYO 03': 'POLIDEPORTIVO',
  'CAMPO GRASS SINTETICO': 'POLIDEPORTIVO',
  'LOSA DEPORTIVA': 'POLIDEPORTIVO',
  'MATCH GYM': 'POLIDEPORTIVO',
  'MATCH TALLERES 1': 'POLIDEPORTIVO',
  'MATCH TALLERES 2': 'POLIDEPORTIVO',
  'MATCH TALLERES 3': 'POLIDEPORTIVO',
  'MATCH TALLERES 4': 'POLIDEPORTIVO',
  'TALLER DE TEATRO Y DANZA': 'POLIDEPORTIVO',
  // Block J.
  'ISLA DE EDICION DE TELEVISION': 'J',
  'SALA DE CONTROL DE TELEVISION': 'J',
  'SALA DE EDICION DE RADIO': 'J',
  // Block C.
  'SALA SUM': 'C',
  // Block E.
  'AUDITORIO PRINCIPAL': 'E',
};

/// Uppercase, single-spaced, accent-free form used for the name lookup, so a
/// PDF that prints `EDICIÓN` and one that prints `EDICION` both match.
String _normalize(String room) {
  final upper = room.toUpperCase();
  final withoutAccents = StringBuffer();
  for (final rune in upper.runes) {
    final char = String.fromCharCode(rune);
    withoutAccents.write(_accents[char] ?? char);
  }
  return withoutAccents.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Spanish vowels as the PDFs may print them.
const Map<String, String> _accents = {
  'Á': 'A',
  'É': 'E',
  'Í': 'I',
  'Ó': 'O',
  'Ú': 'U',
  'Ü': 'U',
};
