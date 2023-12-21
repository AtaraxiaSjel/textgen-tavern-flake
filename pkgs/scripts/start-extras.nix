{ lib
, writeShellScriptBin
, update-extras
, extrasDir ? "$(pwd)/repos/sillytavern-extras"
, extrasModules ? []
, extrasFlags ? []
}:
writeShellScriptBin "start-extras" ''
  ${lib.optionalString (extrasModules == []) ''
		echo "You must specify at least one extras module"
		exit 1
	''}

  if [ ! -d "${extrasDir}/.git" ]; then
    ${update-extras}/bin/update-extras
  fi
  (cd ${extrasDir} && python server.py --enable-modules=${lib.concatStringsSep "," extrasModules} ${lib.concatStringsSep " " extrasFlags})
''