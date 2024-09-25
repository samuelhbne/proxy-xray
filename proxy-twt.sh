#!/bin/bash

usage() {
    >&2 echo -e "TROJAN-WS-TLS proxy builder"
    >&2 echo -e "Usage: proxy-twt <password@domain.com:443:/websocket>[,fingerprint=safari]"
}

if [ -z "$1" ]; then
    >&2 echo -e "Missing command options.\n"
    usage; exit 1
fi

# password@domain.com:443:/websocket,fingerprint=safari
args=(`echo $1 |tr ',' ' '`)
dest="${args[0]}"
for ext_opt in "${args[@]}"
do
    kv=(`echo $ext_opt |tr '=' ' '`)
    case "${kv[0]}" in
        a|alpn)
            ALPN+=("${kv[1]}")
            ;;
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
path="${options[2]}"
passwd="${id}"

if [ -z "${fingerprint}" ]; then fingerprint="safari"; fi

if [ -z "${passwd}" ]; then >&2 echo -e "Error: password undefined.\n"; usage; exit 1; fi

if [ -z "${host}" ]; then >&2 echo -e "Error: destination host undefined.\n"; usage; exit 1; fi

if [ -z "${port}" ]; then port=443; fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo -e "Port number must be numeric.\n"; exit 1; fi

# User settings
Jservers=`jq -nc --arg host "${host}" --arg port "${port}" --arg passwd "${passwd}" \
'. += {"address":$host,"port":($port|tonumber),"password":$passwd}' `

# Stream Settings
Jalpn=`printf '%s\n' "${ALPN[@]}"|jq -R|jq -sc`
JstreamSettings=`jq -nc --arg serverName "${serverName}" --arg fingerprint "${fingerprint}" --arg path "${path}" --argjson Jalpn "${Jalpn}" \
'. += {"network":"ws","security":"tls","tlsSettings":{"serverName":$serverName,"fingerprint":$fingerprint,"alpn":$Jalpn},"wsSettings":{"path":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag":"proxy","protocol":"trojan","settings":{"servers":[$jservers]},"streamSettings":$jstreamSettings}' `

echo "$Jproxy"
exit 0
