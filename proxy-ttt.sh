#!/bin/bash

usage() {
    >&2 echo "Usage: proxy-ts <password@domain.com:443>[,serverName=x.org][,fingerprint=safari]"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# password@domain.com:443,serverName=x.org,fingerprint=safari
args=(`echo $1 |tr ',' ' '`)
dest="${args[0]}"
for ext_opt in "${args[@]}"
do
    kv=(`echo $ext_opt |tr '=' ' '`)
    case "${kv[0]}" in
        s|serverName)
            serverName="${kv[1]}"
            ;;
        f|fingerprint)
            fingerprint="${kv[1]}"
            ;;
    esac
done
options=(`echo $dest |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
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

Jservers=`jq -nc --arg host "${host}" --arg port "${port}" --arg passwd "${passwd}" \
'. += {"address":$host, "port":($port | tonumber), "password":$passwd}' `

JstreamSettings=`jq -nc --arg serverName "${serverName}" --arg fingerprint "${fingerprint}" \
'. += {"network":"tcp", "security":"tls", "tlsSettings":{"serverName":$serverName, "fingerprint":$fingerprint}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag": "proxy", "protocol":"trojan", "settings":{"servers":[$jservers]}, "streamSettings":$jstreamSettings }' `
Jdirect='{"tag": "direct", "protocol": "freedom", "settings": {}}'
Jblocked='{"tag": "blocked", "protocol": "blackhole", "settings": {}}'

jroot=`jq -n --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"}, "outbounds":[$jproxy, $jdirect, $jblocked]}' `

echo "$jroot"
exit 0
