import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';

const _samplePath =
    '/home/marun/Downloads/DISTRIBUCIÓN DE AMBIENTES - 24_09_2026.pdf';

void main() {
  test('extracts the text layer from a pdf source', () async {
    final bytes = File(_samplePath).readAsBytesSync();
    final viewModel = ScannerViewModel();

    await viewModel.scan(
      SchedulePdf(XFile.fromData(bytes, name: 'schedule.pdf')),
    );

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNotNull);
    expect(viewModel.recognizedText, contains('DISTRIBUCIÓN'));
  }, skip: File(_samplePath).existsSync() ? false : 'sample pdf not found');

  test('scan is a no-op without a source', () async {
    final viewModel = ScannerViewModel();

    await viewModel.scan(null);

    expect(viewModel.isScanning, isFalse);
    expect(viewModel.recognizedText, isNull);
  });

  // The ScheduleImage branch goes through ML Kit, which only ships
  // Android/iOS implementations, so it cannot be exercised host-side.
}
