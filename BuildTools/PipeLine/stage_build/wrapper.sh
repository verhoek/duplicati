#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared/utils.sh"

PACKAGES="libgtk2.0-cil rsync"
run "$@" --dockerimage mono \
--dockerpackages "$PACKAGES" \
--sourcecache "$DUPLICATI_ROOT" \
--targetcache "$BUILD_CACHE" \
--dockercommand "./BuildTools/PipeLine/stage_build/build.sh $FORWARD_OPTS"