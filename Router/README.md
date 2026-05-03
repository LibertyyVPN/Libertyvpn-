Запустить скрипт
```
wget -O router.sh "https://raw.githubusercontent.com/libertyvpn/Libertyvpn-/main/Router/check.sh" && sh router.sh && rm router.sh
```

Команда для перезапуска passwall
```
/etc/init.d/passwall stop; \
killall -9 xray sing-box v2ray ssr-local trojan-go trojan naiveproxy tun2socks passwall.sh 2>/dev/null; \
rm -f /tmp/passwall*.lock /var/run/passwall*.pid /var/lock/passwall*.lock 2>/dev/null; \
sleep 2; \
/etc/init.d/passwall start; \
logread -e passwall
```