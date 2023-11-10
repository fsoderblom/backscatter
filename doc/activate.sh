#!/bin/sh
#
# When       Who		What
# 2020-04-20 fredrik@xpd.se	created.

NETS="2.0.0.0/8 3.0.0.0/8 4.0.0.0/8"
#NETS="2.0.0.0/8 3.0.0.0/8 4.0.0.0/8 5.0.0.0/8"

for NET in $NETS
do
	echo "/usr/sbin/ip route add local $NET dev lo src 127.0.0.1"
	echo "/usr/sbin/iptables -t mangle -I PREROUTING -d $NET -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1"
done
exit 0

# ip route add local 192.0.2.0/24 dev lo src 127.0.0.1
# ip route add local 2.0.0.0/8 dev lo src 127.0.0.1
# ip route add local 3.0.2.0/24 dev lo src 127.0.0.1
# iptables -t mangle -I PREROUTING -d 192.0.2.0/24 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
# iptables -t mangle -I PREROUTING -d 2.0.0.0/8 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
# iptables -t mangle -I PREROUTING -d 3.0.2.0/24 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
