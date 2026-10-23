import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ScheduleViewModel extends ChangeNotifier {
  XFile? _file;

  /// The picked PDF, or null while nothing has been picked yet.
  XFile? get file => _file;

  Future<void> pickPdf() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final path = result?.path;
    if (path == null) return;

    _file = XFile(path);
    notifyListeners();
  }
}
