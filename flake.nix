{
  description = "OCaml 4.14.2 + Dune 3.8.0 + deps dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      overlay = final: prev: {
        ocaml-ng = prev.ocaml-ng // {
          ocamlPackages_4_14 = prev.ocaml-ng.ocamlPackages_4_14.overrideScope' (oself: osuper: {
            dune = osuper.dune_3.overrideAttrs (old: {
              version = "3.8.0";
              src = prev.fetchFromGitHub {
                owner = "ocaml";
                repo = "dune";
                rev = "3.8.0";
                sha256 = "<replace-with-correct-hash>";
              };
            });
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
          ];
          shellHook = ''
            echo "OCaml: $(ocamlc -version)"
            echo "Dune: $(dune --version)"
          '';
        };
      };
}
