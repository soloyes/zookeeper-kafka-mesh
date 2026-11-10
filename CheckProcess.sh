#!/usr/bin/env bash
# Make sure the docker daemon answers. Try to start it (systemd / SysV) if it does not.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if docker info >/dev/null 2>&1; then
    log INFO "Docker daemon is running ($(docker version --format '{{.Server.Version}}' 2>/dev/null))"
    exit 0
fi

sudo_cmd=""
[ "$(id -u)" -ne 0 ] && sudo_cmd=sudo

for i in 1 2 3; do
    log INFO "Docker daemon is not reachable, trying to start it ($i/3)"
    if command -v systemctl >/dev/null 2>&1; then
        $sudo_cmd systemctl start docker
    elif command -v service >/dev/null 2>&1; then
        $sudo_cmd service docker start
    fi
    sleep 2
    if docker info >/dev/null 2>&1; then
        log INFO "Docker daemon has been started"
        exit 0
    fi
done

log ERROR "Docker daemon is unable to start"
exit 1
