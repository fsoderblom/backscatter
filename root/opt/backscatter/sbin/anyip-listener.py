#!/usr/bin/env python3
#
# When       Who		What
# 2020-04-20 fredrik@xpd.se	adopted original code from cloudflare.

import socket
import struct
import syslog

IP_TRANSPARENT = 19

syslog.openlog(logoption=syslog.LOG_PID, facility=syslog.LOG_DAEMON)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.setsockopt(socket.IPPROTO_IP, IP_TRANSPARENT, 1)
l_onoff = 1
l_linger = 5
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER,struct.pack('ii', l_onoff, l_linger))
s.bind(('127.0.0.1', 1234))
s.listen(32)
syslog.syslog("[+] Bound to tcp://127.0.0.1:1234")
while True:
    c, (r_ip, r_port) = s.accept()
    l_ip, l_port = c.getsockname()
    syslog.syslog("[ ] Connection from tcp://%s:%d to tcp://%s:%d" % (r_ip, r_port, l_ip, l_port))
    c.send(b"captured in backscatter. contact soc for more information.\n")
    c.close()
sys.exit()
