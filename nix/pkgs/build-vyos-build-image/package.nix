{
  stdenv,
  lib,
  writeShellApplication,
  coreutils,
  docker,
  git,
}:

let
  build-vyos-build-image = writeShellApplication {
    name = "build-vyos-build-image";
    runtimeInputs = [
      coreutils
      docker
      git
    ];
    text = builtins.readFile ./build-vyos-build-image.sh;
  };
in
build-vyos-build-image
