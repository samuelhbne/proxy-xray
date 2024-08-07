FROM golang:1.22-alpine3.20 as builder

ARG XRAY_VER='v1.8.23'
ARG QREC_VER='4.1.1'

RUN apk add --no-cache bash git build-base wget

RUN cd /tmp; wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
RUN cd /tmp; wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

RUN cd /tmp; wget -c -t3 -T30 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf
RUN cd /tmp; wget -c -t3 -T30 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf
RUN cd /tmp; wget -c -t3 -T30 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/bogus-nxdomain.china.conf
RUN cd /tmp; wget -c -t3 -T30 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

RUN cd /tmp; wget -c -t3 -T30 https://fukuchi.org/works/qrencode/qrencode-${QREC_VER}.tar.gz && \
    tar xvf qrencode-${QREC_VER}.tar.gz && \
    cd qrencode-${QREC_VER} && \
    ./configure --without-png && \
    make && \
    cp -a qrencode /tmp/

WORKDIR /go/src/XTLS/Xray-core
RUN git clone https://github.com/XTLS/Xray-core.git . && \
    git checkout ${XRAY_VER} && \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main


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

ADD proxy-ltx.sh    /proxy-ltx.sh
ADD proxy-ltt.sh    /proxy-ltt.sh
ADD proxy-ltpw.sh   /proxy-ltpw.sh
ADD proxy-lttw.sh   /proxy-lttw.sh
ADD proxy-ltpg.sh   /proxy-ltpg.sh
ADD proxy-lttg.sh   /proxy-lttg.sh
ADD proxy-mtt.sh    /proxy-mtt.sh
ADD proxy-mtpw.sh   /proxy-mtpw.sh
ADD proxy-mttw.sh   /proxy-mttw.sh
ADD proxy-ttt.sh    /proxy-ttt.sh
ADD proxy-ttpw.sh   /proxy-ttpw.sh
ADD proxy-tttw.sh   /proxy-tttw.sh
ADD status.sh       /status.sh
ADD run.sh          /run.sh

RUN chmod 755 /*.sh

ENTRYPOINT ["/run.sh"]
