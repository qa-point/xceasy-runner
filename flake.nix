{
  description = "XCEasy Runner command-line tool";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/ac6b2166e7a9375683b8e98f860f273222337b16";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = function:
        builtins.listToAttrs (map (system: {
          name = system;
          value = function system;
        }) systems);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          metadata = builtins.fromJSON (builtins.readFile ./release-metadata.json);
        in {
          xceasyctl = pkgs.stdenv.mkDerivation {
            pname = "xceasyctl";
            version = metadata.version;
            src = pkgs.lib.cleanSourceWith {
              src = self;
              filter = path: type:
                let name = builtins.baseNameOf path;
                in !(builtins.elem name [ ".git" ".build" "dist" "result" ".DS_Store" ]);
            };

            nativeBuildInputs = [ pkgs.swift pkgs.swiftpm pkgs.makeWrapper ];

            buildPhase = ''
              runHook preBuild
              swift build --configuration release --product xceasyctl
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              binary_path=$(swift build --configuration release --show-bin-path)
              install -Dm755 "$binary_path/xceasyctl" "$out/libexec/xceasyctl/xceasyctl"
              install -Dm755 bin/xceasy "$out/libexec/xceasy-runner/bin/xceasy"
              mkdir -p "$out/libexec/xceasy-runner/scripts/lib" "$out/libexec/xceasy-runner/schemas"
              find scripts -maxdepth 1 -type f \( -name '*.sh' -o -name '*.json' \) \
                -exec install -m755 {} "$out/libexec/xceasy-runner/scripts/" \;
              find scripts/lib -maxdepth 1 -type f \
                -exec install -m755 {} "$out/libexec/xceasy-runner/scripts/lib/" \;
              find schemas -maxdepth 1 -type f -name '*.json' \
                -exec install -m644 {} "$out/libexec/xceasy-runner/schemas/" \;
              install -m644 release-metadata.json "$out/libexec/xceasy-runner/release-metadata.json"
              makeWrapper "$out/libexec/xceasyctl/xceasyctl" "$out/bin/xceasyctl" \
                --set XCEASY_RUNNER_ROOT "$out/libexec/xceasy-runner" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.gnugrep pkgs.gnused pkgs.jq ]}
              runHook postInstall
            '';

            doInstallCheck = true;
            installCheckPhase = ''
              "$out/bin/xceasyctl" version | grep -F "${metadata.version}"
            '';

            meta = {
              description = "Runner for XCEasy-based UI tests on Apple devices";
              homepage = "https://github.com/qa-point/xceasy-runner";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "xceasyctl";
              platforms = pkgs.lib.platforms.darwin;
            };
          };
          default = self.packages.${system}.xceasyctl;
        });

      apps = forAllSystems (system: {
        xceasyctl = {
          type = "app";
          program = "${self.packages.${system}.xceasyctl}/bin/xceasyctl";
          meta.description = "Run XCEasy-based UI tests";
        };
        default = self.apps.${system}.xceasyctl;
      });
    };
}
