#!/usr/bin/env bash
# Create the docker network the mesh lives in and remember its name in ./NetName.
# The subnet must be inside one of the private ranges:
#   10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
# Non-interactive: ZKM_SUBNET and ZKM_NETWORK.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [ -f NetName ]; then
    log INFO "Network already exists, use $(net_name)."
    exit 1
fi

ranges="Network IP must be from one of the following ranges:\n10.0.0.0/8\n172.16.0.0/12\n192.168.0.0/16"

valid_subnet() {
    local ip=$1
    [[ $ip =~ ^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})/([0-9]{1,2})$ ]] || return 1
    local a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]} c=${BASH_REMATCH[3]} d=${BASH_REMATCH[4]} p=${BASH_REMATCH[5]}
    [ "$b" -le 255 ] && [ "$c" -le 255 ] && [ "$d" -le 255 ] && [ "$p" -le 30 ] || return 1
    { [ "$a" -eq 10 ] && [ "$p" -ge 8 ]; } ||
        { [ "$a" -eq 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ] && [ "$p" -ge 12 ]; } ||
        { [ "$a" -eq 192 ] && [ "$b" -eq 168 ] && [ "$p" -ge 16 ]; }
}

create() {
    if docker network create --subnet="$1" "$2" >/dev/null; then
        echo "$2" >NetName
        log INFO "Network $2 is created. IP range is $1"
        return 0
    fi
    log ERROR "Could not create network $2 ($1): the name is taken or the subnet overlaps another network."
    return 1
}

if is_noninteractive || [ -n "${ZKM_SUBNET:-}" ]; then
    IP=${ZKM_SUBNET:-}
    NetName=${ZKM_NETWORK:-zkmesh}
    if ! valid_subnet "$IP"; then
        log ERROR "ZKM_SUBNET='$IP' is not valid. $ranges"
        exit 2
    fi
    create "$IP" "$NetName" && exit 0
    exit 2
fi

log WARN "$ranges"
while true; do
    read -r -p "Input network IP (e.g. 10.10.10.0/24) = " IP
    if valid_subnet "$IP"; then
        read -r -p "Input network name = " NetName
        create "$IP" "$NetName" && exit 0
        # Most likely a wrong (taken) name or an overlapping subnet: ask again.
    else
        log WARN "$ranges"
    fi
done
