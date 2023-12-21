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
                "--loader=exllamav2"
                "--model Noromaid-13B-v0.2-GPTQ"
              ];
            };
            update-textgen = prev.callPackage ./pkgs/scripts/update-textgen.nix {
              inherit useNixLlamaCpp;
              pipReqFile = "requirements_amd_noavx2.txt";
              torchInstallationStr = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.6";
            };

            python311 = prev.python311.override {
              # enableOptimizations = true;
              # reproducibleBuild = false;
              # self = final.python311;
              packageOverrides = pyfinal: pyprev: {
                llama-cpp-python = pyfinal.callPackage ./pkgs/llama-cpp-python {
                  llama-cpp = final.llama-cpp;
                };
              };
            };
            llama-cpp = (llama-cpp.overrideAttrs (oa: rec {
              version = "1665";
              src = prev.fetchFromGitHub {
                owner = "ggerganov";
                repo = "llama.cpp";
                rev = "refs/tags/b${version}";
                hash = "sha256-5jVXFmSgpNzszC2PxjOayCoCEyUX3AhEfwQOUoYFSQo=";
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
          update-tavern = pkgs.update-tavern;
          update-textgen = pkgs.update-textgen;
          update-extras = pkgs.update-extras;
        };
        devShells.default = let
          python = (pkgs.python311.withPackages(ps: with ps; [
            pip build virtualenv hnswlib wxPython_4_2
          ]));
        in pkgs.mkShell {
          name = "text-generation-webui";
          packages = [
            pkgs.stdenv.cc.cc.lib
            python
          ] ++ (with pkgs.rocmPackages; [
            clr rocblas hipblas hipsparse rocthrust rocprim hiprand llvm.clang
          ]) ++ lib.optionals useNixLlamaCpp [ pkgs.python311Packages.llama-cpp-python ];
          shellHook = ''
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.stdenv.cc.cc.lib}/lib;
            export CC=${pkgs.rocmPackages.llvm.clang}/bin/clang
            export CCX=${pkgs.rocmPackages.llvm.clang}/bin/clang++
            export CFLAGS='-fPIC'
            export CXXFLAGS='-fPIC'
            export HSA_OVERRIDE_GFX_VERSION="10.3.0"
            export HCC_AMDGPU_TARGET="gfx1030"

            DIR="$(pwd)"
            VENV_DIR="$DIR/.venv"
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