import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';

void main() {
  test('the mark cycle walks none → include → exclude → none', () {
    expect(TypeMark.none.next, TypeMark.include);
    expect(TypeMark.include.next, TypeMark.exclude);
    expect(TypeMark.exclude.next, TypeMark.none);
  });

  test('a mark keeps, drops or ignores what its row matches', () {
    expect(passesMark(TypeMark.none, true), isTrue);
    expect(passesMark(TypeMark.none, false), isTrue);
    expect(passesMark(TypeMark.include, true), isTrue);
    expect(passesMark(TypeMark.include, false), isFalse);
    expect(passesMark(TypeMark.exclude, true), isFalse);
    expect(passesMark(TypeMark.exclude, false), isTrue);
  });

  test('the defaults: labs in, free out, window in — and the labels', () {
    expect(defaultFilterMarks, {
      FilterRow.computeLab: TypeMark.include,
      FilterRow.libres: TypeMark.exclude,
      FilterRow.last15: TypeMark.include,
    });
    expect(
      [for (final row in FilterRow.values) row.label],
      ['Laboratorio de Cómputo', 'Libres', 'Últimos 15 min', 'Ahora'],
    );
    // The now row is opt-in: untouched means absent from the marks.
    expect(defaultFilterMarks[FilterRow.now], isNull);
  });

  group('isComputeLab', () {
    test('every room of block B and the listed C and J rooms count', () {
      expect(isComputeLab('B-101 (LABORATORIO DE CÓMPUTO)'), isTrue);
      expect(isComputeLab('B-101'), isTrue);
      expect(isComputeLab('B-301'), isTrue);
      expect(isComputeLab('C-203'), isTrue);
      expect(isComputeLab('C-204'), isTrue);
      expect(isComputeLab('C-303'), isTrue);
      expect(isComputeLab('C-304'), isTrue);
      expect(isComputeLab('J-108'), isTrue);
      expect(isComputeLab('J-205'), isTrue);
      expect(isComputeLab('J-206'), isTrue);
      expect(isComputeLab('J-210 (LABORATORIO DE CÓMPUTO)'), isTrue);
      expect(isComputeLab('J-215'), isTrue);
    });

    test('nothing else does — the block and the number both count', () {
      expect(isComputeLab('AULA A-102'), isFalse);
      expect(isComputeLab('AULA DE ENSAYO 01'), isFalse);
      expect(isComputeLab('MÚLTIPLE C-202'), isFalse);
      expect(isComputeLab('C-201'), isFalse);
      expect(
        isComputeLab('J-101 (LABORATORIO PLANTA DE TRATAMIENTO Y ENVASADO)'),
        isFalse,
      );
      expect(isComputeLab('J-107 (ESTUDIO DE TELEVISIÓN)'), isFalse);
      expect(isComputeLab('J-109 (ESTUDIO FOTOGRÁFICO)'), isFalse);
      expect(isComputeLab('J-201 (HUB DE INNOVACIÓN SOCIAL)'), isFalse);
      expect(isComputeLab('J-216'), isFalse);
      expect(isComputeLab('SALA DE USOS MÚLTIPLES'), isFalse);
      expect(isComputeLab('LOSA DEPORTIVA'), isFalse);
      expect(isComputeLab('ESTUDIO 1'), isFalse);
      expect(isComputeLab('sin código de aula'), isFalse);
    });
  });

  group('isStale', () {
    final now = DateTime(2026, 1, 1, 10, 5);

    test('more than fifteen minutes ago is stale, the rest is not', () {
      expect(isStale('09:30', now), isTrue); // 35 minutes ago
      expect(isStale('09:49', now), isTrue); // 16 — a minute too old
      expect(isStale('09:50', now), isFalse); // exactly fifteen — still in
      expect(isStale('10:00', now), isFalse); // five minutes ago
      expect(isStale('10:05', now), isFalse); // just started
      expect(isStale('20:00', now), isFalse); // yet to come
    });

    test('no start time, or no parseable one, never ages', () {
      expect(isStale(null, now), isFalse);
      expect(isStale('—', now), isFalse);
      expect(isStale('Recuperación', now), isFalse);
    });
  });

  group('isOngoing', () {
    final now = DateTime(2026, 1, 1, 10, 5);

    test('a printed range covers the clock from its start to its end', () {
      expect(isOngoing('09:30', '11:30', now), isTrue); // mid-session
      expect(isOngoing('10:05', '12:00', now), isTrue); // just started
      expect(isOngoing('08:00', '10:05', now), isTrue); // through the end
      expect(isOngoing('10:06', '12:00', now), isFalse); // yet to come
      expect(isOngoing('08:00', '10:04', now), isFalse); // already over
    });

    test('with no printed end the session runs from its start on', () {
      expect(isOngoing('09:30', null, now), isTrue);
      expect(isOngoing('10:05', null, now), isTrue);
      expect(isOngoing('10:06', null, now), isFalse);
      // An unparseable end is no end either.
      expect(isOngoing('09:30', '—', now), isTrue);
    });

    test('no start time, or no parseable one, is never underway', () {
      expect(isOngoing(null, '12:00', now), isFalse);
      expect(isOngoing(null, null, now), isFalse);
      expect(isOngoing('—', '12:00', now), isFalse);
      expect(isOngoing('Recuperación', null, now), isFalse);
    });

    test('a range closing before it opens runs over midnight', () {
      final late = DateTime(2026, 1, 1, 23);
      final small = DateTime(2026, 1, 1, 5);
      final morning = DateTime(2026, 1, 1, 7);
      final evening = DateTime(2026, 1, 1, 21);

      expect(isOngoing('22:00', '06:00', late), isTrue);
      expect(isOngoing('22:00', '06:00', small), isTrue); // past midnight
      expect(isOngoing('22:00', '06:00', morning), isFalse); // closed
      expect(isOngoing('22:00', '06:00', evening), isFalse); // not yet
    });
  });
}
