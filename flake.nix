{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    oxalica.url = "github:oxalica/rust-overlay";
    oxalica.inputs.nixpkgs.follows = "nixpkgs";
    elm-tools.url = "github:jeslie0/mkElmDerivation";
    elm-tools.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, oxalica, elm-tools }: let
    overlays = [ elm-tools.overlays.mkElmDerivation oxalica.overlays.default ];
    pkgs  = system: import nixpkgs { inherit system overlays; };
    rust = system: with (pkgs system); rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" "rustfmt" "clippy" ];
      targets = [ "wasm32-unknown-unknown" ];
    };
    rsPlatform = system: with (pkgs system); makeRustPlatform {
      cargo = (rust system);
      rustc = (rust system);
    };
    wasm = system: with (pkgs system); (rsPlatform system).buildRustPackage {
      pname = "recipe-site-wasm";
      version = "0.1.0";
      src = ./wasm;
      cargoLock.lockFile = ./wasm/Cargo.lock;
      nativeBuildInputs = [ wasm-pack wasm-bindgen-cli binaryen ];
      buildPhase = ''
        HOME=.
        wasm-pack build --target web
      '';
      installPhase = ''
        mkdir -p $out
        cp -r pkg/* $out
      '';
    };
    js = system: with (pkgs system); mkElmDerivation {
      name = "recipe-site-js";
      version = "0.1.0";
      src = ./elm;
      elmJson = ./elm/elm.json;
      buildPhase = ''
        elm make src/Main.elm --output main.js --optimize
      '';
      installPhase = ''
        mkdir -p $out
        cp main.js $out
      '';
    };
    package = system: (rsPlatform system).buildRustPackage {
      pname = "recipe-site";
      version = "0.2.0";
      src = ./rs;
      cargoLock.lockFile = ./rs/Cargo.lock;
    };
    devShell = system: with (pkgs system); mkShell {
      # All the Rust stuff comes from here
      inputsFrom = [ (package system) ];
      packages = with elmPackages; [
        # For writing nix
        nil
        nixfmt-classic
        # For WASM and testing
        wasm-pack
        wasm-bindgen-cli
        binaryen
        miniserve
        # For writing and building elm
        elm
        elm-language-server
        elm-format
      ];
    };
  in {
    devShells.aarch64-linux.default = devShell "aarch64-linux";
    packages.aarch64-linux.wasm = wasm "aarch64-linux";
    packages.aarch64-linux.js = js "aarch64-linux";
    packages.aarch64-linux.default = package "aarch64-linux";
  };
}
