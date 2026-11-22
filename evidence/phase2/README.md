# Phase 2 evidence (session of 22 Nov 2026)

IPs used: Mac 1 Vikrant `10.7.29.164` (primary DNS) · Mac 2 Asad `10.7.26.179` (edge) ·
Mac 3 Mayank `10.7.18.13` (Backend A, backup DNS, standby edge) · Mac 4 Prashant `10.7.26.134` (Backend B, client).
Files are numbered in the order they were taken. `terminal-<name>.txt` files (where present) are the
timestamped text logs written by the scripts.

## Extension A: Backup DNS (`extA-backup-dns/`)
| File | Shows |
|---|---|
| 01 | Primary DNS (Mac 1) answers `app.team1.test -> 10.7.26.179` with TTL 30 |
| 02 | Backup DNS (Mac 3) gives the same answer |
| 03, 04 | Clients (Mac 4, Mac 3) list both DNS servers: primary first, backup second |
| 05 | Both DNS servers answer; client resolves correctly |
| 06 | With the primary DNS stopped, the site still returns HTTP 200 (resolved via backup) |
| 07 | Load balancing back to normal after the backends were restarted |

## Extension B: TTL and record change (`extB-ttl/`)
| File | Shows |
|---|---|
| 01 | Record changed to `10.7.26.134` on the backup DNS (same change made on the primary) |
| 02, 03 | After the 30 s TTL, the client's cached answer and the fresh answer both show the new IP |
| 04 | Record changed back to `10.7.26.179` |
| 05 | After a cache flush, the client switches back immediately (no 30 s wait) |

## Extension C: Service isolation with pf (`extC-firewall/`)
| File | Shows |
|---|---|
| 01, 02 | pf rules loaded: only `10.7.26.179` may reach port 3001 / 3002; everyone else dropped |
| 03 | From the edge (Mac 2), both backends are ALLOWED |
| 04, 05 | From the clients, direct access to the other backend is BLOCKED (timeout) |
| 06 | The site still works through the edge while the firewall is on |
| 07, 08 | Rollback: original macOS rules reloaded, team rule removed |

## Extension D: Backend failover (`extD-failover/`)
| File | Shows |
|---|---|
| 01 | Normal round robin: A, B, A, B |
| 02 | Backend A stopped: all 6 requests HTTP 200 from B |
| 03 | nginx log: `upstream=10.7.18.13:3001, 10.7.26.134:3002`. The request was tried on A, failed, and was retried on B |
| 04 | Backend A restarted: A and B again |

## Extension E: DNS-based edge migration (`extE-edge-cutover/`)
| File | Shows |
|---|---|
| 01 | Primary edge labels replies `X-Edge: primary-mac2` |
| 02 | Standby nginx on Mac 3 with the same config and certificate: `X-Edge: standby-mac3` |
| 03 | Before the cutover the client uses the primary edge |
| 04, 05 | `app.team1.test` moved to `10.7.18.13` on both DNS servers |
| 06, 08 | Client now served by the standby edge |
| 07 | Fresh lookup on another client goes straight to the standby |
| 09, 10 | Primary nginx stopped; service still works (A and B) through the standby only |
| 11–14 | Rollback: DNS back to Mac 2, primary restarted, client back on primary, standby stopped |

## Extension F: Troubleshooting (`extF-troubleshooting/`)
| File | Shows |
|---|---|
| 01 | Real fault found during setup: HTTP 502 because nginx still pointed at the old backend IPs. Fixed by updating the upstream IPs and reloading nginx |
| 02 | Real fault: DNS fine (both servers answer) but TCP to the edge timed out. Diagnosed layer by layer (DNS ok → ping ok → TCP 8443 failed) |
| 03–05 | Final status after the session: everything back to normal. Asad's last line is `[--]` because Mac 2 is not a test client and does not use the team DNS |

## Not captured as screenshots
- **Ext A:** the client's `dns-test` while the primary DNS was stopped (primary ERR, backup OK). It is in
  Prashant's `extA-backup-dns/terminal-prashant.txt` log. The "both backends down → HTTP 502" screenshot is
  also missing (file 01 in Ext F shows a 502 from a different cause).
- **Ext B:** the moment where the cached answer (old IP) and the fresh answer (new IP) differ.
- **Ext E:** the client still on the old edge right after the DNS change (its cache expired before the check).
- **Ext F:** screenshots of the practice fault rounds.
