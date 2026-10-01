{
  lib,
  flutter,
  targetFlutterPlatform ? "linux",
}:
flutter.buildFlutterApplication {
  pname = "sched_scan";
  version = "0.1.1";

  src = ../.;

  pubspecLock = lib.importJSON ../pubspec.lock.json;

  inherit targetFlutterPlatform;
}
