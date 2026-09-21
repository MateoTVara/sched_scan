import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_view.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/schedule/models/schedule_image.dart';
import 'package:sched_scan/schedule/schedule_view.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _scheduleViewModel = ScheduleViewModel(
    scheduleImage: ScheduleImage(),
  );
  final _scannerViewModel = ScannerViewModel();

  Future<void> _process() async {
    await _scheduleViewModel.pickImage();
    await _scannerViewModel.scanImage(_scheduleViewModel.scheduleImage);
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
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ScheduleView(viewModel: _scheduleViewModel),
                ScannerView(viewModel: _scannerViewModel),               
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _process,
          child: Icon(Icons.image),
        ),
      ),
    );
  }
}

