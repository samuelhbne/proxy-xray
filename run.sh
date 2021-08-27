#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/proxy-xray.json

usage() {
    echo "proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [connect options] [-i|--stdin] [-d|--debug]"
    echo "    -i|--stdin                         [Optional] Read config from stdin instead of auto generation"
    echo "    -d|--debug                         [Optional] Start in debug mode with verbose output"
    echo "    --ignore-china                     [Optional] Add rules to avoid domain and ip located in China being proxied"
    echo "    --ignore-domain <domain rule>      [Optional] Add a non-proxy routing rule for domain, like sina.cn or geosite:apple-cn"
    echo "    --ignore-ip     <ip rule>          [Optional] Add a non-proxy routing rule for ip, like geoip:\!us"
    echo "    --proxy-domain  <domain rule>      [Optional] Add a proxy routing rule for domain, like geosite:apple-cn"
    echo "    --proxy-ip      <ip rule>          [Optional] Add a proxy routing rule for ip, like 1.1.1.1/32 or geoip:netflix"
    echo "    --ltx  <VLESS-TCP-XTLS option>     id@host:port"
    echo "    --ltt  <VLESS-TCP-TLS option>      id@host:port"
    echo "    --lttw <VLESS-TCP-TLS-WS option>   id@host:port:/webpath"
    echo "    --lttg <VLESS-TCP-TLS-GRPC option> id@host:port:/svcpath"
    echo "    --mtt  <VMESS-TCP-TLS option>      id@host:port"
    echo "    --mttw <VMESS-TCP-TLS-WS option>   id@host:port:/webpath"
    echo "    --ttt  <TROJAN-TCP-TLS option>     password@host:port"
    echo "    --tttw <TROJAN-TCP-TLS-WS option>  password@host:port:/webpath"
#   echo "    --ssa  <Shadowsocks-AEAD option>   password:method@host:port"
#   echo "    --sst  <Shadowsocks-TCP option>    password:method@host:port"
}


Jrules='{"rules":[]}'

TEMP=`getopt -o di --long ltx:,ltt:,lttw:,lttg:,mtt:,mttw:,ttt:,tttw:,ssa:,sst:,ignore-domain:,ignore-ip:,ignore-china,proxy-domain:,proxy-ip:,stdin,debug -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        --ltx|--ltt|--lttw|--lttg|--mtt|--mttw|--ttt|--tttw|--ssa|--sst)
            subcmd=`echo "$1"|tr -d "\-\-"`
            $DIR/proxy-${subcmd}.sh $2 >$XCONF
            if [ $? != 0 ]; then
                echo "${subcmd} Config failed: $DIR/proxy-${subcmd}.sh $2"
                exit 2
            else
                XRAY=1
            fi
            shift 2
            ;;
        --ignore-domain)
            Jrules=`echo "${Jrules}" | jq --arg igdomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igdomain]}]'`
            shift 2
            ;;
        --ignore-ip)
            Jrules=`echo "${Jrules}" | jq --arg igip "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$igip]}]'`
            shift 2
            ;;
        --ignore-china)
            Jrules=`echo "${Jrules}" | jq --arg igdomain "geosite:apple-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igdomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igdomain "geosite:geolocation-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igdomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igip "geoip:cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$igip]}]'`
            IGCHINA=1
            shift 1
            ;;
        --proxy-domain)
            Jrules=`echo "${Jrules}" | jq --arg pxdomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "domain":[$pxdomain]}]'`
            shift 2
            ;;
        --proxy-ip)
            Jrules=`echo "${Jrules}" | jq --arg pxip "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "ip":[$pxip]}]'`
            shift 2
            ;;
        -i|--stdin)
            STDINCONF=1
            XRAY=1
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

if [ "${XRAY}" != "1" ]; then
    usage
    exit 1
fi

if [ "${IGCHINA}" = "1" ]; then
    cp -a /etc/dnsmasq-china.d/*.conf /etc/dnsmasq.d/
else
    rm -rf /etc/dnsmasq.d/*.china.conf
fi
dnsmasq

Jrouting='{"routing": {"domainStrategy":"AsIs"}}'
Jrouting=`echo "${Jrouting}" |jq --argjson jrules "${Jrules}" '.routing += $jrules'`
cat $XCONF| jq --argjson jrouting "${Jrouting}" '. += $jrouting' |sponge $XCONF

if [ "${STDINCONF}" = "1" ]; then
    exec /usr/local/bin/xray
fi

if [ "${DEBUG}" = "1" ]; then
    cat $XCONF |jq '.log.loglevel |="debug"' |sponge $XCONF
    cat $XCONF
fi

#exec /usr/local/bin/xray -c $XCONF

