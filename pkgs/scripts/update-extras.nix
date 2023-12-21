{ lib
, writeShellScriptBin
, extrasDir ? "$(pwd)/repos/sillytavern-extras"
, pipReqFiles ? []
}:
writeShellScriptBin "update-extras" ''
	set -euo pipefail

	${lib.optionalString (pipReqFiles == []) ''
		echo "You must specify at least one pip requirements file"
		exit 1
	''}

	if [ ! -d "${extrasDir}/.git" ]; then
		echo "Clone sillytavern-extras repo to ${extrasDir}"
		mkdir -p ${extrasDir}
		pushd ${extrasDir}
		git init -b main && \
			git remote add origin https://github.com/sillytavern/sillytavern-extras && \
			git fetch && \
			git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main && \
			git reset --hard origin/main && \
			git branch --set-upstream-to=origin/main
		popd
	else
		echo "Update sillytavern-extras repo to latest commit"
		git -C ${extrasDir} fetch
		git -C ${extrasDir} reset --hard origin/main
	fi
	echo "Install pip requirements"
	for req in ${extrasDir}/requirements*; do
		sed -i '/^torch\W/d' "$req"
		sed -i '/^torchvision\W/d' "$req"
		sed -i '/^torchaudio\W/d' "$req"
	done
	pip install -U ${lib.strings.concatMapStrings (x: "-r ${extrasDir}/${x}") pipReqFiles}
''