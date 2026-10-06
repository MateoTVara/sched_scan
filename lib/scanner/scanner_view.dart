import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/entries_view.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

class ScannerView extends StatelessWidget {
  final ScannerViewModel viewModel;

  const ScannerView({super.key, required this.viewModel});

  /// The fallback line when nothing was recognized.
  static const noTextMessage = Text('No se reconoció texto');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        // The body is one CustomScrollView, so every state here is a sliver.
        return switch ((
          viewModel.isScanning,
          viewModel.entries.isNotEmpty,
          viewModel.recognizedText,
        )) {
          (true, _, _) => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          // Something parsed, so show the cards — even when every slot in
          // the document turned out to be free.
          (_, true, _) => EntriesView(
            sections: viewModel.visibleSectionsByBlock,
            hasBookings: viewModel.sectionsByBlock.isNotEmpty,
            filter: viewModel.sectionFilter,
          ),
          (_, false, final String text) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(text)),
          ),
          _ => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: noTextMessage),
          ),
        };
      },
    );
  }
}
