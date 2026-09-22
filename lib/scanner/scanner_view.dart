import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';

class ScannerView extends StatelessWidget {
  final ScannerViewModel viewModel;

  const ScannerView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return switch ((viewModel.isScanning, viewModel.recognizedText)) {
          (true, _) => const CircularProgressIndicator(),
          (_, null) => const Text('No text recognized'),
          (_, final RecognizedText text) => Text(text.text),
        };
      },
    );
  }
}
