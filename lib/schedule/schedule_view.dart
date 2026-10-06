import 'package:flutter/material.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

/// The app's opening prompt as slivers, shown while nothing has been picked
/// yet. Once a source exists this view stands aside — the picked file gets
/// no preview, `ScannerView` shows the scan instead.
class ScheduleView extends StatelessWidget {
  final ScheduleViewModel viewModel;

  const ScheduleView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        // A source exists: no preview of the file — `main.dart` joins
        // ScannerView in right after this sliver, and its spinner or
        // cards are the whole show.
        if (viewModel.source != null) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('Selecciona un archivo.')),
        );
      },
    );
  }
}
