let
  pkgs = import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "status-im";
    repo = "nixpkgs";
    rev = "3bd9966672d76e790e56cda234f0c34e5205a267";
    sha256 = "12ggprababkdr37s8q3wz2n6idd9p6wpzj8nsx7vcmdl6940p5y9";
  }) { config = { }; };
  
  derivation = if pkgs.stdenv.isLinux then pkgs.stdenvNoCC.mkDerivation else pkgs.stdenv.mkDerivation;
  nodejs = pkgs."nodejs-10_x";
  conan = with pkgs; import ./scripts/lib/setup/nix/conan {
    # Import a newer version of the Conan package to fix pylint issues with pinned one
    # The remaining dependencies come from Nixpkgs
    inherit lib;
    inherit python3;
    inherit git;
  };
  nodeInputs = import ./scripts/lib/setup/nix/global-node-packages/output {
    # The remaining dependencies come from Nixpkgs
    inherit pkgs;
    inherit nodejs;
  };
  nodePkgs = (map (x: nodeInputs."${x}") (builtins.attrNames nodeInputs));

in with pkgs; derivation rec {
  name = "env";
  env = buildEnv { name = name; paths = buildInputs; };
  statusDesktopBuildInputs = with stdenv; [
    cmake
    extra-cmake-modules
    go_1_10
    qt5.full # Status Desktop, cannot be installed on macOS https://github.com/NixOS/nixpkgs/issues/55892
  ] ++ lib.optional isLinux [conan patchelf];
  buildInputs = with stdenv; [
    clojure
    jq
    leiningen
    maven
    nodejs
    openjdk
    python27 # for e.g. gyp
    watchman
    unzip
    wget
    yarn
  ] ++ nodePkgs
    ++ statusDesktopBuildInputs
    ++ lib.optional isDarwin cocoapods
    ++ lib.optional isLinux gcc7;
  shellHook = ''
      local toolversion="$(git rev-parse --show-toplevel)/scripts/toolversion"

      export JAVA_HOME="${openjdk}"
      export ANDROID_HOME=~/.status/Android/Sdk
      export ANDROID_SDK_ROOT="$ANDROID_HOME"
      export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/android-ndk-$($toolversion android-ndk)"
      export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
      export ANDROID_NDK="$ANDROID_NDK_ROOT"
      export PATH="$ANDROID_HOME/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools:$PATH"
      export QT_PATH="${qt5.full}"

      [ -d "$ANDROID_NDK_ROOT" ] || ./scripts/setup # we assume that if the NDK dir does not exist, make setup needs to be run
  '';
}