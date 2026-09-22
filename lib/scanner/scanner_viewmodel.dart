import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/schedule/models/schedule_image.dart';

class ScannerViewModel extends ChangeNotifier {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  RecognizedText? _recognizedText;
  RecognizedText? get recognizedText => _recognizedText;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> scanImage(ScheduleImage image) async {
    final file = image.file;
    if (file == null) return;

    _isScanning = true;
    notifyListeners();

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}
