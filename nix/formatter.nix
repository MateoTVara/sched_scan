{
  treefmt,
  nixfmt,
  flutter,
}:
treefmt.withConfig {
  runtimeInputs = [
    nixfmt
    flutter # flutter to not redownload another dart binary
  ];

  settings = {
    on-unmatched = "info";
    tree-root-file = "flake.nix";

    formatter = {
      nixfmt = {
        command = "nixfmt";
        includes = [ "*.nix" ];
      };

      # dart flutter wrapped
      dart = {
        command = "dart";
        options = [ "format" ];
        includes = [ "*.dart" ];
      };
    };
  };
}
