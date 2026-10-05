{
  inputs = {
     nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      erlang_version = "erlang_27";
    in
    {
      packages = eachSystem (
        pkgs:
        let
          erlang = pkgs.beam.interpreters.${erlang_version};
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              path: _type:
              !(builtins.elem (baseNameOf path) [
                "build"
                "node_modules"
                ".direnv"
              ]);
          };
          # Hex packages from manifest.toml, fetched once as a fixed-output derivation.
          # Update the hash whenever manifest.toml changes.
          deps = pkgs.stdenvNoCC.mkDerivation {
            name = "tidal-ai-playlist-deps";
            inherit src;
            nativeBuildInputs = [
              pkgs.gleam
              pkgs.cacert
            ];
            buildPhase = ''
              export HOME=$TMPDIR
              gleam deps download
            '';
            installPhase = ''
              mkdir -p $out
              cp -r build/packages $out/packages
              rm -f $out/packages/gleam.lock
            '';
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = "sha256-FJY2CqVF3adub2XCDWET5NNFJYrhNCRVs1t2xpP6fNY=";
          };
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "tidal-ai-playlist";
            version = "1.0.0";
            inherit src;
            nativeBuildInputs = [
              pkgs.gleam
              erlang
              pkgs.beam.packages.${erlang_version}.rebar3
              pkgs.makeWrapper
            ];
            buildPhase = ''
              export HOME=$TMPDIR
              mkdir -p build
              cp -r ${deps}/packages build/packages
              chmod -R u+w build
              gleam export erlang-shipment
            '';
            installPhase = ''
              mkdir -p $out/lib $out/bin
              cp -r build/erlang-shipment $out/lib/tidal-ai-playlist
              makeWrapper $out/lib/tidal-ai-playlist/entrypoint.sh $out/bin/tidal-ai-playlist \
                --prefix PATH : ${pkgs.lib.makeBinPath [ erlang pkgs.coreutils ]} \
                --add-flags run
            '';
            meta.mainProgram = "tidal-ai-playlist";
          };
        }
      );

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              gleam
              beam.interpreters.${erlang_version}
              beam.packages.${erlang_version}.rebar3
            ]
            ++ lib.optional stdenv.isLinux inotify-tools
            ++ (lib.optionals stdenv.isDarwin (
              with darwin.apple_sdk.frameworks;
              [
                CoreFoundation
                CoreServices
              ]
            ));
        };
      });
    };
}
