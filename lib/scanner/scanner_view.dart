import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entries_view.dart';
import 'package:sched_scan/scanner/grouping.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

class ScannerView extends StatelessWidget {
  final ScannerViewModel viewModel;
  final Grouping grouping;

  const ScannerView({
    super.key,
    required this.viewModel,
    required this.grouping,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return switch ((
          viewModel.isScanning,
          viewModel.entries.isNotEmpty,
          grouping,
          viewModel.recognizedText,
        )) {
          (true, _, _, _) => const CircularProgressIndicator(),
          // Something parsed, so show the cards — even when every slot in
          // the document turned out to be free.
          (_, true, Grouping.room, _) => EntriesView(
            sections: viewModel.sectionsByRoom,
          ),
          (_, true, Grouping.block, _) => EntriesView(
            sections: viewModel.sectionsByBlock,
          ),
          (_, false, _, final String text) => Text(text),
          _ => const Text('No se reconoció texto'),
        };
      },
    );
  }
}
