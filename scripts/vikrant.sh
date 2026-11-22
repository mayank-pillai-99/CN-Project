#!/bin/bash
# Vikrant - Mac 1 - primary DNS server (dnsmasq) + test client 2
# Usage: bash vikrant.sh <command>      (bash vikrant.sh help  lists commands)

. "$(cd "$(dirname "$0")" && pwd)/common.sh"
PERSON=vikrant; MY_IP="$MAC1_IP"
CMD="${1:-help}"; shift 2>/dev/null

usage() {
    cat <<EOF
${B}Vikrant - Mac 1 ($MAC1_IP): main DNS server + test client${N}

 Step 0  ${B}check-team${N}       Check your IP and that all 4 Macs answer
 Step 1  ${B}dns-ttl${N}          Update your DNS server: answers may be cached for $DNS_TTL s
         ${B}set-dns${N}          Make this Mac use Mac 1 + Mac 3 (backup) as DNS
 Step 2  ${B}dns-stop${N}         Turn OFF your DNS server (backup demo)
         ${B}dns-start${N}        Turn it back ON
 Step 3  ${B}point-to <mac>${N}   Point $DOMAIN_APP at mac2 (normal), mac3 or mac4;  Mayank does the same
 Step 4  ${B}test-backends${N}    Try to reach the backends directly (should be BLOCKED)
 Step 6  ${B}flush${N}            Empty this Mac's DNS cache
         ${B}which-edge${N}       Show which edge (Asad or Mayank) answers
 Step 7  ${B}status${N}           Check everything is back to normal
 Other   ${B}dns-test${N}  ${B}site${N}  ${B}check-cache${N}  ${B}unset-dns${N}  ${B}undo-dns-ttl${N}
EOF
}

case "$CMD" in
    help|-h|--help) usage; exit 0 ;;
    check-team) check_team "$MY_IP"; exit 0 ;;
esac
require_mac "$MY_IP" "Vikrant (Mac 1)"

case "$CMD" in
    dns-ttl)
        title "Step 1: Primary DNS with a $DNS_TTL second TTL"
        write_dnsmasq "$MAC1_IP" "$MAC2_IP" "Mac 1 (Vikrant) primary DNS"
        shot "the answer line above; the 2nd column ($DNS_TTL) is the TTL (Extension B)"
        ;;
    undo-dns-ttl)
        title "Putting the Phase 1 dnsmasq.conf back"
        restore_original "$DNSMASQ_CONF"
        sudo brew services restart dnsmasq >/dev/null 2>&1; sleep 2; dns_answer "$MAC1_IP"
        ;;
    dns-stop)
        dns_stop
        info "Now Prashant runs:  bash prashant.sh dns-test  and  bash prashant.sh site"
        ;;
    dns-start)  dns_start "$MAC1_IP" ;;
    point-to)
        point_to "$MAC1_IP" "$1" "Mac 1 (Vikrant) primary DNS"
        ;;
    set-dns)      set_dns ;;
    unset-dns)    unset_dns ;;
    flush)        flush_dns ;;
    dns-test)     logrun extA-backup-dns "dns-test" dns_test ;;
    site)         logrun extA-backup-dns "site" site ;;
    check-cache)  logrun extB-ttl "check-cache" check_cache ;;
    test-backends)
        logrun extC-firewall "test-backends from Vikrant (should be BLOCKED)" test_backends
        shot "both backends BLOCKED from Vikrant's Mac (Extension C)"
        ;;
    which-edge)
        logrun extE-edge-cutover "which-edge" which_edge
        shot "which edge answered and the time (Extension E)"
        ;;
    status)
        title "Status of Vikrant's Mac 1"
        status_ip "$MAC1_IP"
        status_proc dnsmasq "DNS server"
        status_dns_record "$MAC1_IP"
        status_client_dns
        status_site
        shot "this status list (Step 7)"
        ;;
    *) bad "Unknown command: $CMD"; echo; usage; exit 1 ;;
esac
