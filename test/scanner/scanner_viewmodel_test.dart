import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
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
///
/// The clock reads midnight, so under the default freshness row every
/// fixture start is still to come and nothing is stale — the window only
/// acts in the test that asks for it.
ScannerViewModel _viewModel() =>
    ScannerViewModel(clock: () => DateTime(2026, 1, 1));

/// Every card of a section list, block headings included.
int _cardCount(List<EntrySection> sections) =>
    sections.fold<int>(0, (total, section) => total + section.entryCount);

/// The cards themselves, block headings flattened away.
Iterable<ScheduleEntry> _cards(List<EntrySection> sections) => sections.expand(
  (section) => [...section.entries, ...section.rooms.values.expand((s) => s)],
);

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

/// Walks one filter row back to `none`.
void _markNone(ScannerViewModel viewModel, FilterRow row) {
  while (viewModel.filters.stateOf(row) != TypeMark.none) {
    viewModel.cycleFilter(row);
  }
}

/// Walks every filter row back to `none`, so a test sees the selection's
/// own effect instead of the default marks' (labs in, free out, stale out).
void _noFilters(ScannerViewModel viewModel) {
  for (final row in FilterRow.values) {
    _markNone(viewModel, row);
  }
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
    // The room grouping — this test reads the room names under each block.
    viewModel.setSort(SortMode.roomThenTime, SortOrder.ascending);

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
    // The room grouping — this test reads the room names under each block.
    viewModel.setSort(SortMode.roomThenTime, SortOrder.ascending);

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
      // The rows off, so the pick's own effect is all that narrows here.
      _noFilters(viewModel);

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
    _noFilters(viewModel);
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

  test('starts on the default sort: time-then-room, ascending', () async {
    final viewModel = _viewModel();

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.ascending);

    await viewModel.scan(SchedulePdf(_sample()));

    expect(viewModel.sortMode, SortMode.timeThenRoom);
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
  }, skip: _missing);

  test('time-first sort groups a block under its start times', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));
    // Back to the room grouping first, so the switch below has a switch
    // to make.
    viewModel.setSort(SortMode.roomThenTime, SortOrder.ascending);
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
    // The room grouping first — its sub-headings are the room names the
    // descending check below compares against.
    viewModel.setSort(SortMode.roomThenTime, SortOrder.ascending);
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
    _noFilters(viewModel);
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
    viewModel.setSort(SortMode.roomThenTime, SortOrder.descending);

    await viewModel.scan(SchedulePdf(_sample()));

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.ascending);
    // Back to the default grouping: start times under the blocks.
    expect(
      viewModel.sectionsByBlock
          .expand((section) => section.rooms.keys)
          .any((key) => RegExp(r'^\d').hasMatch(key)),
      isTrue,
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

  group('filters', () {
    /// Picks every section of [viewModel] in the chip row.
    void selectAll(ScannerViewModel viewModel) {
      for (final section in viewModel.sectionsByBlock) {
        viewModel.toggleSection(section.title);
      }
    }

    /// The sample scanned with every section of it picked — the marks at
    /// their defaults, unless [unfiltered] walks them all back to `none`
    /// first (which also rebuilds the sections, so pick after that).
    Future<ScannerViewModel> allSelected({bool unfiltered = false}) async {
      final viewModel = _viewModel();
      await viewModel.scan(SchedulePdf(_sample()));
      if (unfiltered) _noFilters(viewModel);
      selectAll(viewModel);
      return viewModel;
    }

    test('a scan starts from the default marks', () async {
      final viewModel = _viewModel();

      await viewModel.scan(SchedulePdf(_sample()));

      // The compute labs in, the free slots out, the stale sessions out.
      final filters = viewModel.filters;
      expect(filters.marks, defaultFilterMarks);
      expect(filters.stateOf(FilterRow.computeLab), TypeMark.include);
      expect(filters.stateOf(FilterRow.libres), TypeMark.exclude);
      expect(filters.stateOf(FilterRow.last15), TypeMark.include);
    }, skip: _missing);

    test('the default list is the booked compute labs', () async {
      final viewModel = await allSelected();

      final cards = _cards(viewModel.visibleSectionsByBlock).toList();
      // The sample books compute labs…
      expect(cards, isNotEmpty);
      // …and that is all that shows: no other room and no free slot. The
      // test clock reads midnight, so every fixture start is ahead of it
      // and the window keeps nothing back for being old.
      expect([
        for (final card in cards) isComputeLab(card.room),
      ], everyElement(true));
      expect([for (final card in cards) card.isFree], everyElement(false));
      expect([
        for (final card in cards) isStale(card.start, DateTime(2026, 1, 1)),
      ], everyElement(false));
      // The rest of the schedule is behind the marks: every room outside
      // the lab list never reaches the list.
      expect(
        _cardCount(viewModel.visibleSectionsByBlock),
        lessThan(_cardCount(viewModel.sectionsByBlock)),
      );
    }, skip: _missing);

    test('the compute-lab row picks the labs out and back', () async {
      final viewModel = await allSelected(unfiltered: true);

      final everything = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(everything.any((card) => isComputeLab(card.room)), isTrue);
      expect(everything.any((card) => !isComputeLab(card.room)), isTrue);

      viewModel.cycleFilter(FilterRow.computeLab); // none → include

      final labs = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(labs, isNotEmpty);
      expect([
        for (final card in labs) isComputeLab(card.room),
      ], everyElement(true));
      expect(labs.length, lessThan(everything.length));

      viewModel.cycleFilter(FilterRow.computeLab); // include → exclude

      final rest = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(rest, isNotEmpty);
      expect([
        for (final card in rest) isComputeLab(card.room),
      ], everyElement(false));
      expect(rest.length, everything.length - labs.length);

      viewModel.cycleFilter(FilterRow.computeLab); // exclude → none

      expect(
        _cards(viewModel.visibleSectionsByBlock),
        hasLength(everything.length),
      );
    }, skip: _missing);

    test('the Libres row decides which slots exist as cards', () async {
      final viewModel = _viewModel();

      await viewModel.scan(SchedulePdf(_sample()));
      // The sample has both kinds of slot to filter.
      expect(viewModel.entries.any((entry) => entry.isFree), isTrue);
      expect(viewModel.entries.any((entry) => !entry.isFree), isTrue);
      // Only `Libres` moves here: the labs and the window are walked off,
      // so every room of the sample is on the list.
      _markNone(viewModel, FilterRow.computeLab);
      _markNone(viewModel, FilterRow.last15);

      // Excluded — the default: free slots are not cards at all, neither
      // in the list nor among the chips' sections.
      var cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards, isNotEmpty);
      expect([for (final card in cards) card.isFree], everyElement(false));

      viewModel.cycleFilter(FilterRow.libres); // exclude → none

      // Both kinds now: the free cards join the booked ones, and a room
      // that only ever held free slots gets a section of its own.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards.any((card) => card.isFree), isTrue);
      expect(cards.any((card) => !card.isFree), isTrue);

      viewModel.cycleFilter(FilterRow.libres); // none → include

      // Only the free slots remain — sections and list alike.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards, isNotEmpty);
      expect([for (final card in cards) card.isFree], everyElement(true));
      selectAll(viewModel);
      final visible = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(visible, isNotEmpty);
      expect([for (final card in visible) card.isFree], everyElement(true));

      viewModel.cycleFilter(FilterRow.libres); // include → exclude

      // Back to the default: the free cards are gone again.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect([for (final card in cards) card.isFree], everyElement(false));
      expect([
        for (final card in _cards(viewModel.visibleSectionsByBlock))
          card.isFree,
      ], everyElement(false));
    }, skip: _missing);

    test('the freshness row drops the stale sessions', () async {
      final now = DateTime(2026, 1, 1, 10, 5);
      final viewModel = ScannerViewModel(clock: () => now);

      await viewModel.scan(SchedulePdf(_sample()));
      // Only the window acts here — every room is on the list; the free
      // slots stay at their default exclude.
      _markNone(viewModel, FilterRow.computeLab);
      selectAll(viewModel);

      final booked = _cards(viewModel.sectionsByBlock).toList();
      final stale = [
        for (final card in booked)
          if (isStale(card.start, now)) card,
      ];
      final fresh = [
        for (final card in booked)
          if (!isStale(card.start, now)) card,
      ];
      // The morning is over, the rest of the day is not.
      expect(stale, isNotEmpty);
      expect(fresh, isNotEmpty);

      // Marked in — the default: everything that started more than a
      // quarter of an hour before 10:05 stays behind, the rest shows.
      final shown = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(shown.length, fresh.length);
      expect([
        for (final card in shown) isStale(card.start, now),
      ], everyElement(false));
      // The example the window is built on: a 09:30 card is gone…
      expect([for (final card in shown) card.start], isNot(contains('09:30')));
      // …a 10:00 one is not.
      expect([for (final card in shown) card.start], contains('10:00'));

      // Marked out — the other half: only the sessions already under way
      // for more than fifteen minutes remain.
      viewModel.cycleFilter(FilterRow.last15); // include → exclude

      final behind = _cards(viewModel.visibleSectionsByBlock).toList();
      expect(behind.length, stale.length);
      expect([
        for (final card in behind) isStale(card.start, now),
      ], everyElement(true));

      // Back to none: the window stops filtering at all.
      viewModel.cycleFilter(FilterRow.last15); // exclude → none

      expect(
        _cards(viewModel.visibleSectionsByBlock),
        hasLength(booked.length),
      );
    }, skip: _missing);

    test('the marks narrow inside the chip selection', () async {
      final viewModel = _viewModel();
      await viewModel.scan(SchedulePdf(_sample()));
      _noFilters(viewModel);

      // A section with no compute lab in it — the sample's first block,
      // for one, but asked for rather than assumed.
      final section = viewModel.sectionsByBlock.firstWhere(
        (section) =>
            _cards([section]).every((card) => !isComputeLab(card.room)),
      );
      final titles = [for (final s in viewModel.sectionsByBlock) s.title];
      viewModel.toggleSection(section.title);
      final selected = _cardCount(viewModel.visibleSectionsByBlock);
      expect(selected, greaterThan(0));

      // Marking the labs in empties this selection — every card in it
      // lives in a lab-less room — and says why, since a block *is*
      // selected.
      viewModel.cycleFilter(FilterRow.computeLab); // none → include

      expect(viewModel.visibleSectionsByBlock, isEmpty);
      expect(viewModel.typeFilteredOut, isTrue);

      // One tap further the include becomes an exclude, so the section's
      // own cards — none of them labs — are back.
      viewModel.cycleFilter(FilterRow.computeLab); // include → exclude

      expect(_cardCount(viewModel.visibleSectionsByBlock), selected);
      expect(viewModel.typeFilteredOut, isFalse);

      // Through all of it the section stayed in the chips' list.
      expect([for (final s in viewModel.sectionsByBlock) s.title], titles);
    }, skip: _missing);

    test('the marks filter inside a time group as well', () async {
      final viewModel = await allSelected(unfiltered: true);

      final before = _cardCount(viewModel.visibleSectionsByBlock);
      viewModel.cycleFilter(FilterRow.computeLab); // none → include

      final visible = viewModel.visibleSectionsByBlock;
      expect(_cardCount(visible), lessThan(before));
      expect(_cardCount(visible), greaterThan(0));
      expect([
        for (final card in _cards(visible)) isComputeLab(card.room),
      ], everyElement(true));
      // A block's sub-headings are still start times, not rooms.
      expect(
        visible
            .expand((section) => section.rooms.keys)
            .any((key) => RegExp(r'^\d').hasMatch(key)),
        isTrue,
      );
    }, skip: _missing);

    test('a new scan resets the marks', () async {
      final viewModel = await allSelected();
      _noFilters(viewModel);
      expect(viewModel.filters.marks, isNot(defaultFilterMarks));
      expect(viewModel.filters.stateOf(FilterRow.libres), TypeMark.none);

      await viewModel.scan(SchedulePdf(_sample()));

      expect(viewModel.filters.marks, defaultFilterMarks);
      expect(viewModel.typeFilteredOut, isFalse);
      expect(viewModel.visibleSectionsByBlock, isEmpty); // chips went too
    }, skip: _missing);
  });

  // The ScheduleImage branch goes through ML Kit, which only ships
  // Android/iOS implementations, so it cannot be exercised host-side.
}
