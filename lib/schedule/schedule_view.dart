import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_view.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

/// The picked file's preview as slivers — and, while nothing has been
/// picked yet, the initial prompt that opens the app.
class ScheduleView extends StatelessWidget {
  final ScheduleViewModel viewModel;

  const ScheduleView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return switch (viewModel.source) {
          // Nothing picked: both opening lines as one block filling the
          // viewport, so they sit centred on the screen instead of two
          // slivers stacked at the top. They always show together at this
          // point — the scanner has nothing to add while there is no
          // source, so `main.dart` leaves it out until one exists.
          null => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Selecciona un archivo.'),
                  ScannerView.noTextMessage,
                ],
              ),
            ),
          ),
          ScheduleImage(:final file) => SliverToBoxAdapter(
            child: Center(child: Image.file(File(file.path))),
          ),
          SchedulePdf() => const SliverToBoxAdapter(
            child: Center(child: Icon(Icons.picture_as_pdf, size: 64)),
          ),
        };
      },
    );
  }
}
