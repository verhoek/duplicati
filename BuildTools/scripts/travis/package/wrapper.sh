#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"


parse_options "$@"
load_mono
setup_copy_cache
#https://itnext.io/docker-in-docker-521958d34efd

sudo apt-get install qemu-user qemu-user-static
package_in_docker