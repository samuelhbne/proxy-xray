#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-ttt <uuid@domain0.com:443>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# password:method@domain0.com:443:/websocket
temp=$1
options=(`echo $temp |tr '@' ' '`)
id="${options[0]}"
temp="${options[1]}"
options=(`echo $temp |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

temp=$id
options=(`echo $temp |tr ':' ' '`)
passwd="${options[0]}"
method="${options[1]}"

if [ -z "${passwd}" ]; then
    >&2 echo "Error: passwd undefined."
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

JstreamSettings=`echo '{}' | jq --arg host "${host}" \
'. += {"network":"tcp", "security":"tls", "tlsSettings":{"serverName":$host}}' `

Jproxy=`echo '{}' | jq --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"trojan", "settings":{"servers":[$jservers]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`echo '{}' | jq --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
