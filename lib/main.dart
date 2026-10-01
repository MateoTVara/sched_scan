import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_view.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/schedule_view.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

enum InputMode { image, pdf }

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _scheduleViewModel = ScheduleViewModel();
  final _scannerViewModel = ScannerViewModel();

  InputMode _mode = InputMode.pdf;

  void _toggleMode() {
    setState(() {
      _mode = _mode == InputMode.image ? InputMode.pdf : InputMode.image;
    });
  }

  Future<void> _process() async {
    switch (_mode) {
      case InputMode.image:
        await _scheduleViewModel.pickImage();
      case InputMode.pdf:
        await _scheduleViewModel.pickPdf();
    }
    await _scannerViewModel.scan(_scheduleViewModel.source);
  }

  @override
  void dispose() {
    _scheduleViewModel.dispose();
    _scannerViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Schedule Scanner',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
              onPressed: _toggleMode,
              icon: const Icon(Icons.sync_alt, color: Colors.white),
              tooltip: 'Cambiar entre imagen y PDF',
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _scheduleViewModel,
          // The app bar covers the top inset; at the bottom the body must
          // end above the (translucent) system navigation bar instead of
          // scrolling behind it — the FAB already clears it on its own.
          builder: (context, _) => SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                ScheduleView(viewModel: _scheduleViewModel),
                // While no source exists, ScheduleView fills the viewport
                // with the initial prompt and the scanner has nothing to
                // show — it only joins once there is something to scan.
                if (_scheduleViewModel.source != null)
                  ScannerView(viewModel: _scannerViewModel),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _process,
          child: Icon(
            _mode == InputMode.image ? Icons.image : Icons.picture_as_pdf,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
