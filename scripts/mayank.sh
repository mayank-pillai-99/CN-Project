#!/bin/bash
# Mayank - Mac 3 - Backend A + test client (same as Phase 1)
#          Phase 2 additions: backup DNS + standby edge
# Usage: bash mayank.sh <command>      (bash mayank.sh help  lists commands)

. "$(cd "$(dirname "$0")" && pwd)/common.sh"
PERSON=mayank; MY_IP="$MAC3_IP"
CMD="${1:-help}"; shift 2>/dev/null

usage() {
    cat <<EOF
${B}Mayank - Mac 3 ($MAC3_IP): Backend A + test client${N}
${B}         Phase 2 additions: backup DNS + standby edge${N}

 Step 0  ${B}check-team${N}       Check your IP and that all 4 Macs answer
 Step 1  ${B}backup-dns${N}       Install and start the BACKUP DNS server on this Mac
         ${B}set-dns${N}          Make this Mac use Mac 1 + Mac 3 (backup) as DNS
 Step 3  ${B}point-to <mac>${N}   Point $DOMAIN_APP at mac2 (normal), mac3 or mac4;  Vikrant does the same
 Step 4  ${B}firewall-on${N}      Only Asad's edge may reach Backend A (port $PORT_A)
         ${B}test-backends${N}    Try to reach Prashant's backend directly (should be BLOCKED)
         ${B}firewall-off${N}     Remove that rule again (rollback)
 Step 5  ${B}backend-a${N}        Start Backend A (Ctrl+C stops it)
 Step 6  ${B}standby-edge${N}     Set up nginx here as a copy of Asad's edge
         ${B}flush${N}            Empty this Mac's DNS cache
         ${B}which-edge${N}       Show which edge (Asad or Mayank) answers
         ${B}standby-stop${N}     Stop the standby nginx
 Step 7  ${B}status${N}           Check everything is back to normal
 Other   ${B}dns-test${N}  ${B}site${N}  ${B}check-cache${N}  ${B}loop${N}  ${B}unset-dns${N}
         ${B}dns-stop${N}  ${B}dns-start${N}  ${B}undo-backup-dns${N}
EOF
}

case "$CMD" in
    help|-h|--help) usage; exit 0 ;;
    check-team) check_team "$MY_IP"; exit 0 ;;
esac
require_mac "$MY_IP" "Mayank (Mac 3)"

case "$CMD" in
    backup-dns)
        title "Step 1: Backup DNS server on Mac 3"
        write_dnsmasq "$MAC3_IP" "$MAC2_IP" "Mac 3 (Mayank) BACKUP DNS"
        shot "the answer from the backup DNS server above (Extension A)"
        ;;
    undo-backup-dns)
        title "Removing the backup DNS server"
        sudo brew services stop dnsmasq >/dev/null 2>&1
        restore_original "$DNSMASQ_CONF"
        ok "Backup DNS stopped."
        ;;
    dns-stop)   dns_stop ;;
    dns-start)  dns_start "$MAC3_IP" ;;
    point-to)
        point_to "$MAC3_IP" "$1" "Mac 3 (Mayank) BACKUP DNS"
        ;;
    firewall-on)   firewall_on "$PORT_A" "Backend A" ;;
    firewall-off)  firewall_off "$PORT_A" ;;
    # --- test client commands (Mac 3 was a client in Phase 1 too) ---
    set-dns)      set_dns ;;
    unset-dns)    unset_dns ;;
    flush)        flush_dns ;;
    dns-test)     logrun extA-backup-dns "dns-test" dns_test ;;
    site)         logrun extA-backup-dns "site" site ;;
    check-cache)  logrun extB-ttl "check-cache" check_cache ;;
    loop)         logrun extD-failover "loop" loop ;;
    test-backends)
        logrun extC-firewall "test-backends from Mayank (should be BLOCKED)" test_backends
        shot "Prashant's backend BLOCKED from Mayank's Mac (Extension C)"
        ;;
    which-edge)
        logrun extE-edge-cutover "which-edge" which_edge
        shot "which edge answered and the time (Extension E)"
        ;;
    backend-a)
        cd "$REPO_ROOT" && exec python3 backend/backend_a.py
        ;;
    standby-edge)
        title "Step 6: standby nginx edge on Mac 3"
        src="${1:-}"
        for d in "$src" "$HOME/Downloads/team1-standby-edge" "$HOME/Desktop/team1-standby-edge"; do
            [ -n "$d" ] && [ -f "$d/nginx.conf" ] && { src="$d"; break; }
        done
        [ -f "$src/nginx.conf" ] || die "Folder team1-standby-edge not found in Downloads or Desktop. Ask Asad to run 'bash asad.sh pack-for-standby' and AirDrop it."
        ok "Using files from $src"
        command -v nginx >/dev/null 2>&1 || { title "Installing nginx"; brew install nginx || die "brew install nginx failed"; }
        sudo mkdir -p "$NGINX_DIR" "$BREW_PREFIX/var/log/nginx"
        backup_once "$NGINX_CONF"
        # Same config as Asad's, with paths fixed for this Mac's Homebrew folder.
        sed "s#/opt/homebrew#$BREW_PREFIX#g; s#/usr/local#$BREW_PREFIX#g" "$src/nginx.conf" > "$STATE_DIR/nginx.standby.conf"
        sudo cp "$STATE_DIR/nginx.standby.conf" "$NGINX_CONF"
        for f in "$src"/*.pem; do
            sudo cp "$f" "$NGINX_DIR/"
        done
        sudo chmod 600 "$NGINX_DIR"/*-key.pem 2>/dev/null
        ok "Copied nginx.conf and the certificate into $NGINX_DIR"
        set_edge_header standby-mac3
        nginx_apply
        edge_check "$MAC3_IP"
        if sudo pfctl -sr 2>/dev/null | grep -q "port = "; then
            warn "A firewall rule is still on. Run firewall-off here, and Prashant too,"
            warn "or this standby edge cannot reach Backend B."
        fi
        shot "X-Edge: standby-mac3 above (Extension E)"
        ;;
    standby-stop)
        title "Stopping the standby nginx"
        sudo "$(nginx_bin)" -s stop 2>/dev/null; sleep 1
        pgrep -x nginx >/dev/null && bad "nginx still running" || ok "Standby nginx stopped."
        ;;
    status)
        title "Status of Mayank's Mac 3"
        status_ip "$MAC3_IP"
        status_listen "$PORT_A" "Backend A"
        status_proc dnsmasq "Backup DNS server"
        status_dns_record "$MAC3_IP"
        status_pf "$PORT_A"
        status_client_dns
        status_site
        if pgrep -x nginx >/dev/null; then st_line 1 "Standby nginx is still running (stop it after Step 6)"; else st_line 0 "Standby nginx is stopped (normal)"; fi
        shot "this status list (Step 7)"
        ;;
    *) bad "Unknown command: $CMD"; echo; usage; exit 1 ;;
esac
