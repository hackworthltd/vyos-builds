{
  description = "Hackworth Ltd's opinionated generic Nix flake template";

  inputs = {
    hacknix.url = "github:hackworthltd/hacknix";
    nixpkgs.follows = "hacknix/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    systems.url = "github:nix-systems/default";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    gitignore-nix.url = "github:hercules-ci/gitignore.nix";
    gitignore-nix.flake = false;

    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      # A flake can get its git revision via `self.rev` if its working
      # tree is clean and its index is empty, so we use that for the
      # program version when it's available.
      #
      # When the working tree is modified or the index is not empty,
      # evaluating `self.rev` is an error. However, we *can* use
      # `self.lastModifiedDate` in that case, which is at least a bit
      # more helpful than returning "unknown" or some other static
      # value.
      version =
        let
          v = inputs.self.rev or inputs.self.lastModifiedDate;
        in
        builtins.trace "Flake version is ${v}" "git-${v}";

      allOverlays = [
        inputs.hacknix.overlays.default
      ];

    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;

      systems = import inputs.systems;

      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            self'.allowUnfree = true;
            self'.allowBroken = true;
            overlays = allOverlays;
          };

          formatter = pkgs.nixfmt-rfc-style;

          pre-commit = {
            check.enable = true;
            settings = {
              src = ./.;
              hooks = {
                treefmt.enable = true;
                nixfmt-rfc-style.enable = true;
                prettier.enable = true;

                actionlint = {
                  enable = true;
                  name = "actionlint";
                  entry = "${pkgs.actionlint}/bin/actionlint";
                  language = "system";
                  files = "^.github/workflows/";
                };
              };

              excludes = [
                "CODE_OF_CONDUCT.md"
                "LICENSE"
                "flake.lock"
              ];
            };
          };

          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              prettier.enable = true;
              nixfmt.enable = true;
            };
          };

          packages.default = pkgs.hello-unfree;

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.treefmt.build.devShell
              config.pre-commit.devShell
            ];
            buildInputs = with pkgs; [
              actionlint
              nixd
              nixfmt-rfc-style
              nodejs
              nodePackages.prettier
              vscode-langservers-extracted
            ];

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
