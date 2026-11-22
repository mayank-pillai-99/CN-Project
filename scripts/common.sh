#!/bin/bash
# Shared helpers for the Phase 2 scripts (vikrant.sh, asad.sh, mayank.sh,
# prashant.sh). Do not run this file directly.
#
# Everything the scripts change is backed up first in ~/.team1-phase2/ so it
# can be put back. Works with the bash that ships with macOS (3.2).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=team.env
. "$SCRIPT_DIR/team.env"

if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
elif [ -d /opt/homebrew ]; then
    BREW_PREFIX=/opt/homebrew
else
    BREW_PREFIX=/usr/local
fi
DNSMASQ_CONF="$BREW_PREFIX/etc/dnsmasq.conf"
NGINX_DIR="$BREW_PREFIX/etc/nginx"
NGINX_CONF="$NGINX_DIR/nginx.conf"
NGINX_ACCESS_LOG="$BREW_PREFIX/var/log/nginx/access.log"
NGINX_ERROR_LOG="$BREW_PREFIX/var/log/nginx/error.log"
PF_TEAM_CONF=/etc/pf.team1.conf
STATE_DIR="$HOME/.team1-phase2"     # backups and saved settings live here
EVIDENCE_DIR="$REPO_ROOT/evidence/phase2"
URL_STATUS="https://$DOMAIN_APP:$EDGE_PORT/api/status"
mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------- output ----
if [ -t 1 ]; then
    B=$'\033[1m'; G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'
else
    B=''; G=''; R=''; Y=''; C=''; N=''
fi
title() { echo; echo "${B}${C}== $* ==${N}"; }
ok()    { echo "${G}OK  $*${N}"; }
bad()   { echo "${R}ERR $*${N}"; }
warn()  { echo "${Y}!   $*${N}"; }
info()  { echo "    $*"; }
die()   { bad "$*"; exit 1; }
shot()  { echo; echo "${B}${Y}>>> SCREENSHOT: $*${N}"; }

# Run a command, show its output, and also append it (without colours) to
# evidence/phase2/<ext>/terminal-<person>.txt with a timestamp.
#   logrun extA "what this is" command args...
logrun() {
    local ext="$1" what="$2"; shift 2
    local dir="$EVIDENCE_DIR/$ext"
    mkdir -p "$dir"
    local f="$dir/terminal-${PERSON:-unknown}.txt"
    {
        echo
        echo "===== $(date '+%Y-%m-%d %H:%M:%S') | $(hostname -s) ($(ipconfig getifaddr "$IFACE" 2>/dev/null)) | $what ====="
        "$@" 2>&1
    } | awk -v f="$f" '{ print; fflush(); l = $0; gsub("\033\\[[0-9;]*m", "", l); print l >> f }'
    info "(also saved to ${f#"$REPO_ROOT"/})"
}

# --------------------------------------------------------------- checks -----
# Stop if this is not the Mac the script was written for.
require_mac() {   # $1 expected IP, $2 who
    [ "${FORCE:-0}" = 1 ] && return 0
    local actual
    actual="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
    if [ "$actual" != "$1" ]; then
        bad "This script is for $2, expected IP $1, but this Mac's IP is '${actual:-none}'."
        info "- Wrong Mac? Run your own script instead."
        info "- Did your Wi-Fi IP change? Put the new IP in scripts/team.env on ALL four Macs."
        info "- To run anyway: FORCE=1 bash $(basename "$0") ${CMD:-<command>}"
        exit 1
    fi
}

is_ip() { echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }

nginx_bin() { command -v nginx 2>/dev/null || echo "$BREW_PREFIX/bin/nginx"; }

# --------------------------------------------------------------- backups ----
# Save the ORIGINAL version of a file once. Running a script twice never
# overwrites the first backup, so "undo" always goes back to the real original.
backup_once() {   # $1 file
    local name dst
    name="$(basename "$1")"
    dst="$STATE_DIR/$name.original"
    [ -e "$dst" ] || [ -e "$dst.did-not-exist" ] && return 0
    if [ -f "$1" ]; then
        sudo cp "$1" "$dst" && sudo chown "$USER" "$dst"
        ok "Backed up original $1 -> $dst"
    else
        touch "$dst.did-not-exist"
    fi
}

restore_original() {   # $1 file
    local name dst
    name="$(basename "$1")"
    dst="$STATE_DIR/$name.original"
    if [ -f "$dst" ]; then
        sudo cp "$dst" "$1" && ok "Restored original $1"
    elif [ -e "$dst.did-not-exist" ]; then
        sudo rm -f "$1" && ok "Removed $1 (it did not exist before Phase 2)"
    else
        warn "No backup of $1 found; nothing to restore."
    fi
}

# ----------------------------------------------------------------- DNS ------
# The DNS server that dnsmasq asks for normal internet names. Found once,
# before the Mac's own DNS settings are pointed at the team servers.
upstream_dns() {
    local f="$STATE_DIR/upstream-dns" ip
    [ -n "${UPSTREAM_DNS:-}" ] && echo "$UPSTREAM_DNS" > "$f"
    if [ -s "$f" ]; then cat "$f"; return; fi
    for ip in $(scutil --dns | awk '/nameserver\[[0-9]+\]/ {print $3}'); do
        case "$ip" in
            "$MAC1_IP"|"$MAC3_IP"|127.*|*:*) continue ;;
        esac
        echo "$ip" > "$f"; echo "$ip"; return
    done
    ip="$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')"
    echo "${ip:-8.8.8.8}" > "$f"; echo "${ip:-8.8.8.8}"
}

dnsmasq_conf_text() {   # $1 listen IP, $2 IP for app.team1.test, $3 upstream, $4 description
    cat <<EOF
# Phase 2 dnsmasq config: $4
# Written by scripts/$(basename "$0") using scripts/team.env.
# Do not edit by hand; run the script again instead.

listen-address=$1,127.0.0.1
interface=$IFACE

# Do not read /etc/resolv.conf: this Mac's own DNS settings may point back at
# the team DNS servers, which would create a loop. Other names go here:
no-resolv
server=$3

# Team records. The last number is the TTL in seconds: how long a client may
# cache the answer (Extension B). Phase 1 used address=, which sends TTL 0.
host-record=$DOMAIN_APP,$2,$DNS_TTL
host-record=$DOMAIN_API,$MAC2_IP,$DNS_TTL
EOF
}

# Write the dnsmasq config, check it, and restart dnsmasq.
write_dnsmasq() {   # $1 listen IP, $2 IP for app.team1.test, $3 description
    command -v dnsmasq >/dev/null 2>&1 || [ -x "$BREW_PREFIX/sbin/dnsmasq" ] || {
        title "Installing dnsmasq"
        brew install dnsmasq || die "brew install dnsmasq failed"
    }
    backup_once "$DNSMASQ_CONF"
    local up tmp
    up="$(upstream_dns)"
    tmp="$(mktemp)"
    dnsmasq_conf_text "$1" "$2" "$up" "$3" > "$tmp"
    "$BREW_PREFIX/sbin/dnsmasq" --test -C "$tmp" >/dev/null 2>&1 \
        || { cat "$tmp"; die "dnsmasq says this config is invalid (see above)"; }
    sudo cp "$tmp" "$DNSMASQ_CONF"; rm -f "$tmp"
    ok "Wrote $DNSMASQ_CONF  ($DOMAIN_APP -> $2, TTL $DNS_TTL s, other names -> $up)"
    sudo brew services restart dnsmasq >/dev/null 2>&1 || die "Could not (re)start dnsmasq"
    wait_dns "$1"
}

# dnsmasq can take a few seconds to start (longer the first time): retry for ~10 s.
wait_dns() {   # $1 DNS server IP
    local i
    for i in 1 2 3 4 5; do
        dig @"$1" "$DOMAIN_APP" +short +time=1 +tries=1 2>/dev/null | grep -q . && break
        sleep 2
    done
    dns_answer "$1"
}

# Ask one DNS server directly and print the answer line (name, TTL, IP).
dns_answer() {   # $1 DNS server IP
    local out
    out="$(dig @"$1" "$DOMAIN_APP" +nocmd +noall +answer +time=3 +tries=2 2>&1)"
    if echo "$out" | grep -q "IN.*A"; then
        ok "DNS server $1 answers:"; info "$out"
        info "(columns: name, TTL seconds, class, type, IP address)"
    else
        bad "DNS server $1 did not answer for $DOMAIN_APP"; [ -n "$out" ] && info "$out"
        return 1
    fi
}

dns_stop()  { title "Stopping dnsmasq"; sudo brew services stop dnsmasq >/dev/null 2>&1; sleep 1
              pgrep -x dnsmasq >/dev/null && bad "dnsmasq is still running" || ok "dnsmasq is stopped (this DNS server no longer answers)"; }
dns_start() { title "Starting dnsmasq"; sudo brew services start dnsmasq >/dev/null 2>&1; wait_dns "$1"; }

# mac1..mac4 -> IP from team.env (an IP is passed through unchanged)
mac_ip() {
    case "$1" in
        mac1|Mac1|MAC1) echo "$MAC1_IP" ;;
        mac2|Mac2|MAC2) echo "$MAC2_IP" ;;
        mac3|Mac3|MAC3) echo "$MAC3_IP" ;;
        mac4|Mac4|MAC4) echo "$MAC4_IP" ;;
        *) echo "$1" ;;
    esac
}

point_to() {   # $1 listen IP, $2 mac2|mac3|mac4 or an IP, $3 description
    local target; target="$(mac_ip "$2")"
    is_ip "$target" || die "Usage: point-to mac2|mac3|mac4   (mac2 = normal, Asad's edge)"
    title "Changing $DOMAIN_APP -> $target ($2) on this DNS server"
    write_dnsmasq "$1" "$target" "$3"
    echo
    warn "Vikrant AND Mayank must both run point-to with the SAME Mac,"
    warn "otherwise clients get different answers from the two DNS servers."
    [ "$target" = "$MAC2_IP" ] && ok "This is the normal address (Asad's edge)."
}

# Show this Mac's IP and check that every IP in team.env answers ping.
check_team() {   # $1 this person's expected IP
    title "Checking the IPs in scripts/team.env"
    local mine; mine="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
    if [ "$mine" = "$1" ]; then
        ok "Your IP is $mine, same as team.env"
    else
        bad "Your IP is ${mine:-none}, but team.env says $1. Update team.env (and tell the team)."
    fi
    local e ip label
    for e in "$MAC1_IP:Mac 1 Vikrant" "$MAC2_IP:Mac 2 Asad" "$MAC3_IP:Mac 3 Mayank" "$MAC4_IP:Mac 4 Prashant"; do
        ip="${e%%:*}"; label="${e#*:}"
        [ "$ip" = "$mine" ] && continue
        if ping -c 1 -t 2 "$ip" >/dev/null 2>&1; then
            ok "$label  $ip  answers ping"
        else
            bad "$label  $ip  no answer: IP changed, Mac asleep, or not on this Wi-Fi?"
        fi
    done
}

# ------------------------------------------------------------ client side ---
flush_dns() {
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    ok "This Mac's DNS cache is empty; the next lookup asks the DNS server again."
}

set_dns() {
    title "Using Mac 1 ($MAC1_IP) as main DNS and Mac 3 ($MAC3_IP) as backup DNS"
    networksetup -listallnetworkservices | grep -qx "$WIFI_SERVICE" \
        || die "No network service called '$WIFI_SERVICE' (see: networksetup -listallnetworkservices)"
    [ -f "$STATE_DIR/dns-before" ] || networksetup -getdnsservers "$WIFI_SERVICE" > "$STATE_DIR/dns-before"
    sudo networksetup -setdnsservers "$WIFI_SERVICE" "$MAC1_IP" "$MAC3_IP" || die "Could not change DNS settings"
    flush_dns
    show_dns_settings
    shot "the two DNS servers listed above (Extension A)"
}

unset_dns() {
    title "Putting this Mac's DNS settings back"
    local before
    before="$(cat "$STATE_DIR/dns-before" 2>/dev/null)"
    if [ -z "$before" ] || echo "$before" | grep -q "aren't any"; then
        sudo networksetup -setdnsservers "$WIFI_SERVICE" Empty
    else
        # shellcheck disable=SC2086
        sudo networksetup -setdnsservers "$WIFI_SERVICE" $before
    fi
    rm -f "$STATE_DIR/dns-before"
    flush_dns
    show_dns_settings
}

show_dns_settings() {
    info "DNS servers set on $WIFI_SERVICE:"
    networksetup -getdnsservers "$WIFI_SERVICE" | sed 's/^/      /'
    info "DNS servers macOS is really using (scutil --dns):"
    scutil --dns | awk '/^resolver #1/{f=1} f && /nameserver/ {print "      " $0} f && /^$/ {exit}'
}

# What this Mac's own resolver (used by curl and browsers) returns. Uses the
# macOS DNS cache, unlike dig.
system_lookup() {
    dscacheutil -q host -a name "$DOMAIN_APP" | awk '/ip_address/ {print $2; exit}'
}

dns_test() {
    title "Asking each team DNS server directly (dig @server)"
    dns_answer "$MAC1_IP"; echo
    dns_answer "$MAC3_IP"; echo
    title "What this Mac itself uses (system resolver, can fail over)"
    local ip; ip="$(system_lookup)"
    if [ -n "$ip" ]; then ok "$DOMAIN_APP -> $ip"; else bad "$DOMAIN_APP could not be resolved"; fi
}

site() {
    title "Opening $URL_STATUS"
    local out rc code
    out="$(curl -isS --max-time 15 "$URL_STATUS" 2>&1)"; rc=$?
    echo "$out" | tr -d '\r'
    echo
    code="$(echo "$out" | awk '/^HTTP/ {print $2; exit}')"
    if [ $rc -ne 0 ]; then
        bad "curl failed (exit code $rc): no HTTPS connection to the edge"
    elif [ "$code" = 200 ]; then
        ok "Website works: HTTP 200"
    else
        bad "Edge answered, but with HTTP $code (502 = nginx could not reach any backend)"
    fi
}

check_cache() {
    title "DNS caching check at $(date '+%H:%M:%S')"
    info "1) This Mac's cached answer (what curl/browser use):"
    local ip; ip="$(system_lookup)"
    echo "      $DOMAIN_APP -> ${B}${ip:-no answer}${N}"
    info "2) Fresh answer straight from the DNS server (dig skips the cache):"
    echo "      $DOMAIN_APP -> ${B}$(dig "$DOMAIN_APP" +short +time=3 +tries=2 | head -1)${N}"
    echo
    info "If 1) and 2) differ, this Mac is still using its cached (old) answer."
    info "It switches after the $DNS_TTL second TTL runs out, or right away after 'flush'."
}

# One request, printed as one short line.
one_request() {
    local h code be edge
    h="$(curl -s -o /dev/null -D - --max-time 15 "$URL_STATUS" | tr -d '\r')"
    if [ -z "$h" ]; then echo "      ${R}no response (curl failed)${N}"; return; fi
    code="$(echo "$h" | awk 'NR==1 {print $2}')"
    be="$(echo "$h" | awk -F': ' 'tolower($1)=="x-backend" {print $2}')"
    edge="$(echo "$h" | awk -F': ' 'tolower($1)=="x-edge" {print $2}')"
    echo "      HTTP ${B}$code${N}   X-Backend: ${B}${be:--}${N}${edge:+   X-Edge: $edge}"
}

loop() {
    title "6 requests to $URL_STATUS at $(date '+%H:%M:%S')"
    local i
    for i in 1 2 3 4 5 6; do printf "  %s." "$i"; one_request; done
}

which_edge() {
    title "Which edge answered? ($(date '+%H:%M:%S'))"
    local ip who; ip="$(system_lookup)"
    case "$ip" in
        "$MAC2_IP") who="Asad's Mac 2, the primary edge" ;;
        "$MAC3_IP") who="Mayank's Mac 3, the standby edge" ;;
        *) who="unknown" ;;
    esac
    info "This Mac resolves $DOMAIN_APP -> ${B}${ip:-nothing}${N}  ($who)"
    printf "  "; one_request
}

test_backends() {
    title "Trying to reach the backends DIRECTLY from this Mac (not via nginx)"
    local t ip port
    for t in "$MAC3_IP:$PORT_A:Backend A (Mayank)" "$MAC4_IP:$PORT_B:Backend B (Prashant)"; do
        ip="${t%%:*}"; port="$(echo "$t" | cut -d: -f2)"
        # A Mac's own backend is not a fair test (traffic to yourself skips the
        # firewall), so only test the other Mac's backend.
        if [ "$ip" = "$(ipconfig getifaddr "$IFACE" 2>/dev/null)" ]; then
            continue
        fi
        echo; info "$(echo "$t" | cut -d: -f3-)  $ip:$port"
        if nc -z -G 6 "$ip" "$port" 2>/dev/null; then
            ok "ALLOWED: TCP connection to $ip:$port works"
            curl -s --max-time 10 "http://$ip:$port/api/status" | sed 's/^/      /'; echo
        else
            bad "BLOCKED: no TCP connection to $ip:$port (timed out / refused)"
        fi
    done
}

# --------------------------------------------------------------- firewall ---
pf_rules_text() {   # $1 port, $2 description
    cat <<EOF
# Phase 2 Extension C: only the edge (Mac 2, $MAC2_IP) may reach $2 on port $1.
# Written by scripts/$(basename "$0"). Undo with: bash $(basename "$0") firewall-off
set skip on lo0
pass  in quick proto tcp from $MAC2_IP to any port $1
block drop in quick proto tcp from any to any port $1
pass all
EOF
}

pf_quiet() { grep -v -e "ALTQ" -e "flushing of rules" -e "/etc/pf.conf for further" -e "^$" || true; }

firewall_on() {   # $1 port, $2 description
    title "Firewall ON: only Asad's edge ($MAC2_IP) may connect to port $1"
    backup_once /etc/pf.conf
    if [ ! -f "$STATE_DIR/pf-was-enabled" ]; then
        if sudo pfctl -s info 2>/dev/null | head -1 | grep -q Enabled; then
            echo yes > "$STATE_DIR/pf-was-enabled"
        else
            echo no > "$STATE_DIR/pf-was-enabled"
        fi
    fi
    local tmp; tmp="$(mktemp)"
    pf_rules_text "$1" "$2" > "$tmp"
    sudo pfctl -nf "$tmp" 2>&1 | pf_quiet
    sudo cp "$tmp" "$PF_TEAM_CONF"; rm -f "$tmp"
    sudo pfctl -f "$PF_TEAM_CONF" 2>&1 | pf_quiet
    sudo pfctl -e 2>&1 | grep -v -e "already enabled" -e ALTQ || true
    ok "Rules loaded from $PF_TEAM_CONF:"
    sudo pfctl -sr 2>/dev/null | sed 's/^/      /'
    info "Original rules are untouched in /etc/pf.conf (copy in $STATE_DIR/pf.conf.original)."
    shot "the rules above (firewall ON)"
}

firewall_off() {   # $1 port
    title "Firewall OFF: going back to the original macOS rules"
    sudo pfctl -f /etc/pf.conf 2>&1 | pf_quiet
    if [ "$(cat "$STATE_DIR/pf-was-enabled" 2>/dev/null)" = no ]; then
        sudo pfctl -d 2>&1 | grep -v ALTQ || true
    fi
    rm -f "$STATE_DIR/pf-was-enabled"
    info "pf now: $(sudo pfctl -s info 2>/dev/null | head -1)"
    info "Rules now loaded:"
    sudo pfctl -sr 2>/dev/null | pf_quiet | sed 's/^/      /'
    sudo pfctl -sr 2>/dev/null | grep -q "port = $1" && bad "Team rule still loaded!" \
        || ok "Team firewall rule removed (rollback done)."
    shot "the rules above (firewall OFF / rollback)"
}

# ----------------------------------------------------------------- nginx ----
# Add or change the X-Edge header that tells you which edge answered.
set_edge_header() {   # $1 value, e.g. primary-mac2
    if grep -q 'add_header X-Edge' "$NGINX_CONF"; then
        sudo sed -i '' -E "s/add_header X-Edge \"[^\"]*\"/add_header X-Edge \"$1\"/" "$NGINX_CONF"
    else
        sudo perl -0pi -e "s/(\n([ \t]*)server_name [^\n]*;)/\$1\n\$2add_header X-Edge \"$1\" always;   # Phase 2: shows which edge answered/" "$NGINX_CONF"
    fi
    grep -q "add_header X-Edge \"$1\"" "$NGINX_CONF" || die "Could not add the X-Edge header to $NGINX_CONF"
    ok "nginx.conf now sends header  X-Edge: $1"
}

nginx_apply() {   # test config, then reload (or start if not running)
    sudo "$(nginx_bin)" -t || die "nginx config test failed; nothing was reloaded"
    # Reload the running nginx; only start a new one if none is running
    # (reload fails when there is no running nginx to signal).
    if sudo "$(nginx_bin)" -s reload 2>/dev/null; then
        ok "nginx reloaded"
    else
        sudo "$(nginx_bin)" && ok "nginx started"
    fi
    sleep 1
}

edge_check() {   # $1 IP of this edge: ask it directly, bypassing DNS
    info "Asking this edge directly (curl --resolve, DNS not used):"
    local h
    h="$(curl -s -o /dev/null -D - --max-time 15 --resolve "$DOMAIN_APP:$EDGE_PORT:$1" "$URL_STATUS" | tr -d '\r')"
    if [ -n "$h" ]; then
        echo "$h" | grep -i -e '^HTTP' -e '^x-edge' -e '^x-backend' | sed 's/^/      /'
    else
        warn "No HTTPS answer from $1:$EDGE_PORT (is nginx running? is the mkcert CA trusted on this Mac?)"
    fi
}

# ---------------------------------------------------------------- status ----
st_line() { if [ "$1" = 0 ]; then echo "  ${G}[ok]${N} $2"; else echo "  ${Y}[--]${N} $2"; fi; }

status_ip() {   # $1 expected
    local a; a="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
    [ "$a" = "$1" ]; st_line $? "IP address: ${a:-none} (team.env says $1)"
}
status_proc() {   # $1 process name, $2 label
    pgrep -x "$1" >/dev/null; st_line $? "$2 running ($1)"
}
status_listen() {   # $1 port, $2 label
    sudo lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; st_line $? "$2 listening on port $1"
}
status_dns_record() {   # $1 DNS server IP
    local a; a="$(dig @"$1" "$DOMAIN_APP" +short +time=3 +tries=2 2>/dev/null | head -1)"
    [ "$a" = "$MAC2_IP" ]; st_line $? "DNS on $1: $DOMAIN_APP -> ${a:-no answer} (normal: $MAC2_IP)"
}
status_pf() {   # $1 port
    if sudo pfctl -sr 2>/dev/null | grep -q "port = $1"; then
        st_line 1 "Firewall rule for port $1 is ON (run firewall-off after the demo)"
    else
        st_line 0 "Firewall rule for port $1 is off (normal)"
    fi
}
status_client_dns() {
    local s; s="$(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ')"
    echo "$s" | grep -q "$MAC1_IP" && echo "$s" | grep -q "$MAC3_IP"
    st_line $? "DNS servers on this Mac: $s"
}
status_site() {
    local code; code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$URL_STATUS")"
    [ "$code" = 200 ]; st_line $? "$URL_STATUS -> HTTP $code"
}
