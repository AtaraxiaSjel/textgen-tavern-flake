{ nodejs
, writeShellScriptBin
, update-tavern
, tavernDir ? "$(pwd)/repos/sillytavern"
}:
writeShellScriptBin "start-tavern" ''
  if [ ! -d "${tavernDir}/.git" ]; then
    ${update-tavern}/bin/update-tavern
  fi
  (cd ${tavernDir} && ${nodejs}/bin/npm i --no-audit && ${nodejs}/bin/node ./server.js)
''