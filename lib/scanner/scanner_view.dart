import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

class ScannerView extends StatelessWidget {
  final ScannerViewModel viewModel;

  const ScannerView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final text = viewModel.recognizedText;

        print(text);

        return Text(
          text == null
            ? 'No text recognized'
            : text
        );
      }
    );
  }
}
