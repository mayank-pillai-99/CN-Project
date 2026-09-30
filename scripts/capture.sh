#!/usr/bin/env bash
# Task G: bounded packet capture on a CLIENT Mac -> screenshots/phase1-<time>.pcap
#   Terminal 1:  ./scripts/capture.sh 30
#   Terminal 2:  (flush DNS first) then  curl -v https://app.team1.test:8443/api/status
# Open the .pcap in Wireshark. Filters:  dns | tcp.flags.syn==1 | tls.handshake | tcp.port==8443
secs="${1:-30}"
iface="$(route -n get default | awk '/interface:/{print $2}')"
out="$(dirname "$0")/../screenshots/phase1-$(date +%H%M%S).pcap"
echo "Capturing ${secs}s on $iface -> $out"
echo "Flush DNS first:  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
sudo perl -e 'alarm shift; exec @ARGV' "$secs" tcpdump -i "$iface" -n -w "$out" \
  "port 53 or port 8443 or port 3001 or port 3002"
sudo chown "$(id -un)" "$out"
echo "Saved $out"
