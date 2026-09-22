import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sched_scan/schedule/models/schedule_image.dart';

class ScheduleViewModel extends ChangeNotifier {
  final _imagePicker = ImagePicker();

  final ScheduleImage scheduleImage;

  ScheduleViewModel({required this.scheduleImage});

  Future<void> pickImage() async {
    final result = await _imagePicker.pickImage(source: ImageSource.gallery);

    if (result == null) return;

    scheduleImage.file = result;
    notifyListeners();
  }
}
