#!/bin/bash

DIR=`dirname $0`
DIR="$(cd $DIR; pwd)"
XCONF=/tmp/proxy-xray.json

usage() {
    echo "proxy-xray <connection-options>"
    echo "    --lgp  <VLESS-GRPC-PLN option>        id@host:port:svcname"
    echo "    --lgr  <VLESS-GRPC-RLTY option>       id@host:port:svcname,d=dest.com,pub=xxxx[,shortId=abcd]"
    echo "    --lgt  <VLESS-GRPC-TLS option>        id@host:port:svcname[,s=sni.com]"
    echo "    --lsp  <VLESS-SPLT-PLN option>        id@host:port:/webpath"
    echo "    --lst  <VLESS-SPLT-TLS option>        id@host:port:/webpath[,s=sni.com]"
    echo "    --ltr  <VLESS-TCP-RLTY option>        id@host:port,d=dest.com,pub=xxxx[,shortId=abcd][,xtls]"
    echo "    --ltrx <VLESS-TCP-RLTY-XTLS option>   id@host:port,d=dest.com,pub=xxxx[,shortId=abcd]"
    echo "    --ltt  <VLESS-TCP-TLS option>         id@host:port[,s=sni.com][,xtls]"
    echo "    --lttx <VLESS-TCP-TLS-XTLS option>    id@host:port[,s=sni.com]"
    echo "    --lwp  <VLESS-WS-PLN option>          id@host:port:/wspath"
    echo "    --lwt  <VLESS-WS-TLS option>          id@host:port:/wspath[,s=sni.com]"
    echo "    --mtt  <VMESS-TCP-TLS option>         id@host:port[,s=sni.com]"
    echo "    --mwp  <VMESS-WS-PLN option>          id@host:port:/wspath"
    echo "    --mwt  <VMESS-WS-TLS option>          id@host:port:/wspath[,s=sni.com]"
    echo "    --ttt  <TROJAN-TCP-TLS option>        password@host:port[,s=sni.com]"
    echo "    --twp  <TROJAN-WS-PLN option>         password@host:port:/wspath"
    echo "    --twt  <TROJAN-WS-TLS option>         password@host:port:/wspath[,s=sni.com]"
    echo "    -d|--debug                            Start in debug mode with verbose output"
    echo "    -i|--stdin                            Read config from stdin instead of auto generation"
    echo "    -j|--json                             Json snippet to merge into the config. Say '{"log":{"loglevel":"info"}'"
    echo "    --dns  <upstream-DNS-ip>              Designated upstream DNS server IP, 1.1.1.1 will be applied by default"
#   echo "    --dns-local <local-conf-file>         Enable designated domain conf file. Like apple.china.conf"
    echo "    --dns-local-cn                        Enable China-accessible domains to be resolved in China"
    echo "    --domain-direct <domain-rule>         Add a domain rule for direct routing, likegeosite:geosite:geolocation-cn"
    echo "    --domain-proxy  <domain-rule>         Add a domain rule for proxy routing, like twitter.com or geosite:google-cn"
    echo "    --domain-block  <domain-rule>         Add a domain rule for block routing, like geosite:category-ads-all"
    echo "    --ip-direct     <ip-rule>             Add a ip-addr rule for direct routing, like 114.114.114.114/32 or geoip:cn"
    echo "    --ip-proxy      <ip-rule>             Add a ip-addr rule for proxy routing, like 1.1.1.1/32 or geoip:netflix"
    echo "    --ip-block      <ip-rule>             Add a ip-addr rule for block routing, like geoip:private"
    echo "    --cn-direct                           Add routing rules to avoid domains and IPs located in China being proxied"
    echo "    --rules-path    <rules-dir-path>      Folder path contents geoip.dat, geosite.dat and other rule files"
}


Jrules='{"rules":[]}'

TEMP=`getopt -o j:di --long lgp:,lgr:,lgt:,lsp:,lst:,ltr:,ltrx:,ltt:,lttx:,lwp:,lwt:,mtt:,mwp:,mwt:,ttt:,twp:,twt:,stdin,debug,dns:,dns-local:,dns-local-cn,domain-direct:,domain-proxy:,domain-block:,ip-direct:,ip-proxy:,ip-block:,cn-direct,rules-path:json: -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi
eval set -- "$TEMP"
while true ; do
    case "$1" in
        --lgp|--lgr|--lgt|--lsp|--lst|--ltr|--ltt|--lwp|--lwt|--mtt|--mwp|--mwt|--ttt|--twp|--twt)
            subcmd=`echo "$1"|tr -d "\-\-"`
            $DIR/proxy-${subcmd}.sh $2 >$XCONF
            if [ $? != 0 ]; then
                echo "${subcmd} Config failed: $DIR/proxy-${subcmd}.sh $2"
                exit 2
            else
                XRAYCFG=1
            fi
            shift 2
            ;;
        # Alias options
        --ltrx|--lttx)
            subcmd=`echo $1|tr -d '\-\-'|tr -d x`
            $DIR/proxy-${subcmd}.sh $2,xtls >$XCONF
            if [ $? != 0 ]; then
                echo "${subcmd} Config failed: $DIR/proxy-${subcmd}.sh $2"
                exit 2
            else
                XRAYCFG=1
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
        -j|--json)
            INJECT+=("$2")
            shift 2
            ;;
        -i|--stdin)
            STDINCONF=1
            XRAYCFG=1
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

if [ "${XRAYCFG}" != "1" ]; then
    echo "Missing Xray connection option"
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

    if [ -n "${INJECT}" ]; then
        for JSON_IN in "${INJECT[@]}"
        do
            echo "${JSON_IN}"|jq -ec >/tmp/merge.json
            if [[ $? -ne 0 ]]; then
                echo "Invalid json ${JSON_IN}"
                exit 1
            fi
            jq -s '.[0] * .[1]' $XCONF /tmp/merge.json |sponge $XCONF
        done
    fi

exec /usr/local/bin/xray -c $XCONF

