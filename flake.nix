{
  description = "A flake wrapper around elm-watch.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };

    npm-fix = {
      url = "github:jeslie0/npm-lockfile-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, npmlock2nix, npm-fix }:
    let
      supportedSystems =
        [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

      forAllSystems =
        nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays =
            [ (final: prev: {
              npmlock2nix = import npmlock2nix { pkgs = prev; };
            }) ];
        }
      );

      elm-watch-version =
        "v1.1.2";

      elm-watch-repo = system:
        nixpkgsFor.${system}.fetchFromGitHub {
          owner = "lydell";
          repo = "elm-watch";
          rev = elm-watch-version;
          hash = "sha256-TOkX1V64uXJRBZzZccrKuodBOyXLOMXwZu3hsVvjaWI=";
        };

      patched-elm-watch = system:
        nixpkgsFor.${system}.stdenvNoCC.mkDerivation {
          pname = "elm-watch-src";
          version = elm-watch-version;
          src = elm-watch-repo system;
          patches = [ ./package.json.patch ];
          installPhase = ''
            mkdir $out
            cp -r * $out
            rm $out/package-lock.json
            cp ${./package-lock.json} $out/package-lock.json
          '';
        };

      elm-watch = system:
        nixpkgsFor.${system}.npmlock2nix.v2.build {
          src = patched-elm-watch system;
          installPhase = "mkdir $out; cp -r . $out";
          buildCommands = [ "npm run build" ];
        };
    in
      {
        packages =
          forAllSystems (system:
            let
              pkgs =
                nixpkgsFor.${system};
            in
              {
                default = self.packages.${system}.elm-watch;
                elm-watch = pkgs.stdenvNoCC.mkDerivation rec {
                  pname = "elm-watch";
                  version = elm-watch-version;
                  src = elm-watch system;
                  nativeBuildInputs = [ pkgs.makeWrapper ];
                  installPhase = ''
                         mkdir -p $out/bin
                         makeWrapper ${src}/build/index.js elm-watch \
                         --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.elmPackages.elm ]}

                         cp elm-watch $out/bin
                         '';
                };
              }
          );

        devShells =
          forAllSystems (system:
            let
              pkgs =
                nixpkgsFor.${system};
            in
              {
                default =
                  pkgs.mkShell {
                    packages = [npm-fix.packages.${system}.default];
                  };
              }
          );
      };
}
