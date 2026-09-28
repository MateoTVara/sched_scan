import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';

const _samplePath =
    '/home/marun/Downloads/DISTRIBUCIÓN DE AMBIENTES - 24_09_2026.pdf';

final _missing = File(_samplePath).existsSync()
    ? false
    : 'sample pdf not found';

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

  test('groups parsed pdf entries by room', () async {
    final viewModel = _viewModel();

    await viewModel.scan(SchedulePdf(_sample()));

    final byRoom = viewModel.entriesByRoom;
    expect(byRoom, isNotEmpty);
    // The raw text stays available as the fallback for anything unparsed.
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));

    // Sections keep the order the table prints them in.
    expect(byRoom.keys.first, 'AULA DE ENSAYO 01');

    // Nothing is lost or duplicated by the grouping.
    final grouped = [for (final entries in byRoom.values) ...entries];
    expect(grouped, hasLength(viewModel.entries.length));
    expect(viewModel.entries.every((entry) => entry.start != null), isTrue);

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
