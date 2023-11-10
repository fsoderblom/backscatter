#!/usr/bin/python

import socket
import struct

SO_ORIGINAL_DST = 80

s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', 2000))
s.listen(10)

while True:
    csock, caddr = s.accept()
    orig_dst = csock.getsockopt(socket.SOL_IP, SO_ORIGINAL_DST, 16)

    orig_port = struct.unpack('>H', orig_dst[2:4])
    orig_addr = socket.inet_ntoa(orig_dst[4:8])

    print 'connection from', caddr
    print 'connection to', (orig_addr, orig_port)
    print
