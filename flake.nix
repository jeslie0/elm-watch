{
  description = "A flake wrapper around elm-watch.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    npmlock2nix = {
      url = github:nix-community/npmlock2nix;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, npmlock2nix }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              npmlock2nix = import npmlock2nix { pkgs = prev; };
            })
          ];
        };
        elm-watch-version = "v1.1.2";
        elm-watch-repo = pkgs.fetchFromGitHub {
          owner = "lydell";
          repo = "elm-watch";
          rev = elm-watch-version;
          hash = "sha256-TOkX1V64uXJRBZzZccrKuodBOyXLOMXwZu3hsVvjaWI=";
        };
        patched-elm-watch = pkgs.stdenvNoCC.mkDerivation {
          pname = "elm-watch-src";
          version = elm-watch-version;
          src = elm-watch-repo;
          patches = [ ./packages.patch ];
          installPhase = "mkdir $out; cp -r * $out";
        };
        elm-watch = pkgs.npmlock2nix.v2.build {
            src = patched-elm-watch;
            installPhase = "mkdir $out; cp -r . $out";
            buildCommands = [ "npm run build" ];
          };
      in
      {
        packages = {
          default = self.packages.${system}.elm-watch;
          elm-watch = pkgs.stdenvNoCC.mkDerivation rec {
            pname = "elm-watch";
            version = elm-watch-version;
            src = elm-watch;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
                         mkdir -p $out/bin
                         makeWrapper ${src}/build/index.js elm-watch \
                         --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.elmPackages.elm ]}

                         cp elm-watch $out/bin
                         '';
          };
        };
      }
    );
}
