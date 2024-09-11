#!/bin/bash

usage() {
    >&2 echo "VLESS-SPLT-PLAIN proxy builder"
    >&2 echo "Usage: proxy-lsp <id@domain.com:80:/webpath>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# id@domain.com:443:/webpath
options=(`echo $1 |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

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
    port=80
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

Jusers=`jq -nc --arg uuid "${id}" '. += {"id":$uuid, "encryption":"none", "level":0}'`

Jvnext=`jq -nc --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host, "port":($port | tonumber), "users":[$juser]}' `

JstreamSettings=`jq -nc --arg serverName "${serverName}" --arg fingerprint "${fingerprint}" --arg path "${path}" \
'. += {"network":"splithttp", "security":"none", "splithttpSettings":{"path":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"vless", "settings":{"vnext":[$jvnext]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`jq -n --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
