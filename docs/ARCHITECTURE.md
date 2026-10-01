# Architecture: Team 1 Private Network Service Platform

## Network topology
```
                  Private Wi-Fi/LAN  10.7.0.0/19   (gateway 10.7.0.1)
 +--------------------+        +----------------------+
 | Mac 1  Vikrant     |        | Mac 2  Asad          |
 | Private DNS        |        | Edge reverse proxy   |
 | dnsmasq  :53       |        | + load balancer      |
 | 10.7.13.235        |        | nginx  :8443 (TLS)   |
 +--------------------+        | 10.7.17.39           |
                               +----------+-----------+
                                          |  round-robin
                         +----------------+----------------+
                         |                                 |
              +----------+---------+            +----------+---------+
              | Mac 3  Mayank      |            | Mac 4  Prashant    |
              | Backend A  :3001   |            | Backend B  :3002   |
              | 10.7.5.187         |            | 10.7.15.184        |
              +--------------------+            +--------------------+

 Clients (Mac 3 / Mac 4) -> DNS query to Mac 1 -> HTTPS to Mac 2 -> Backend A or B
```

## Machine roles, IP and service table
| Machine | Person | Role | Service / port | Cloud equivalent | Interface | IPv4 | Subnet mask | Gateway | MAC |
|---|---|---|---|---|---|---|---|---|---|
| Mac 1 | Vikrant | Private DNS server | dnsmasq, 53 | Route 53 | en0 | 10.7.13.235 | 255.255.224.0 (/19) | 10.7.0.1 | 92:2c:cb:62:ea:90 |
| Mac 2 | Asad | Edge reverse proxy + load balancer | nginx, 8443 | Cloud load balancer / CDN edge | en0 | 10.7.17.39 | 255.255.224.0 (/19) | 10.7.0.1 | 92:95:4c:6a:39:49 |
| Mac 3 | Mayank | Backend Server A + client | Python REST, 3001 | App server instance A | en0 | 10.7.5.187 | 255.255.224.0 (/19) | 10.7.0.1 | de:9f:c0:36:69:0c |
| Mac 4 | Prashant | Backend Server B + client | Python REST, 3002 | App server instance B | en0 | 10.7.15.184 | 255.255.224.0 (/19) | 10.7.0.1 | ea:bd:68:1c:68:2e |

All four addresses fall in 10.7.0.0 to 10.7.31.255, so they share one subnet.

## Request flow and protocol layers
| Step | What happens | Layer | Protocol / port |
|---|---|---|---|
| 1 | Client asks Mac 1 for app.team1.test and gets 10.7.17.39 | Application | DNS, UDP 53 |
| 2 | Client opens a connection to 10.7.17.39:8443 (SYN, SYN-ACK, ACK) | Transport | TCP, ephemeral port to 8443 |
| 3 | ClientHello, ServerHello, Certificate, Key Exchange, Finished; nginx terminates TLS | Session / Transport | TLS |
| 4 | Client sends the encrypted HTTP request | Application | HTTP/1.1 over TLS |
| 5 | nginx picks Backend A or B (round-robin) and forwards the request | Application | HTTP to 3001 / 3002 |
| 6 | The backend replies with X-Backend; nginx relays it to the client | Application | HTTP |
| all | Packets are routed by IP and carried over Wi-Fi | Network / Link | IPv4, Ethernet/Wi-Fi |
