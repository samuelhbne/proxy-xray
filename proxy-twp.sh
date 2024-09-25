#!/bin/bash

usage() {
    >&2 echo -e "TROJAN-WS-PLAIN proxy builder"
    >&2 echo -e "Usage: proxy-twp <password@domain.com:443:/websocket>"
}

if [ -z "$1" ]; then
    >&2 echo -e "Missing command options.\n"
    usage; exit 1
fi

# password@domain.com:443:/websocket
options=(`echo $1 |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"
passwd="${id}"

if [ -z "${passwd}" ]; then >&2 echo -e "Error: password undefined.\n"; usage; exit 1; fi

if [ -z "${host}" ]; then >&2 echo -e "Error: destination host undefined.\n"; usage; exit 1; fi

if [ -z "${port}" ]; then port=80; fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo -e "Port number must be numeric.\n"; exit 1; fi

# User settings
Jservers=`jq -nc --arg host "${host}" --arg port "${port}" --arg passwd "${passwd}" \
'. += {"address":$host,"port":($port|tonumber),"password":$passwd}' `

# Stream Settings
JstreamSettings=`jq -nc --arg path "${path}" \
'. += {"network":"ws","security":"none","wsSettings":{"path":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jservers "${Jservers}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag":"proxy","protocol":"trojan","settings":{"servers":[$jservers]},"streamSettings":$jstreamSettings}' `

echo "$Jproxy"
exit 0
