import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_view.dart';
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

        // Nothing picked: both opening lines as one block filling the
        // viewport, so they sit centred on the screen instead of two
        // slivers stacked at the top. They always show together at this
        // point — the scanner has nothing to add while there is no
        // source, so `main.dart` leaves it out until one exists.
        return const SliverFillRemaining(
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
        );
      },
    );
  }
}
