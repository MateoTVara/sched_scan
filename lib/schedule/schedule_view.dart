import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

class ScheduleView extends StatelessWidget {
  final ScheduleViewModel viewModel;

  const ScheduleView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final image = viewModel.scheduleImage.file;

        return image == null
            ? const Text('No image selected yet')
            : Image.file(File(image.path));
      },
    );
  }
}
