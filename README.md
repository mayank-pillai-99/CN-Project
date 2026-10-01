# Computer Networks Project: Private Network Service Platform (Team 1)

Phase 1: Build and Observe the Network. Private domain: `app.team1.test` / `api.team1.test`.

## Team members

| Enrollment No. | Name | Machine | Role |
|---|---|---|---|
| 2401010268 | Mayank Pillai | Mac 3 | Backend A (port 3001) |
| 2401010504 | Vikrant Yadav | Mac 1 | Private DNS server (dnsmasq) |
| 2401010108 | Asad Ali | Mac 2 | nginx edge: TLS + load balancer (port 8443) |
| 2401010340 | Prashant Raj | Mac 4 | Backend B (port 3002) |

| Mac | Role | IP |
|---|---|---|
| Mac 1 | Private DNS (dnsmasq) | 10.7.13.235 |
| Mac 2 | nginx edge: TLS + load balancer (port 8443) | 10.7.17.39 |
| Mac 3 | Backend A (port 3001) | 10.7.5.187 |
| Mac 4 | Backend B (port 3002) | 10.7.15.184 |

## How to run the backends

Requirements: Python 3 (standard library only, nothing to install). Run each backend on its own Mac, from the project folder:

```bash
git clone https://github.com/mayank-pillai-99/CN-Project.git
cd CN-Project

python3 backend/backend_a.py     # on Mac 3: Backend A, listens on 0.0.0.0:3001
python3 backend/backend_b.py     # on Mac 4: Backend B, listens on 0.0.0.0:3002
```

Each backend prints `Backend X running on port ...`. Stop it with Ctrl+C.

Check a backend from any Mac on the same network (replace the IP with that backend's IP):

```bash
curl -i http://10.7.5.187:3001/api/status     # Backend A, response header: X-Backend: A
curl -i http://10.7.15.184:3002/api/status    # Backend B, response header: X-Backend: B
```

Endpoints: `GET /` (page confirming the service is running) and `GET /api/status` (JSON with `backend` and `status`). Every response includes `X-Backend` and `Cache-Control: max-age=60`.

The backends are reached by clients through the nginx edge (Mac 2) at `https://app.team1.test:8443`, using the DNS server on Mac 1.

## Repository layout

- `backend/`: source code for Backend A and Backend B
- `config/`: `dnsmasq.conf` (Mac 1) and `nginx.conf` (Mac 2)
- `docs/ARCHITECTURE.md`: topology, roles and IP table, request flow
- `evidence/`: screenshots and captures, one folder per task
- `report/`: Phase 1 report (`report.pdf`) and demo video script
