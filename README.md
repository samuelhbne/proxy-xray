# proxy-xray

[Xray](https://github.com/XTLS/Xray-core) client container with SOCKS5/HTTP/DNS proxy and QR code support. Support x86 and arm/arm64 (Raspberry Pi).

![docker-build](https://github.com/samuelhbne/proxy-xray/workflows/docker-buildx-latest/badge.svg)

## [Optional] How to build proxy-xray docker image

```shell
$ git clone https://github.com/samuelhbne/proxy-xray.git
$ cd proxy-xray
$ docker build -t samuelhbne/proxy-xray -f Dockerfile.amd64 .
...
```

### NOTE1

Please replace "amd64" with the arch match the current box accordingly. Other supported platforms:

- "arm64" for arm64v8 platforms. Support Raspberry Pi4 with 64bits OS like [Ubuntu arm64](https://ubuntu.com/download/raspberry-pi) or [Debian](https://raspi.debian.net/tested-images/).
- "arm" for arm32v7 platforms. Support most Raspberry-Pi releases (Pi2, Pi3, Pi4) with 32bits OS like [Ubuntu armhf](https://ubuntu.com/download/raspberry-pi) or [Debian](https://raspi.debian.net/tested-images/).

### NOTE2

- [Raspberry Pi OS](https://www.raspberrypi.org/software/operating-systems/) (AKA Raspbian) users may encounter dnsmasq core dump issue due to the broken docker.io package from Raspbian upstream. Please switch to Ubuntu, Debian to avoid this issue or wait the fix from Raspbian. Although SOCKS/HTTP proxies still work properly.
- arm32v5 platforms are not supported yet.

## How to start proxy-xray container

```shell
$ docker run --rm samuelhbne/proxy-xray
proxy-xray <connection-options>
    --ltx  <VLESS-TCP-XTLS option>     id@host:port[,s=sniname.org]
    --ltt  <VLESS-TCP-TLS option>      id@host:port[,s=sniname.org]
    --lttw <VLESS-TCP-TLS-WS option>   id@host:port:/webpath[,s=sniname.org]
    --lttg <VLESS-TCP-TLS-GRPC option> id@host:port:/svcpath[,s=sniname.org]
    --mtt  <VMESS-TCP-TLS option>      id@host:port[,s=sniname.org]
    --mttw <VMESS-TCP-TLS-WS option>   id@host:port:/webpath[,s=sniname.org]
    --ttt  <TROJAN-TCP-TLS option>     password@host:port[,s=sniname.org]
    --tttw <TROJAN-TCP-TLS-WS option>  password@host:port:/webpath[,s=sniname.org]
    -d|--debug                         [Optional] Start in debug mode with verbose output
    -i|--stdin                         [Optional] Read config from stdin instead of auto generation
    --dns <upstream-DNS-ip>            [Optional] Designated upstream DNS server IP, 1.1.1.1 will be applied by default
    --dns-local-cn                     [Optional] Enable China-accessible domains to be resolved in China
    --domain-direct <domain-rule>      [Optional] Add a domain rule for direct routing, likegeosite:geosite:geolocation-cn
    --domain-proxy  <domain-rule>      [Optional] Add a domain rule for proxy routing, like twitter.com or geosite:google-cn
    --domain-block  <domain-rule>      [Optional] Add a domain rule for block routing, like geosite:category-ads-all
    --ip-direct     <ip-rule>          [Optional] Add a ip-addr rule for direct routing, like 114.114.114.114/32 or geoip:cn
    --ip-proxy      <ip-rule>          [Optional] Add a ip-addr rule for proxy routing, like 1.1.1.1/32 or geoip:netflix
    --ip-block      <ip-rule>          [Optional] Add a ip-addr rule for block routing, like geoip:private
    --cn-direct                        [Optional] Add routing rules to avoid domains and IPs located in China being proxied
    --rules-path    <rules-dir-path>   [Optional] Folder path contents geoip.dat, geosite.dat and other rule files

$ docker run --name proxy-xray -p 2080:1080 -p 2080:1080/udp -p 8223:8123 -p 65353:53/udp \
-d samuelhbne/proxy-xray --ltx myid@mydomain.duckdns.org:443 --cn-direct --dns-local-cn
...
```

### NOTE3

- Please replace "mydomain.duckdns.org" with the Xray server domain you want to connect
- Please replace 2080 (-p 2080:1080, -p 2080:1080/udp) with the port number you set for SOCKS5 proxy TCP listerning.
- Please replace 8223 (-p 8223:8123) with the port number you set for HTTP proxy TCP listerning.
- Please replace 65353 (-p 65353:53/udp) with the port number you set for DNS UDP listerning.
- Please replace "myid" with the id string or standard UUID (like "MyMobile or "b77af52c-2a93-4b3e-8538-f9f91114ba00") you set for Xray server access.

### NOTE4

Name query for sites outside China like twitter.com will be always forwarded to designated DNS like 1.1.1.1 to avoid the contaminated result. Name query for sites inside China like apple.com.cn will be forwarded to local DNS servers in China to avoid cross region slow access when "--dns-local-cn" options applied. Otherwise dnsmasq will act as a forward only cache server.

## How to verify if proxy tunnel is working properly

```shell
$ curl -sSx socks5h://127.0.0.1:2080 https://ifconfig.co
12.34.56.78

$ curl -sSx http://127.0.0.1:8223 https://checkip.amazonaws.com/
12.34.56.78

$ dig +short @127.0.0.1 -p 65353 twitter.com
104.244.42.193
104.244.42.129

$ docker exec proxy-xray proxychains whois 104.244.42.193|grep OrgId
[proxychains] config file found: /etc/proxychains/proxychains.conf
[proxychains] preloading /usr/lib/libproxychains4.so
[proxychains] DLL init: proxychains-ng 4.14
[proxychains] Strict chain  ...  127.0.0.1:1080  ...  whois.arin.net:43  ...  OK
OrgId:          TWITT
```

### NOTE5

- curl should return the Xray server address given above if SOCKS5/HTTP proxy works properly.
- dig should return resolved IP recorders of twitter.com if DNS server works properly.
- Whois should return "OrgId: TWITT". That means the IP address returned from dig query belongs to twitter.com indeed, hence untaminated.
- Whois was actually running inside the proxy container through the proxy tunnel to avoid potential access blocking.
- Please have a look over the sibling project [server-xray](https://github.com/samuelhbne/server-xray) if you'd like to set a Xray server.

## How to get the XRay QR code for mobile connection

```shell
$ docker exec -t proxy-xray /status.sh
VPS-Server: mydomain.duckdns.org
Xray-URL: vless://myid@mydomain.duckdns.org:443?security=xtls&type=tcp&flow=xtls-rprx-direct#mydomain.duckdns.org:443
```

![QR code example](https://github.com/samuelhbne/proxy-xray/blob/master/images/qr-xray.png)

## How to stop and remove the running container

```shell
$ docker stop proxy-xray
...
$ docker rm proxy-xray
...
```

## More complex examples

### 1. Connect to Vless+TCP+XTLS server

The following instruction connect to mydomain.duckdns.org port 443 in Vless+TCP+XTLS mode. Connection made via IP address to avoid DNS contamination. TLS servername provided via parameter. All sites and IP from China will not been proxied.

```shell
$ docker run --name proxy-xray -p 1080:1080 -p 1080:1080/udp -d samuelhbne/proxy-xray \
--ltx myid@12.34.56.78:443,serverName=mydomain.duckdns.org --cn-direct
```

### 2. Connect to Vless+TCP+TLS+Websocket server

The following instruction connect to Xray server port 443 in Vless+TCP+TLS+Websocket mode with given id. All apple-cn sites will be proxied. All sites located in China will not be proxied.

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray \
--lttw myid@mydomain.duckdns.org:443:/websocket \
--domain-proxy geosite:apple-cn --domain-direct geosite:geolocation-cn
```

### 3. Connect to Vless+TCP+TLS+gRPC server

The following instruction connect to Xray server port 443 in Vless+TCP+TLS+gRPC mode with given password. All sites not located in China will be proxied. You need to escape '!' character in --domain-proxy parameter to be accepted by shell.

```shell
$ docker run --name proxy-xray -p 1080:1080 samuelhbne/proxy-xray \
--lttg myid@mydomain.duckdns.org:443:/gsvc --domain-proxy geosite:geolocation-\!cn
```

### 4. Connect to TCP+TLS+Trojan server

The following instruction connect to Xray server port 443 in TCP+TLS+Trojan mode with given password; Update geosite and geoip rule dat files; All sites and IPs located in Iran will be connected directed.

```shell
$ mkdir -p /tmp/rules
$ cd /tmp/rules
$ wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
$ wget -c -t3 -T30 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
$ wget -c -t3 -T30 https://github.com/SamadiPour/iran-hosted-domains/releases/download/202108210015/iran.dat
$ docker run --name proxy-xray -p 1080:1080 -v /tmp/rules:/opt/rules -d samuelhbne/proxy-xray \
--ttt trojan_pass@mydomain.duckdns.org:8443 \
--rules-path /opt/rules --domain-direct ext:iran.dat:ir --ip-direct geoip:ir
```

### 5. Start proxy-xray container in debug mode for for connection issue diagnosis

The following instruction start proxy-xray in debug mode. Output Xray config file generated and the Xray log to console for connection diagnosis.

```shell
$ docker run --rm -p 1080:1080 samuelhbne/proxy-xray \
--mttw myid@mydomain.duckdns.org:443:/websocket --debug
```

### NOTE6

For more details about routing rules setting up please look into [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) project (Chinese).

## Credits

Thanks to [RPRX](https://github.com/RPRX) for the [Xray](https://github.com/XTLS/Xray-core) project.

Thanks to [Loyalsoldier](https://github.com/Loyalsoldier) for the [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) project.

Thanks to [felixonmars](https://github.com/felixonmars) for the [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) project.
