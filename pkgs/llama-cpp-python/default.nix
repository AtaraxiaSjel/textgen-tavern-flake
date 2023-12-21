{ buildPythonPackage
, diskcache
, fetchFromGitHub
, lib
, llama-cpp
, numpy
, pytestCheckHook
, setuptools
, stdenv
, typing-extensions
, scipy
}:

buildPythonPackage rec {
  pname = "llama-cpp-python";
  version = "0.2.24";
  pyproject = true;
  doCheck = false;

  src = fetchFromGitHub {
    repo = "llama-cpp-python";
    owner = "abetlen";
    rev = "v${version}";
    hash = "sha256-RA0FpDXcu/rmjivrJIqXN0SqkimfRsZ6AfK1zEJ9gFA=";
  };

  patches = [
    ./disable-llama-cpp-build.patch
    ./set-llamacpp-path.patch
  ];

  postPatch = ''
    substituteInPlace llama_cpp/llama_cpp.py \
      --subst-var-by llamaCppSharedLibrary "${llama-cpp}/lib/libllama${stdenv.hostPlatform.extensions.sharedLibrary}"

    substituteInPlace tests/test_llama.py \
      --subst-var-by llamaCppModels "${llama-cpp}/share/models"
  '';

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    diskcache
    numpy
    typing-extensions
  ];

  nativeCheckInputs = [
    pytestCheckHook
    scipy
  ];

  meta = with lib; {
    description = "Python bindings for llama.cpp";
    homepage = "https://github.com/abetlen/llama-cpp-python";
    license = licenses.mit;
    maintainers = with maintainers; [ elohmeier ataraxiasjel ];
  };
}
