import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';
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

/// Whether a run of cards is in [order] by start time, with every entry
/// that has no printed time last — whichever end the order starts from.
bool _isSorted(List<ScheduleEntry> slots, SortOrder order) {
  final sign = order == SortOrder.ascending ? 1 : -1;
  String? previous;
  var untimed = false;
  for (final slot in slots) {
    final start = slot.start;
    if (start == null) {
      untimed = true;
      continue;
    }
    if (untimed) return false; // a timed entry after an untimed one
    if (previous != null && sign * previous.compareTo(start) > 0) return false;
    previous = start;
  }
  return true;
}

void main() {
  test('extracts the text layer from a pdf source', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNotNull);
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));
  }, skip: _missing);

  test('keeps only the booked cards, rooms in table order', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    final sections = viewModel.sectionsByBlock;
    expect(sections, isNotEmpty);
    // The raw text stays available as the fallback for anything unparsed.
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));

    // Free slots are still parsed — they are only dropped from the display.
    expect(viewModel.entries.where((entry) => entry.isFree), isNotEmpty);
    expect(viewModel.entries.every((entry) => entry.start != null), isTrue);

    // Every booked slot shows up exactly once, and nothing else does —
    // whether it sits in a block's room or under a blockless room's own
    // heading.
    final booked = [
      for (final entry in viewModel.entries)
        if (!entry.isFree) entry,
    ];
    final grouped = <ScheduleEntry>[
      for (final section in sections) ...[
        ...section.entries,
        for (final slots in section.rooms.values) ...slots,
      ],
    ];
    expect(grouped, hasLength(booked.length));
    expect(grouped.where((entry) => entry.isFree), isEmpty);

    // A room with nothing but free slots gets no heading at all — neither as
    // a block's room nor as its own section.
    final freeOnlyRooms = {
      for (final entry in viewModel.entries)
        if (entry.isFree) entry.room,
    }..removeWhere((room) => booked.any((entry) => entry.room == room));
    final headings = <String>{
      for (final section in sections) ...[section.title, ...section.rooms.keys],
    };
    expect(headings.intersection(freeOnlyRooms), isEmpty);

    // Where each room's first booked slot appears in the table.
    final firstSeen = <String, int>{};
    for (var i = 0; i < booked.length; i++) {
      firstSeen.putIfAbsent(booked[i].room, () => i);
    }

    // Rooms keep the table's order inside each block, and the blockless ones
    // keep it among themselves after the blocks.
    for (final section in sections) {
      final rooms = section.rooms.keys.toList();
      for (var i = 1; i < rooms.length; i++) {
        expect(
          firstSeen[rooms[i - 1]]!,
          lessThan(firstSeen[rooms[i]]!),
          reason: '${section.title}: rooms out of table order',
        );
      }
    }
    final loose = [
      for (final section in sections)
        if (section.entries.isNotEmpty) section.title,
    ];
    for (var i = 1; i < loose.length; i++) {
      expect(
        firstSeen[loose[i - 1]]!,
        lessThan(firstSeen[loose[i]]!),
        reason: 'blockless rooms out of table order',
      );
    }

    // Slots inside a room are ordered by start time, missing times last.
    for (final section in sections) {
      final runs = [
        (section.title, section.entries),
        for (final room in section.rooms.entries) (room.key, room.value),
      ];
      for (final (title, entries) in runs) {
        for (var i = 1; i < entries.length; i++) {
          final previous = entries[i - 1].start;
          final current = entries[i].start;
          if (current == null) continue;
          expect(
            previous,
            isNotNull,
            reason: '$title: an entry without a time must come last',
          );
          expect(
            previous!.compareTo(current),
            lessThanOrEqualTo(0),
            reason: '$title is not sorted by start time',
          );
        }
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
        // A room with no block letter keeps its own single heading, and only
        // ever after the blocks.
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

    // Every booked card lands in the block layout exactly once.
    expect(
      _cardCount(sections),
      viewModel.entries.where((entry) => !entry.isFree).length,
    );
  }, skip: _missing);

  test(
    'the section filter starts with nothing selected, showing no section',
    () async {
      final viewModel = _viewModel();

      await viewModel.scan(SchedulePdf(_sample()));

      final sections = viewModel.sectionsByBlock;
      expect(sections, isNotEmpty);

      // Nothing starts selected: the card list is empty, so the view shows
      // its "Selecciona un bloque." prompt instead of every section.
      expect(viewModel.sectionFilter.selected, isEmpty);
      expect(viewModel.visibleSectionsByBlock, isEmpty);

      // Picking a section narrows the card list to it — the chip row keeps
      // them all, so the pick can be undone...
      final first = sections.first;
      viewModel.toggleSection(first.title);
      expect(viewModel.visibleSectionsByBlock, [first]);
      expect(viewModel.sectionsByBlock, sections);
      expect(viewModel.sectionFilter.selected, {first.title});

      // ...and deselecting the last pick empties the selection again,
      // which brings the prompt back rather than every section.
      viewModel.toggleSection(first.title);
      expect(viewModel.sectionFilter.selected, isEmpty);
      expect(viewModel.visibleSectionsByBlock, isEmpty);
    },
    skip: _missing,
  );

  test('a new scan forgets the previous filter', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    viewModel.toggleSection(viewModel.sectionsByBlock.first.title);
    // Narrowed to just the pick.
    expect(viewModel.visibleSectionsByBlock, hasLength(1));

    await viewModel.scan(SchedulePdf(_sample()));

    // The selection is emptied: no pick outlives its scan, so the new
    // scan starts back at the empty selection — every section still on
    // hand behind the prompt, ready for a chip.
    expect(viewModel.sectionFilter.selected, isEmpty);
    expect(viewModel.visibleSectionsByBlock, isEmpty);
    expect(viewModel.sectionsByBlock, isNotEmpty);
  }, skip: _missing);

  test(
    'starts on the default sort: rooms first, earliest time first',
    () async {
      final viewModel = _viewModel();

      expect(viewModel.sortMode, SortMode.roomThenTime);
      expect(viewModel.sortOrder, SortOrder.ascending);

      await viewModel.scan(SchedulePdf(_sample()));

      expect(viewModel.sortMode, SortMode.roomThenTime);
      expect(viewModel.sortOrder, SortOrder.ascending);
      for (final section in viewModel.sectionsByBlock) {
        for (final slots in [
          section.entries,
          for (final room in section.rooms.values) room,
        ]) {
          expect(
            _isSorted(slots, SortOrder.ascending),
            isTrue,
            reason: '${section.title} is not earliest-first',
          );
        }
      }
    },
    skip: _missing,
  );

  test('time-first sort groups a block under its start times', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    final roomsFirst = viewModel.sectionsByBlock;
    final booked = [
      for (final entry in viewModel.entries)
        if (!entry.isFree) entry,
    ];
    // Where each room starts in the table, so the rooms inside a time group
    // can be checked against it.
    final firstSeen = <String, int>{};
    for (var i = 0; i < booked.length; i++) {
      firstSeen.putIfAbsent(booked[i].room, () => i);
    }

    viewModel.setSort(SortMode.timeThenRoom, SortOrder.ascending);

    final sections = viewModel.sectionsByBlock;
    // The same sections in the same order — only what is under each block
    // heading changes.
    expect(
      [for (final section in sections) section.title],
      [for (final section in roomsFirst) section.title],
    );
    // Nothing lost, nothing duplicated, nothing free.
    expect(_cardCount(sections), booked.length);
    for (final section in sections) {
      expect(section.entryCount, greaterThan(0), reason: section.title);
    }

    for (final section in sections) {
      if (section.rooms.isEmpty) {
        // A blockless room has no sub-headings to turn into times — it just
        // sorts by time like any other run.
        expect(_isSorted(section.entries, SortOrder.ascending), isTrue);
        continue;
      }

      final times = section.rooms.keys.toList();
      expect(
        times,
        everyElement(matches(RegExp(r'^\d{1,2}:\d{2}$'))),
        reason: '${section.title}: sub-headings must be start times',
      );
      expect(
        times,
        equals([...times]..sort()),
        reason: '${section.title}: times must run earliest first',
      );

      for (final group in section.rooms.values) {
        for (var i = 1; i < group.length; i++) {
          expect(
            firstSeen[group[i - 1].room],
            lessThanOrEqualTo(firstSeen[group[i].room]!),
            reason:
                '${section.title}: rooms inside a time group lost the '
                'table order',
          );
        }
      }
    }
  }, skip: _missing);

  test('descending reverses the times, not the blocks or the rooms', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    final titles = [
      for (final section in viewModel.sectionsByBlock) section.title,
    ];
    final subHeadings = {
      for (final section in viewModel.sectionsByBlock)
        section.title: section.rooms.keys.toList(),
    };

    viewModel.setSort(SortMode.roomThenTime, SortOrder.descending);

    final sections = viewModel.sectionsByBlock;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      // Blocks stay alphabetical and rooms keep the table's order…
      expect(section.title, titles[i]);
      expect(section.rooms.keys.toList(), subHeadings[section.title]);
      // …only the cards run backwards, untimed ones still last.
      for (final slots in [
        section.entries,
        for (final room in section.rooms.values) room,
      ]) {
        expect(
          _isSorted(slots, SortOrder.descending),
          isTrue,
          reason: '${section.title} is not latest-first',
        );
      }
    }

    // In time-first mode the sub-headings themselves run backwards.
    viewModel.setSort(SortMode.timeThenRoom, SortOrder.descending);

    for (final section in viewModel.sectionsByBlock) {
      final times = section.rooms.keys.toList();
      for (var i = 1; i < times.length; i++) {
        expect(
          times[i - 1].compareTo(times[i]),
          greaterThan(0),
          reason: '${section.title}: times must run latest first',
        );
      }
    }
  }, skip: _missing);

  test('the chip selection survives a sort change', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    final titles = [
      for (final section in viewModel.sectionsByBlock) section.title,
    ];

    viewModel.toggleSection(titles.first);
    expect(viewModel.visibleSectionsByBlock, hasLength(1));

    viewModel.setSort(SortMode.timeThenRoom, SortOrder.descending);

    // Both modes keep the same top-level titles, so the pick still points at
    // the same section and the chips need no reshuffling.
    expect(viewModel.sectionFilter.selected, {titles.first});
    expect(
      [for (final section in viewModel.visibleSectionsByBlock) section.title],
      [titles.first],
    );
    expect([
      for (final section in viewModel.sectionsByBlock) section.title,
    ], titles);
  }, skip: _missing);

  test('a new scan resets the sort', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    viewModel.setSort(SortMode.timeThenRoom, SortOrder.descending);

    await viewModel.scan(SchedulePdf(_sample()));

    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.ascending);
    // Back to room names under the blocks, not times.
    expect(
      viewModel.sectionsByBlock
          .expand((section) => section.rooms.keys)
          .any((key) => RegExp(r'^\d').hasMatch(key)),
      isFalse,
    );
  }, skip: _missing);

  test('scan is a no-op without a source', () async {
    final viewModel = _viewModel();

    await viewModel.scan(null);

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNull);
    expect(viewModel.entries, isEmpty);
    expect(viewModel.sectionsByBlock, isEmpty);
  });

  // The ScheduleImage branch goes through ML Kit, which only ships
  // Android/iOS implementations, so it cannot be exercised host-side.
}
