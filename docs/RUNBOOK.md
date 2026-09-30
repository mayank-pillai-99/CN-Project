# Phase 1 runbook: what's left, in order

Domain: `app.team1.test` / `api.team1.test`. Edge port: **8443** (allowed by the doc).
Save every screenshot/export into `screenshots/` with a descriptive name.

| Mac | Role | IP |
|---|---|---|
| Mac 1 (vikrant) | DNS | 10.7.13.235 |
| Mac 2 (asad) | nginx edge | 10.7.17.39 |
| Mac 3 (mayank) | Backend A :3001 | 10.7.5.187 |
| Mac 4 (prashant) | Backend B :3002 | 10.7.15.184 |

## 0. Redeploy changed files
- Mac 3: `python3 backend_a.py`   Mac 4: `python3 backend_b.py`  (new: /api/cacheable with ETag/304)
- Mac 2: copy `nginx.conf` to `/opt/homebrew/etc/nginx/nginx.conf`, then `nginx -t && brew services restart nginx`
  (sudo not needed for port 8443). Delete `http2 on;` if `nginx -t` complains.
- Mac 1: copy `dns/dnsmasq.conf` to `/opt/homebrew/etc/dnsmasq.conf`, then `sudo brew services restart dnsmasq`

## 1. Task A: LAN evidence
On **each** Mac: `./scripts/net-info.sh` and `./scripts/ping-matrix.sh`. Screenshot all 8 outputs
(or paste the net-info outputs into `docs/ARCHITECTURE.md`). Note: netmask `0xffffe000` = 255.255.224.0 = /19.

## 2. Task B: clients use Mac 1 as resolver
On two Macs (e.g. Mac 3 and Mac 4): System Settings > Network > Wi-Fi > Details > DNS > add `10.7.13.235`, then
```
dig app.team1.test        # no @server! SERVER line must say 10.7.13.235
dig api.team1.test
```
Screenshot both. (dig skips the macOS resolver order quirks: also run `dscacheutil -q host -a name app.team1.test`.)

## 3. Task E: TLS (ask faculty OK for mkcert first; doc allows it "with faculty approval")
On Mac 2 (already done if the .pem files exist): `mkcert -CAROOT` shows the CA folder.
Copy `rootCA.pem` (NOT rootCA-key.pem) to Mac 3 and Mac 4, then on each:
```
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem
curl -v https://app.team1.test:8443/api/status      # no -k
openssl s_client -connect app.team1.test:8443 -servername app.team1.test </dev/null | grep -E "Verify|Protocol|subject"
curl --http2 -sI https://app.team1.test:8443/       # shows HTTP/2 if enabled
```
Also open `https://app.team1.test:8443` in a browser and screenshot the padlock.

## 3b. Task D by name
```
for i in 1 2 3 4 5 6; do curl -s -o /dev/null -D - https://app.team1.test:8443/api/status | grep -i x-backend; done
```
Expect A, B, A, B... Screenshot it. On Mac 2: `tail /opt/homebrew/var/log/nginx/access.log` shows `backend=A/B`.

## 4. Task F: caching
```
curl -sI https://app.team1.test:8443/api/cacheable            # note Cache-Control + ETag
curl -sI -H 'If-None-Match: "<etag from above>"' https://app.team1.test:8443/api/cacheable   # 304 Not Modified
```
Fresh hit = browser DevTools > Network shows "(disk cache)" within 60s (no request sent).
Conditional = request sent with If-None-Match, answered 304 (no body).
Full new request = no cached copy, 200 with body.

## 5. Task G: Wireshark evidence (on a client Mac)
1. `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
2. Terminal A: `./scripts/capture.sh 30`   Terminal B: `curl -v https://app.team1.test:8443/api/status`
3. Open the .pcap in Wireshark and screenshot each filter:
   - `dns`: query for app.team1.test to 10.7.13.235 (UDP dst port 53) + answer 10.7.17.39
   - `tcp.flags.syn==1 && tcp.port==8443`: SYN, SYN-ACK, ACK (ephemeral src port vs 8443)
   - `tls.handshake`: ClientHello, ServerHello, Certificate; later packets "Application Data" (encrypted)
   - explain why `curl -v` can show HTTP headers but Wireshark cannot: TLS encrypts HTTP
4. Also screenshot `curl -v` output showing the DNS->TCP->TLS->HTTP lines.

## 6. Failure demos (screenshot before, during, after; ALWAYS roll back)
| # | Break | Expect | Roll back |
|---|---|---|---|
| 1 | Client DNS -> `8.8.8.8` | `dig`/curl can't resolve, `ping 10.7.17.39` still works | DNS back to 10.7.13.235 |
| 2 | Mac 1: change both `address=` lines to `192.0.2.99`, `sudo brew services restart dnsmasq`, flush client cache | `dig` returns 192.0.2.99, curl hangs/times out | restore 10.7.17.39, restart |
| 3 | Ctrl+C backend_a.py on Mac 3 | requests still succeed, all `X-Backend: B` | rerun backend |
| 4 | Stop Mac 4 backend too | `502 Bad Gateway: edge is up...` (DNS+TLS still fine) | rerun both |
| 5 | `curl -v --max-time 5 https://app.team1.test:9999/` | resolves, then connection refused | none |
For each, say which layer failed (DNS / IP / TCP / TLS / app) and how you proved it.

## 7. Documents
Fill in `docs/ARCHITECTURE.md` (topology, IP table, request flow) and keep configs + backends in the repo.
