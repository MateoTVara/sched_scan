import 'package:flutter/material.dart';
import 'package:sched_scan/scanner/scanner_view.dart';
import 'package:sched_scan/scanner/scanner_viewmodel.dart';
import 'package:sched_scan/scanner/settings_store.dart';
import 'package:sched_scan/scanner/sort_menu.dart';
import 'package:sched_scan/schedule/schedule_view.dart';
import 'package:sched_scan/schedule/schedule_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The platform side has to be up before the first frame: the scanner
  // viewmodel reads the persisted choice synchronously, at its
  // construction below.
  final prefs = await SharedPreferences.getInstance();
  runApp(MainApp(settings: SharedPrefsSettingsStore(prefs)));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, this.settings});

  /// Where the scanner viewmodel keeps its sort and filter choices between
  /// scans and restarts; without one nothing is stored or restored.
  final SettingsStore? settings;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _scheduleViewModel = ScheduleViewModel();
  late final _scannerViewModel = ScannerViewModel(settings: widget.settings);

  Future<void> _process() async {
    await _scheduleViewModel.pickPdf();
    await _scannerViewModel.scan(_scheduleViewModel.file);
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
            // The chips belong to the scan on screen, so the way to drop
            // them all at once only makes sense while some are picked.
            ListenableBuilder(
              listenable: _scannerViewModel,
              builder: (context, _) => _scannerViewModel.hasSelection
                  ? IconButton(
                      onPressed: _scannerViewModel.clearSelection,
                      icon: const Icon(Icons.clear_all, color: Colors.white),
                      tooltip: 'Limpiar selección',
                    )
                  : const SizedBox.shrink(),
            ),
            // The sort menu only orders what a scan has produced — its
            // choice is persisted now (see `SettingsStore`), so it outlives
            // both the scan and the app, but there is still nothing to
            // order before one, and the button follows the scan.
            ListenableBuilder(
              listenable: _scannerViewModel,
              builder: (context, _) => _scannerViewModel.sectionsByBlock.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () => showSortMenu(context, _scannerViewModel),
                      icon: const Icon(Icons.sort, color: Colors.white),
                      tooltip: 'Ordenar',
                    ),
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
                // While nothing has been picked, ScheduleView fills the
                // viewport with the initial prompt and the scanner has
                // nothing to show — it only joins once there is something
                // to scan.
                if (_scheduleViewModel.file != null)
                  ScannerView(viewModel: _scannerViewModel),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _process,
          child: const Icon(Icons.picture_as_pdf),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
