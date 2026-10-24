#!/bin/sh
set -e

# Directorio en tiempo de ejecución para sshd
mkdir -p /run/sshd

# Arranca sshd en segundo plano y Apache en primer plano (PID 1 del contenedor)
/usr/sbin/sshd
exec apachectl -D FOREGROUND
