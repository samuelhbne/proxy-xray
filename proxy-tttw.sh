#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-tttw <uuid@domain0.com:443:/websocket>"
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

JstreamSettings=`echo '{}' | jq --arg host "${host}" --arg path "${path}" \
'. += {"network":"ws", "security":"tls", "tlsSettings":{"serverName":$host}, "wsSettings":{"path":$path}}' `

Jproxy=`echo '{}' | jq --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"trojan", "settings":{"servers":[$jservers]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

JibSOCKS=`echo '{}' | jq '. +={"tag": "socks", "port":1080, "listen":"0.0.0.0", "protocol":"socks", "settings":{"udp":true}}' `
JibHTTP=`echo '{}' | jq '. +={"tag": "http", "port":8123, "listen":"0.0.0.0", "protocol":"http"}' `

jroot=`echo '{}' | jq --argjson jibsocks "${JibSOCKS}" --argjson jibhttp "${JibHTTP}" \
--argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "inbounds":[$jibsocks, $jibhttp], "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
