#!/bin/bash

usage() {
    >&2 echo "VMESS-WS-PLAIN proxy builder"
    >&2 echo "Usage: proxy-mpw <id@domain.com:443:/websocket>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# id@domain.com:443:/websocket
options=(`echo $1 |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

if [ -z "${serverName}" ]; then serverName=${host}; fi
if [ -z "${fingerprint}" ]; then fingerprint="safari"; fi

if [ -z "${id}" ]; then
    >&2 echo "Error: id undefined."
    usage
    exit 1
fi

if [ -z "${host}" ]; then
    >&2 echo "Error: destination host undefined."
    usage
    exit 1
fi

if [ -z "${port}" ]; then
    port=443
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

Jusers=`jq -nc --arg uuid "${id}" '. += {"id":$uuid, "encryption":"none", "level":0}'`

Jvnext=`jq -nc --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host, "port":($port | tonumber), "users":[$juser]}' `

JstreamSettings=`jq -nc --arg serverName "${serverName}" --arg fingerprint "${fingerprint}" --arg path "${path}" \
'. += {"network":"ws", "security":"none", "wsSettings":{"path":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"vmess", "settings":{"vnext":[$jvnext]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`jq -n --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
