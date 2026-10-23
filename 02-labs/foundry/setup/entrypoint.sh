#!/bin/sh
set -e

# Directorio en tiempo de ejecución para sshd
mkdir -p /run/sshd

# Arranca sshd en segundo plano y nginx en primer plano (PID 1 del contenedor)
/usr/sbin/sshd
exec nginx -g 'daemon off;'
