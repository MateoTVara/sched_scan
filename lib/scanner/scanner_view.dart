import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entries_view.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

class ScannerView extends StatelessWidget {
  final ScannerViewModel viewModel;

  const ScannerView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return switch ((
          viewModel.isScanning,
          viewModel.entries.isNotEmpty,
          viewModel.entriesByRoom,
          viewModel.recognizedText,
        )) {
          (true, _, _, _) => const CircularProgressIndicator(),
          // Something parsed, so show the cards — even when every slot in
          // the document turned out to be free.
          (_, true, final bookings, _) => EntriesView(entriesByRoom: bookings),
          (_, false, _, final String text) => Text(text),
          _ => const Text('No text recognized'),
        };
      },
    );
  }
}
