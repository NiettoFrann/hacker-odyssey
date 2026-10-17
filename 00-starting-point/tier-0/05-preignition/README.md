---
title: Preignition
os: Linux
dificultad: Very Easy
ip: 10.129.58.34
fecha: 2026-10-17
categoria: Starting Point
estado: completada
tags: [htb, linux, nginx, default-credentials, broken-access-control]
---

# Preignition — Informe de Pentest

> Writeup de la máquina **Preignition** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                   | Detalle        |
| ----------------------- | -------------- |
| **Máquina**             | Preignition    |
| **Sistema operativo**   | Linux          |
| **Dificultad**          | Very Easy      |
| **Categoría**           | Starting Point |
| **Dirección IP**        | `10.129.58.34` |
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

La máquina `Preignition` se comprometió a través de un panel de administración web protegido con **credenciales por defecto**.

- El único puerto abierto es el **80/tcp (HTTP)**, con un servidor `nginx 1.14.2` sirviendo la página por defecto.
- La enumeración de directorios con `gobuster` reveló un panel `admin.php` no enlazado desde la web principal.
- El panel aceptó las credenciales triviales/por defecto `admin:admin`, lo que permitió el acceso sin necesidad de explotar ninguna vulnerabilidad de software, y mostró la flag directamente en la página.

**Impacto:** cualquier persona que descubra la ruta `/admin.php` puede iniciar sesión con credenciales triviales y acceder al panel de administración de la aplicación.

## Alcance y metodología

- **Objetivo:** `10.129.58.34` (Preignition)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (TTL 63 → Linux) -> Escaneo de 65535 puertos (solo 80/tcp) -> Escaneo detallado (nginx 1.14.2)
  -> Fuzzing de directorios (gobuster) -> Descubrimiento de /admin.php -> Login con credenciales por defecto (admin:admin)
  -> Acceso al panel -> Flag visible en la página
```

---

## Reconocimiento

### Conectividad y sistema operativo

Se comprobó que el host responde y se infirió el sistema operativo a partir del TTL.

```bash
ping -c 1 10.129.58.34 | tee loot/ping.txt
```

```text
PING 10.129.58.34 (10.129.58.34) 56(84) bytes of data.
64 bytes from 10.129.58.34: icmp_seq=1 ttl=63 time=238 ms

--- 10.129.58.34 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 238.202/238.202/238.202/0.000 ms
```

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

| Dato     | Valor   | Interpretación                                                                                          |
| -------- | ------- | --------------------------------------------------------------------------------------------------------- |
| Latencia | ~238 ms | Host activo, alcanzable por la VPN.                                                                       |
| TTL      | `63`    | Los sistemas Linux/Unix parten de TTL 64; el valor 63 indica un salto intermedio (VPN). Sistema **Linux**. |

### Escaneo de puertos

Primero se escanearon **todos los puertos TCP** de forma rápida para descubrir la superficie de ataque:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.58.34 -oN loot/puertos.txt
```

```text
Nmap scan report for 10.129.58.34
Host is up (0.24s latency).
Not shown: 65534 closed tcp ports (conn-refused)
PORT   STATE SERVICE
80/tcp open  http
```

> Evidencia: [`loot/puertos.txt`](loot/puertos.txt)

| Opción            | Motivo                                                   |
| ------------------ | ----------------------------------------------------------- |
| `-p-`              | Todos los puertos (1-65535).                                |
| `--min-rate=5000`  | Envía al menos 5000 paquetes/s para acelerar el escaneo.    |
| `-T4`              | Plantilla de tiempos agresiva.                              |
| `-Pn`              | Omite el descubrimiento de host (se asume activo).         |
| `-n`               | Sin resolución DNS.                                         |
| `-oN`              | Guarda la salida en formato normal.                          |

**Resultado:** 65534 puertos cerrados y un único puerto abierto.

| Puerto | Estado | Servicio |
| ------ | ------ | -------- |
| 80/tcp | open   | http     |

Sobre el puerto descubierto se lanzó un escaneo de **detección de versiones y scripts por defecto**:

```bash
nmap -p80 -sCV -Pn -n -T4 10.129.58.34 -oN loot/detallado.txt
```

```text
PORT   STATE SERVICE VERSION
80/tcp open  http    nginx 1.14.2
|_http-title: Welcome to nginx!
|_http-server-header: nginx/1.14.2
```

> Evidencia: [`loot/detallado.txt`](loot/detallado.txt)

| Opción | Motivo                                               |
| ------ | ------------------------------------------------------ |
| `-p80` | Limita el escaneo al puerto encontrado.                 |
| `-sC`  | Ejecuta los scripts NSE por defecto.                    |
| `-sV`  | Detecta la versión del servicio.                        |

**Resultado:**

| Puerto | Estado | Servicio | Versión        |
| ------ | ------ | -------- | --------------- |
| 80/tcp | open   | http     | `nginx 1.14.2`  |

La página por defecto (`Welcome to nginx!`) indica que la instalación de nginx no fue personalizada a nivel de página de inicio, pero no descarta contenido adicional alojado en otras rutas.

## Enumeración

### HTTP (80/tcp) — Fuzzing de directorios

Dado que la raíz web no mostraba más que la página por defecto de nginx, se buscaron rutas y ficheros ocultos con `gobuster`, incluyendo la extensión `.php` por tratarse de una posible aplicación PHP:

```bash
gobuster dir -u http://10.129.58.34 \
  -w /usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt \
  -x php -t 200
```

```text
admin.php            (Status: 200) [Size: 999]
```

> Evidencia: [`loot/gobuster.txt`](loot/gobuster.txt)

| Opción | Motivo                                                        |
| ------ | --------------------------------------------------------------- |
| `-u`   | URL objetivo.                                                   |
| `-w`   | Wordlist de directorios/ficheros comunes (DirBuster medium).    |
| `-x php` | Añade la extensión `.php` a cada palabra del diccionario.      |
| `-t 200` | 200 hilos concurrentes para acelerar el escaneo.               |

**Resultado:** se descubrió `/admin.php`, devolviendo un código `200` (página accesible), no enlazado desde ningún sitio visible de la aplicación.

Al visitar `http://10.129.58.34/admin.php` en el navegador se encontró un formulario de **inicio de sesión de administrador**.

## Explotación (Foothold)

- **Vulnerabilidad:** panel de administración protegido con **credenciales por defecto / triviales** (`admin:admin`).
- **Referencia:** [CWE-521 – Weak Password Requirements](https://cwe.mitre.org/data/definitions/521.html) / [CWE-284 – Improper Access Control](https://cwe.mitre.org/data/definitions/284.html).
- **Impacto:** acceso al panel de administración de la aplicación sin necesidad de explotar ningún fallo de software.

### Procedimiento

1. Se navegó a `http://10.129.58.34/admin.php`.
2. Se probaron credenciales triviales/por defecto en el formulario de login: usuario `admin`, contraseña `admin`.
3. El login fue aceptado y el panel mostró la flag directamente en la página resultante.

```text
Usuario:    admin
Contraseña: admin
```

No fue necesario inyectar código ni explotar una vulnerabilidad de la aplicación: el propio desarrollador dejó credenciales de administrador triviales en producción.

## Escalada de privilegios

No fue necesaria. El objetivo de la máquina (obtener la flag) se cumple con el acceso al panel `admin.php` mediante credenciales por defecto, sin llegar a obtener una shell en el sistema. Por ello no hay vector de escalada que documentar.

---

## Flags

| Flag     | Valor                              |
| -------- | ----------------------------------- |
| `flag`   | `6483bee07c1c1d57f14e5b0717503c73` |

> Preignition pertenece a Starting Point: solo existe una flag, obtenida directamente desde el panel `admin.php` (no hay `user.txt` / `root.txt`). Evidencia: [`loot/flag.txt`](loot/flag.txt).

## Vulnerabilidades identificadas

| # | Vulnerabilidad                                   | Severidad | CVSS | Componente         | Mitigación                                                           |
| - | -------------------------------------------------- | --------- | ---- | -------------------- | ------------------------------------------------------------------------ |
| 1 | Credenciales de administrador por defecto/triviales | Crítica   | N/A  | Panel `admin.php`    | Forzar el cambio de credenciales por defecto y usar contraseñas robustas. |
| 2 | Panel de administración sin control de acceso adicional | Alta  | N/A  | Panel `admin.php`    | Restringir el acceso por IP/VPN y añadir autenticación multifactor.       |
| 3 | Exposición de rutas sensibles no enlazadas (security by obscurity) | Media | N/A | Servidor web (80/tcp) | No depender de la ocultación de rutas; proteger cada endpoint por autenticación real. |

> Severidad: Crítica / Alta / Media / Baja / Informativa. Los valores CVSS no se calcularon para los hallazgos de configuración.

## Recomendaciones de mitigación

- [ ] Eliminar o cambiar inmediatamente cualquier credencial por defecto (`admin:admin`) antes de pasar a producción.
- [ ] Exigir contraseñas robustas y políticas de bloqueo tras varios intentos fallidos de login.
- [ ] Restringir el acceso a paneles de administración mediante firewall, VPN o listas de IP permitidas.
- [ ] No confiar en que una ruta no esté enlazada para considerarla protegida (security by obscurity).
- [ ] Añadir autenticación multifactor en paneles administrativos.
- [ ] Mantener el software del servidor (nginx) y la aplicación actualizados.

## Lecciones aprendidas

- Cuando la raíz web no aporta información, un fuzzing de directorios/ficheros (`gobuster`, `feroxbuster`, `ffuf`) con diccionarios comunes suele revelar paneles ocultos.
- Probar siempre credenciales triviales o por defecto (`admin:admin`, `admin:password`, etc.) en cualquier formulario de login antes de buscar vulnerabilidades más complejas.
- El TTL de un `ping` da una pista rápida del sistema operativo (64 ≈ Linux, 128 ≈ Windows).
- Escanear primero todos los puertos y luego profundizar solo en los abiertos ahorra tiempo.

## Herramientas utilizadas

| Herramienta | Uso                                           |
| ----------- | ---------------------------------------------- |
| ping        | Test de conectividad y estimación del SO       |
| nmap        | Escaneo de puertos, versiones y scripts        |
| gobuster    | Fuzzing de directorios y ficheros web          |
| navegador   | Acceso al panel `admin.php` y login            |

## Evidencia

Todos los artefactos están en la carpeta [`loot/`](loot/):

| Fichero                                | Contenido                                                      |
| --------------------------------------- | ----------------------------------------------------------------- |
| [`ping.txt`](loot/ping.txt)            | Test de conectividad (TTL 63).                                    |
| [`puertos.txt`](loot/puertos.txt)      | Escaneo completo de puertos (solo 80/tcp abierto).                |
| [`detallado.txt`](loot/detallado.txt)  | Detección de versión (nginx 1.14.2).                               |
| [`gobuster.txt`](loot/gobuster.txt)    | Fuzzing de directorios: descubrimiento de `admin.php`.            |
| [`flag.txt`](loot/flag.txt)            | Flag obtenida desde el panel `admin.php` tras el login.           |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Preignition)
- [CWE-521 – Weak Password Requirements](https://cwe.mitre.org/data/definitions/521.html)
