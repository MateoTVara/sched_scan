{
  lib,
  flutter,
  targetFlutterPlatform ? "linux",
}:
flutter.buildFlutterApplication {
  pname = "sched_scan";
  version = "0.1.0";

  src = ../.;

  pubspecLock = lib.importJSON ../pubspec.lock.json;

  inherit targetFlutterPlatform;
}
