{ lib
, writeShellScriptBin
, tabbyDir ? "$(pwd)/repos/tabbyAPI"
, userDir ? "$(pwd)/user/tabbyAPI"
, pipReqFile ? ""
, torchCommand ? ""
}:
writeShellScriptBin "update-tabby" ''
	set -euo pipefail

	${lib.optionalString (pipReqFile == "") ''
		echo "You must specify pip requirements file"
		exit 1
	''}
	${lib.optionalString (torchCommand == "") ''
		echo "You must specify torch installation command"
		exit 1
	''}

	declare -a userDirs=("loras" "models" "templates")
	link_dirs() {
		echo "Link predefined directories from user folder to tabbyAPI repo"
		for folder in "''${userDirs[@]}"; do
			if [ -d "${tabbyDir}/$folder" ]; then
				rsync -avq --ignore-existing "${tabbyDir}/$folder/" "${userDir}/$folder"
				rm -rf "${tabbyDir}/$folder"
			else
				mkdir -p "${userDir}/$folder"
			fi
			ln -s "${userDir}/$folder" "${tabbyDir}/$folder"
		done
	}
	remove_dirs() {
		echo "Remove predefined directories in tabbyAPI repo"
		for folder in "''${userDirs[@]}"; do
			[[ -L "${tabbyDir}/$folder" || -d "${tabbyDir}/$folder" ]] && rm -rf "${tabbyDir}/$folder" || true
		done
	}

	if [ ! -d "${tabbyDir}/.git" ]; then
		echo "Clone tabbyAPI repo to ${tabbyDir}"
		mkdir -p ${tabbyDir}
		pushd ${tabbyDir}
		git init -b main && \
			git remote add origin https://github.com/theroyallab/tabbyAPI && \
			git fetch && \
			git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main && \
			git reset --hard origin/main && \
			git branch --set-upstream-to=origin/main
		popd
	fi
	[ ! -d "${userDir}" ] && mkdir -p ${userDir}

	remove_dirs;
	echo "Update tabbyAPI repo to latest commit"
	git -C ${tabbyDir} fetch
	git -C ${tabbyDir} reset --hard origin/main
	link_dirs;
	[ ! -f "${userDir}/config.yml" ] && cp "${tabbyDir}/config_sample.yml" "${userDir}/config.yaml"
	ln -s "${userDir}/config.yml" "${tabbyDir}/config.yml"

	sed -i '/pytorch/d' "${tabbyDir}/${pipReqFile}"
	sed -i '/^torch/d' "${tabbyDir}/${pipReqFile}"
	${torchCommand}
	pip install -U -r "${tabbyDir}/${pipReqFile}"
''
