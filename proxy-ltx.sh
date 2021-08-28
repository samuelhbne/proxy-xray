#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-ltx <uuid@domain0.com:443>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# uuid@domain0.com:443
temp=$1
options=(`echo $temp |tr '@' ' '`)
id="${options[0]}"
temp="${options[1]}"
options=(`echo $temp |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"

if [ -z "${id}" ]; then
    >&2 echo "Error: uuid undefined."
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

Jusers=`echo '{}' |jq --arg uuid "${id}" '. += {"id":$uuid, "flow":"xtls-rprx-direct", "encryption":"none", "level":0}'`

Jvnext=`echo '{}' | jq --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host, "port":($port | tonumber), "users":[$juser]}' `

JstreamSettings=`echo '{}' | jq --arg host "${host}" \
'. += {"network":"tcp", "security":"xtls", "xtlsSettings":{"serverName":$host}}' `

Jproxy=`echo '{}' | jq --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"vless", "settings":{"vnext":[$jvnext]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`echo '{}' | jq --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
