# Architecture: Team 1 Private Network Service Platform

## Topology
```
                        Private Wi-Fi/LAN (10.7.x.x, gateway 10.7.0.1)
   +--------------------+        +----------------------+
   | Mac 1  vikrant     |        | Mac 2  asad          |
   | DNS (dnsmasq :53)  |        | nginx edge :8443     |
   | 10.7.13.235        |        | TLS + load balancer  |
   +--------------------+        | 10.7.17.39           |
                                 +----------+-----------+
                                      round-robin
                     +------------------+  |  +------------------+
                     | Mac 3  mayank    |<-+--+>| Mac 4  prashant |
                     | Backend A :3001  |       | Backend B :3002 |
                     | 10.7.5.187       |       | 10.7.15.184     |
                     +------------------+       +-----------------+
   Clients (any Mac) -> ask Mac 1 for app.team1.test -> HTTPS to Mac 2 -> A or B
```

## Roles, services, cloud equivalents
| Machine | Role | Service | Cloud equivalent |
|---|---|---|---|
| Mac 1 | DNS server + client | dnsmasq, UDP/TCP 53 | Route 53 |
| Mac 2 | Edge reverse proxy + LB | nginx, TCP 8443 (TLS) | CDN edge / ALB |
| Mac 3 | Backend A | Python REST, TCP 3001 | app server instance A |
| Mac 4 | Backend B + client | Python REST, TCP 3002 | app server instance B |

Per-machine interface details (mask, gateway, MAC): fill in from `scripts/net-info.sh`.
Mac 3: en0, 10.7.5.187, mask 255.255.224.0 (/19), gateway 10.7.0.1, MAC de:9f:c0:36:69:0c.

## Request flow and protocol layers
| Step | What happens | Layer | Protocol / port |
|---|---|---|---|
| 1 | Client asks Mac 1 "A record for app.team1.test?" -> 10.7.17.39 | Application | DNS, UDP 53 |
| 2 | Client opens connection to 10.7.17.39:8443 (SYN, SYN-ACK, ACK) | Transport | TCP, ephemeral -> 8443 |
| 3 | ClientHello / ServerHello / Certificate / Finished; nginx terminates TLS | Session/Transport | TLS 1.2/1.3 |
| 4 | Encrypted HTTP GET /api/status | Application | HTTP/1.1 (or HTTP/2) |
| 5 | nginx picks Backend A or B (round-robin), forwards over plain HTTP | Application | HTTP to :3001 / :3002 |
| 6 | Backend replies with `X-Backend`, `Cache-Control`, `ETag`; nginx relays it | Application | HTTP |
| All | Packets routed by IP, framed by Ethernet/Wi-Fi | Network / Link | IPv4, 802.11 |

Clients never learn backend IPs: DNS names only the edge, and nginx hides the pool.
