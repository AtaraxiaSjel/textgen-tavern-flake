{ lib
, writeShellScriptBin
, update-textgen
, textgenDir ? "$(pwd)/repos/textgen"
, textgenFlags ? []
}:
writeShellScriptBin "start-textgen" ''
  if [ ! -d "${textgenDir}/.git" ]; then
    ${update-textgen}/bin/update-textgen
  fi
  (cd ${textgenDir} && python server.py ${lib.concatStringsSep " " textgenFlags})
''