import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';

void main() {
  test('the sections read in the order the menu lists them', () {
    expect(
      [for (final choice in RoomTypeChoice.values) choice.label],
      ['Todos los espacios', 'Solo aulas', 'Solo laboratorios'],
    );
    expect(
      [for (final choice in ViewChoice.values) choice.label],
      ['Todo el día', 'Ahora', 'Inicios próximos'],
    );
    expect(
      [for (final choice in StateChoice.values) choice.label],
      ['Libres y ocupadas', 'Solo libres', 'Solo ocupadas'],
    );
  });

  test('a choice advances one step and wraps back to its first', () {
    expect(RoomTypeChoice.all.next, RoomTypeChoice.rooms);
    expect(RoomTypeChoice.rooms.next, RoomTypeChoice.labs);
    expect(RoomTypeChoice.labs.next, RoomTypeChoice.all);

    expect(ViewChoice.all.next, ViewChoice.now);
    expect(ViewChoice.now.next, ViewChoice.soon);
    expect(ViewChoice.soon.next, ViewChoice.all);

    expect(StateChoice.all.next, StateChoice.free);
    expect(StateChoice.free.next, StateChoice.busy);
    expect(StateChoice.busy.next, StateChoice.all);
  });

  test('the opening-soon view looks ten minutes back', () {
    expect(recentlyStartedWindow, const Duration(minutes: 10));
  });

  group('passesRoomType', () {
    test('every room, the labs only, or the rest only', () {
      expect(passesRoomType(RoomTypeChoice.all, room: 'AULA A-102'), isTrue);
      expect(
        passesRoomType(
          RoomTypeChoice.all,
          room: 'B-101 (LABORATORIO DE CÓMPUTO)',
        ),
        isTrue,
      );

      expect(
        passesRoomType(
          RoomTypeChoice.labs,
          room: 'B-101 (LABORATORIO DE CÓMPUTO)',
        ),
        isTrue,
      );
      expect(passesRoomType(RoomTypeChoice.labs, room: 'C-203'), isTrue);
      expect(passesRoomType(RoomTypeChoice.labs, room: 'AULA A-102'), isFalse);
      expect(
        passesRoomType(RoomTypeChoice.labs, room: 'LOSA DEPORTIVA'),
        isFalse,
      );

      expect(passesRoomType(RoomTypeChoice.rooms, room: 'AULA A-102'), isTrue);
      expect(
        passesRoomType(RoomTypeChoice.rooms, room: 'LOSA DEPORTIVA'),
        isTrue,
      );
      expect(
        passesRoomType(
          RoomTypeChoice.rooms,
          room: 'B-101 (LABORATORIO DE CÓMPUTO)',
        ),
        isFalse,
      );
      expect(passesRoomType(RoomTypeChoice.rooms, room: 'C-203'), isFalse);
    });
  });

  group('passesView', () {
    final now = DateTime(2026, 1, 1, 10, 5);

    test('todo keeps every slot, whenever it runs', () {
      expect(
        passesView(ViewChoice.all, start: '07:00', end: '07:15', now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.all, start: null, end: null, now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.all, start: '20:00', end: '21:00', now: now),
        isTrue,
      );
    });

    test('ahora keeps the sessions underway, like isOngoing', () {
      expect(
        passesView(ViewChoice.now, start: '09:30', end: '11:30', now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.now, start: '10:06', end: '12:00', now: now),
        isFalse,
      );
      expect(
        passesView(ViewChoice.now, start: null, end: null, now: now),
        isFalse,
      );
    });

    test('inicios próximos keeps future starts and the last ten minutes, '
        'like isStartingSoon', () {
      expect(
        passesView(ViewChoice.soon, start: '10:15', end: '11:00', now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.soon, start: '20:00', end: '21:00', now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.soon, start: '10:00', end: '11:30', now: now),
        isTrue,
      );
      expect(
        passesView(ViewChoice.soon, start: '09:54', end: '11:30', now: now),
        isFalse,
      );
      expect(
        passesView(ViewChoice.soon, start: '09:30', end: '11:30', now: now),
        isFalse,
      );
      expect(
        passesView(ViewChoice.soon, start: null, end: null, now: now),
        isFalse,
      );
    });
  });

  group('passesState', () {
    test('both kinds, the free slots only, or the booked ones only', () {
      expect(passesState(StateChoice.all, isFree: true), isTrue);
      expect(passesState(StateChoice.all, isFree: false), isTrue);

      expect(passesState(StateChoice.free, isFree: true), isTrue);
      expect(passesState(StateChoice.free, isFree: false), isFalse);

      expect(passesState(StateChoice.busy, isFree: true), isFalse);
      expect(passesState(StateChoice.busy, isFree: false), isTrue);
    });
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

  group('isStartingSoon', () {
    final now = DateTime(2026, 1, 1, 10, 5);

    test('every future start counts, however far ahead', () {
      expect(isStartingSoon('10:06', now), isTrue); // a minute away
      expect(isStartingSoon('10:15', now), isTrue);
      expect(isStartingSoon('11:00', now), isTrue);
      expect(isStartingSoon('20:00', now), isTrue); // the last class
    });

    test('the clock and the ten minutes before it still count', () {
      expect(isStartingSoon('10:05', now), isTrue); // the clock itself
      expect(isStartingSoon('10:00', now), isTrue); // five minutes ago
      expect(isStartingSoon('09:55', now), isTrue); // exactly ten — still in
      expect(isStartingSoon('09:54', now), isFalse); // a minute too old
      expect(isStartingSoon('09:30', now), isFalse); // long over
    });

    test('no start, or no parseable one, never counts', () {
      expect(isStartingSoon(null, now), isFalse);
      expect(isStartingSoon('—', now), isFalse);
      expect(isStartingSoon('Recuperación', now), isFalse);
    });
  });
}
