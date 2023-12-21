{ writeShellScriptBin
, nodejs
, tavernDir ? "$(pwd)/repos/sillytavern"
, userDir ? "$(pwd)/user/sillytavern"
}:
writeShellScriptBin "update-tavern" ''
	set -euo pipefail

	declare -a userDirs=(
		"public/assets" "public/backgrounds" "public/characters" "public/chats"
		"public/context" "public/groups" "public/group chats" "public/instruct"
		"public/movingUI" "public/KoboldAI Settings" "public/NovelAI Settings"
		"public/OpenAI Settings" "public/QuickReplies" "public/TextGen Settings"
		"public/themes" "public/User Avatars" "public/worlds" "public/user"
	)
	declare -a userFiles=("public/settings.json" "secrets.json" "config.yaml")

	link_dirs() {
		echo "Link predefined directories from user folder to sillytavern repo"
		for folder in "''${userDirs[@]}"; do
			if [ -d "${tavernDir}/$folder" ]; then
				rsync -avq --ignore-existing "${tavernDir}/$folder/" "${userDir}/$folder"
				rm -rf "${tavernDir}/$folder"
			else
				mkdir -p "${userDir}/$folder"
			fi
			ln -s "${userDir}/$folder" "${tavernDir}/$folder"
		done
	}
	link_files() {
		echo "Link predefined files from user folder to sillytavern repo"
		for file in "''${userFiles[@]}"; do
			if [ -f "${tavernDir}/$file" ]; then
				rsync -avq --ignore-existing "${tavernDir}/$file" "${userDir}/$file"
				rm -f "${tavernDir}/$file"
			else
				if [ ! -f "${userDir}/$file" ]; then
					[ "$file" = "public/settings.json" ] && cp "${tavernDir}/default/settings.json" "${userDir}/public/settings.json"
					[ "$file" = "config.yaml" ] && cp "${tavernDir}/default/config.yaml" "${userDir}/config.yaml"
				fi
			fi
			ln -s "${userDir}/$file" "${tavernDir}/$file"
		done
	}
	remove_dirs() {
		echo "Remove predefined directories in sillytavern repo"
		for folder in "''${userDirs[@]}"; do
			[[ -L "${tavernDir}/$folder" || -d "${tavernDir}/$folder" ]] && rm -rf "${tavernDir}/$folder" || true
		done
	}
	remove_files() {
		echo "Remove predefined files in sillytavern repo"
		for file in "''${userFiles[@]}"; do
			[[ -L "${tavernDir}/$file" || -f "${tavernDir}/$file" ]] && rm -f "${tavernDir}/$file" || true
		done
	}

	if [ ! -d "${tavernDir}/.git" ]; then
		echo "Clone sillytavern repo to ${tavernDir}"
		mkdir -p ${tavernDir}
		pushd ${tavernDir}
		git init -b release && \
			git remote add origin https://github.com/sillytavern/sillytavern && \
			git fetch && \
			git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/release && \
			git reset --hard origin/release && \
			git branch --set-upstream-to=origin/release
		popd
	fi
	[ ! -d "${userDir}/public" ] && mkdir -p ${userDir}/public
	remove_dirs;
	remove_files;
	echo "Update sillytavern repo to latest commit"
	git -C ${tavernDir} reset --hard
	git -C ${tavernDir} reset --hard origin/release
	link_dirs;
	link_files;
	sed -i 's|\"node |\"${nodejs}/bin/node |g' ${tavernDir}/package.json
	(cd ${tavernDir} && ${nodejs}/bin/npm i --no-audit)
''