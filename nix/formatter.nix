{
  treefmt,
  nixfmt,
}:
treefmt.withConfig {
  runtimeInputs = [
    nixfmt
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
