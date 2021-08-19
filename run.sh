#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/proxy-xray.json

usage() {
    echo "proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [options]"
    echo "    --ltx  <VLESS-TCP-XTLS option>        uuid@host:port"
    echo "    --ltt  <VLESS-TCP-TLS option>         uuid@host:port"
    echo "    --lttw <VLESS-TCP-TLS-WS option>      uuid@host:port:/webpath"
    echo "    --lttg <VLESS-TCP-TLS-GRPC option>    uuid@host:port:/svcpath"
    echo "    --mtt  <VMESS-TCP-TLS option>         uuid@host:port"
    echo "    --mttw <VMESS-TCP-TLS-WS option>      uuid@host:port:/webpath"
    echo "    --ttt  <TROJAN-TCP-TLS option>        password@host:port"
    echo "    --tttw <TROJAN-TCP-TLS-WS option>     password@host:port:/webpath"
#   echo "    --ssa  <Shadowsocks-AEAD option>      password:method@host:port"
#   echo "    --sst  <Shadowsocks-TCP option>       password:method@host:port"
    echo "    --stdin                               Read XRay config from stdin instead of auto generation"
}

TEMP=`getopt -o d --long ltx:,ltt:,lttw:,lttg:,mtt:,mttw:,ttt:,tttw:,ssa:,sst:stdin,debug -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        --ltx|--ltt|--lttw|--lttg|--mtt|--mttw|--ttt|--tttw|--ssa|--sst)
            subcmd=`echo "$1"|tr -d "\-\-"`
            echo "${DIR}proxy-${subcmd}.sh $2 >$XCONF"
            $DIR/proxy-${subcmd}.sh $2 >$XCONF
            if [ $? != 0 ]; then
                echo "${subcmd} Config failed: $DIR/proxy-${subcmd}.sh $2"
                exit 2
            else
                XRAY=1
            fi
            shift 2
            ;;
        --stdin)
            STDINCONF=1
            shift 1
            ;;
        -d|--debug)
            DEBUG=1
            shift 1
            ;;
        --)
            shift
            break
            ;;
        *)
            usage;
            exit 1
            ;;
    esac
done

if [ "${STDINCONF}" = "1" ]; then
    exec /usr/local/bin/xray
else
    if [ "${XRAY}" = "1" ]; then
        if [ "${DEBUG}" = "1" ]; then
            cat $XCONF |jq '.log.loglevel |="debug"' |sponge $XCONF
            echo
            cat $XCONF
            echo
        else
            /usr/bin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml &
        fi
    else
        usage
        echo "Missing xray option"
        echo "Abort"
        exit 1
    fi
fi

exec /usr/local/bin/xray -c $XCONF
