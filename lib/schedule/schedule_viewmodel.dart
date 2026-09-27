import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';

class ScheduleViewModel extends ChangeNotifier {
  final _imagePicker = ImagePicker();

  ScheduleSource? _source;
  ScheduleSource? get source => _source;

  Future<void> pickImage() async {
    final result = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (result == null) return;

    _source = ScheduleImage(result);
    notifyListeners();
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final path = result?.path;
    if (path == null) return;

    _source = SchedulePdf(XFile(path));
    notifyListeners();
  }
}
