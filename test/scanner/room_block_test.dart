import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/room_block.dart';

void main() {
  group('blockOf', () {
    test('reads the code printed in the room name', () {
      expect(blockOf('AULA A-203'), 'A');
      expect(blockOf('J-110A (LABORATORIO DE CÓMPUTO)'), 'J');
      expect(blockOf('MÚLTIPLE C-202'), 'C');
    });

    test('a hyphen inside a word is not a block code', () {
      expect(blockOf('TALLER-2'), isNull);
      expect(blockOf('sin código de aula'), isNull);
    });

    test('maps the named rooms of every block', () {
      const expected = <String, String>{
        // POLIDEPORTIVO.
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
        // J.
        'ISLA DE EDICION DE TELEVISIÓN': 'J',
        'SALA DE CONTROL DE TELEVISIÓN': 'J',
        'SALA DE EDICION DE RADIO': 'J',
        // C.
        'SALA SUM': 'C',
        // E.
        'AUDITORIO PRINCIPAL': 'E',
      };

      for (final MapEntry(key: room, value: block) in expected.entries) {
        expect(blockOf(room), block, reason: room);
      }
    });

    test('matches case, spacing and accents', () {
      expect(blockOf('  losa   deportiva '), 'POLIDEPORTIVO');
      expect(blockOf('CAMPO GRASS SINTÉTICO'), 'POLIDEPORTIVO');
      expect(blockOf('SALA DE EDICIÓN DE RADIO'), 'J');
    });

    test('leaves a room the campus map does not know unassigned', () {
      expect(blockOf('SALA DE USOS MÚLTIPLES'), isNull);
      expect(blockOf('ESTUDIO 1'), isNull);
    });
  });
}
