#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/proxy-xray.json

usage() {
    echo "proxy-xray <connection-options>"
    echo "    -i|--stdin                         [Optional] Read config from stdin instead of auto generation"
    echo "    -d|--debug                         [Optional] Start in debug mode with verbose output"
    echo "    --direct-china                     [Optional] Add routing rules to avoid domain and ip located in China being proxied"
    echo "    --direct-domain <domain-rule>      [Optional] Add a direct routing rule for domain, likegeosite:geosite:geolocation-cn"
    echo "    --direct-ip     <ip-rule>          [Optional] Add a direct routing rule for ip, like geoip:cn"
    echo "    --proxy-domain  <domain-rule>      [Optional] Add a proxy routing rule for domain, like twitter.com or geosite:google-cn"
    echo "    --proxy-ip      <ip-rule>          [Optional] Add a proxy routing rule for ip, like 1.1.1.1/32 or geoip:netflix"
    echo "    --block-domain  <domain-rule>      [Optional] Add a block routing rule for domain, like geosite:category-ads-all"
    echo "    --block-ip      <ip-rule>          [Optional] Add a block routing rule for ip, like geoip:private"
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

TEMP=`getopt -o di --long ltx:,ltt:,lttw:,lttg:,mtt:,mttw:,ttt:,tttw:,ssa:,sst:,direct-domain:,direct-ip:,direct-china,proxy-domain:,proxy-ip:,block-domain:,block-ip:,stdin,debug -n "$0" -- $@`
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
        --direct-domain)
            Jrules=`echo "${Jrules}" | jq --arg igndomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            shift 2
            ;;
        --direct-ip)
            Jrules=`echo "${Jrules}" | jq --arg ignip "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$ignip]}]'`
            shift 2
            ;;
        --direct-china)
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:apple-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:geolocation-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg ignip "geoip:cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$ignip]}]'`
            IGCHINA=1
            shift 1
            ;;
        --proxy-domain)
            Jrules=`echo "${Jrules}" | jq --arg pxydomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "domain":[$pxydomain]}]'`
            shift 2
            ;;
        --proxy-ip)
            Jrules=`echo "${Jrules}" | jq --arg pxyip "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "ip":[$pxyip]}]'`
            shift 2
            ;;
        --block-domain)
            Jrules=`echo "${Jrules}" | jq --arg blkdomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "domain":[$blkdomain]}]'`
            shift 2
            ;;
        --block-ip)
            Jrules=`echo "${Jrules}" | jq --arg blkip "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "ip":[$blkip]}]'`
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

