import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/models/preset.dart';
import 'package:sched_scan/scanner/models/room_block.dart';
import 'package:sched_scan/scanner/models/scan_filters.dart';
import 'package:sched_scan/scanner/models/sort_mode.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/scanner/settings_store.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';
import 'package:sched_scan/schedule/models/schedule_entry.dart';

const _samplePath = 'test/fixtures/sample_01.pdf';

final _missing = File(_samplePath).existsSync()
    ? false
    : 'sample_01 pdf not found — place it at $_samplePath';

/// The sample schedule as a picked file.
XFile _sample() =>
    XFile.fromData(File(_samplePath).readAsBytesSync(), name: 'schedule.pdf');

/// The viewmodel owns no platform resource, so these tests never dispose
/// it — the factory just wires the clock and the store.
///
/// The clock reads midnight; the time-bound views (`Ahora`, `A punto de
/// comenzar`) are off by the default choice, so only the tests that ask
/// for them act on it.
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

/// Walks the choice back to "nothing filters": every room, the whole
/// day, both kinds of slot — so a test sees the pick's own effect
/// instead of the defaults' (labs starting soon, booked only).
void _noFilters(ScannerViewModel viewModel) {
  viewModel
    ..setRoomType(RoomTypeChoice.all)
    ..setView(ViewChoice.all)
    ..setState(StateChoice.all);
}

/// An in-memory [SettingsStore]: what the viewmodel writes, [read] hands
/// straight back — no platform behind it.
class _FakeSettings implements SettingsStore {
  ScanSettings? stored;

  @override
  ScanSettings? read() => stored;

  @override
  Future<void> write(ScanSettings settings) async => stored = settings;
}

/// A viewmodel over the [FakeSettings] above, on the same midnight clock
/// as [_viewModel].
ScannerViewModel _storedViewModel(_FakeSettings settings) =>
    ScannerViewModel(clock: () => DateTime(2026, 1, 1), settings: settings);

void main() {
  test('extracts the text layer from a pdf file', () async {
    final viewModel = _viewModel();

    await viewModel.scan(_sample());

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNotNull);
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));
  }, skip: _missing);

  test('keeps only the booked cards, rooms in table order', () async {
    final viewModel = _viewModel();

    await viewModel.scan(_sample());
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

    await viewModel.scan(_sample());
    // The room grouping — this test reads the room names under each block.
    viewModel.setSort(SortMode.roomThenTime, SortOrder.ascending);

    final sections = viewModel.sectionsByBlock;
    expect(sections, isNotEmpty);

    final blockNames = <String>[];
    final loose = <String>[];
    var seenLoose = false;
    for (final section in sections) {
      if (section.rooms.isEmpty) {
        // A room the campus map does not know keeps its own single heading,
        // and only ever after the blocks.
        seenLoose = true;
        loose.add(section.title);
        expect(blockOf(section.title), isNull);
        continue;
      }

      expect(seenLoose, isFalse, reason: '${section.title} follows a room');
      expect(section.title, startsWith('Bloque '));
      final block = section.title.substring('Bloque '.length);
      blockNames.add(block);
      for (final room in section.rooms.keys) {
        expect(
          blockOf(room),
          block,
          reason: '$room does not belong to block $block',
        );
      }
      // Blocks group rooms, so one heading over no rooms would be a lie.
      expect(section.rooms, isNotEmpty);
      expect(section.entries, isEmpty);
    }

    // Alphabetical, only the blocks that occur, and at least one of them.
    expect(blockNames, isNotEmpty);
    expect(blockNames, equals([...blockNames]..sort()));
    // This sample has no F/G/H buildings; every other letter A…K has booked
    // rooms, and the three sports rooms that do book sit under the named
    // POLIDEPORTIVO block.
    expect(blockNames, [
      'A',
      'B',
      'C',
      'D',
      'E',
      'I',
      'J',
      'K',
      'POLIDEPORTIVO',
    ]);
    // Every room the sample prints is on the campus map, so no fallback
    // section is left over.
    expect(loose, isEmpty);

    // Every booked card lands in the block layout exactly once.
    expect(
      _cardCount(sections),
      viewModel.entries.where((entry) => !entry.isFree).length,
    );
  }, skip: _missing);

  test(
    'the section filter starts with nothing picked, showing no section',
    () async {
      final viewModel = _viewModel();

      await viewModel.scan(_sample());
      // The choice off, so the pick's own effect is all that narrows here.
      _noFilters(viewModel);

      final sections = viewModel.sectionsByBlock;
      expect(sections, isNotEmpty);

      // Nothing starts picked: the card list is empty, so the view shows
      // its "Selecciona un bloque." prompt instead of every section.
      expect(viewModel.sectionFilter.selected, isNull);
      expect(viewModel.visibleSectionsByBlock, isEmpty);

      // Picking a section narrows the card list to it — the chip row keeps
      // them all, so the pick can be moved or undone...
      final first = sections.first;
      viewModel.selectSection(first.title);
      expect(viewModel.visibleSectionsByBlock, [first]);
      expect(viewModel.sectionsByBlock, sections);
      expect(viewModel.sectionFilter.selected, first.title);

      // ...another chip replaces it: one section at a time...
      final second = sections[1];
      viewModel.selectSection(second.title);
      expect(viewModel.visibleSectionsByBlock, [second]);
      expect(viewModel.sectionFilter.selected, second.title);

      // ...and tapping the pick again empties it, which brings the prompt
      // back rather than every section.
      viewModel.selectSection(second.title);
      expect(viewModel.sectionFilter.selected, isNull);
      expect(viewModel.visibleSectionsByBlock, isEmpty);
    },
    skip: _missing,
  );

  test('a new scan forgets the previous pick', () async {
    final viewModel = _viewModel();

    await viewModel.scan(_sample());
    _noFilters(viewModel);
    viewModel.selectSection(viewModel.sectionsByBlock.first.title);
    // Narrowed to just the pick.
    expect(viewModel.visibleSectionsByBlock, hasLength(1));

    await viewModel.scan(_sample());

    // The pick is dropped: no chip outlives its scan, so the new scan
    // starts back at the empty row — every section still on hand behind
    // the prompt, ready for a chip.
    expect(viewModel.sectionFilter.selected, isNull);
    expect(viewModel.visibleSectionsByBlock, isEmpty);
    expect(viewModel.sectionsByBlock, isNotEmpty);
  }, skip: _missing);

  test('starts on the default sort: time-then-room, ascending', () async {
    final viewModel = _viewModel();

    expect(viewModel.sortMode, SortMode.timeThenRoom);
    expect(viewModel.sortOrder, SortOrder.ascending);

    await viewModel.scan(_sample());

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

    await viewModel.scan(_sample());
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

    await viewModel.scan(_sample());
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

  test('the chip pick survives a sort change', () async {
    final viewModel = _viewModel();

    await viewModel.scan(_sample());
    _noFilters(viewModel);
    final titles = [
      for (final section in viewModel.sectionsByBlock) section.title,
    ];

    viewModel.selectSection(titles.first);
    expect(viewModel.visibleSectionsByBlock, hasLength(1));

    viewModel.setSort(SortMode.timeThenRoom, SortOrder.descending);

    // Both modes keep the same top-level titles, so the pick still points at
    // the same section and the chips need no reshuffling.
    expect(viewModel.sectionFilter.selected, titles.first);
    expect(
      [for (final section in viewModel.visibleSectionsByBlock) section.title],
      [titles.first],
    );
    expect([
      for (final section in viewModel.sectionsByBlock) section.title,
    ], titles);
  }, skip: _missing);

  test('a new scan keeps the sort', () async {
    final viewModel = _viewModel();

    await viewModel.scan(_sample());
    viewModel.setSort(SortMode.roomThenTime, SortOrder.descending);

    await viewModel.scan(_sample());

    // The choice outlives the scan — persisted now, reset only by hand —
    // and the grouping follows it: in room mode a block's sub-headings
    // are rooms, not start times.
    expect(viewModel.sortMode, SortMode.roomThenTime);
    expect(viewModel.sortOrder, SortOrder.descending);
    expect(
      viewModel.sectionsByBlock
          .expand((section) => section.rooms.keys)
          .any((key) => RegExp(r'^\d').hasMatch(key)),
      isFalse,
    );
  }, skip: _missing);

  test('scan is a no-op without a file', () async {
    final viewModel = _viewModel();

    await viewModel.scan(null);

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNull);
    expect(viewModel.entries, isEmpty);
    expect(viewModel.sectionsByBlock, isEmpty);
  });

  group('filters', () {
    /// Every card the chip row can show, walked one section at a time —
    /// the row itself only ever holds one pick.
    List<ScheduleEntry> visibleCards(ScannerViewModel viewModel) {
      final cards = <ScheduleEntry>[];
      for (final section in viewModel.sectionsByBlock) {
        viewModel.selectSection(section.title);
        cards.addAll(_cards(viewModel.visibleSectionsByBlock));
      }
      return cards;
    }

    test('a scan starts from the default choice', () async {
      final viewModel = _viewModel();

      await viewModel.scan(_sample());

      // The labs about to start, booked slots only — what a fresh install
      // shows — under the time-first ascending sort.
      expect(viewModel.choice, ScanSettings.defaults);
      final filters = viewModel.filters;
      expect(filters.roomType, RoomTypeChoice.labs);
      expect(filters.view, ViewChoice.soon);
      expect(filters.state, StateChoice.busy);
      expect(viewModel.sortMode, SortMode.timeThenRoom);
      expect(viewModel.sortOrder, SortOrder.ascending);
      // The defaults are exactly the first preset's choice, so a fresh
      // install opens already under a named preset.
      expect(viewModel.activePreset, presets[0]);
      expect(ScanSettings.defaults, presets[0].settings);
    }, skip: _missing);

    test('the default list is the booked compute labs opening soon', () async {
      // The default view (`Inicios próximos`) reads the clock, so this
      // one runs at 10:05: every future start qualifies, plus the last
      // ten minutes.
      final now = DateTime(2026, 1, 1, 10, 5);
      final viewModel = ScannerViewModel(clock: () => now);

      await viewModel.scan(_sample());

      final cards = visibleCards(viewModel);
      // The sample books compute labs…
      expect(cards, isNotEmpty);
      // …and that is all that shows: no other room, no free slot, and —
      // under the default view — only starts still ahead or just begun.
      expect([
        for (final card in cards) isComputeLab(card.room),
      ], everyElement(true));
      expect([for (final card in cards) card.isFree], everyElement(false));
      expect([
        for (final card in cards) isStartingSoon(card.start, now),
      ], everyElement(true));
      // The rest of the schedule is behind the choice: every room outside
      // the lab list and every start older than ten minutes never reaches
      // the list.
      expect(cards.length, lessThan(_cardCount(viewModel.sectionsByBlock)));
    }, skip: _missing);

    test('the Tipo de espacio choice picks the labs out and back', () async {
      final viewModel = _viewModel();
      await viewModel.scan(_sample());
      _noFilters(viewModel);

      final everything = visibleCards(viewModel);
      expect(everything.any((card) => isComputeLab(card.room)), isTrue);
      expect(everything.any((card) => !isComputeLab(card.room)), isTrue);

      viewModel.setRoomType(RoomTypeChoice.labs);

      final labs = visibleCards(viewModel);
      expect(labs, isNotEmpty);
      expect([
        for (final card in labs) isComputeLab(card.room),
      ], everyElement(true));
      expect(labs.length, lessThan(everything.length));

      viewModel.setRoomType(RoomTypeChoice.rooms);

      final rest = visibleCards(viewModel);
      expect(rest, isNotEmpty);
      expect([
        for (final card in rest) isComputeLab(card.room),
      ], everyElement(false));
      expect(rest.length, everything.length - labs.length);

      viewModel.setRoomType(RoomTypeChoice.all);

      expect(visibleCards(viewModel), hasLength(everything.length));
    }, skip: _missing);

    test('the Estado choice decides which slots exist as cards', () async {
      final viewModel = _viewModel();

      await viewModel.scan(_sample());
      // The view off: this section is the Estado choice's alone — the
      // default one reads the clock, which the cards below do not.
      viewModel.setView(ViewChoice.all);
      // The sample has both kinds of slot to filter.
      expect(viewModel.entries.any((entry) => entry.isFree), isTrue);
      expect(viewModel.entries.any((entry) => !entry.isFree), isTrue);

      // Solo ocupadas — the default: free slots are not cards at all,
      // neither in the list nor among the chips' sections.
      var cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards, isNotEmpty);
      expect([for (final card in cards) card.isFree], everyElement(false));

      viewModel.setState(StateChoice.all);

      // Both kinds now: the free cards join the booked ones, and a room
      // that only ever held free slots gets a section of its own.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards.any((card) => card.isFree), isTrue);
      expect(cards.any((card) => !card.isFree), isTrue);

      viewModel.setState(StateChoice.free);

      // Only the free slots remain — sections and list alike.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards, isNotEmpty);
      expect([for (final card in cards) card.isFree], everyElement(true));
      final visible = visibleCards(viewModel);
      expect(visible, isNotEmpty);
      expect([for (final card in visible) card.isFree], everyElement(true));

      viewModel.setState(StateChoice.busy);

      // Back to the default: the free cards are gone again.
      cards = _cards(viewModel.sectionsByBlock).toList();
      expect(cards, isNotEmpty);
      expect([for (final card in cards) card.isFree], everyElement(false));
      expect([
        for (final card in visibleCards(viewModel)) card.isFree,
      ], everyElement(false));
    }, skip: _missing);

    test('the Momento choice picks the part of the day', () async {
      final now = DateTime(2026, 1, 1, 10, 5);
      final viewModel = ScannerViewModel(clock: () => now);

      await viewModel.scan(_sample());
      // Only the view acts here — every room on the list, the free slots
      // out at their default state.
      viewModel.setRoomType(RoomTypeChoice.all);

      final booked = _cards(viewModel.sectionsByBlock).toList();
      final underway = [
        for (final card in booked)
          if (isOngoing(card.start, card.end, now)) card,
      ];
      final rest = [
        for (final card in booked)
          if (!isOngoing(card.start, card.end, now)) card,
      ];
      final startingSoon = [
        for (final card in booked)
          if (isStartingSoon(card.start, now)) card,
      ];
      // The sample runs sessions across the clock's hour and has more
      // still ahead.
      expect(underway, isNotEmpty);
      expect(rest, isNotEmpty);
      expect(startingSoon, isNotEmpty);

      // Ahora: only the cards whose printed range covers 10:05 stay — a
      // room with nothing underway drops out with them.
      viewModel.setView(ViewChoice.now);

      final shown = visibleCards(viewModel);
      expect(shown.length, underway.length);
      expect([
        for (final card in shown) isOngoing(card.start, card.end, now),
      ], everyElement(true));

      // Inicios próximos: every start still ahead, plus the last ten
      // minutes — the morning long past is out, the 10:00 card stays.
      viewModel.setView(ViewChoice.soon);

      final soon = visibleCards(viewModel);
      expect(soon.length, startingSoon.length);
      expect([
        for (final card in soon) isStartingSoon(card.start, now),
      ], everyElement(true));
      expect([for (final card in soon) card.start], isNot(contains('09:30')));
      expect([for (final card in soon) card.start], contains('10:00'));

      // Todo el día: the view stops filtering at all.
      viewModel.setView(ViewChoice.all);

      expect(visibleCards(viewModel), hasLength(booked.length));
    }, skip: _missing);

    test('the Momento choice can empty a pick and say why', () async {
      // After the last session of the day: every booked card is over, so
      // whichever section is picked empties under `Ahora`.
      final now = DateTime(2026, 1, 1, 23, 59);
      final viewModel = ScannerViewModel(clock: () => now);

      await viewModel.scan(_sample());
      // Only the view acts here: the rooms widen to every one, and the
      // view walks to `Todo el día` — the default would already be filtering
      // the section this test needs on screen first. The free slots stay out
      // at their default state — with free slots in, some room would
      // always hold something underway.
      viewModel.setRoomType(RoomTypeChoice.all);
      viewModel.setView(ViewChoice.all);

      final section = viewModel.sectionsByBlock.first;
      expect(_cards([section]), isNotEmpty);
      expect(
        _cards([section])
            .every((card) => !isOngoing(card.start, card.end, now)),
        isTrue,
      );
      viewModel.selectSection(section.title);
      expect(viewModel.visibleSectionsByBlock, isNotEmpty);

      viewModel.setView(ViewChoice.now);

      // A block *is* picked, so the view says why there is nothing.
      expect(viewModel.visibleSectionsByBlock, isEmpty);
      expect(viewModel.typeFilteredOut, isTrue);
    }, skip: _missing);

    test('the choices narrow inside the chip pick', () async {
      final viewModel = _viewModel();
      await viewModel.scan(_sample());
      _noFilters(viewModel);

      // A section with no compute lab in it — the sample's first block,
      // for one, but asked for rather than assumed.
      final section = viewModel.sectionsByBlock.firstWhere(
        (section) =>
            _cards([section]).every((card) => !isComputeLab(card.room)),
      );
      final titles = [for (final s in viewModel.sectionsByBlock) s.title];
      viewModel.selectSection(section.title);
      final selected = _cardCount(viewModel.visibleSectionsByBlock);
      expect(selected, greaterThan(0));

      // The labs on this section empties it — every card in it lives in
      // a lab-less room — and says why, since a block *is* picked.
      viewModel.setRoomType(RoomTypeChoice.labs);

      expect(viewModel.visibleSectionsByBlock, isEmpty);
      expect(viewModel.typeFilteredOut, isTrue);

      // The other way round, the section's own cards — none of them labs
      // — are all back.
      viewModel.setRoomType(RoomTypeChoice.rooms);

      expect(_cardCount(viewModel.visibleSectionsByBlock), selected);
      expect(viewModel.typeFilteredOut, isFalse);

      // Through all of it the section stayed in the chips' list.
      expect([for (final s in viewModel.sectionsByBlock) s.title], titles);
    }, skip: _missing);

    test('the choices filter inside a time group as well', () async {
      final viewModel = _viewModel();
      await viewModel.scan(_sample());
      _noFilters(viewModel);

      // A block holding both kinds of room, so the choice has something to
      // take away without emptying the pick.
      final section = viewModel.sectionsByBlock.firstWhere(
        (section) =>
            _cards([section]).any((card) => isComputeLab(card.room)) &&
            _cards([section]).any((card) => !isComputeLab(card.room)),
      );
      viewModel.selectSection(section.title);

      final before = _cardCount(viewModel.visibleSectionsByBlock);
      viewModel.setRoomType(RoomTypeChoice.labs);

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

    test(
      'a preset applies its whole choice, and names itself active',
      () async {
        final viewModel = _viewModel();

        await viewModel.scan(_sample());

        // The defaults fit the first preset — `Laboratorios por empezar`…
        expect(viewModel.activePreset, presets[0]);

        viewModel.applyPreset(presets[1]); // Aulas libres ahora

        // …one tap puts the whole choice on another, and the name follows.
        expect(viewModel.choice, presets[1].settings);
        expect(viewModel.activePreset, presets[1]);
        expect(viewModel.roomType, RoomTypeChoice.rooms);
        expect(viewModel.view, ViewChoice.now);
        expect(viewModel.state, StateChoice.free);
        expect(viewModel.sortMode, SortMode.roomThenTime);
        // The sections followed the state choice: free slots only.
        expect([
          for (final card in _cards(viewModel.sectionsByBlock)) card.isFree,
        ], everyElement(true));

        // One field moved off the preset and the name is gone again.
        viewModel.setSort(SortMode.timeThenRoom, SortOrder.ascending);

        expect(viewModel.activePreset, isNull);
      },
      skip: _missing,
    );

    test('a new scan keeps the choice and clears the pick', () async {
      final viewModel = _viewModel();
      await viewModel.scan(_sample());
      _noFilters(viewModel);
      expect(viewModel.choice, isNot(ScanSettings.defaults));
      expect(viewModel.state, StateChoice.all);
      viewModel.selectSection(viewModel.sectionsByBlock.first.title);
      expect(viewModel.sectionFilter.selected, isNotNull);

      await viewModel.scan(_sample());

      // The choice outlives the scan now — only the pick starts over, so
      // the prompt shows until a chip is chosen.
      expect(viewModel.choice, isNot(ScanSettings.defaults));
      expect(viewModel.state, StateChoice.all);
      expect(viewModel.typeFilteredOut, isFalse);
      expect(viewModel.visibleSectionsByBlock, isEmpty); // chips went too
      expect(viewModel.sectionFilter.selected, isNull);
    }, skip: _missing);
  });

  group('persistence', () {
    test('a fresh viewmodel starts from the stored choice', () async {
      final settings = _FakeSettings()
        ..stored = const ScanSettings(
          sortMode: SortMode.roomThenTime,
          sortOrder: SortOrder.descending,
          roomType: RoomTypeChoice.rooms,
          view: ViewChoice.soon,
          state: StateChoice.all,
        );
      final viewModel = _storedViewModel(settings);

      await viewModel.scan(_sample());

      // The stored snapshot is the whole state — the five fields, nothing
      // derived.
      expect(viewModel.choice, settings.stored);
      expect(viewModel.roomType, RoomTypeChoice.rooms);
      expect(viewModel.view, ViewChoice.soon);
      expect(viewModel.state, StateChoice.all);
      // And the grouping follows the stored sort — in room mode a block's
      // sub-headings are rooms, not start times.
      expect(
        viewModel.sectionsByBlock
            .expand((section) => section.rooms.keys)
            .any((key) => RegExp(r'^\d').hasMatch(key)),
        isFalse,
      );
      // With `Libres y ocupadas`, free slots are cards.
      expect([
        for (final card in _cards(viewModel.sectionsByBlock)) card.isFree,
      ], contains(true));
    }, skip: _missing);

    test('every choice is written back as it is made', () async {
      final settings = _FakeSettings();
      final viewModel = _storedViewModel(settings);

      await viewModel.scan(_sample());
      viewModel.setSort(SortMode.roomThenTime, SortOrder.descending);

      expect(settings.stored!.sortMode, SortMode.roomThenTime);
      expect(settings.stored!.sortOrder, SortOrder.descending);
      // The untouched sections come along as they stand — the defaults
      // from the scan before the first change.
      expect(settings.stored!.roomType, RoomTypeChoice.labs);
      expect(settings.stored!.view, ViewChoice.soon);
      expect(settings.stored!.state, StateChoice.busy);

      viewModel.setState(StateChoice.free);

      // The new field written, the sort kept…
      expect(
        settings.stored,
        const ScanSettings(
          sortMode: SortMode.roomThenTime,
          sortOrder: SortOrder.descending,
          roomType: RoomTypeChoice.labs,
          view: ViewChoice.soon,
          state: StateChoice.free,
        ),
      );
      viewModel.setRoomType(RoomTypeChoice.all);
      expect(settings.stored!.roomType, RoomTypeChoice.all);
      viewModel.setView(ViewChoice.soon);
      expect(settings.stored!.view, ViewChoice.soon);
    }, skip: _missing);
  });
}
