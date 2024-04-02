#!/bin/bash

XCONF=/tmp/proxy-xray.json

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    LC_COLLATE=$old_lc_collate
}

PROTOCOL=`cat $XCONF | jq -r '.outbounds[0].protocol'`
case "${PROTOCOL}" in
    vless)
        XHOST=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].address'`
        XPORT=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].port'`
        WPATH=`cat $XCONF | jq -r '.outbounds[0].streamSettings.wsSettings.path'`
        SVCNAME=`cat $XCONF | jq -r '.outbounds[0].streamSettings.grpcSettings.serviceName'`
        UUID=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].users[0].id'`
        XENCRYPT=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].users[0].encryption'`
        XSEC=`cat $XCONF | jq -r '.outbounds[0].streamSettings.security'`
        XNETWORK=`cat $XCONF | jq -r '.outbounds[0].streamSettings.network'`
        XFLOW=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].users[0].flow'`
        XURL="${PROTOCOL}://${UUID}@${XHOST}:${XPORT}?security=${XSEC}&type=${XNETWORK}"
        if [ "${XFLOW}" != "null" ]; then XURL="${XURL}&flow=${XFLOW}"; fi
        if [ "${WPATH}" != "null" ]; then XURL="${XURL}&path=$(urlencode ${WPATH})"; fi
        if [ "${SVCNAME}" != "null" ]; then XURL="${XURL}&serviceName=${SVCNAME}&mode=gun"; fi
        XURL="${XURL}#${XHOST}:${XPORT}"
        ;;
    vmess)
        XHOST=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].address'`
        XPORT=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].port'`
        WPATH=`cat $XCONF | jq -r '.outbounds[0].streamSettings.wsSettings.path'`
        UUID=`cat $XCONF | jq -r '.outbounds[0].settings.vnext[0].users[0].id'`
        XNETWORK=`cat $XCONF | jq -r '.outbounds[0].streamSettings.network'`
        JXURL=`echo '{}' |jq --arg xhost "${XHOST}" --arg xport "${XPORT}" '. += {"v":2, "add":$xhost, "port":$xport}' `
        JXURL=`echo ${JXURL} | jq --arg uuid "${UUID}" --arg network "${XNETWORK}" '. += {"id":$uuid, "net":$network}' `
        JXURL=`echo ${JXURL} | jq '. += {"scy":"auto", "tls":"tls"}' `
        if [ "${WPATH}" != "null" ]; then
            JXURL=`echo ${JXURL} | jq --arg wpath "${WPATH}" '. += {"path":$wpath}' `
        fi
        JXURL=`echo ${JXURL} |jq --arg xhost "${XHOST}" --arg xport "${XPORT}" '. += {"ps":($xhost+":"+$xport)}' `
        XURL=`echo $JXURL|jq -c|base64|tr -d '\n'`
        XURL="${PROTOCOL}://${XURL}"
        ;;
    trojan)
        XHOST=`cat $XCONF | jq -r '.outbounds[0].settings.servers[0].address'`
        XPORT=`cat $XCONF | jq -r '.outbounds[0].settings.servers[0].port'`
        XPASS=`cat $XCONF | jq -r '.outbounds[0].settings.servers[0].password'`
        WPATH=`cat $XCONF | jq -r '.outbounds[0].streamSettings.wsSettings.path'`
        XURL="${PROTOCOL}://${XPASS}@${XHOST}:${XPORT}"
        if [ "${WPATH}" != "null" ]; then
            XURL="${XURL}/?type=ws&path=$(urlencode ${WPATH})"
        fi
        XURL="${XURL}#${XHOST}:${XPORT}"
        ;;
    *)
        echo "Unknown protocol: ${PROTOCOL}"
        echo "Abort"
        exit 2
        ;;
esac

echo "VPS-Server: ${XHOST}"
echo "Xray-URL: ${XURL}"
qrencode -m 2 -t ANSIUTF8 "${XURL}"
exit 0



