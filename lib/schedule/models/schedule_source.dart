import 'package:cross_file/cross_file.dart';

sealed class ScheduleSource {
  final XFile file;
  const ScheduleSource(this.file);
}

class ScheduleImage extends ScheduleSource {
  const ScheduleImage(super.file);
}

class SchedulePdf extends ScheduleSource {
  const SchedulePdf(super.file);
}
