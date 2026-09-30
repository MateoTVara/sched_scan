import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';

const _samplePath = 'test/fixtures/sample.pdf';

final _missing = File(_samplePath).existsSync()
    ? false
    : 'sample pdf not found — place it at $_samplePath';

/// The room-code regex the viewmodel groups blocks with, kept here so the
/// test can check the result without duplicating the logic under test.
final _blockCode = RegExp(r'(?:^|\s)([A-Z])-\d');

/// The sample schedule as a picked file.
XFile _sample() =>
    XFile.fromData(File(_samplePath).readAsBytesSync(), name: 'schedule.pdf');

/// Never disposed: closing the ML Kit recognizer reaches a plugin that does
/// not exist on the host, and no OCR runs in these tests to allocate one.
ScannerViewModel _viewModel() => ScannerViewModel();

/// Every card of a section list, block headings included.
int _cardCount(List<EntrySection> sections) =>
    sections.fold<int>(0, (total, section) => total + section.entryCount);

void main() {
  test('extracts the text layer from a pdf source', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNotNull);
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));
  }, skip: _missing);

  test('groups the booked pdf entries by room', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    final sections = viewModel.sectionsByRoom;
    expect(sections, isNotEmpty);
    // The raw text stays available as the fallback for anything unparsed.
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));

    // Free slots are still parsed — they are only dropped from the display.
    expect(viewModel.entries.where((entry) => entry.isFree), isNotEmpty);
    expect(viewModel.entries.every((entry) => entry.start != null), isTrue);

    // Every booked slot shows up exactly once, and nothing else does.
    final booked = [
      for (final entry in viewModel.entries)
        if (!entry.isFree) entry,
    ];
    final grouped = [for (final section in sections) ...section.entries];
    expect(grouped, hasLength(booked.length));
    expect(grouped.where((entry) => entry.isFree), isEmpty);
    expect(sections.every((section) => section.rooms.isEmpty), isTrue);

    // Sections keep the order the first booked slot of each room appears in
    // the table; a room with nothing but free slots gets no section at all.
    expect(sections.first.title, booked.first.room);
    final freeOnlyRooms = {
      for (final entry in viewModel.entries)
        if (entry.isFree) entry.room,
    }..removeWhere((room) => booked.any((entry) => entry.room == room));
    expect(
      sections
          .map((section) => section.title)
          .toSet()
          .intersection(freeOnlyRooms),
      isEmpty,
    );

    // Slots inside a room are ordered by start time, missing times last.
    for (final section in sections) {
      final entries = section.entries;
      for (var i = 1; i < entries.length; i++) {
        final previous = entries[i - 1].start;
        final current = entries[i].start;
        if (current == null) continue;
        expect(
          previous,
          isNotNull,
          reason: '${section.title}: an entry without a time must come last',
        );
        expect(
          previous!.compareTo(current),
          lessThanOrEqualTo(0),
          reason: '${section.title} is not sorted by start time',
        );
      }
    }
  }, skip: _missing);

  test('groups the booked pdf entries by block', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    final sections = viewModel.sectionsByBlock;
    expect(sections, isNotEmpty);

    final blockLetters = <String>[];
    final loose = <String>[];
    var seenLoose = false;
    for (final section in sections) {
      if (section.rooms.isEmpty) {
        // A room with no block letter keeps the single heading it has in the
        // by-room layout, and only ever after the blocks.
        seenLoose = true;
        loose.add(section.title);
        expect(_blockCode.hasMatch(section.title), isFalse);
        continue;
      }

      expect(seenLoose, isFalse, reason: '${section.title} follows a room');
      expect(section.title, startsWith('Bloque '));
      final letter = section.title.substring('Bloque '.length);
      blockLetters.add(letter);
      for (final room in section.rooms.keys) {
        expect(
          _blockCode.firstMatch(room)?.group(1),
          letter,
          reason: '$room does not belong to block $letter',
        );
      }
      // Blocks group rooms, so one heading over no rooms would be a lie.
      expect(section.rooms, isNotEmpty);
      expect(section.entries, isEmpty);
    }

    // Alphabetical, only the blocks that occur, and at least one of them.
    expect(blockLetters, isNotEmpty);
    expect(blockLetters, equals([...blockLetters]..sort()));
    // This sample has no F/G/H buildings; every other letter A…K has booked
    // rooms, so the grouping must find all eight.
    expect(blockLetters, ['A', 'B', 'C', 'D', 'E', 'I', 'J', 'K']);
    // Rooms without a block letter still get their own section.
    expect(loose, isNotEmpty);

    // Both layouts show exactly the same set of booked cards.
    expect(_cardCount(sections), _cardCount(viewModel.sectionsByRoom));
    expect(
      _cardCount(sections),
      viewModel.entries.where((entry) => !entry.isFree).length,
    );
  }, skip: _missing);

  test('scan is a no-op without a source', () async {
    final viewModel = _viewModel();

    await viewModel.scan(null);

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNull);
    expect(viewModel.entries, isEmpty);
    expect(viewModel.sectionsByRoom, isEmpty);
    expect(viewModel.sectionsByBlock, isEmpty);
  });

  // The ScheduleImage branch goes through ML Kit, which only ships
  // Android/iOS implementations, so it cannot be exercised host-side.
}
