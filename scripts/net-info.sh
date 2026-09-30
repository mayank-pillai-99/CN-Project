#!/usr/bin/env bash
# Task A: run on EACH Mac and paste the output into docs/ARCHITECTURE.md
iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
[ -n "$iface" ] || { echo "No default route - are you on Wi-Fi/LAN?"; exit 1; }
echo "Host      : $(scutil --get ComputerName)"
echo "Interface : $iface"
echo "IPv4      : $(ipconfig getifaddr "$iface")"
echo "Netmask   : $(ifconfig "$iface" | awk '/inet /{print $4; exit}') (hex; 0xffffff00 = 255.255.255.0 = /24)"
echo "Gateway   : $gateway"
echo "MAC       : $(ifconfig "$iface" | awk '/ether/{print $2; exit}')"
