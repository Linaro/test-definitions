#!/bin/sh

set -e

get_vland_entry() {
    lava-vland-names | grep "^${1}" | cut -d , -f 2
}

get_vland_sys_path() {
    vland_entries=$(get_vland_entry "${1}")
    if [ -z "${vland_entries}" ]; then
        echo "No valid vland name given" >&2
        echo "Alternatives are:" >&2
        get_vland_names >&2
        exit 1
    fi
    lava-vland-self | grep -F "${vland_entries}" | cut -d , -f 3-
}

get_vland_interface() {
    sys_path=$(get_vland_sys_path "${1}")
    find "${sys_path}" -maxdepth 1 -mindepth 1 -type d | sed -e 's|.*/||g'
}

get_vland_names() {
    lava-vland-names | cut -d , -f 1 | grep -v "^$"
}

##
# Main entry point

vland_name=${1}

if [ -z "$(which lava-vland-names 2>/dev/null)" ]; then
    echo "Not in LAVA"
    exit 1
fi

if [ -n "${vland_name}" ]; then
    ret=$(get_vland_interface "${vland_name}")
    if [ -n "${ret}" ]; then
        echo "${ret}"
        exit 0
    fi
    echo "No such vland: $vland_name" >&2
    exit 1
fi

if [ "$(get_vland_names|wc -l)" -ne 1 ]; then
    echo "More then one vland name available" >&2
    echo "Alternatives are:" >&2
    get_vland_names >&2
    exit 1
else
    get_vland_interface "$(get_vland_names)"
fi
