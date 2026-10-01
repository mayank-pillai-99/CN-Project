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
