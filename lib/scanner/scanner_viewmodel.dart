import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sched_scan/schedule/models/schedule_source.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ScannerViewModel extends ChangeNotifier {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  String? _recognizedText;
  String? get recognizedText => _recognizedText;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> scan(ScheduleSource? source) async {
    if (source == null) return;

    _isScanning = true;
    notifyListeners();

    try {
      _recognizedText = switch (source) {
        ScheduleImage(:final file) => await _scanImage(file),
        SchedulePdf(:final file) => await _scanPdf(file),
      };
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<String> _scanImage(XFile file) async {
    final input = InputImage.fromFilePath(file.path);
    final result = await _textRecognizer.processImage(input);
    return result.text;
  }

  Future<String> _scanPdf(XFile file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();

    document.dispose();
    return text;
  }
}
