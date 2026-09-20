{
  mkShell,
  callPackage,
  androidenv,
  google-chrome,
  jdk21,
  just,
  yj,
}:
let
  mainPkg = callPackage ./package.nix { };

  androidComposition = androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [ "36.0.0" ];
    platformToolsVersion = "37.0.1";
    cmdLineToolsVersion = "22.0";
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ];

    abiVersions = [
      "armeabi-v7a"
      "arm64-v8a"
    ];

    extraLicenses = [
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
      "android-googlexr-license"
    ];
  };

  androidSdk = androidComposition.androidsdk;
in
mkShell {
  inputsFrom = [ mainPkg ];

  packages = [
    google-chrome
    jdk21
    androidSdk
    just
    yj
  ];

  ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
}
