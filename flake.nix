{
  description = "Dev shell for Mina with OCaml 4.02.3 and Dune 3.1";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_02;
      dune = ocamlPackages.dune_3.overrideAttrs (old: {
        version = "3.1.0";
        src = pkgs.fetchFromGitHub {
          owner = "ocaml";
          repo = "dune";
          rev = "3.1.0";
          sha256 = "sha256-cfSeH7Ej6rGXOPFtjyK0tK6cmuT4Xt1rS4Q8IMkhwBs="; # Update if needed
        };
      });
      minaDeps = [
        ocamlPackages.ocaml
        dune
        ocamlPackages.findlib
        ocamlPackages.dolog 
        ocamlPackages.fileutils 
        ocamlPackages.jingoo
        # Add any additional dependencies below as needed:
        # ocamlPackages.core
        # ocamlPackages.async
        # etc.
      ];
    in {
      devShells."x86_64-linux" = pkgs.mkShell {
        buildInputs = minaDeps;
        shellHook = ''
          echo "Welcome to the Mina dev shell (OCaml 4.02.3 + Dune 3.1)"
        '';
      };
    };
}
