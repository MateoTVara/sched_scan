import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';

const _samplePath =
    'test/fixtures/sample.pdf';

final _missing = File(_samplePath).existsSync()
    ? false
    : 'sample pdf not found — place it at $_samplePath';

/// The sample schedule as a picked file.
XFile _sample() =>
    XFile.fromData(File(_samplePath).readAsBytesSync(), name: 'schedule.pdf');

/// Never disposed: closing the ML Kit recognizer reaches a plugin that does
/// not exist on the host, and no OCR runs in these tests to allocate one.
ScannerViewModel _viewModel() => ScannerViewModel();

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

    final byRoom = viewModel.entriesByRoom;
    expect(byRoom, isNotEmpty);
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
    final grouped = [for (final entries in byRoom.values) ...entries];
    expect(grouped, hasLength(booked.length));
    expect(grouped.where((entry) => entry.isFree), isEmpty);

    // Sections keep the order the first booked slot of each room appears in
    // the table; a room with nothing but free slots gets no section at all.
    expect(byRoom.keys.first, booked.first.room);
    final freeOnlyRooms = {
      for (final entry in viewModel.entries)
        if (entry.isFree) entry.room,
    }..removeWhere((room) => booked.any((entry) => entry.room == room));
    expect(byRoom.keys.toSet().intersection(freeOnlyRooms), isEmpty);

    // Slots inside a room are ordered by start time, missing times last.
    for (final room in byRoom.keys) {
      final entries = byRoom[room]!;
      for (var i = 1; i < entries.length; i++) {
        final previous = entries[i - 1].start;
        final current = entries[i].start;
        if (current == null) continue;
        expect(
          previous,
          isNotNull,
          reason: '$room: an entry without a time must come last',
        );
        expect(
          previous!.compareTo(current),
          lessThanOrEqualTo(0),
          reason: '$room is not sorted by start time',
        );
      }
    }
  }, skip: _missing);

  test('scan is a no-op without a source', () async {
    final viewModel = _viewModel();

    await viewModel.scan(null);

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNull);
    expect(viewModel.entries, isEmpty);
    expect(viewModel.entriesByRoom, isEmpty);
  });

  // The ScheduleImage branch goes through ML Kit, which only ships
  // Android/iOS implementations, so it cannot be exercised host-side.
}
