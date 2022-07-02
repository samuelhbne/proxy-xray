#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-ttpw <password@domain.com:443:/websocket>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# password@domain.com:443:/websocket
options=(`echo $1 |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"
passwd="${id}"

if [ -z "${serverName}" ]; then serverName=${host}; fi
if [ -z "${fingerprint}" ]; then fingerprint="safari"; fi

if [ -z "${passwd}" ]; then
    >&2 echo "Error: password undefined."
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

Jservers=`echo '{}' | jq --arg host "${host}" --arg port "${port}" --arg passwd "${passwd}" \
'. += {"address":$host, "port":($port | tonumber), "password":$passwd}' `

JstreamSettings=`echo '{}' | jq --arg serverName "${serverName}" --arg fingerprint "${fingerprint}" --arg path "${path}" \
'. += {"network":"ws", "security":"none", "wsSettings":{"path":$path}}' `

Jproxy=`echo '{}' | jq --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"trojan", "settings":{"servers":[$jservers]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`echo '{}' | jq --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
