# Phase 2 configuration bundle

These are the files the Phase 2 scripts (`scripts/`) install on each Mac, with the current IPs
from `scripts/team.env`. The Phase 1 files in `config/` are unchanged.

| File | Mac | Installed at | Extension |
|---|---|---|---|
| `dnsmasq-mac1-primary.conf` | Mac 1 (Vikrant) | `/opt/homebrew/etc/dnsmasq.conf` | A, B |
| `dnsmasq-mac3-backup.conf` | Mac 3 (Mayank) | `/opt/homebrew/etc/dnsmasq.conf` | A |
| `pf-mac3-backend-a.conf` | Mac 3 (Mayank) | `/etc/pf.team1.conf` | C |
| `pf-mac4-backend-b.conf` | Mac 4 (Prashant) | `/etc/pf.team1.conf` | C |
| `nginx-mac2-primary.conf` | Mac 2 (Asad) | `/opt/homebrew/etc/nginx/nginx.conf` | D, E |
| `nginx-mac3-standby.conf` | Mac 3 (Mayank) | `/opt/homebrew/etc/nginx/nginx.conf` | E |

What changed from Phase 1:
- **dnsmasq:** `address=` (TTL 0) became `host-record=...,30` (TTL 30 s). `no-resolv` plus `server=`
  stops a forwarding loop now that clients list both team DNS servers. The `server=` value is this
  Mac's original upstream DNS, detected by the script (8.8.8.8 in our session).
- **pf:** only the edge (10.7.17.39) may open TCP connections to the backend port; everyone else
  is dropped. Rollback: `sudo pfctl -f /etc/pf.conf`, which loads the untouched macOS default rules.
  The scripts also keep a copy in `~/.team1-phase2/pf.conf.original`.
- **nginx:** identical to Phase 1 plus one `add_header X-Edge ...` line, so a client can see which
  edge answered. The standby uses the same mkcert certificate as the primary. The private key is
  copied by AirDrop and never committed to Git.
