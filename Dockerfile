FROM golang:1.23-alpine3.20 AS builder

ARG XRAY_VER='v1.8.24'
ARG QREC_VER='4.1.1'

RUN apk add --no-cache bash git build-base curl

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAY_VER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

RUN cd /tmp; curl -O https://fukuchi.org/works/qrencode/qrencode-${QREC_VER}.tar.gz && \
    tar xvf qrencode-${QREC_VER}.tar.gz && \
    cd qrencode-${QREC_VER} && \
    ./configure --without-png && \
    make && \
    cp -a qrencode /tmp/

RUN cd /tmp; curl -O  https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN cd /tmp; curl -O  https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

RUN cd /tmp; curl -O  https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf
RUN cd /tmp; curl -O https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf
RUN cd /tmp; curl -O https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/bogus-nxdomain.china.conf
RUN cd /tmp; curl -O https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf


FROM alpine:3.20

COPY --from=builder /go/src/XTLS/Xray-core/xray /usr/local/bin/
COPY --from=builder /tmp/geosite.dat /usr/local/bin/
COPY --from=builder /tmp/geoip.dat /usr/local/bin/

RUN mkdir -p /etc/dnsmasq.disable

COPY --from=builder /tmp/apple.china.conf /etc/dnsmasq.disable/
COPY --from=builder /tmp/google.china.conf /etc/dnsmasq.disable/
COPY --from=builder /tmp/bogus-nxdomain.china.conf /etc/dnsmasq.disable/
COPY --from=builder /tmp/accelerated-domains.china.conf /etc/dnsmasq.disable/

COPY --from=builder /tmp/qrencode /usr/local/bin/

RUN apk --no-cache add bash openssl curl jq moreutils \
    whois dnsmasq ca-certificates proxychains-ng

RUN sed -i "s/^socks4.*/socks5\t127.0.0.1 1080/g" /etc/proxychains/proxychains.conf

ADD proxy-lgp.sh    /proxy-lgp.sh
ADD proxy-lgr.sh    /proxy-lgr.sh
ADD proxy-lgt.sh    /proxy-lgt.sh

ADD proxy-lsp.sh    /proxy-lsp.sh
ADD proxy-lst.sh    /proxy-lst.sh

ADD proxy-ltr.sh    /proxy-ltr.sh
ADD proxy-ltt.sh    /proxy-ltt.sh

ADD proxy-lwp.sh    /proxy-lwp.sh
ADD proxy-lwt.sh    /proxy-lwt.sh

ADD proxy-mtt.sh    /proxy-mtt.sh
ADD proxy-mwp.sh    /proxy-mwp.sh
ADD proxy-mwt.sh    /proxy-mwt.sh

ADD proxy-ttt.sh    /proxy-ttt.sh
ADD proxy-twp.sh    /proxy-twp.sh
ADD proxy-twt.sh    /proxy-twt.sh

ADD status.sh       /status.sh
ADD run.sh          /run.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
