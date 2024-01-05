{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }: let
        useNixLlamaCpp = true;
        torchCommand = "pip install -U torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.6";
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [(final: prev: let
            llama-cpp = prev.callPackage ./pkgs/llama-cpp { };
          in {
            start-tavern = prev.callPackage ./pkgs/scripts/start-tavern.nix { };
            update-tavern = prev.callPackage ./pkgs/scripts/update-tavern.nix { };
            start-extras = prev.callPackage ./pkgs/scripts/start-extras.nix {
              extrasModules = [ "chromadb" ];
            };
            update-extras = prev.callPackage ./pkgs/scripts/update-extras.nix {
              pipReqFiles = [ "requirements-rocm.txt" ];
            };
            start-textgen = prev.callPackage ./pkgs/scripts/start-textgen.nix {
              textgenFlags = [
                "--nowebui"
                "--extensions openai"
                "--loader=llama.cpp"
                "--model deepseek-coder-6.7b-instruct.Q6_K.gguf"
              ];
            };
            update-textgen = prev.callPackage ./pkgs/scripts/update-textgen.nix {
              inherit useNixLlamaCpp torchCommand;
              pipReqFile = "requirements_amd_noavx2.txt";
            };
            start-sd = prev.callPackage ./pkgs/scripts/start-sd.nix {
              useAccelerate = true;
              useTCMalloc = true;
              sdFlags = [
                # "--api" "--api-log"
                "--medvram"
                "--opt-sub-quad-attention"
                "--theme dark"
                "--ckpt models/Stable-diffusion/dreamshaperXL_turboDpmppSDE.safetensors"
              ];
            };
            update-sd = prev.callPackage ./pkgs/scripts/update-sd.nix {
              inherit torchCommand;
            };
            start-tabby = prev.callPackage ./pkgs/scripts/start-tabby.nix { };
            update-tabby = prev.callPackage ./pkgs/scripts/update-tabby.nix {
              inherit torchCommand;
              pipReqFile = "requirements-amd.txt";
            };

            python311 = prev.python311.override {
              # enableOptimizations = true;
              # reproducibleBuild = false;
              # self = final.python311;
              packageOverrides = pyfinal: pyprev: {
                llama-cpp-python = (pyfinal.callPackage ./pkgs/llama-cpp-python {
                  llama-cpp = final.llama-cpp;
                }).overrideAttrs (oa: rec {
                  version = "0.2.26";
                  src = prev.fetchFromGitHub {
                    repo = "llama-cpp-python";
                    owner = "abetlen";
                    rev = "v${version}";
                    hash = "sha256-Jhgb7E6ncyu6T06FSLiw+G6trFJSVx48acZ0tNDzZ74=";
                  };
                });
              };
            };
            llama-cpp = (llama-cpp.overrideAttrs (oa: rec {
              version = "1742";
              src = prev.fetchFromGitHub {
                owner = "ggerganov";
                repo = "llama.cpp";
                rev = "refs/tags/b${version}";
                hash = "sha256-0xpWDKzRcm32jkPsvHD2o9grUdo9n+4cvpYiKQ8LqRY=";
              };
              cmakeFlags = [
                "-DAMDGPU_TARGETS=gfx1030"
                "-DLLAMA_AVX2=off"
                "-DLLAMA_FMA=off"
                "-DLLAMA_F16C=off"
              ] ++ oa.cmakeFlags or [];
              enableParallelBuilding = true;
            })).override {
              cudaSupport = false;
              rocmSupport = true;
              openclSupport = false;
              openblasSupport = false;
            };
          })];
        };
        packages = {
          start-tavern = pkgs.start-tavern;
          start-textgen = pkgs.start-textgen;
          start-extras = pkgs.start-extras;
          start-sd = pkgs.start-sd;
          start-tabby = pkgs.start-tabby;
          update-tavern = pkgs.update-tavern;
          update-textgen = pkgs.update-textgen;
          update-extras = pkgs.update-extras;
          update-sd = pkgs.update-sd;
          update-tabby = pkgs.update-tabby;
          llama-cpp = pkgs.llama-cpp;
        };
        devShells.default = let
          python = (pkgs.python311.withPackages(ps: with ps; [
            pip build virtualenv hnswlib wxPython_4_2
          ]));
        in pkgs.mkShell {
          name = "text-generation-webui";
          packages = [ python ] ++ (with pkgs.rocmPackages; [
            clr rocblas hipblas hipsparse rocthrust rocprim hiprand rocsparse llvm.clang
          ]) ++ lib.optionals useNixLlamaCpp [ pkgs.python311Packages.llama-cpp-python ];
          shellHook = ''
            export LD_LIBRARY_PATH=${with pkgs; lib.makeLibraryPath [ stdenv.cc.cc.lib libGL glib ]}:$LD_LIBRARY_PATH;
            export CC=${pkgs.rocmPackages.llvm.clang}/bin/clang
            export CCX=${pkgs.rocmPackages.llvm.clang}/bin/clang++
            export CFLAGS='-fPIC'
            export CXXFLAGS='-fPIC'
            export HSA_OVERRIDE_GFX_VERSION="10.3.0"
            export HCC_AMDGPU_TARGET="gfx1030"

            DIR="$(pwd)"
            export VENV_DIR="$DIR/.venv"
            SOURCE_DATE_EPOCH=$(date +%s) # required for python wheels
            virtualenv --no-setuptools "$VENV_DIR"
            export PYTHONPATH="$VENV_DIR/${python.sitePackages}:$PYTHONPATH"
            export PATH="$VENV_DIR/bin:$PATH"

            source .venv/bin/activate
          '';
        };
      };
    };
}
