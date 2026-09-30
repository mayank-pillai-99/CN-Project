#!/usr/bin/env bash
# Task A / demo step 2: ping every other Mac from THIS Mac. Run it on all four.
declare -a NAMES=("Mac1-DNS" "Mac2-Edge" "Mac3-BackendA" "Mac4-BackendB")
declare -a IPS=("10.7.13.235" "10.7.17.39" "10.7.5.187" "10.7.15.184")
for i in "${!IPS[@]}"; do
  if ping -c 2 -W 1000 "${IPS[$i]}" >/dev/null 2>&1; then r="OK  "; else r="FAIL"; fi
  printf '%s  %-14s %s\n' "$r" "${NAMES[$i]}" "${IPS[$i]}"
done
