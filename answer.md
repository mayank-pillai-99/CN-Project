# Phase 1 Submission Answers (Team 1)

Items marked **TODO** still need new evidence before you submit (listed at the end of this file).

---

## A1: Machine IPs and roles
```
Mac 1 / DNS server (Vikrant):    10.7.13.235  (en0)
Mac 2 / Edge nginx (Asad):       10.7.17.39   (en0)
Mac 3 / Backend A (Mayank):      10.7.5.187   (en0)
Mac 4 / Backend B (Prashant):    10.7.15.184  (en0)
```
Subnet 10.7.0.0/19 (mask 255.255.224.0), gateway 10.7.0.1. All machines are local MacBooks on the same Wi-Fi. Evidence: `evidence/taskA-lan/`.

## A2: dnsmasq configuration
```
listen-address=10.7.13.235,127.0.0.1
interface=en0
address=/app.team1.test/10.7.17.39
address=/api.team1.test/10.7.17.39
```
`listen-address` includes Mac 1's LAN IP (10.7.13.235), not only 127.0.0.1, so other machines can use this DNS server.
**TODO:** `interface=en0` was added to `config/dnsmasq.conf` in the repo; Vikrant must add the same line to the running `/opt/homebrew/etc/dnsmasq.conf` and restart dnsmasq so the pasted lines match what is running.

## A3: `dig app.team1.test` from a client (Mac 3)
```
$ dig app.team1.test

; <<>> DiG 9.10.6 <<>> app.team1.test
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 37158
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;app.team1.test.			IN	A

;; ANSWER SECTION:
app.team1.test.		0	IN	A	10.7.17.39

;; Query time: 57 msec
;; SERVER: 10.7.13.235#53(10.7.13.235)
;; WHEN: Thu Oct 01 13:49:53 IST 2026
;; MSG SIZE  rcvd: 59
```
The ANSWER SECTION shows the edge IP (10.7.17.39) and the SERVER line shows our DNS server (10.7.13.235), not 8.8.8.8 or the router. Evidence: `evidence/taskB-dns/taskB-mac3-dig.png`.

## A4: `dig @8.8.8.8 app.team1.test` (run from Mac 3)
```
$ dig @8.8.8.8 app.team1.test +time=3 +tries=1

; <<>> DiG 9.10.6 <<>> @8.8.8.8 app.team1.test +time=3 +tries=1
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 59539
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;app.team1.test.			IN	A

;; AUTHORITY SECTION:
.			86359	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2026100100 1800 900 604800 86400

;; Query time: 14 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Thu Oct 01 17:55:47 IST 2026
;; MSG SIZE  rcvd: 118
```
Google's public DNS returns NXDOMAIN, so `app.team1.test` exists only on our private DNS server.

## A5: Ping between machines
Run from Mac 3 (10.7.5.187), 4 packets each:
```
Mac3 -> Mac1: ping 10.7.13.235 - 4 packets transmitted, 4 received, 0.0% packet loss (avg 63.1 ms)
Mac3 -> Mac2: ping 10.7.17.39  - 4 packets transmitted, 4 received, 0.0% packet loss (avg 36.8 ms)
Mac3 -> Mac4: ping 10.7.15.184 - 4 packets transmitted, 4 received, 0.0% packet loss (avg 680.8 ms)
```
Evidence: `evidence/taskA-lan/taskA-mac3-pingmatrix.png` also shows all four targets reachable from Mac 3.
**TODO:** the other pairs (Mac1-Mac2, Mac1-Mac4, Mac2-Mac4) must be run from those Macs and added here as `4 packets, 0% loss`.

---

## B1: `curl -v https://app.team1.test:8443/api/status` (Mac 3, no `-k`)
```
$ curl -v https://app.team1.test:8443/api/status

* Host app.team1.test:8443 was resolved.
* IPv6: (none)
* IPv4: 10.7.17.39
*   Trying 10.7.17.39:8443...
* Connected to app.team1.test (10.7.17.39) port 8443
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256 / [blank] / UNDEF
* ALPN: server accepted h2
* Server certificate:
*  subject: O=mkcert development certificate; OU=faizali1@Asads-MacBook-Pro-2.local (Faiz Ali)
*  start date: Oct  1 07:10:34 2026 GMT
*  expire date: Jan  1 07:10:34 2029 GMT
*  subjectAltName: host "app.team1.test" matched cert's "app.team1.test"
*  issuer: O=mkcert development CA; OU=faizali1@Asads-MacBook-Pro-2.local (Faiz Ali); CN=mkcert faizali1@Asads-MacBook-Pro-2.local (Faiz Ali)
*  SSL certificate verify ok.
* using HTTP/2
* [HTTP/2] [1] OPENED stream for https://app.team1.test:8443/api/status
* [HTTP/2] [1] [:method: GET]
* [HTTP/2] [1] [:scheme: https]
* [HTTP/2] [1] [:authority: app.team1.test:8443]
* [HTTP/2] [1] [:path: /api/status]
* [HTTP/2] [1] [user-agent: curl/8.7.1]
* [HTTP/2] [1] [accept: */*]
> GET /api/status HTTP/2
> Host: app.team1.test:8443
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/2 200
< server: nginx/1.31.6
< date: Thu, 01 Oct 2026 08:39:35 GMT
< content-type: application/json
< x-backend: A
< cache-control: max-age=60
<
* Connection #0 left intact
{"backend": "A", "status": "ok"}
```
No `-k`, domain name used (not an IP), TLSv1.3, certificate SAN matches `app.team1.test`, verify ok, HTTP 200. (The "(304)" in the TLS lines is curl's label for TLS 1.3 handshake messages, not an HTTP status.) Evidence: `evidence/taskE-tls/tls-curl-success-mac3.png` (Mac 4 has the same: `tls-curl-success-mac4.png`).

## B2: Load balancing, consecutive `curl -i https://app.team1.test:8443/api/status`
```
Request 1: x-backend: A   {"backend": "A", "status": "ok"}
Request 2: x-backend: A   {"backend": "A", "status": "ok"}
Request 3: x-backend: B   {"backend": "B", "status": "ok"}
Request 4: x-backend: A   {"backend": "A", "status": "ok"}
Request 5: x-backend: B   {"backend": "B", "status": "ok"}
```
Five consecutive requests to the same domain name through the nginx edge were served by both Backend A and Backend B (A, A, B, A, B), so the traffic is being distributed across both backends. Evidence: `evidence/taskC-D-load-balancing/load-balancer.png`.

## B3: nginx configuration
```nginx
http {
    upstream backend_servers {
        server 10.7.5.187:3001;   # Mac 3 (Backend A)
        server 10.7.15.184:3002;  # Mac 4 (Backend B)
    }

    server {
        listen 8443 ssl;
        server_name app.team1.test api.team1.test;

        ssl_certificate     /opt/homebrew/etc/nginx/app.team1.test.pem;
        ssl_certificate_key /opt/homebrew/etc/nginx/app.team1.test-key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
```
**TODO:** the live nginx on Mac 2 also has HTTP/2 enabled and a custom 502 page (visible in the curl output). Copy the real `/opt/homebrew/etc/nginx/nginx.conf` into `config/nginx.conf` and paste that version here.

---

## C1: DNS capture (filter: `dns`)
Query (frame 1, t=0.000000, 74 bytes): `Standard query 0x1327 A app.team1.test` from the client Mac 3, 10.7.5.187 (UDP source port 58206), to our DNS server Mac 1, 10.7.13.235, UDP destination port 53.
Response (frame 2, t=0.046210, 90 bytes): `Standard query response 0x1327 A app.team1.test A 10.7.17.39` from 10.7.13.235:53 back to 10.7.5.187:58206. ANSWER: `app.team1.test A 10.7.17.39`, TTL 0, so the name resolves to the edge (Mac 2, nginx). Both packets carry the same transaction ID 0x1327, and the answer came back in about 46 ms. Evidence: `evidence/taskG-packet-analysis/dns-flow.png`.

## C2: TCP 3-way handshake (filter: `tcp.port==8443`, SYN packets shown by `tcp.flags.syn==1`)
- **SYN** (frame 3): 10.7.5.187:56982 to 10.7.17.39:8443, Seq=0, Win=65535, MSS=1460. The client's ephemeral port is 56982 and the server's destination port is 8443.
- **SYN-ACK** (frame 4): 10.7.17.39:8443 to 10.7.5.187:56982, Seq=0, Ack=1. The server accepts and acknowledges the SYN.
- **ACK** (frame 5): 10.7.5.187:56982 to 10.7.17.39:8443, Seq=1, Ack=1. The connection is established.
- The first data packet, the TLS ClientHello (frame 6), only starts after this ACK, so no application data is sent before the handshake completes.
- This handshake establishes a reliable, ordered, connection-oriented channel between the two ports, and the sequence and acknowledgement numbers track the bytes in each direction. The connection is closed later with FIN/ACK packets (frames 27 to 33).
Evidence: `evidence/taskG-packet-analysis/tcp-3-way.png`.

## C3: TLS handshake (filter: `tls`)
- **ClientHello** (frame 6, 390 bytes, 10.7.5.187:56982 to 10.7.17.39:8443): SNI `app.team1.test`; offers TLS 1.3 (also 1.2, 1.1 and 1.0) via the supported_versions extension, with cipher suites starting `TLS_CHACHA20_POLY1305_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_AES_128_GCM_SHA256`, followed by older TLS 1.2 suites.
- **ServerHello** (frame 9, 1514 bytes, from 10.7.17.39:8443): the server picks `TLS_CHACHA20_POLY1305_SHA256` (TLS 1.3), matching curl's "SSL connection using TLSv1.3". The same frame contains a Change Cipher Spec and Application Data records.
- **Certificate:** in TLS 1.3 the server's certificate is sent encrypted inside those Application Data records, so Wireshark shows no separate Certificate packet. curl -v (B1) shows the certificate: subject mkcert development certificate, SAN `app.team1.test` matched, issuer mkcert development CA, verify ok.
- **ChangeCipherSpec / Application Data:** the client sends its own Change Cipher Spec (frame 12) and then only `Application Data` packets (frames 13 to 26). After the handshake, every packet is an encrypted TLS record.
- **Why HTTP is unreadable:** the HTTP request and response (HTTP/2 here) travel inside those encrypted records, so the headers, URL and body cannot be read in Wireshark without the session keys. Only IP addresses, ports, packet sizes and timing are visible. That is why we use `curl -v` to show the HTTP headers.
Evidence: `evidence/taskG-packet-analysis/TLS-handshake.png` and `application-data.png`.

---

## D1: `curl -i https://app.team1.test:8443/api/status` (caching headers)
```
HTTP/2 200
server: nginx/1.31.6
date: Thu, 01 Oct 2026 08:47:45 GMT
content-type: application/json
x-backend: A
cache-control: max-age=60

{"backend": "A", "status": "ok"}
```
Cache-Control, Date and X-Backend are all present. We did not add an ETag. Evidence: `evidence/taskF-caching/taskF-curl-headers.png`.
**TODO:** the form asks for `curl -sI`. That sends a HEAD request, which the original backends rejected with 501. `do_HEAD` is now added to both backends in the repo; restart both backends from the repo, re-run `curl -sI https://app.team1.test:8443/api/status` and paste that output here.

## D2: What the Cache-Control value means
`Cache-Control: max-age=60` tells the client that the response is fresh for 60 seconds, so during that time a browser or cache can reuse its stored copy without contacting the server at all. After 60 seconds the copy is stale, and the client must send a new request to the server (through nginx to one of the backends) and store the new response. We did not set an ETag, so our stale responses are re-fetched in full instead of getting a 304 Not Modified. (If an ETag were set, the client could send it back as If-None-Match, and the server would answer 304 with no body when nothing had changed.)

## D3: Failure demonstration
1. **Option A: stop one backend** (Backend A on Mac 3).
2. **Before:** requests to `https://app.team1.test:8443/api/status` are served by both backends (x-backend: A, A, B, A, B). Evidence: `evidence/taskC-D-load-balancing/load-balancer.png`.
3. **After:** with Backend A stopped, every response is `HTTP/2 200` with `x-backend: B` and `{"backend": "B", "status": "ok"}` (three consecutive requests at 09:57:41, 09:57:44 and 09:57:46 GMT). Evidence: `evidence/failure-scenarios/fail3-one-backend-stopped.png`.
4. **Layer affected:** the application / backend service layer behind the load balancer. The service on 10.7.5.187:3001 stopped accepting connections, so nginx stopped sending requests to it and used the remaining healthy backend. DNS, IP, the TCP connection to the edge and TLS were not affected, since the client still resolved the name, connected to nginx and completed the TLS handshake. It shows why a load balancer gives resilience.
5. **Restored:** Backend A is restarted with `python3 backend/backend_a.py` on Mac 3, after which responses alternate between A and B again.
**TODO:** capture a screenshot after restarting Backend A that shows A and B alternating again, as proof it was restored.

---

## TODO list before submitting
1. Restart both backends from the repo (HEAD fix), then run `curl -sI` (D1) and paste the output.
2. Take a post-restore screenshot for D3 (Backend A back, A and B alternating).
3. Pings between the remaining machine pairs (A5).
4. Vikrant: add `interface=en0` to the running dnsmasq config (A2). Asad: copy the live nginx.conf into `config/nginx.conf` (B3).
