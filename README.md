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

- Please replace Dockerfile.amd64 with the Dockerfile.ARCH match your server accordingly. For example: Dockerfile.arm for 32bit Raspbian, Dockerfile.arm64 for 64bit Ubuntu for Raspberry Pi.

## How to start proxy-xray container

```shell
$ docker run --rm -it samuelhbne/proxy-xray:amd64
proxy-xray --<ltx|ltt|lttw|mtt|mttw|ttt|tttw|ssa|sst|stdin> [options]
    --ltx  <VLESS-TCP-XTLS option>    uuid@xray-host:port
    --ltt  <VLESS-TCP-TLS option>     uuid@xray-host:port
    --lttw <VLESS-TCP-TLS-WS option>  uuid@xray-host:port:/webpath
    --mtt  <VMESS-TCP-TLS option>     uuid@xray-host:port
    --mttw <VMESS-TCP-TLS-WS option>  uuid@xray-host:port:/webpath
    --ttt  <TROJAN-TCP-TLS option>    password@xray-host:port
    --tttw <TROJAN-TCP-TLS-WS option> password@xray-host:port:/webpath
    --stdin                           Read XRay config from stdin instead of auto generation

$ docker run --name proxy-xray -p 21080:1080 -p 65353:53/udp -p 28123:8123 -d samuelhbne/proxy-xray:amd64 --ltx bec24d96-410f-4723-8b3b-46987a1d9ed8@mydomain.duckdns.org:443
...
```

### NOTE2

- Please replace "amd64" with the arch match the current box accordingly. For example: "arm64" for AWS ARM64 platform like A1, t4g instance or 64bit Ubuntu on Raspberry Pi. "arm" for 32bit Raspbian.
- Please replace "mydomain.duckdns.org" with the Xray server hotsname you want to connect
- Please replace 21080 with the port number you want for SOCKS5 proxy TCP listerning.
- Please replace 28123 with the port number you want for HTTP proxy TCP listerning.
- Please replace 65353 with the port number you want for DNS UDP listerning.
- Please replace "bec24d96-410f-4723-8b3b-46987a1d9ed8" with the uuid you want to set for Xray server access.

## How to verify if proxy tunnel is working properly

```shell
$ curl -sSx socks5h://127.0.0.1:21080 http://ifconfig.co
12.34.56.78

$ curl -sSx http://127.0.0.1:28123 http://ifconfig.co
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
Xray-URL: vless://bec24d96-410f-4723-8b3b-46987a1d9ed8@mydomain.duckdns.org:443?security=xtls&type=tcp&flow=xtls-rprx-direct#mydomain.duckdns.org:443
```

![QR code example](https://github.com/samuelhbne/proxy-xray/blob/master/images/qr-xray.png)

## How to stop and remove the running container

```shell
$ docker stop proxy-xray
...
$ docker rm proxy-xray
...
```
