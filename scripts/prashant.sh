#!/bin/bash
# Prashant - Mac 4 - Backend B + main test client
# Usage: bash prashant.sh <command>      (bash prashant.sh help  lists commands)

. "$(cd "$(dirname "$0")" && pwd)/common.sh"
PERSON=prashant; MY_IP="$MAC4_IP"
CMD="${1:-help}"; shift 2>/dev/null

usage() {
    cat <<EOF
${B}Prashant - Mac 4 ($MAC4_IP): Backend B + main test client${N}

 Step 0  ${B}check-team${N}       Check your IP and that all 4 Macs answer
 Step 1  ${B}set-dns${N}          Make this Mac use Mac 1 + Mac 3 (backup) as DNS
         ${B}dns-test${N}         Ask both DNS servers for $DOMAIN_APP
 Step 2  ${B}site${N}             Open the website ($URL_STATUS)
 Step 3  ${B}check-cache${N}      Cached DNS answer vs fresh DNS answer
         ${B}flush${N}            Empty this Mac's DNS cache
 Step 4  ${B}firewall-on${N}      Only Asad's edge may reach Backend B (port $PORT_B)
         ${B}firewall-off${N}     Remove that rule again (rollback)
 Step 5  ${B}loop${N}             Send 6 requests, show which backend answered each
         ${B}backend-b${N}        Start Backend B (Ctrl+C stops it)
 Step 6  ${B}which-edge${N}       Show which edge (Asad or Mayank) answers
 Step 7  ${B}status${N}           Check everything is back to normal
 Other   ${B}unset-dns${N}        Put this Mac's DNS settings back
EOF
}

case "$CMD" in
    help|-h|--help) usage; exit 0 ;;
    check-team) check_team "$MY_IP"; exit 0 ;;
esac
require_mac "$MY_IP" "Prashant (Mac 4)"

case "$CMD" in
    set-dns)    set_dns ;;
    unset-dns)  unset_dns ;;
    dns-test)
        logrun extA-backup-dns "dns-test" dns_test
        shot "the DNS answers above (Extension A)"
        ;;
    site)
        logrun extA-backup-dns "site" site
        shot "the website reply above (Extension A)"
        ;;
    check-cache)
        logrun extB-ttl "check-cache" check_cache
        shot "the cached vs fresh answer and the time (Extension B)"
        ;;
    flush)  flush_dns ;;
    firewall-on)   firewall_on "$PORT_B" "Backend B" ;;
    firewall-off)  firewall_off "$PORT_B" ;;
    loop)
        logrun extD-failover "loop" loop
        shot "which backend answered each request (Extension D)"
        ;;
    backend-b)
        cd "$REPO_ROOT" && exec python3 backend/backend_b.py
        ;;
    which-edge)
        logrun extE-edge-cutover "which-edge" which_edge
        shot "which edge answered and the time (Extension E)"
        ;;
    status)
        title "Status of Prashant's Mac 4"
        status_ip "$MAC4_IP"
        status_listen "$PORT_B" "Backend B"
        status_pf "$PORT_B"
        status_client_dns
        status_site
        shot "this status list (Step 7)"
        ;;
    *) bad "Unknown command: $CMD"; echo; usage; exit 1 ;;
esac
