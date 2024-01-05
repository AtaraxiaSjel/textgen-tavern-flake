{ writeShellScriptBin
, update-tabby
, tabbyDir ? "$(pwd)/repos/tabbyAPI"
}:
writeShellScriptBin "start-tabby" ''
  set -euo pipefail

  if [ ! -d "${tabbyDir}/.git" ]; then
    ${update-tabby}/bin/update-tabby
  fi
  (cd ${tabbyDir} && python main.py)
''