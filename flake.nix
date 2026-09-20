{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
      };
    in
    {
      packages.${system} =
        let
          targets = [
            "linux"
            "web"
          ];
          packages = lib.genAttrs targets (
            target:
            pkgs.callPackage ./nix/package.nix {
              targetFlutterPlatform = target;
            }
          );
        in
        packages
        // {
          default = packages.linux;
        };

      devShells.${system}.default = pkgs.callPackage ./nix/shell.nix { };

      formatter.${system} = pkgs.callPackage ./nix/formatter.nix { };

      checks.${system} = self.packages.${system};
    };
}
