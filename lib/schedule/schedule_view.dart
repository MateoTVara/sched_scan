import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

class ScheduleView extends StatelessWidget {
  final ScheduleViewModel viewModel;

  const ScheduleView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return switch (viewModel.source) {
          null => const Text('Selecciona un archivo.'),
          ScheduleImage(:final file) => Image.file(File(file.path)),
          SchedulePdf() => const Icon(Icons.picture_as_pdf, size: 64),
        };
      },
    );
  }
}
