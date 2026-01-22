FROM golang:1.25-alpine3.22 AS builder

ARG XRAY_VER='v26.1.18'

RUN apk add --no-cache bash git build-base curl

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAY_VER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

RUN curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN curl -sSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
RUN curl -sSLO https://github.com/bootmortis/iran-hosted-domains/releases/download/202507140045/iran.dat

RUN curl -sSLO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf
RUN curl -sSLO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf
RUN curl -sSLO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/bogus-nxdomain.china.conf
RUN curl -sSLO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf


FROM alpine:3.22

COPY --from=builder /go/src/XTLS/Xray-core/xray         /usr/local/bin/
COPY --from=builder /go/src/XTLS/Xray-core/geosite.dat  /usr/local/bin/
COPY --from=builder /go/src/XTLS/Xray-core/geoip.dat    /usr/local/bin/
COPY --from=builder /go/src/XTLS/Xray-core/iran.dat     /usr/local/bin/

RUN mkdir -p /etc/dnsmasq.disable

COPY --from=builder /go/src/XTLS/Xray-core/apple.china.conf                 /etc/dnsmasq.disable/
COPY --from=builder /go/src/XTLS/Xray-core/google.china.conf                /etc/dnsmasq.disable/
COPY --from=builder /go/src/XTLS/Xray-core/bogus-nxdomain.china.conf        /etc/dnsmasq.disable/
COPY --from=builder /go/src/XTLS/Xray-core/accelerated-domains.china.conf   /etc/dnsmasq.disable/

RUN apk --no-cache add bash openssl curl jq moreutils \
    whois dnsmasq ca-certificates proxychains-ng libqrencode-tools

RUN sed -i "s/^socks4.*/socks5\t127.0.0.1 1080/g" /etc/proxychains/proxychains.conf

COPY proxy-lgp.sh   /proxy-lgp.sh
COPY proxy-lgr.sh   /proxy-lgr.sh
COPY proxy-lgt.sh   /proxy-lgt.sh

COPY proxy-lsp.sh   /proxy-lsp.sh
COPY proxy-lst.sh   /proxy-lst.sh

COPY proxy-ltr.sh   /proxy-ltr.sh
COPY proxy-ltt.sh   /proxy-ltt.sh

COPY proxy-lwp.sh   /proxy-lwp.sh
COPY proxy-lwt.sh   /proxy-lwt.sh

COPY proxy-mtt.sh   /proxy-mtt.sh
COPY proxy-mwp.sh   /proxy-mwp.sh
COPY proxy-mwt.sh   /proxy-mwt.sh

COPY proxy-ttt.sh   /proxy-ttt.sh
COPY proxy-twp.sh   /proxy-twp.sh
COPY proxy-twt.sh   /proxy-twt.sh

COPY qrcode.sh      /qrcode
COPY run.sh         /run.sh

RUN chmod 755 /*.sh
RUN chmod 755 /qrcode

ENTRYPOINT ["/run.sh"]
