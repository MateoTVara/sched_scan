{
  mkShell,
  callPackage,
  androidenv,
  google-chrome,
  jdk21,
  just,
  yj,
  writeShellApplication,
  git,
  tree,
  gnused,
  coreutils,
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

  packages =
    let
      scripts = {
        mycommit = writeShellApplication {
          name = "mycommit";
          runtimeInputs = [
            git
            tree
            gnused
            coreutils
          ];
          text = /* bash */ ''
            TMP_DIR="temp"
            mkdir -p "$TMP_DIR"

            echo "Saving staged changes to $TMP_DIR/staged.diff..."
            git diff --staged > "$TMP_DIR/staged.diff"

            echo "Gathering commit history to $TMP_DIR/commits.log..."
            git log > "$TMP_DIR/commits.log"

            echo "Generating directory structure to $TMP_DIR/tree.log..."
            basename "$PWD" > "$TMP_DIR/tree.log"
            tree -a --dirsfirst -I '.git|temp' \
              | sed '1d' >> "$TMP_DIR/tree.log"

            echo "All information has been saved to $PWD/$TMP_DIR."
          '';
        };
      };
    in
    [
      google-chrome
      jdk21
      androidSdk
      just
      yj
    ]
    ++ builtins.attrValues scripts;

  ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
}
