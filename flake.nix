{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:adisbladis/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
    }:
    let
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      getPythonPackage =
        pkgs: version:
        let
          major = builtins.substring 0 1 version;
          minor = builtins.substring 2 2 version;
          packageName = "python${major}${minor}";
        in
        pkgs.${packageName} or pkgs.python3;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pythonVersion = pkgs.lib.removeSuffix "\n" (builtins.readFile ./.python-version);

        python = getPythonPackage pkgs pythonVersion;

        pyprojectOverrides = pkgs.callPackage ./pyproject-overrides.nix { };

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              pkgs.lib.composeManyExtensions [
                pyproject-build-systems.overlays.default
                overlay
                pyprojectOverrides
              ]
            );

        manifest = (pkgs.lib.importTOML ./pyproject.toml).project;
      in
      {
        devShells.default =
          let
            editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };
            editablePythonSet = pythonSet.overrideScope editableOverlay;

            virtualenv = editablePythonSet.mkVirtualEnv "${manifest.name}-dev-env" workspace.deps.all;
          in
          pkgs.mkShell {
            packages = [
              virtualenv
              pkgs.uv
              (pkgs.symlinkJoin {
                name = "ruff-wrapped";
                paths = [ pkgs.ruff ];
                buildInputs = [ pkgs.makeWrapper ];
                postBuild = ''
                  wrapProgram $out/bin/ruff \
                    --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.ruff ]}
                '';
              })
            ];
            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)
              LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib/";
            '';
          };
      }
    );

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
