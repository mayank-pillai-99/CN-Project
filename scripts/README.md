# Phase 2 scripts: how to run

Each person has one script and runs it only on their own Mac.

The Phase 1 roles stay the same. Phase 2 only adds jobs, and the PDF requires both added jobs
to be on a Mac other than Mac 1 and Mac 2.

| Person | Mac | Role (same as Phase 1) | Added in Phase 2 | Script |
|---|---|---|---|---|
| Vikrant | Mac 1 | DNS server | 30 s TTL on records | `vikrant.sh` |
| Asad | Mac 2 | nginx edge (TLS + load balancer) | `X-Edge` header, failover demo | `asad.sh` |
| Mayank | Mac 3 | Backend A + test client | Backup DNS, standby edge, firewall on 3001 | `mayank.sh` |
| Prashant | Mac 4 | Backend B + test client (main) | Firewall on 3002 | `prashant.sh` |

## Before you start (every time)

1. Get the latest files: `git pull`.
2. Check your IP: `ipconfig getifaddr en0`. It must match your line in `team.env`.
   If not, update `team.env` and give the same file to everyone.
3. Go to this folder: `cd CN-Project/scripts`.
4. Run a command: `bash <yourname>.sh <command>`. Type your Mac password when asked.
   `bash <yourname>.sh help` lists your commands.

The script stops if it is run on the wrong Mac. Before changing anything, it saves the
original file in `~/.team1-phase2/` so it can be put back.

## Step 0: Update IPs (every session, takes 2 minutes)

The campus Wi-Fi gives Macs new IPs, so do this at the start of every session, including
evaluation day.

1. **Everyone** runs `ipconfig getifaddr en0` and posts their IP in the group chat.
2. **One person** puts the four IPs into `scripts/team.env`, then commits and pushes.
3. **Everyone** runs `git pull`, then `bash <name>.sh check-team`. Every line should be OK.
4. **Asad** runs `bash asad.sh update-backends`. This writes Mayank's and Prashant's new IPs
   into nginx.conf.
5. **Vikrant** runs `bash vikrant.sh dns-ttl` and **Mayank** runs `bash mayank.sh backup-dns`.
   This makes `app.team1.test` point to Asad's new IP.
6. **Prashant** and **Mayank** (the test clients) run `bash <name>.sh set-dns` to use the new DNS server IPs.

The scripts take every IP from `team.env`. Nothing else needs editing; for example, Step 3 uses
`point-to mac4`, not an IP. Your mkcert certificate is tied to the name `app.team1.test`, not an
IP, so it keeps working.

## The steps, in order

Do each step together, on the same Wi-Fi. Lines marked `>>> SCREENSHOT` in the script output
tell you when to take a screenshot. Save screenshots in `evidence/phase2/<extension folder>/`.
Prashant's and Mayank's test commands also save their output to text files in those folders.

### Step 1: Second DNS server (Extension A)
| Who | Command |
|---|---|
| Vikrant | `bash vikrant.sh dns-ttl` |
| Mayank | `bash mayank.sh backup-dns` |
| Prashant | `bash prashant.sh set-dns`, then `bash prashant.sh dns-test` 📸 |
| Mayank | `bash mayank.sh set-dns` 📸 |

### Step 2: Main DNS goes down, website still works (Extension A)
| Who | Command |
|---|---|
| Vikrant | `bash vikrant.sh dns-stop` |
| Prashant | `bash prashant.sh flush`, `bash prashant.sh dns-test` 📸, `bash prashant.sh site` 📸 |
| Vikrant | `bash vikrant.sh dns-start` |

DNS failure vs app failure: Mayank and Prashant stop both backends (Ctrl+C).
Prashant runs `dns-test` (works) and `site` (502) 📸. Then start them again
(`bash mayank.sh backend-a`, `bash prashant.sh backend-b`).

### Step 3: Change the address, watch the 30 s delay (Extension B)
Be quick: the cached answer only lasts 30 s. Vikrant and Mayank should type their `point-to`
command first and press Enter together right after Prashant's first `check-cache`.
Do the same in Step 6.

| Who | Command |
|---|---|
| Prashant | `bash prashant.sh check-cache` (loads the answer into his cache) |
| Vikrant **and** Mayank | `bash <name>.sh point-to mac4` |
| Prashant | `bash prashant.sh check-cache` 📸: cached = old, fresh = new |
| Prashant | wait 30 s, `bash prashant.sh check-cache` 📸: both new |
| Vikrant **and** Mayank | `bash <name>.sh point-to mac2` |
| Prashant | `bash prashant.sh flush`, `bash prashant.sh check-cache` 📸: changes immediately |

### Step 4: Firewall on the backends (Extension C)
| Who | Command |
|---|---|
| Mayank **and** Prashant | `bash <name>.sh firewall-on` 📸 |
| Asad | `bash asad.sh test-backends` 📸: ALLOWED |
| Mayank | `bash mayank.sh test-backends` 📸: Prashant's backend BLOCKED |
| Prashant | `bash prashant.sh test-backends` 📸: Mayank's backend BLOCKED |
| Prashant | `bash prashant.sh site` 📸: website still works through nginx |
| Mayank **and** Prashant | `bash <name>.sh firewall-off` 📸 (rollback) |

### Step 5: Backend A dies, website keeps working (Extension D)
| Who | Command |
|---|---|
| Asad | `bash asad.sh show-log` (leave it open) |
| Prashant | `bash prashant.sh loop` 📸: A, B, A, B |
| Mayank | press Ctrl+C on Backend A |
| Prashant | `bash prashant.sh loop` 📸: only B, all 200 |
| Asad | 📸 the log line that shows two upstream addresses |
| Mayank | `bash mayank.sh backend-a` |
| Prashant | wait 10 s, `bash prashant.sh loop` 📸: A, B again |

### Step 6: Move the edge to Mayank's Mac (Extension E)
Do Step 4's `firewall-off` first.

| Who | Command |
|---|---|
| Asad | `bash asad.sh add-edge-header`, then `bash asad.sh pack-for-standby` |
| Asad | AirDrop the folder `team1-standby-edge` from the Desktop to Mayank **only** (it holds the private key) |
| Mayank | `bash mayank.sh standby-edge` 📸 |
| Prashant | `bash prashant.sh which-edge` 📸: Asad's edge |
| Vikrant **and** Mayank | `bash <name>.sh point-to mac3` |
| Prashant | `bash prashant.sh which-edge` 📸: still Asad's (cached) |
| Mayank | `bash mayank.sh flush`, `bash mayank.sh which-edge` 📸: Mayank's (fresh lookup) |
| Prashant | wait 30 s, `bash prashant.sh which-edge` 📸: Mayank's |
| Asad | `bash asad.sh edge-stop` |
| Prashant | `bash prashant.sh which-edge` 📸: still works |
| Vikrant **and** Mayank | `bash <name>.sh point-to mac2` |
| Asad | `bash asad.sh edge-start` |
| Mayank | `bash mayank.sh standby-stop` |

### Step 7: Back to normal
Everyone: `bash <name>.sh status` 📸. Every line should be `[ok]`.

### Step 8: Practise troubleshooting (Extension F, no script)
One person secretly breaks something. The others check, in this order:
1. `dig app.team1.test`: does the name resolve?
2. `ping <Asad's IP>`: can we reach Asad's Mac?
3. `nc -vz <Asad's IP> 8443`: is nginx accepting connections?
4. `curl -v https://app.team1.test:8443/api/status`: is TLS OK? what HTTP status?
5. On Asad's Mac: `sudo nginx -t`, `tail /opt/homebrew/var/log/nginx/error.log`,
   `curl http://<Mayank's IP>:3001/api/status`

## At the evaluation

Use the scripts to get the Macs ready. During the demo, type the real commands yourself
(`dig`, `curl -I`, `sudo pfctl -sr`, `nc -vz`) and explain them, and be ready to open the
config files in `config/phase2/`.
