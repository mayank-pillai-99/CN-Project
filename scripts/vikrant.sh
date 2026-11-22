#!/bin/bash
# Vikrant - Mac 1 - primary DNS server (dnsmasq), same as Phase 1
# Usage: bash vikrant.sh <command>      (bash vikrant.sh help  lists commands)

. "$(cd "$(dirname "$0")" && pwd)/common.sh"
PERSON=vikrant; MY_IP="$MAC1_IP"
CMD="${1:-help}"; shift 2>/dev/null

usage() {
    cat <<EOF
${B}Vikrant - Mac 1 ($MAC1_IP): main DNS server${N}

 Step 0  ${B}check-team${N}       Check your IP and that all 4 Macs answer
 Step 1  ${B}dns-ttl${N}          Update your DNS server: answers may be cached for $DNS_TTL s
 Step 2  ${B}dns-stop${N}         Turn OFF your DNS server (backup demo)
         ${B}dns-start${N}        Turn it back ON
 Step 3  ${B}point-to <mac>${N}   Point $DOMAIN_APP at mac2 (normal), mac3 or mac4;  Mayank does the same
 Step 7  ${B}status${N}           Check everything is back to normal
 Other   ${B}undo-dns-ttl${N}     Put the Phase 1 dnsmasq.conf back
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
        warn "The Phase 1 file has the OLD IPs in it; run dns-ttl again if the IPs changed."
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
    status)
        title "Status of Vikrant's Mac 1"
        status_ip "$MAC1_IP"
        status_proc dnsmasq "DNS server"
        status_dns_record "$MAC1_IP"
        shot "this status list (Step 7)"
        ;;
    *) bad "Unknown command: $CMD"; echo; usage; exit 1 ;;
esac
