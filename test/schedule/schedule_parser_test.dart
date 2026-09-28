import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
import 'package:sched_scan/schedule/models/schedule_line.dart';
import 'package:sched_scan/schedule/models/schedule_word.dart';
import 'package:sched_scan/schedule/schedule_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Height of every synthetic word. The parser only uses it to stack label
/// words into visual lines.
const _height = 8.0;

/// Room labels are left-aligned inside the room column; the parser drops any
/// line touching the left edge of the sheet as chrome, so they start at 12.
const _labelX = 12.0;

/// Left edge of the time area, read from the `AULA / HORA` anchors below —
/// words left of it are labels, words right of it are cell content.
const _boundary = 80.0;

/// Centres of two cell columns. Lines of one cell share a centre exactly;
/// neighbouring columns are far apart.
const _col1 = 200.0;
const _col2 = 400.0;

const _samplePath = 'test/fixtures/sample.pdf';

ScheduleLine _header(int page) => ScheduleLine(
  pageIndex: page,
  words: [
    ScheduleWord(text: 'AULA / HORA', left: 5, top: 10, right: 55, bottom: 18),
    ScheduleWord(
      text: '07:00',
      left: _boundary,
      top: 10,
      right: 120,
      bottom: 18,
    ),
    ScheduleWord(text: '08:00', left: 120, top: 10, right: 160, bottom: 18),
  ],
);

/// One room-label line, left-aligned in the room column.
ScheduleLine _label(int page, double top, String text) => ScheduleLine(
  pageIndex: page,
  words: [
    ScheduleWord(
      text: text,
      left: _labelX,
      top: top,
      right: _labelX + text.length * 4,
      bottom: top + _height,
    ),
  ],
);

/// One line of a cell, centred on [column].
ScheduleLine _cell(int page, double top, double column, String text) {
  final width = text.length * 4.0;
  return ScheduleLine(
    pageIndex: page,
    words: [
      ScheduleWord(
        text: text,
        left: column - width / 2,
        top: top,
        right: column + width / 2,
        bottom: top + _height,
      ),
    ],
  );
}

/// Page chrome printed against the left edge of the sheet (the running title).
ScheduleLine _edge(int page, double top, String text) => ScheduleLine(
  pageIndex: page,
  words: [
    ScheduleWord(
      text: text,
      left: 3,
      top: top,
      right: 3 + text.length * 4,
      bottom: top + _height,
    ),
  ],
);

void main() {
  group('ScheduleParser', () {
    test('parses nothing from an empty document', () {
      expect(ScheduleParser().parse(const []), isEmpty);
    });

    test('reads a free cell', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-101'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
      ]);

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.room, 'AULA A-101');
      expect(entry.pageIndex, 0);
      expect(entry.status, 'LIBRE');
      expect(entry.isFree, isTrue);
      expect(entry.start, '07:00');
      expect(entry.end, '11:00');
      expect(entry.timeLabel, '07:00 – 11:00');
      expect(entry.course, isNull);
      expect(entry.person, isNull);
    });

    test('reads a booked cell', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-102'),
        _cell(0, 100, _col1, 'MATEMÁTICA SEC: 3'),
        _cell(0, 103, _col1, 'CICLO: 2'),
        _cell(0, 106, _col1, '(ADMINISTRACIÓN DE EMPRESAS)'),
        _cell(0, 109, _col1, 'PÉREZ LÓPEZ JUAN'),
        _cell(0, 112, _col1, 'De: 08:00 a 10:15'),
      ]);

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.status, isNull);
      expect(entry.course, 'MATEMÁTICA');
      expect(entry.section, '3');
      expect(entry.cycle, '2');
      expect(entry.program, '(ADMINISTRACIÓN DE EMPRESAS)');
      expect(entry.person, 'PÉREZ LÓPEZ JUAN');
      expect(entry.start, '08:00');
      expect(entry.end, '10:15');
    });

    test('reads a reservation that only holds the (-) placeholder', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-103'),
        _cell(0, 100, _col1, 'RESERVA ONLINE'),
        _cell(0, 103, _col1, '( - )'),
        _cell(0, 106, _col1, 'ANA GARCÍA LÓPEZ'),
        _cell(0, 109, _col1, 'De: 12:00 a 14:00'),
      ]);

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.status, 'RESERVA ONLINE');
      expect(entry.course, isNull);
      expect(entry.person, 'ANA GARCÍA LÓPEZ');
      expect(entry.start, '12:00');
      expect(entry.end, '14:00');
    });

    test('treats a bare (-) cell as nothing at all', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-104'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
        _cell(0, 100, _col2, '( - )'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.room, 'AULA A-104');
    });

    test('keeps a docente out of the title when the cell has no course', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'LOSA DEPORTIVA'),
        _cell(0, 100, _col1, '( - )'),
        _cell(0, 103, _col1, 'PAUCARIMA FRANCO ERIN'),
        _cell(0, 106, _col1, 'De: 12:00 a 14:00'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.course, isNull);
      expect(entries.single.person, 'PAUCARIMA FRANCO ERIN');
    });

    test('splits an event title from its docente across the programme', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA C-104'),
        _cell(0, 100, _col1, 'Feria Interautonoma'),
        _cell(0, 103, _col1, '(DIRECCIÓN DE RELACIONES'),
        _cell(0, 106, _col1, 'INTERINSTITUCIONALES)'),
        _cell(0, 109, _col1, 'RIVAROLA GANOZA IVAN JAVIER'),
        _cell(0, 112, _col1, 'De: 10:00 a 12:00'),
      ]);

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.course, 'Feria Interautonoma');
      expect(entry.program, '(DIRECCIÓN DE RELACIONES INTERINSTITUCIONALES)');
      expect(entry.person, 'RIVAROLA GANOZA IVAN JAVIER');
      expect(entry.section, isNull);
      expect(entry.start, '10:00');
    });

    test('joins a room label that wraps onto a second line', () {
      final entries = ScheduleParser().parse([
        _header(0),
        // 108.7 clears the first line's 108pt bottom but stays within the
        // 1pt gap that keeps two label lines in one room.
        _label(0, 100, 'J-103 (LABORATORIO DE'),
        _label(0, 108.7, 'MECATRÓNICA)'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.room, 'J-103 (LABORATORIO DE MECATRÓNICA)');
    });

    test('reads a section whose value wrapped onto its own line', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-105'),
        _cell(0, 100, _col1, 'MATEMÁTICA SEC:'),
        _cell(0, 103, _col1, '3'),
        _cell(0, 106, _col1, 'De: 08:00 a 10:15'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.course, 'MATEMÁTICA');
      expect(entries.single.section, '3');
      expect(entries.single.start, '08:00');
    });

    test('reads a time range split over two lines', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-106'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00'),
        _cell(0, 106, _col1, 'a 07:15'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.start, '07:00');
      expect(entries.single.end, '07:15');
    });

    test('collects the free-form notes printed after the time', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA A-107'),
        _cell(0, 100, _col1, 'FÍSICA SEC: 1'),
        _cell(0, 103, _col1, 'De: 08:00 a 10:00'),
        _cell(0, 106, _col1, 'Recuperación'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.notes, ['Recuperación']);
    });

    test('gives every row its own cells', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA B-101'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
        _label(0, 116, 'AULA B-102'),
        _cell(0, 116, _col1, 'MATEMÁTICA SEC: 4'),
        _cell(0, 119, _col1, 'De: 12:00 a 14:00'),
      ]);

      expect(entries, hasLength(2));
      expect(entries[0].room, 'AULA B-101');
      expect(entries[0].status, 'LIBRE');
      expect(entries[1].room, 'AULA B-102');
      expect(entries[1].course, 'MATEMÁTICA');
      expect(entries[1].section, '4');
      expect(entries[1].start, '12:00');
    });

    test('keeps cells in their own column', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 100, 'AULA B-103'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
        _cell(0, 100, _col2, 'FÍSICA SEC: 2'),
        _cell(0, 103, _col2, 'De: 12:00 a 14:00'),
      ]);

      expect(entries, hasLength(2));
      expect(entries[0].status, 'LIBRE');
      expect(entries[0].start, '07:00');
      expect(entries[1].course, 'FÍSICA');
      expect(entries[1].section, '2');
      expect(entries[1].start, '12:00');
    });

    test('drops the page chrome', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _edge(0, 5, 'DISTRIBUCIÓN DE AMBIENTES 24/09/2026'),
        _cell(0, 30, _col1, 'Buscar por aula o programa'),
        _cell(0, 760, _col1, '2 de 6'),
        _label(0, 100, 'AULA A-101'),
        _cell(0, 100, _col1, 'LIBRE'),
        _cell(0, 103, _col1, 'De: 07:00 a 11:00'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.room, 'AULA A-101');
      expect(entries.single.status, 'LIBRE');
    });

    test('glues a room name that a page break cut in half', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 700, 'J-223 (LABORATORIO DE BIOLOGÍA CELULAR Y'),
        _cell(0, 700, _col1, 'LIBRE'),
        _cell(0, 703, _col1, 'De: 07:00 a 11:00'),
        _header(1),
        _label(1, 50, 'MICROBIOLOGÍA)'),
        _cell(1, 50, _col1, 'LIBRE'),
        _cell(1, 53, _col1, 'De: 12:00 a 14:00'),
        _label(1, 100, 'AULA C-101'),
        _cell(1, 100, _col1, 'FÍSICA SEC: 1'),
        _cell(1, 103, _col1, 'De: 15:00 a 17:00'),
      ]);

      const merged = 'J-223 (LABORATORIO DE BIOLOGÍA CELULAR Y MICROBIOLOGÍA)';
      expect(entries, hasLength(3));
      expect(entries[0].room, merged);
      expect(entries[0].pageIndex, 0);
      expect(entries[1].room, merged);
      expect(entries[1].pageIndex, 1);
      expect(entries[1].start, '12:00');
      expect(entries[2].room, 'AULA C-101');
      expect(entries[2].course, 'FÍSICA');
    });

    test('keeps a cell together across a page break', () {
      final entries = ScheduleParser().parse([
        _header(0),
        _label(0, 700, 'AULA D-201'),
        _cell(0, 700, _col1, 'FÍSICA SEC: 2'),
        _cell(0, 703, _col1, 'CICLO: 1'),
        _cell(0, 706, _col1, '(CIENCIAS NATURALES)'),
        // The cell continues above the next page's first room label.
        _header(1),
        _cell(1, 41, _col1, 'GARCÍA LÓPEZ MARÍA'),
        _cell(1, 44, _col1, 'De: 08:00 a 10:00'),
        _label(1, 50, 'AULA D-202'),
        _cell(1, 50, _col1, 'QUÍMICA SEC: 1'),
        _cell(1, 53, _col1, 'De: 11:00 a 13:00'),
      ]);

      expect(entries, hasLength(2));

      final split = entries[0];
      expect(split.room, 'AULA D-201');
      expect(split.pageIndex, 0);
      expect(split.course, 'FÍSICA');
      expect(split.section, '2');
      expect(split.cycle, '1');
      expect(split.program, '(CIENCIAS NATURALES)');
      expect(split.person, 'GARCÍA LÓPEZ MARÍA');
      expect(split.start, '08:00');
      expect(split.end, '10:00');

      final next = entries[1];
      expect(next.room, 'AULA D-202');
      expect(next.course, 'QUÍMICA');
      expect(next.section, '1');
      expect(next.person, isNull);
      expect(next.start, '11:00');
    });
  });

  group('ScheduleParser on the sample PDF', () {
    final present = File(_samplePath).existsSync();
    final skip = present ? false : 'sample pdf not found';

    late List<ScheduleEntry> entries;
    late int timeAnchors;
    late int sectionAnchors;

    setUpAll(() {
      if (!present) return;

      final pdf = PdfDocument(inputBytes: File(_samplePath).readAsBytesSync());
      final lines = PdfTextExtractor(pdf).extractTextLines();

      // `De:` is printed once per slot and `SEC:` once per section, so the
      // parser must consume exactly as many as the text layer holds.
      timeAnchors = 0;
      sectionAnchors = 0;
      for (final line in lines) {
        final text = line.text.trim();
        if (text.startsWith('De:')) timeAnchors++;
        if (text.contains('SEC:')) sectionAnchors++;
      }

      entries = ScheduleParser().parse([
        for (final line in lines)
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
      ]);
      pdf.dispose();
    });

    test('gives every printed time range and section an entry', () {
      expect(entries, isNotEmpty);
      expect(
        entries.where((entry) => entry.start != null),
        hasLength(timeAnchors),
      );
      expect(
        entries.where((entry) => entry.section != null),
        hasLength(sectionAnchors),
      );
      expect(entries.where((entry) => entry.start == null), isEmpty);
    }, skip: skip);

    test('never splits a room name', () {
      final rooms = {for (final entry in entries) entry.room};
      expect(rooms, isNotEmpty);
      expect(
        rooms.where((room) => room.contains('(') && !room.contains(')')),
        isEmpty,
      );
    }, skip: skip);

    test('reads the room whose name the first page break cuts', () {
      expect(
        entries.map((entry) => entry.room),
        contains('J-223 (LABORATORIO DE BIOLOGÍA CELULAR Y MICROBIOLOGÍA)'),
      );
    }, skip: skip);
  });
}
