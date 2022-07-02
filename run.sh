#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/proxy-xray.json

usage() {
    echo "proxy-xray <connection-options>"
    echo "    --ltx  <VLESS-TCP-XTLS option>        id@host:port[,s=sniname.org]"
    echo "    --ltt  <VLESS-TCP-TLS option>         id@host:port[,s=sniname.org]"
    echo "    --ltpw <VLESS-TCP-PLAIN-WS option>    id@host:port:/webpath"
    echo "    --lttw <VLESS-TCP-TLS-WS option>      id@host:port:/webpath[,s=sniname.org]"
    echo "    --ltpg <VLESS-TCP-PLAIN-GRPC option>  id@host:port:svcname"
    echo "    --lttg <VLESS-TCP-TLS-GRPC option>    id@host:port:svcname[,s=sniname.org]"
    echo "    --mtt  <VMESS-TCP-TLS option>         id@host:port[,s=sniname.org]"
    echo "    --mtpw <VMESS-TCP-PLAIN-WS option>    id@host:port:/webpath"
    echo "    --mttw <VMESS-TCP-TLS-WS option>      id@host:port:/webpath[,s=sniname.org]"
    echo "    --ttt  <TROJAN-TCP-TLS option>        password@host:port[,s=sniname.org]"
    echo "    --ttpw <TROJAN-TCP-PLAIN-WS option>   password@host:port:/webpath"
    echo "    --tttw <TROJAN-TCP-TLS-WS option>     password@host:port:/webpath[,s=sniname.org]"
#   echo "    --ssa  <Shadowsocks-AEAD option>      password:method@host:port"
#   echo "    --sst  <Shadowsocks-TCP option>       password:method@host:port"
    echo "    -d|--debug                            [Optional] Start in debug mode with verbose output"
    echo "    -i|--stdin                            [Optional] Read config from stdin instead of auto generation"
    echo "    --dns <upstream-DNS-ip>               [Optional] Designated upstream DNS server IP, 1.1.1.1 will be applied by default"
#   echo "    --dns-local <local-conf-file>         [Optional] Enable designated domain conf file. Like apple.china.conf"
    echo "    --dns-local-cn                        [Optional] Enable China-accessible domains to be resolved in China"
    echo "    --domain-direct <domain-rule>         [Optional] Add a domain rule for direct routing, likegeosite:geosite:geolocation-cn"
    echo "    --domain-proxy  <domain-rule>         [Optional] Add a domain rule for proxy routing, like twitter.com or geosite:google-cn"
    echo "    --domain-block  <domain-rule>         [Optional] Add a domain rule for block routing, like geosite:category-ads-all"
    echo "    --ip-direct     <ip-rule>             [Optional] Add a ip-addr rule for direct routing, like 114.114.114.114/32 or geoip:cn"
    echo "    --ip-proxy      <ip-rule>             [Optional] Add a ip-addr rule for proxy routing, like 1.1.1.1/32 or geoip:netflix"
    echo "    --ip-block      <ip-rule>             [Optional] Add a ip-addr rule for block routing, like geoip:private"
    echo "    --cn-direct                           [Optional] Add routing rules to avoid domains and IPs located in China being proxied"
    echo "    --rules-path    <rules-dir-path>      [Optional] Folder path contents geoip.dat, geosite.dat and other rule files"
}


Jrules='{"rules":[]}'

TEMP=`getopt -o di --long ltx:,ltt:,ltpw:,lttw:,ltpg:,lttg:,mtt:,mtpw:,mttw:,ttt:,ttpw:,tttw:,ssa:,sst:,stdin,debug,dns:,dns-local:,dns-local-cn,domain-direct:,domain-proxy:,domain-block:,ip-direct:,ip-proxy:,ip-block:,cn-direct,rules-path: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi
eval set -- "$TEMP"
while true ; do
    case "$1" in
        --ltx|--ltt|--ltpw|--lttw|--ltpg|--lttg|--mtt|--mtpw|--mttw|--ttt|--ttpw|--tttw|--ssa|--sst)
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
        --dns)
            DNS=$2
            shift 2
            ;;
        --dns-local)
            DNSLOCAL+=($2)
            shift 2
            ;;
        --dns-local-cn)
            DNSLOCAL+=("apple.china.conf")
            DNSLOCAL+=("google.china.conf")
            DNSLOCAL+=("bogus-nxdomain.china.conf")
            DNSLOCAL+=("accelerated-domains.china.conf")
            shift 1
            ;;
        --cn-direct)
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:apple-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:google-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:geolocation-cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg igndomain "geosite:cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            Jrules=`echo "${Jrules}" | jq --arg ignip "geoip:cn" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$ignip]}]'`
            shift 1
            ;;
        --domain-direct)
            Jrules=`echo "${Jrules}" | jq --arg igndomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "domain":[$igndomain]}]'`
            shift 2
            ;;
        --domain-proxy)
            Jrules=`echo "${Jrules}" | jq --arg pxydomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "domain":[$pxydomain]}]'`
            shift 2
            ;;
        --domain-block)
            Jrules=`echo "${Jrules}" | jq --arg blkdomain "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "domain":[$blkdomain]}]'`
            shift 2
            ;;
        --ip-direct)
            Jrules=`echo "${Jrules}" | jq --arg ignip "$2" \
            '.rules += [{"type":"field", "outboundTag":"direct", "ip":[$ignip]}]'`
            shift 2
            ;;
        --ip-proxy)
            Jrules=`echo "${Jrules}" | jq --arg pxyip "$2" \
            '.rules += [{"type":"field", "outboundTag":"proxy", "ip":[$pxyip]}]'`
            shift 2
            ;;
        --ip-block)
            Jrules=`echo "${Jrules}" | jq --arg blkip "$2" \
            '.rules += [{"type":"field", "outboundTag":"block", "ip":[$blkip]}]'`
            shift 2
            ;;
        --rules-path)
            export XRAY_LOCATION_ASSET=$2
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

if [ -n "${DNSLOCAL}" ]; then
    for dnslocal in "${DNSLOCAL[@]}"
    do
        cp -a /etc/dnsmasq.disable/${dnslocal} /etc/dnsmasq.d/
    done
fi
echo -e "no-resolv\nserver=127.0.0.1#5353" >/etc/dnsmasq.d/upstream.conf
/usr/sbin/dnsmasq

if [ -z "${DNS}" ]; then
    DNS="1.1.1.1"
fi

# Add inbounds config
JibDKDEMO=`echo '{}' | jq --arg dns "${DNS}" \
'. +={"tag": "dns-in", "port":5353, "listen":"0.0.0.0", "protocol":"dokodemo-door", "settings":{"address": $dns, "port":53, "network":"tcp,udp"}}' `
JibSOCKS=`echo '{}' | jq '. +={"tag": "socks", "port":1080, "listen":"0.0.0.0", "protocol":"socks", "settings":{"udp":true}}' `
JibHTTP=`echo '{}' | jq '. +={"tag": "http", "port":8123, "listen":"0.0.0.0", "protocol":"http"}' `
cat $XCONF| jq --argjson jibdkdemo "${JibDKDEMO}" --argjson jibsocks "${JibSOCKS}" --argjson jibhttp "${JibHTTP}" \
'. += {"inbounds":[$jibdkdemo, $jibsocks, $jibhttp]}' | sponge $XCONF

# Add routing config
Jrouting='{"routing": {"domainStrategy":"AsIs"}}'
Jrouting=`echo "${Jrouting}" |jq --argjson jrules "${Jrules}" '.routing += $jrules'`
cat $XCONF| jq --argjson jrouting "${Jrouting}" '. += $jrouting' | sponge $XCONF

if [ "${STDINCONF}" = "1" ]; then
    exec /usr/local/bin/xray
fi

if [ "${DEBUG}" = "1" ]; then
    cat $XCONF |jq '.log.loglevel |="debug"' | sponge $XCONF
    cat $XCONF
fi

exec /usr/local/bin/xray -c $XCONF

