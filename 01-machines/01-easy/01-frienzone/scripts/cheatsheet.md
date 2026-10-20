# Cheatsheet de comandos - Friendzone

Notas rápidas de comandos útiles. No es parte del writeup, es para tener a mano mientras resuelvo.

## Nmap

```bash
# Escaneo rápido de todos los puertos TCP
nmap -p- --min-rate 5000 -T4 IP -oN loot/nmap-allports.txt

# Escaneo detallado sobre los puertos que encontré abiertos
nmap -p<puertos> -sC -sV -oN loot/nmap-detallado.txt IP

# Escaneo UDP (DNS puede necesitar esto para confirmar 53/udp)
nmap -sU --top-ports 20 IP
```

## DNS

```bash
# Transferencia de zona (AXFR) - lo primero que probaría si veo el 53 abierto
dig axfr @IP dominio.tld
host -t axfr dominio.tld IP

# Consulta normal de registros
dig @IP dominio.tld ANY
dig @IP dominio.tld A
dig @IP dominio.tld NS
dig @IP dominio.tld TXT

# Si la transferencia de zona no funciona, fuerza bruta de subdominios
gobuster dns -d dominio.tld -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt -r IP
```

## /etc/hosts

```bash
# Agregar dominio y subdominios encontrados
sudo sh -c 'echo "IP  dominio.tld sub1.dominio.tld sub2.dominio.tld" >> /etc/hosts'
```

## Fuzzing web (virtual hosting / directorios)

```bash
# Fuzzing de subdominios por Host header (virtual host fuzzing)
ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
     -u http://IP -H "Host: FUZZ.dominio.tld" -fs <tamaño_respuesta_default>

gobuster vhost -u http://dominio.tld -w wordlist.txt --append-domain

# Fuzzing de directorios/archivos en un sitio ya resuelto
gobuster dir -u http://sub.dominio.tld -w /usr/share/wordlists/dirb/common.txt -x php,txt,html

ffuf -w /usr/share/wordlists/dirb/common.txt -u http://sub.dominio.tld/FUZZ -e .php,.txt,.html
```

Tip con `ffuf`: siempre probar primero con una palabra random (ej. `asdf1234`) para ver qué tamaño de respuesta da un 404/not-found, y usar `-fs <tamaño>` para filtrar ese ruido.

## SMB

```bash
# Listar shares con sesión nula (sin credenciales)
smbclient -L //IP -N

# Ver permisos de cada share de forma más clara (lectura/escritura)
smbmap -H IP
smbmap -H IP -u anonymous

# Conectarse a un share puntual
smbclient //IP/nombre_share -N

# Una vez dentro de smbclient:
#   ls          -> listar contenido
#   get archivo -> descargar
#   put archivo -> subir (si el share tiene escritura)
#   cd carpeta  -> moverse

# Montar el share en el filesystem (alternativa a smbclient interactivo)
mkdir /tmp/smb-mount
sudo mount -t cifs //IP/nombre_share /tmp/smb-mount -o username=anonymous,password=

# enum4linux para enumeración más agresiva (users, shares, policies)
enum4linux -a IP
```

## Varios

```bash
# Curl mandando Host header manualmente (si no querés tocar /etc/hosts para probar algo rápido)
curl -H "Host: sub.dominio.tld" http://IP/

# Ver headers completos de una respuesta
curl -I http://sub.dominio.tld
```
