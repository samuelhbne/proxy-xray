#!/bin/bash

usage() {
    >&2 echo -e "VLESS-SPLT-PLAIN proxy builder"
    >&2 echo -e "Usage: proxy-lsp <id@domain.com:80:/webpath>"
}

if [ -z "$1" ]; then
    >&2 echo -e "Missing command options.\n"
    usage; exit 1
fi

# id@domain.com:443:/webpath
options=(`echo $1 |tr '@' ' '`)
id="${options[0]}"
options=(`echo ${options[1]} |tr ':' ' '`)
host="${options[0]}"
port="${options[1]}"
path="${options[2]}"

if [ -z "${id}" ]; then >&2 echo -e "Error: id undefined.\n"; usage; exit 1; fi

if [ -z "${host}" ]; then >&2 echo -e "Error: destination host undefined.\n"; usage; exit 1; fi

if [ -z "${port}" ]; then port=80; fi

if ! [ "${port}" -eq "${port}" ] 2>/dev/null; then >&2 echo -e "Port number must be numeric.\n"; exit 1; fi

# User settings
Jusers=`jq -nc --arg uuid "${id}" '. += {"id":$uuid,"encryption":"none","level":0}'`

# Vnext settings
Jvnext=`jq -nc --arg host "${host}" --arg port "${port}" --argjson juser "${Jusers}" \
'. += {"address":$host,"port":($port|tonumber),"users":[$juser]}' `

# Stream Settings
JstreamSettings=`jq -nc --arg path "${path}" \
'. += {"network":"splithttp","security":"none","splithttpSettings":{"path":$path}}' `

Jproxy=`jq -nc --arg host "${host}" --argjson jvnext "${Jvnext}" --argjson jstreamSettings "${JstreamSettings}" \
'. += { "tag":"proxy","protocol":"vless","settings":{"vnext":[$jvnext]},"streamSettings":$jstreamSettings}' `

echo "$Jproxy"
exit 0
