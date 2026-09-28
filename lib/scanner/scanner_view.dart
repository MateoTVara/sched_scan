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
          viewModel.entriesByRoom,
          viewModel.recognizedText,
        )) {
          (true, _, _) => const CircularProgressIndicator(),
          (_, final entries, _) when entries.isNotEmpty => EntriesView(
            entriesByRoom: entries,
          ),
          (_, _, final String text) => Text(text),
          _ => const Text('No text recognized'),
        };
      },
    );
  }
}
