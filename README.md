# Computer Networks Project: Private Network Service Platform (Team 1)

Domain: `app.team1.test` / `api.team1.test`

| Mac | Role | IP |
|---|---|---|
| Mac 1 | Private DNS (dnsmasq) | 10.7.13.235 |
| Mac 2 | nginx edge: TLS + load balancer (port 8443) | 10.7.17.39 |
| Mac 3 | Backend A (port 3001) | 10.7.5.187 |
| Mac 4 | Backend B (port 3002) | 10.7.15.184 |

## Launching the backends
```bash
python3 backend/backend_a.py     # Mac 3, port 3001
python3 backend/backend_b.py     # Mac 4, port 3002
```

## Layout
- `docs/ARCHITECTURE.md`: topology, roles and IP table, request flow
- `config/`: `dnsmasq.conf` (Mac 1), `nginx.conf` (Mac 2)
- `backend/`: source for both backends
- `evidence/`: screenshots and captures, one folder per task

## Phase 2: Harden & Recover
Phase 2 adds to the same setup. Phase 1 files are unchanged.

| Mac | Phase 2 additions |
|---|---|
| Mac 1 (Vikrant) | DNS records now have a 30 s TTL; also test client 2 |
| Mac 2 (Asad) | `X-Edge: primary-mac2` header; backend failover demo |
| Mac 3 (Mayank) | Backup DNS server, firewall on port 3001, standby nginx edge |
| Mac 4 (Prashant) | Firewall on port 3002; main test client |

- `scripts/`: one script per person. **Start with [scripts/README.md](scripts/README.md)** for the step-by-step run order.
- `config/phase2/`: Phase 2 configs (backup DNS, TTL, pf firewall rules, primary and standby nginx)
- `evidence/phase2/`: screenshots and logs, one folder per extension (A–F)
- `report/phase2/`: Phase 2 report
