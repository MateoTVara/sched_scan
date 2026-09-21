import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/schedule/models/schedule_image.dart';

class ScannerViewModel extends ChangeNotifier {
  final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  String? _recognizedText;
  String? get recognizedText => _recognizedText;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> scanImage(ScheduleImage image) async {
    final file = image.file;
    if (file == null) return;

    final inputImage = InputImage.fromFilePath(file.path);
    final result = await _textRecognizer.processImage(inputImage);
    _recognizedText = result.text;
    notifyListeners();
  }
}
