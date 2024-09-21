#!/bin/bash

usage() {
    >&2 echo "VLESS-GRPC-TLS proxy builder"
    >&2 echo "Usage: proxy-lgr <id@domain.com:443:/svcpath><d=yahoo.com>,pub=xxxx[,shortId=abcd][,fingerprint=safari]"
}

if [ -z "$1" ]; then
    >&2 echo "Missing options"
    usage
    exit 1
fi

# id@domain.com:443:/svcpath,dest=yahoo.com,pub=xxxx,fingerprint=safari
args=(`echo $1 |tr ',' ' '`)
dest="${args[0]}"
for ext_opt in "${args[@]}"
do
    kv=(`echo $ext_opt |tr '=' ' '`)
    case "${kv[0]}" in
        d|dest)
            serverName="${kv[1]}"
            ;;
        s|serverName)
            serverName="${kv[1]}"
            ;;
        f|fingerprint)
            fingerprint="${kv[1]}"
            ;;
        flow)
            flow="${kv[1]}"
            ;;
        pub|publicKey)
            publicKey="${kv[1]}"
            ;;
        shortId)
            shortId="${kv[1]}"
            ;;
        xtls)
            flow="xtls-rprx-vision"
            ;;
    esac
done
options=(`echo $dest |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

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

if [ -z "${publicKey}" ]; then
    >&2 echo "Error: publicKey undefined."
    usage
    exit 1
fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo "Port number must be numeric"; exit 1; fi

# User settings
Jusers=`jq -nc --arg uuid "${id}" --arg flow "${flow}" '. += {"flow":$flow,"id":$uuid,"encryption":"none","level":0}'`

# Vnext settings
Jvnext=`jq -nc --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host,"port":($port | tonumber),"users":[$juser]}' `

# Stream Settings
JstreamSettings=`jq -nc --arg serverName "${serverName}" --arg publicKey "${publicKey}" --arg shortId "${shortId}" --arg fingerprint "${fingerprint}" --arg path "${path}" \
'. += {"network":"grpc","security":"reality","realitySettings":{"publicKey":$publicKey,"serverName":$serverName,"shortId":$shortId,"fingerprint":$fingerprint},"grpcSettings":{"serviceName":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag":"proxy","protocol":"vless","settings":{"vnext":[$jvnext]},"streamSettings":$jstreamSettings}' `
Jdirect='{"tag":"direct","protocol":"freedom","settings":{}}'
Jblocked='{"tag":"blocked","protocol":"blackhole","settings":{}}'

jroot=`jq -n --argjson jproxy "${Jproxy}" --argjson jdirect "${Jdirect}" --argjson jblocked "${Jblocked}" \
'. += {"log":{"loglevel":"warning"},"outbounds":[$jproxy,$jdirect,$jblocked]}' `

echo "$jroot"
exit 0
