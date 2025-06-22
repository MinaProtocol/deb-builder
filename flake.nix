{
  description = "mina deb builder dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      overlay = final: prev: {
        dune_3 = prev.dune_3.overrideAttrs (old: {
          version = "3.19.1";
          src = prev.fetchFromGitHub {
            owner = "ocaml";
            repo = "dune";
            rev = "3.19.1";
            sha256 = "sha256-iM5sfmX/5BaefESrFy9gXabVTg03n4nXne2haR0ZDy4=";
          };
        });
        dune = final.dune_3; # ensure top-level dune points to dune_3

        ocaml-ng = prev.ocaml-ng // {
          ocamlPackages_4_14 = prev.ocaml-ng.ocamlPackages_4_14.overrideScope' (oself: osuper: {
            dune_3 = final.dune_3;
            dune = final.dune_3;
          });
        };
      };
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          ocamlPackages.ocaml
          ocamlPackages.dune
          ocamlPackages.core
          ocamlPackages.async
          ocamlPackages.dolog
          ocamlPackages.fileutils
          ocamlPackages.jingoo
          ocamlPackages.ppx_jane
          ocamlPackages.findlib
          ocamlPackages.yojson
          ocamlPackages.ppx_deriving_yojson
          ocamlPackages.re2
          ocamlPackages.alcotest
        ];
      };
    };
}
