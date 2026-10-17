---
title: Fawn
os: Linux
dificultad: Very Easy
ip: 10.129.1.14
fecha: 2026-10-17
categoria: Starting Point
estado: completada
tags: [htb, linux, ftp, anonymous-login]
---

# Fawn — Informe de Pentest

> Writeup de la máquina **Fawn** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                   | Detalle        |
| ----------------------- | -------------- |
| **Máquina**             | Fawn           |
| **Sistema operativo**   | Linux          |
| **Dificultad**          | Very Easy      |
| **Categoría**           | Starting Point |
| **Dirección IP**        | `10.129.1.14`  |
| **Fecha de resolución** | 2026-10-17     |
| **Autor del informe**   | NiettoFrann    |
| **Estado**              | Completada     |

## Índice

1. [Resumen ejecutivo](#resumen-ejecutivo)
2. [Alcance y metodología](#alcance-y-metodología)
3. [Cadena de ataque](#cadena-de-ataque)
4. [Reconocimiento](#reconocimiento)
5. [Enumeración](#enumeración)
6. [Explotación (Foothold)](#explotación-foothold)
7. [Escalada de privilegios](#escalada-de-privilegios)
8. [Flags](#flags)
9. [Vulnerabilidades identificadas](#vulnerabilidades-identificadas)
10. [Recomendaciones de mitigación](#recomendaciones-de-mitigación)
11. [Lecciones aprendidas](#lecciones-aprendidas)
12. [Herramientas utilizadas](#herramientas-utilizadas)
13. [Evidencia](#evidencia)
14. [Referencias](#referencias)

---

## Resumen ejecutivo

La máquina `Fawn` se comprometió a través de un servicio **FTP mal configurado que permite el acceso anónimo**.

- El único puerto abierto es el **21/tcp (FTP)**, con `vsftpd 3.0.3`.
- El servidor acepta el login `anonymous` sin contraseña y expone un fichero `flag.txt` legible por cualquiera.
- No fue necesario explotar ninguna vulnerabilidad de software: bastó con autenticarse como `anonymous` y descargar el fichero.
- La versión `vsftpd 3.0.3` tiene un CVE conocido ([CVE-2021-30047](https://www.cve.org/CVERecord?id=CVE-2021-30047)), pero solo permite una denegación de servicio (DoS), por lo que no aporta a la intrusión y no se utilizó.

**Impacto:** cualquier persona con conectividad de red al puerto 21 puede leer (y potencialmente escribir, según la configuración) ficheros del servidor sin autenticación.

## Alcance y metodología

- **Objetivo:** `10.129.1.14` (Fawn)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (TTL 63 → Linux) -> Escaneo de 65535 puertos (solo 21/tcp) -> Escaneo detallado (vsftpd 3.0.3, ftp-anon habilitado)
  -> Login FTP como anonymous -> Descarga de flag.txt
```

---

## Reconocimiento

### Conectividad y sistema operativo

Se comprobó que el host responde y se infirió el sistema operativo a partir del TTL.

```bash
ping -c 1 10.129.1.14 | tee loot/ping.txt
```

```text
PING 10.129.1.14 (10.129.1.14) 56(84) bytes of data.
64 bytes from 10.129.1.14: icmp_seq=1 ttl=63 time=232 ms

--- 10.129.1.14 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 232.082/232.082/232.082/0.000 ms
```

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

| Dato    | Valor    | Interpretación                                                                                                   |
| ------- | -------- | ---------------------------------------------------------------------------------------------------------------- |
| Latencia | ~232 ms  | Host activo, alcanzable por la VPN.                                                                              |
| TTL     | `63`     | Los sistemas Linux/Unix parten de TTL 64; el valor 63 indica un salto intermedio (VPN). Sistema **Linux**.       |

### Escaneo de puertos

Primero se escanearon **todos los puertos TCP** de forma rápida para descubrir la superficie de ataque:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.1.14 -oN loot/puertos.txt
```

```text
Nmap scan report for 10.129.1.14
Host is up (0.23s latency).
Not shown: 65534 closed tcp ports (conn-refused)
PORT   STATE SERVICE
21/tcp open  ftp
```

> Evidencia: [`loot/puertos.txt`](loot/puertos.txt)

| Opción           | Motivo                                                              |
| ---------------- | ------------------------------------------------------------------- |
| `-p-`            | Todos los puertos (1-65535).                                        |
| `--min-rate=5000`| Envía al menos 5000 paquetes/s para acelerar el escaneo.            |
| `-T4`            | Plantilla de tiempos agresiva.                                      |
| `-Pn`            | Omite el descubrimiento de host (se asume activo).                  |
| `-n`             | Sin resolución DNS.                                                 |
| `-oN`            | Guarda la salida en formato normal.                                 |

**Resultado:** 65534 puertos cerrados y un único puerto abierto.

| Puerto | Estado | Servicio |
| ------ | ------ | -------- |
| 21/tcp | open   | ftp      |

Sobre el puerto descubierto se lanzó un escaneo de **detección de versiones y scripts por defecto**:

```bash
nmap -p21 -sCV -Pn -n -T4 10.129.1.14 -oN loot/detallado.txt
```

```text
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_-rw-r--r--    1 0        0              32 Jun 04  2021 flag.txt
| ftp-syst: 
|   STAT: 
| FTP server status:
|      Connected to ::ffff:10.10.14.175
|      Logged in as ftp
|      TYPE: ASCII
|      No session bandwidth limit
|      Session timeout in seconds is 300
|      Control connection is plain text
|      Data connections will be plain text
|      At session startup, client count was 1
|      vsFTPd 3.0.3 - secure, fast, stable
|_End of status
Service Info: OS: Unix
```

> Evidencia: [`loot/detallado.txt`](loot/detallado.txt)

| Opción | Motivo                                              |
| ------ | --------------------------------------------------- |
| `-p21` | Limita el escaneo al puerto encontrado.             |
| `-sC`  | Ejecuta los scripts NSE por defecto (ej. `ftp-anon`).|
| `-sV`  | Detecta la versión del servicio.                    |

**Resultado:**

| Puerto | Estado | Servicio | Versión         |
| ------ | ------ | -------- | --------------- |
| 21/tcp | open   | ftp      | `vsftpd 3.0.3`  |

Hallazgos relevantes de la salida de nmap:

- `ftp-anon: Anonymous FTP login allowed (FTP code 230)` → **el login anónimo está permitido**.
- El script ya lista un fichero en la raíz del FTP: `-rw-r--r-- 1 0 0 32 Jun 04 2021 flag.txt` (propiedad de root, legible por todos, 32 bytes).
- `Control connection is plain text` / `Data connections will be plain text` → el tráfico no está cifrado (sin TLS).

## Enumeración

### FTP (21/tcp)

Con la información del escaneo, se verificó manualmente el acceso anónimo. El usuario es `anonymous` y la contraseña puede quedar vacía.

```bash
ftp 10.129.1.14
# Name: anonymous
# Password: (vacía / Enter)
ftp> ls
```

Se confirmó el listado visto por nmap: un único fichero, `flag.txt`.

### Búsqueda de vulnerabilidades

Se revisó la versión `vsftpd 3.0.3`:

- **CVE-2021-30047**: DoS por agotamiento de recursos. No permite acceso ni ejecución de código, por lo que se descartó para este objetivo.
- La conocida puerta trasera de `vsftpd 2.3.4` **no aplica** a esta versión.

## Explotación (Foothold)

- **Vulnerabilidad:** acceso anónimo habilitado en el servicio FTP (configuración insegura, no un fallo de software).
- **Referencia:** [CWE-287 – Improper Authentication](https://cwe.mitre.org/data/definitions/287.html) / [CWE-284 – Improper Access Control](https://cwe.mitre.org/data/definitions/284.html).
- **Impacto:** lectura de ficheros del servidor sin autenticar.

### Procedimiento

```bash
ftp 10.129.1.14
# Name: anonymous
ftp> ls
ftp> get flag.txt
ftp> bye

cat flag.txt
```

`get flag.txt` descarga el fichero a la máquina atacante y `cat` muestra su contenido:

```text
035db21c881520061c53e0536e44f815
```

> Evidencia: [`loot/flag.txt`](loot/flag.txt)

## Escalada de privilegios

No fue necesaria. El objetivo de la máquina (obtener la flag) se cumple con el acceso anónimo inicial, sin obtener una shell en el sistema. Por ello no hay vector de escalada que documentar.

---

## Flags

| Flag       | Valor                              |
| ---------- | ---------------------------------- |
| `flag.txt` | `035db21c881520061c53e0536e44f815` |

> Fawn pertenece a Starting Point: solo existe una flag, obtenida directamente por FTP (no hay `user.txt` / `root.txt`). Evidencia: [`loot/flag.txt`](loot/flag.txt).

## Vulnerabilidades identificadas

| # | Vulnerabilidad                         | Severidad | CVSS | Componente         | Mitigación                                                    |
| - | -------------------------------------- | --------- | ---- | ------------------ | ------------------------------------------------------------- |
| 1 | Acceso FTP anónimo habilitado          | Alta      | N/A  | vsftpd (21/tcp)    | Deshabilitar `anonymous_enable` en `vsftpd.conf`.             |
| 2 | Tráfico FTP sin cifrar                 | Media     | N/A  | vsftpd (21/tcp)    | Usar FTPS/SFTP.                                               |
| 3 | vsftpd 3.0.3 vulnerable a DoS (CVE-2021-30047) | Baja | N/A | vsftpd 3.0.3 | Actualizar a una versión corregida.                           |

> Severidad: Crítica / Alta / Media / Baja / Informativa. Los valores CVSS no se calcularon para los hallazgos de configuración.

## Recomendaciones de mitigación

- [ ] Deshabilitar el acceso anónimo (`anonymous_enable=NO`) salvo necesidad justificada.
- [ ] Si el FTP debe ser público, limitarlo a solo lectura y a un directorio sin información sensible.
- [ ] Sustituir FTP por SFTP o FTPS para cifrar las credenciales y los datos.
- [ ] Mantener el software y los servicios actualizados.
- [ ] Restringir el acceso al puerto 21 mediante firewall a las IP necesarias.
- [ ] No dejar ficheros sensibles ni credenciales en directorios accesibles.

## Lecciones aprendidas

- Probar siempre el login `anonymous` cuando hay un FTP expuesto; nmap con `-sC` lo detecta automáticamente (`ftp-anon`).
- Una configuración insegura puede ser más grave que una versión vulnerable: aquí el CVE existente no servía y el fallo real era de configuración.
- El TTL de un `ping` da una pista rápida del sistema operativo (64 ≈ Linux, 128 ≈ Windows).
- Escanear primero todos los puertos y luego profundizar solo en los abiertos ahorra tiempo.

## Herramientas utilizadas

| Herramienta | Uso                                      |
| ----------- | ---------------------------------------- |
| ping        | Test de conectividad y estimación del SO |
| nmap        | Escaneo de puertos, versiones y scripts  |
| ftp         | Conexión al servicio y descarga de la flag |

## Evidencia

Todos los artefactos están en la carpeta [`loot/`](loot/):

| Fichero                                | Contenido                                                      |
| -------------------------------------- | -------------------------------------------------------------- |
| [`ping.txt`](loot/ping.txt)            | Test de conectividad (TTL 63).                                 |
| [`puertos.txt`](loot/puertos.txt)      | Escaneo completo de puertos (solo 21/tcp abierto).             |
| [`detallado.txt`](loot/detallado.txt)  | Detección de versión y scripts (vsftpd 3.0.3, ftp-anon).       |
| [`flag.txt`](loot/flag.txt)            | Flag descargada por FTP.                                       |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Fawn)
- [CVE-2021-30047](https://www.cve.org/CVERecord?id=CVE-2021-30047)
- [vsftpd – sitio oficial](https://security.appspot.com/vsftpd.html)
