{
  description = "Dev shell with OCaml 4.14.2 and Dune 3.3.1";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;
      dune = ocamlPackages.dune_3.overrideAttrs (old: {
        version = "3.3.1";
        src = pkgs.fetchFromGitHub {
          owner = "ocaml";
          repo = "dune";
          rev = "3.3.1";
          sha256 = "sha256-k5+MLyDAU8uQjq4cKjsyk7u06e/GyGS5gxqR3MCsVwA="; # Replace if hash mismatch
        };
      });
      devDeps = [
        ocamlPackages.ocaml
        dune
        ocamlPackages.findlib
        ocamlPackages.dolog 
        ocamlPackages.fileutils 
        ocamlPackages.jingoo
        # Add your additional OCaml dependencies below:
        # ocamlPackages.core
        # ocamlPackages.async
      ];
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = devDeps;
        shellHook = ''
          echo "OCaml: $(ocamlc -version), Dune: $(dune --version)"
        '';
      };
    };
}
