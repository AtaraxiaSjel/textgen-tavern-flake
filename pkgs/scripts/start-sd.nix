{ lib
, writeShellScriptBin
, gperftools
, update-sd
, sdDir ? "$(pwd)/repos/sd-webui"
, userDir ? "$(pwd)/user/sd-webui"
, sdFlags ? []
, useAccelerate ? false
, useTCMalloc ? false
}:
writeShellScriptBin "start-sd" ''
  set -euo pipefail

  if [ ! -d "${sdDir}/.git" ]; then
    ${update-sd}/bin/update-sd
  fi

  USER_DIR="${userDir}"

  (${lib.optionalString useTCMalloc "set +u; export LD_PRELOAD=${gperftools}/lib/libtcmalloc.so:$LD_PRELOAD &&"} \
    export TRANSFORMERS_CACHE="$USER_DIR/transformers-cache" && cd ${sdDir} && \
    ${if useAccelerate then "accelerate launch --num_cpu_threads_per_process=6" else "python -u"} launch.py --styles-file $USER_DIR/styles.csv \
    --ui-config-file $USER_DIR/ui-config.json --ui-settings-file $USER_DIR/config.json --skip-python-version-check \
    --skip-version-check --no-download-sd-model --skip-prepare-environment ${lib.concatStringsSep " " sdFlags})
''