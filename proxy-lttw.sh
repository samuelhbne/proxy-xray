#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-lttw <uuid@domain0.com:443:/websocket>"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# uuid@domain0.com:443:/websocket
temp=$1
options=(`echo $temp |tr '@' ' '`)
id="${options[0]}"
temp="${options[1]}"
options=(`echo $temp |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

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

Jusers=`echo '{}' |jq --arg uuid "${id}" '. += {"id":$uuid, "encryption":"none", "level":0}'`

Jvnext=`echo '{}' | jq --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host, "port":($port | tonumber), "users":[$juser]}' `

JstreamSettings=`echo '{}' | jq --arg host "${host}" --arg path "${path}" \
'. += {"network":"ws", "security":"tls", "tlsSettings":{"serverName":$host}, "wsSettings":{"path":$path}}' `

Joutbounds=`echo '{}' | jq --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "protocol":"vless", "settings":{"vnext":[$jvnext]}, "streamSettings":$jstreamSettings }' `

JibSOCKS=`echo '{}' | jq '. +={"port":1080, "listen":"0.0.0.0", "protocol":"socks", "settings":{"udp":true}}' `
JibHTTP=`echo '{}' | jq '. +={"port":8123, "listen":"0.0.0.0", "protocol":"http"}' `

jroot=`echo '{}' | jq --argjson jibsocks "${JibSOCKS}" --argjson jibhttp "${JibHTTP}" --argjson joutbounds "${Joutbounds}" \
'. += {"log":{"loglevel":"warning"}, "inbounds":[$jibsocks, $jibhttp], "outbounds":[$joutbounds]}' `

echo "$jroot"
exit 0
