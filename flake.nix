{
  description = "whisrs — Linux-first voice-to-text dictation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };

        nativeBuildInputs = with pkgs; [
          pkg-config
          cmake
          llvmPackages.clang
          rustPlatform.bindgenHook
        ];

        buildInputs = with pkgs; [
          alsa-lib
          libxkbcommon
          cudaPackages.cudatoolkit
          cudaPackages.cuda_cudart
          cudaPackages.libcublas
        ];
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "whisrs";
          version = "0.1.16";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          inherit nativeBuildInputs buildInputs;
          
          WHISPER_CUDA = "1";
          CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          
          preBuild = ''
            export LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cuda_cudart}/lib:${pkgs.cudaPackages.libcublas}/lib:$LIBRARY_PATH"
            export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cuda_cudart}/lib:$LD_LIBRARY_PATH"
            export CUDA_TOOLKIT_ROOT_DIR="${pkgs.cudaPackages.cudatoolkit}"
          '';

          postInstall = ''
            install -Dm644 contrib/whisrs.1 $out/share/man/man1/whisrs.1
            install -Dm644 contrib/whisrsd.1 $out/share/man/man1/whisrsd.1
            install -Dm644 contrib/99-whisrs.rules $out/lib/udev/rules.d/99-whisrs.rules
            install -Dm644 contrib/whisrs.service $out/lib/systemd/user/whisrs.service
          '';

          meta = with pkgs.lib; {
            description = "Linux-first voice-to-text dictation tool";
            homepage = "https://github.com/y0sif/whisrs";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "whisrs";
          };
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          nativeBuildInputs = nativeBuildInputs ++ (with pkgs; [
            cargo
            rustc
            rust-analyzer
            clippy
            rustfmt
          ]);

          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        };
      }
    );
}
