import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/grouping.dart';
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
  Grouping _grouping = Grouping.room;

  void _toggleMode() {
    setState(() {
      _mode = _mode == InputMode.image ? InputMode.pdf : InputMode.image;
    });
  }

  void _toggleGrouping() {
    setState(() {
      _grouping = _grouping == Grouping.room ? Grouping.block : Grouping.room;
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
            IconButton(
              onPressed: _toggleGrouping,
              icon: Icon(
                _grouping == Grouping.room
                    ? Icons.meeting_room
                    : Icons.apartment,
                color: Colors.white,
              ),
              tooltip: 'Agrupar por aula o bloque',
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ScheduleView(viewModel: _scheduleViewModel),
                ScannerView(viewModel: _scannerViewModel, grouping: _grouping),
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
