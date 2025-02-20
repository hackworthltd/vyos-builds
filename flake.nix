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

    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
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

      formattingExcludes = [
        "CODE_OF_CONDUCT.md"
        "LICENSE"
        "flake.lock"
      ];

    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;

      systems = import inputs.systems;

      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
        inputs.pkgs-by-name-for-flake-parts.flakeModule
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

              excludes = formattingExcludes;
            };
          };

          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              prettier.enable = true;
              nixfmt.enable = true;
            };
            settings.formatter.prettier.excludes = formattingExcludes;
          };

          pkgsDirectory = ./nix/pkgs;

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

              act
              docker
              git
            ];

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };

      flake =
        let
          # See above, we need to use our own `pkgs` within the flake.
          pkgs = import inputs.nixpkgs {
            system = "x86_64-linux";
            config = {
              allowUnfree = true;
              allowBroken = true;
            };
            overlays = allOverlays;
          };
        in
        {
          hydraJobs = {
            inherit (inputs.self) checks;
            inherit (inputs.self) packages;
            inherit (inputs.self) devShells;
          };

          required = pkgs.releaseTools.aggregate {
            name = "required-nix-ci";
            constituents = builtins.map builtins.attrValues (
              with inputs.self.hydraJobs;
              [
                packages.x86_64-linux
                packages.aarch64-darwin
                checks.x86_64-linux
                checks.aarch64-darwin
              ]
            );
            meta.description = "Required Nix CI builds";
          };

          ciJobs = pkgs.lib.flakes.recurseIntoHydraJobs inputs.self.hydraJobs;
        };
    };
}
