{ lib
, writeShellScriptBin
, textgenDir ? "$(pwd)/repos/textgen"
, userDir ? "$(pwd)/user/textgen"
, pipReqFile ? ""
, torchCommand ? ""
, useNixLlamaCpp ? true
}:
writeShellScriptBin "update-textgen" ''
	set -euo pipefail

	${lib.optionalString (pipReqFile == "") ''
		echo "You must specify pip requirements file"
		exit 1
	''}
	${lib.optionalString (torchCommand == "") ''
		echo "You must specify torch installation command"
		exit 1
	''}

	declare -a userDirs=(
		"characters" "extensions" "loras" "models" "presets"
		"prompts" "softprompts" "training"
		# "extensions"
	)
	link_dirs() {
		echo "Link predefined directories from user folder to textgen repo"
		for folder in "''${userDirs[@]}"; do
			if [ -d "${textgenDir}/$folder" ]; then
				rsync -avq --ignore-existing "${textgenDir}/$folder/" "${userDir}/$folder"
				[ "$folder" = "models" ] && cp "${textgenDir}/$folder/config.yaml" "${userDir}/$folder/config.yaml"
				rm -rf "${textgenDir}/$folder"
			else
				mkdir -p "${userDir}/$folder"
			fi
			ln -s "${userDir}/$folder" "${textgenDir}/$folder"
		done
	}
	remove_dirs() {
		echo "Remove predefined directories in textgen repo"
		for folder in "''${userDirs[@]}"; do
			[[ -L "${textgenDir}/$folder" || -d "${textgenDir}/$folder" ]] && rm -rf "${textgenDir}/$folder" || true
		done
	}

	if [ ! -d "${textgenDir}/.git" ]; then
		echo "Clone textgen repo to ${textgenDir}"
		mkdir -p ${textgenDir}
		pushd ${textgenDir}
		git init -b main && \
			git remote add origin https://github.com/oobabooga/text-generation-webui && \
			git fetch && \
			git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main && \
			git reset --hard origin/main && \
			git branch --set-upstream-to=origin/main
		popd
	fi
	[ ! -d "${userDir}" ] && mkdir -p ${userDir}

	remove_dirs;
	echo "Update textgen repo to latest commit"
	git -C ${textgenDir} fetch
	git -C ${textgenDir} reset --hard origin/main
	link_dirs;

	${lib.optionalString useNixLlamaCpp ''
		sed -i '/llama-cpp-python/d' "${textgenDir}/${pipReqFile}"
	''}
	${torchCommand}
	pip install -U -r "${textgenDir}/${pipReqFile}"
	pip install -U -r "${textgenDir}/extensions/openai/requirements.txt"
''
