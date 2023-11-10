# Set 192.0.2.0/24 to be routed locally with AnyIP.
# Make it explicit that the source IP used for this network
# when connecting locally should be in 127.0.0.0/8 range.
# This is needed since otherwise the TPROXY rule would match
# both forward and backward traffic. We want it to catch 
# forward traffic only.
# 2/8, 3/8, 4/8, 5/8
ip route add local 192.0.2.0/24 dev lo src 127.0.0.1
ip route add local 2.0.0.0/8 dev lo src 127.0.0.1
ip route add local 3.0.2.0/24 dev lo src 127.0.0.1

# Set the magical TPROXY routing
iptables -t mangle -I PREROUTING -d 192.0.2.0/24 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
iptables -t mangle -I PREROUTING -d 2.0.0.0/8 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
iptables -t mangle -I PREROUTING -d 3.0.2.0/24 -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
