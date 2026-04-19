#!/bin/sh
# ===SYSTEM INFO ===
cat /etc/openwrt_release
uptime
uname -a
free -h
df -h
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | while read temp; do echo "$(($temp / 1000))°C"; done 2>/dev/null || echo "Temperature: N/A"

# === PACKAGES CHECK ===
SYSTEM_DEPS="luci-compat ipset"
NFTABLES_DEPS="iptables-mod-tproxy iptables-mod-iprange iptables-mod-socket iptables-mod-conntrack-extra"
KERNEL_DEPS="kmod-nft-socket kmod-nft-tproxy kmod-nf-socket kmod-nf-tproxy kmod-ipt-socket kmod-ipt-tproxy kmod-ipt-nat"
NETWORK_DEPS="kmod-nfnetlink kmod-nfnetlink-queue"
PROXY_DEPS="xray-core curl"
LANG_DEPS="luci-i18n-base-ru luci-i18n-firewall-ru"
PASSWALL_DEPS="dnsmasq-full chinadns-ng dns2socks microsocks tcping luci-app-passwall"
ALL_DEPS="$SYSTEM_DEPS $NFTABLES_DEPS $KERNEL_DEPS $NETWORK_DEPS $PROXY_DEPS $LANG_DEPS $PASSWALL_DEPS"
MISSING_PACKAGES=""
for pkg in $ALL_DEPS; do echo -n "Checking $pkg... "; if opkg list-installed | grep -q "^$pkg "; then echo "✓ installed"; else echo "✗ MISSING"; MISSING_PACKAGES="$MISSING_PACKAGES $pkg"; fi; done
[ -n "$MISSING_PACKAGES" ] && echo "⚠️  CRITICAL: Missing packages:$MISSING_PACKAGES" || echo "✅ All packages installed"

# === PASSWALL CONFIGURATION ===
uci show passwall.@global[0] 2>/dev/null | head -20 || echo "PassWall not configured"
DNS_SHUNT=$(uci get passwall.@global[0].dns_shunt 2>/dev/null || echo "not_set")
DNS_MODE=$(uci get passwall.@global[0].dns_mode 2>/dev/null || echo "not_set")
DNS_REDIRECT=$(uci get passwall.@global[0].dns_redirect 2>/dev/null || echo "not_set")
TCP_PROXY_MODE=$(uci get passwall.@global[0].tcp_proxy_mode 2>/dev/null || echo "not_set")
LOCALHOST_PROXY=$(uci get passwall.@global[0].localhost_proxy 2>/dev/null || echo "not_set")
echo "DNS Shunt: $DNS_SHUNT | DNS Mode: $DNS_MODE | DNS Redirect: $DNS_REDIRECT | TCP Proxy: $TCP_PROXY_MODE | Localhost Proxy: $LOCALHOST_PROXY"
echo "Real DNS processes running:"
ps w | grep -E "(chinadns|dnsmasq_default)" | grep -v grep || echo "No DNS processes found"

# === ACTIVE PROCESSES & MEMORY ===
ps w | grep -E "(passwall|xray|chinadns|dnsmasq_default)" | grep -v grep || echo "No PassWall processes running"
ps w | head -15
for pid in $(ps | awk 'NR>1 {print $1}' | head -15); do if [ -r "/proc/$pid/status" ]; then name=$(grep "^Name:" /proc/$pid/status 2>/dev/null | awk '{print $2}'); rss=$(grep "^VmRSS:" /proc/$pid/status 2>/dev/null | awk '{print $2}'); [ -n "$name" ] && [ -n "$rss" ] && echo "$name: $rss kB"; fi; done | sort -k2 -nr | head -10

# === PASSWALL FILES & VERSIONS ===
ls -la /tmp/etc/passwall*/bin/* 2>/dev/null || echo "No PassWall binaries found"
du -sh /tmp/etc/passwall* 2>/dev/null || echo "No PassWall temp files"
/usr/bin/xray version 2>/dev/null | head -3 || echo "Xray not found"
/usr/bin/chinadns-ng --version 2>/dev/null | head -1 || echo "ChinaDNS-NG not found"
dnsmasq --version 2>/dev/null | head -1 || echo "dnsmasq version not available"

# === NETWORK & FIREWALL ===
ip addr show | grep -E "(inet |UP|DOWN)" | head -8
ip route show | head -8
cat /etc/resolv.conf
iptables -t nat -L | head -10 2>/dev/null || echo "Cannot read iptables"
nft list tables 2>/dev/null | head -3 || echo "No nftables"
lsmod | grep -E "(nf_|xt_|ipt_|ip_set)" | head -8

# === LOGS COLLECTION ===
logread | tail -100
dmesg | grep -i -E "(oom|kill|memory)" | tail -10 || echo "No memory errors in dmesg"
logread | grep -i passwall | tail -15 || echo "No PassWall logs"
logread | grep -i -E "(dnsmasq.*error|dns.*fail|query.*fail)" | tail -10 || echo "No DNS errors"
ls /tmp/etc/passwall*/log/ 2>/dev/null && cat /tmp/etc/passwall*/log/*.log 2>/dev/null | tail -15 || echo "No Xray log files"
logread | grep -i xray | tail -10 || echo "No Xray logs in syslog"
cat /tmp/log/passwall.log 2>/dev/null | tail -30 || echo "No PassWall startup log"
cat /var/log/passwall.log 2>/dev/null | tail -30 || echo "No PassWall var log"  
cat /tmp/passwall.log 2>/dev/null | tail -30 || echo "No PassWall temp log"
ls /usr/share/passwall/*.log 2>/dev/null && cat /usr/share/passwall/*.log | tail -20 || echo "No PassWall share logs"
/etc/init.d/passwall enabled 2>/dev/null && echo "PassWall: enabled on boot" || echo "PassWall: not enabled on boot"
cat /tmp/log/xray.log 2>/dev/null | tail -20 || echo "No Xray startup log"
cat /var/log/xray.log 2>/dev/null | tail -20 || echo "No Xray var log"
cat /tmp/etc/passwall*/xray*.log 2>/dev/null | tail -15 || echo "No Xray PassWall logs"
find /tmp/etc/passwall* -name "*xray*" -o -name "*error*" -o -name "*access*" 2>/dev/null | head -5 | while read f; do echo "Found: $f"; cat "$f" | tail -5; done 2>/dev/null || echo "No additional Xray logs"
pgrep -f xray | head -3 | while read pid; do echo "Xray PID $pid:"; cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' '; echo; done || echo "No Xray process details"
ls /tmp/etc/passwall*/acl/*/TCP*.json 2>/dev/null && echo "Xray config files found" || echo "No Xray config files"
cat /tmp/etc/passwall*/acl/*/TCP*.json 2>/dev/null | grep -E "(listen|port|address)" | head -10 || echo "No Xray config details"
dmesg | grep -i -E "(error|fail|warn)" | grep -v -E "(thermal|wifi|regulatory)" | tail -10 || echo "No critical kernel errors"
ping -c 2 8.8.8.8 >/dev/null 2>&1 && echo "✓ Internet: 8.8.8.8 OK" || echo "✗ Internet: 8.8.8.8 FAIL"
ping -c 2 1.1.1.1 >/dev/null 2>&1 && echo "✓ Internet: 1.1.1.1 OK" || echo "✗ Internet: 1.1.1.1 FAIL"

# === SERVICE STATUS ===
/etc/init.d/passwall status 2>/dev/null || echo "PassWall service status unknown"
ls -la /etc/rc.d/*passwall* 2>/dev/null || echo "Service not enabled on boot"
uci get luci.main.lang 2>/dev/null || echo "Language not set"

# === FINAL ANALYSIS ===
AVAILABLE_MEM=$(free | awk '/^Mem:/ {print int($7/1024)}')
NODES=$(uci show passwall | grep -c "=nodes" 2>/dev/null || echo "0")
XRAY_PROC=$(ps | grep xray | grep -v grep | wc -l)
VPN_DOMAINS=$(uci show passwall | grep -c "domain.*=" 2>/dev/null || echo "0")
echo "SUMMARY: Memory: ${AVAILABLE_MEM}MB free | Nodes: $NODES | Xray processes: $XRAY_PROC | VPN domains: $VPN_DOMAINS"

# Critical issues check
[ "$AVAILABLE_MEM" -lt 50 ] && echo "⚠️  LOW MEMORY: ${AVAILABLE_MEM}MB (need >50MB)"
[ "$DNS_REDIRECT" = "1" ] && [ "$DNS_SHUNT" = "dnsmasq" ] && echo "ℹ️  DNS INFO: Redirect enabled - using ChinaDNS-NG instead of dnsmasq (normal)"
[ "$XRAY_PROC" -eq 0 ] && echo "⚠️  XRAY NOT RUNNING"
[ -n "$MISSING_PACKAGES" ] && echo "⚠️  MISSING PACKAGES: $MISSING_PACKAGES"
echo "=== DIAGNOSTICS COMPLETE ==="
