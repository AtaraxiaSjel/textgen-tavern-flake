{ lib
, writeShellScriptBin
, sdDir ? "$(pwd)/repos/sd-webui"
, userDir ? "$(pwd)/user/sd-webui"
, torchCommand ? ""
}:
writeShellScriptBin "update-sd" ''
	set -euo pipefail

	${if (torchCommand == "") then ''
		unset TORCH_COMMAND
	'' else ''
		TORCH_COMMAND="${torchCommand}"
	''}

	declare -a userDirs=(
		"configs" "embeddings" "extensions" "localizations" "log"
		"models" "outputs" "repositories" "textual_inversion_templates"
	)
	link_dirs() {
		echo "Link predefined directories from user folder to sd-webui repo"
		for folder in "''${userDirs[@]}"; do
			if [ -d "${sdDir}/$folder" ]; then
				rsync -avq --ignore-existing "${sdDir}/$folder/" "${userDir}/$folder"
				rm -rf "${sdDir}/$folder"
			else
				mkdir -p "${userDir}/$folder"
			fi
			ln -s "${userDir}/$folder" "${sdDir}/$folder"
		done
	}
	remove_dirs() {
		echo "Remove predefined directories in sd-webui repo"
		for folder in "''${userDirs[@]}"; do
			[[ -L "${sdDir}/$folder" || -d "${sdDir}/$folder" ]] && rm -rf "${sdDir}/$folder" || true
		done
	}

	if [ ! -d "${sdDir}/.git" ]; then
		echo "Clone sd-webui repo to ${sdDir}"
		mkdir -p ${sdDir}
		pushd ${sdDir}
		git init -b master && \
			git remote add origin https://github.com/AUTOMATIC1111/stable-diffusion-webui && \
			git fetch && \
			git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master && \
			git reset --hard origin/master && \
			git branch --set-upstream-to=origin/master
		popd
	fi
	[[ ! -d "${userDir}" ]] && mkdir -p ${userDir}

	remove_dirs;
	echo "Update sd-webui repo to latest commit"
	git -C ${sdDir} fetch
	git -C ${sdDir} reset --hard origin/master
	link_dirs;

  (export TORCH_COMMAND="${torchCommand}"; export TRANSFORMERS_CACHE="${userDir}/transformers-cache"; cd ${sdDir} && \
		python launch.py --data-dir ${userDir} --styles-file ${userDir}/styles.csv \
		--ui-config-file ${userDir}/ui-config.json --ui-settings-file ${userDir}/config.json \
		--skip-python-version-check --skip-version-check --no-download-sd-model --update-all-extensions --exit)
''