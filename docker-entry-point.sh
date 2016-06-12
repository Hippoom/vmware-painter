#!/bin/bash

set -e

if [ -z "$1" -o  "${1:0:1}" = '-' ]; then
    exec ruby ${PAINTER_EXECUTABLE} -c ${PAINTER_CONFIG_DIR}/${PAINTER_CONFIG_FILE} "$@"
fi

exec "$@"
