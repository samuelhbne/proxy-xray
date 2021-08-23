# proxy-xray

Xray client container with SOCKS5/HTTP/DNS proxy and QR code support. Running on x86 and arm/arm64 (Raspberry Pi).

![docker-build](https://github.com/samuelhbne/proxy-xray/workflows/docker-buildx-latest/badge.svg)

## [Optional] How to build proxy-xray docker image

```shell
$ git clone https://github.com/samuelhbne/proxy-xray.git
$ cd proxy-xray
$ docker build -t samuelhbne/proxy-xray:amd64 -f Dockerfile.amd64 .
...
```

### NOTE1

- Please replace Dockerfile.amd64 with the Dockerfile.ARCH match your server accordingly. For example: Dockerfile.arm for 32bit Raspbian, Dockerfile.arm64 for 64bit Ubuntu on Raspberry Pi.

## How to start proxy-xray container

```shell
$ docker run --rm -it samuelhbne/proxy-xray:amd64
proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [connect options] [-i|--stdin] [-d|--debug]
    -i|--stdin                         [Optional] Read config from stdin instead of auto generation
    -d|--debug                         [Optional] Start in debug mode with verbose output
    --ltx  <VLESS-TCP-XTLS option>     id@host:port
    --ltt  <VLESS-TCP-TLS option>      id@host:port
    --lttw <VLESS-TCP-TLS-WS option>   id@host:port:/webpath
    --lttg <VLESS-TCP-TLS-GRPC option> id@host:port:/svcpath
    --mtt  <VMESS-TCP-TLS option>      id@host:port
    --mttw <VMESS-TCP-TLS-WS option>   id@host:port:/webpath
    --ttt  <TROJAN-TCP-TLS option>     password@host:port
    --tttw <TROJAN-TCP-TLS-WS option>  password@host:port:/webpath

$ docker run --name proxy-xray -p 1080:2080 -p 65353:53/udp -p 8123:8223 -d samuelhbne/proxy-xray \
--ltx myid@mydomain.duckdns.org:443
...
```

### NOTE2

- Please replace "mydomain.duckdns.org" with the Xray server domain you want to connect
- Please replace 1080 (-p 1080:2080) with the port number you set for SOCKS5 proxy TCP listerning.
- Please replace 8123 (-p 8123:8223) with the port number you set for HTTP proxy TCP listerning.
- Please replace 65353 (-p 65353:53/udp) with the port number you set for DNS UDP listerning.
- Please replace "myid" with the id string or standard UUID (like "MyMobile or "b77af52c-2a93-4b3e-8538-f9f91114ba00") you set for Xray server access.

## How to verify if proxy tunnel is working properly

```shell
$ curl -sSx socks5h://127.0.0.1:1080 http://ifconfig.co
12.34.56.78

$ curl -sSx http://127.0.0.1:8123 http://ifconfig.co
12.34.56.78

$ dig +short @127.0.0.1 -p 65353 twitter.com
104.244.42.193
104.244.42.129

$ docker exec -it proxy-xray proxychains whois 104.244.42.193|grep OrgId
[proxychains] config file found: /etc/proxychains/proxychains.conf
[proxychains] preloading /usr/lib/libproxychains4.so
[proxychains] DLL init: proxychains-ng 4.14
[proxychains] Strict chain  ...  127.0.0.1:1080  ...  whois.arin.net:43  ...  OK
OrgId:          TWITT
```

### NOTE3

- curl should return the VPN server address given above if SOCKS5/HTTP proxy works properly.
- dig should return resolved IP recorders of twitter.com if DNS server works properly.
- Whois should return "OrgId: TWITT". That means the IP address returned from dig query belongs to twitter.com indeed, hence untaminated.
- Whois was actually running inside the proxy container through the proxy tunnel to avoid potential access blocking.
- Please have a look over the sibling project [server-xray](https://github.com/samuelhbne/server-xray) if you'd like to set a Xray server.

## How to get the XRay QR code for mobile connection

```shell
$ docker exec -it proxy-xray /status.sh
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

The following instruction connect to Xray server port 443 in Vless+TCP+XTLS mode with given id.

```shell
$ docker run --name proxy-xray -p 1080:1080 -p 1080:1080/udp -d samuelhbne/proxy-xray --ltx \
myid@mydomain.duckdns.org:443
```

### 2. Connect to Vless+TCP+TLS+Websocket server

The following instruction connect to Xray server port 443 in Vless+TCP+TLS+Websocket mode with given id.

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --lttw \
myid@mydomain.duckdns.org:443:/websocket
```

### 3. Connect to Vless+TCP+TLS+gRPC server in debug mode for diagnosis

The following instruction connect to Xray server port 443 in Vless+TCP+TLS+gRPC mode with given password.

```shell
$ docker run --name proxy-xray -p 1080:1080 -it samuelhbne/proxy-xray --lttg \
myid@mydomain.duckdns.org:443:/gsvc
```

### 4. Connect to TCP+TLS+Trojan in server

The following instruction connect to Xray server port 443 in TCP+TLS+Trojan mode with given password.

```shell
$ docker run --name proxy-xray -p 1080:1080 -d samuelhbne/proxy-xray --ttt \
trojan_pass@mydomain.duckdns.org:8443
```

### 5. Start proxy-trojan container in debug mode for for connection issue diagnosis

The following instruction start proxy-trojan in debug mode. Output Xray config file and the log to console for connection diagnosis. dnscrypt-proxy will be disabled to avoid flooding the log output.

```shell
$ docker run --rm -p 1080:1080 -it samuelhbne/proxy-xray \
--mttw myid@mydomain.duckdns.org:443:/websocket --debug
```
