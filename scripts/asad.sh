#!/bin/bash
# Asad - Mac 2 - edge: nginx reverse proxy, TLS, load balancer
# Usage: bash asad.sh <command>      (bash asad.sh help  lists commands)

. "$(cd "$(dirname "$0")" && pwd)/common.sh"
PERSON=asad; MY_IP="$MAC2_IP"
CMD="${1:-help}"; shift 2>/dev/null

usage() {
    cat <<EOF
${B}Asad - Mac 2 ($MAC2_IP): nginx edge${N}

 Step 0  ${B}check-team${N}         Check your IP and that all 4 Macs answer
         ${B}update-backends${N}    Put Mayank's + Prashant's current IPs into nginx.conf
 Step 4  ${B}test-backends${N}      Reach both backends directly (should be ALLOWED)
 Step 5  ${B}show-log${N}           Watch nginx pick backends live (Ctrl+C to quit)
 Step 6  ${B}add-edge-header${N}    Make nginx say "X-Edge: primary-mac2" in every reply
         ${B}pack-for-standby${N}   Put nginx.conf + certificate on your Desktop for Mayank
         ${B}edge-stop${N}          Stop nginx (after the switch to Mayank)
         ${B}edge-start${N}         Start nginx again
 Step 7  ${B}status${N}             Check everything is back to normal
 Other   ${B}undo-edge-header${N}   Remove the X-Edge header again
EOF
}

case "$CMD" in
    help|-h|--help) usage; exit 0 ;;
    check-team) check_team "$MY_IP"; exit 0 ;;
esac
require_mac "$MY_IP" "Asad (Mac 2)"

case "$CMD" in
    test-backends)
        logrun extC-firewall "test-backends from Asad's edge (should be ALLOWED)" test_backends
        shot "both backends ALLOWED from the edge (Extension C)"
        ;;
    show-log)
        title "nginx access log (live). Ctrl+C to stop."
        info "upstream= shows which backend got each request. Two addresses on one line"
        info "means nginx tried the first one, it failed, and it retried on the second."
        shot "the log lines while Backend A is stopped (Extension D)"
        echo
        tail -n 5 -f "$NGINX_ACCESS_LOG"
        ;;
    add-edge-header)
        title "Step 6: label this edge as primary-mac2"
        [ -f "$NGINX_CONF" ] || die "Cannot find $NGINX_CONF"
        backup_once "$NGINX_CONF"
        set_edge_header primary-mac2
        nginx_apply
        edge_check "$MAC2_IP"
        ;;
    update-backends)
        title "Step 0: point nginx at Backend A = $MAC3_IP, Backend B = $MAC4_IP (from team.env)"
        [ -f "$NGINX_CONF" ] || die "Cannot find $NGINX_CONF"
        backup_once "$NGINX_CONF"
        sudo sed -i '' -E "s/server [0-9.]+:$PORT_A/server $MAC3_IP:$PORT_A/; s/server [0-9.]+:$PORT_B/server $MAC4_IP:$PORT_B/" "$NGINX_CONF"
        info "Backend lines in nginx.conf now:"
        grep -E "server [0-9.]+:($PORT_A|$PORT_B)" "$NGINX_CONF" | sed 's/^ */      /'
        nginx_apply
        ;;
    undo-edge-header)
        title "Removing the X-Edge header line"
        sudo sed -i '' '/add_header X-Edge/d' "$NGINX_CONF"
        ok "X-Edge header removed (backend IPs are left as they are)."
        nginx_apply
        ;;
    pack-for-standby)
        title "Step 6: files Mayank needs for the standby edge"
        grep -q 'X-Edge' "$NGINX_CONF" || warn "Run add-edge-header first so both edges have the header."
        out="$HOME/Desktop/team1-standby-edge"
        cert="$(awk '$1=="ssl_certificate" {gsub(";","",$2); print $2}' "$NGINX_CONF")"
        key="$(awk '$1=="ssl_certificate_key" {gsub(";","",$2); print $2}' "$NGINX_CONF")"
        [ -f "$cert" ] && sudo test -f "$key" || die "Certificate or key not found ($cert / $key)"
        rm -rf "$out"; mkdir -p "$out"
        cp "$NGINX_CONF" "$out/nginx.conf"
        sudo cp "$cert" "$key" "$out/"
        sudo chown "$USER" "$out"/*; chmod 600 "$out/$(basename "$key")"
        ok "Packed into $out :"
        ls -1 "$out" | sed 's/^/      /'
        echo
        warn "AirDrop the folder 'team1-standby-edge' (on your Desktop) to Mayank ONLY."
        warn "It contains the private key: never commit it to Git or share it elsewhere."
        info "Then Mayank runs:  bash mayank.sh standby-edge"
        ;;
    edge-stop)
        title "Stopping nginx on the primary edge"
        sudo "$(nginx_bin)" -s stop 2>/dev/null; sleep 2
        if pgrep -x nginx >/dev/null; then
            bad "nginx is still running. If it was started with brew services, run: brew services stop nginx"
        else
            ok "nginx stopped. Clients must now be using Mayank's standby edge."
        fi
        ;;
    edge-start)
        title "Starting nginx on the primary edge"
        nginx_apply
        edge_check "$MAC2_IP"
        ;;
    status)
        title "Status of Asad's Mac 2"
        status_ip "$MAC2_IP"
        status_proc nginx "nginx edge"
        status_listen "$EDGE_PORT" "nginx"
        status_site
        shot "this status list (Step 7)"
        ;;
    *) bad "Unknown command: $CMD"; echo; usage; exit 1 ;;
esac
