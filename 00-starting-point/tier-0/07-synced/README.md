---
report_id: HO-0006-00
target: Synced
platform: Hack The Box
os: Linux
difficulty: Very Easy
ip: 10.129.228.37
date: 2026-10-17
version: 1.0
author: Francisco Nieto
status: Final
tags: [htb, linux, very-easy, starting-point, rsync, unauthenticated-access]
---

# Informe de Prueba de Penetración — Synced

| | |
|---|---|
| **ID de informe** | HO-0006-00 |
| **Objetivo** | Synced (`10.129.228.37`) |
| **Plataforma** | Hack The Box — Starting Point (Tier 0) |
| **Tipo de prueba** | Caja negra (black box) |
| **Fecha de ejecución** | 2026-10-17 |
| **Autor** | Francisco Nieto — [@NiettoFrann](https://github.com/NiettoFrann) |
| **Versión** | 1.0 |
| **Clasificación** | Público — uso educativo |

> **Aviso legal.** Las pruebas se realizaron sobre un entorno de laboratorio autorizado
> (Hack The Box). Ninguna técnica descrita debe aplicarse sobre sistemas sin autorización
> expresa por escrito de su propietario.

### Control de versiones

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0 | 2026-10-17 | Versión inicial |

---

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Alcance y metodología](#2-alcance-y-metodología)
3. [Narrativa del ataque](#3-narrativa-del-ataque)
4. [Hallazgos técnicos](#4-hallazgos-técnicos)
5. [Post-explotación](#5-post-explotación)
6. [Conclusiones](#6-conclusiones)
7. [Anexos](#7-anexos)

---

## 1. Resumen ejecutivo

### 1.1 Objetivo

Evaluar la seguridad del host **Synced** simulando un atacante externo sin credenciales ni
conocimiento previo del entorno, con el fin de obtener el máximo nivel de acceso posible.

### 1.2 Resultado

> El servidor ofrece un servicio de sincronización de archivos que publica una carpeta
> compartida a la que cualquier persona con acceso a la red puede entrar sin usuario ni
> contraseña. Se listó su contenido y se descargó un archivo en menos de un minuto. No se
> probó si también permite escribir o borrar. Un atacante real podría leer todo lo que se
> guarde allí y, si hubiera escritura, alterar archivos en los que otros sistemas confían.

**Nivel de riesgo global:** `ALTO`

### 1.3 Distribución de hallazgos

| Crítica | Alta | Media | Baja | Informativa |
|:-------:|:----:|:-----:|:----:|:-----------:|
| 0 | 1 | 0 | 0 | 0 |

### 1.4 Resumen de hallazgos

| ID | Hallazgo | Severidad | CVSS |
|----|----------|-----------|------|
| [HO-0006-01](#ho-0006-01--módulo-rsync-public-accesible-sin-autenticación) | Módulo rsync `public` accesible sin autenticación | Alta | 7.5 |

### 1.5 Recomendaciones prioritarias

1. Exigir usuario y contraseña en el módulo (`auth users` y `secrets file`) y retirar el acceso anónimo.
2. Restringir el puerto 873/tcp con `hosts allow` y firewall a los equipos que realmente sincronizan.
3. Revisar los registros de conexión y el contenido del módulo para descartar accesos previos.

---

## 2. Alcance y metodología

### 2.1 Alcance

| Activo | Dirección | Incluido |
|--------|-----------|:--------:|
| Synced | `10.129.228.37` | Sí |

**Fuera de alcance:** ataques de denegación de servicio, infraestructura de la
plataforma y otros jugadores. No se modificó ni eliminó ningún dato en el objetivo.

### 2.2 Metodología

La prueba siguió las fases del estándar **PTES** (Penetration Testing Execution
Standard):

1. **Reconocimiento** — descubrimiento de puertos y servicios.
2. **Enumeración** — listado de módulos expuestos.
3. **Análisis de vulnerabilidades** — validación manual del control de acceso.
4. **Explotación** — obtención de acceso inicial.
5. **Post-explotación** — recolección de evidencia.
6. **Reporte** — documentación de hallazgos y recomendaciones.

### 2.3 Entorno del auditor

| Componente | Detalle |
|------------|---------|
| Sistema | Linux (kernel 7.2.11-zen1-1-zen) |
| Conexión | VPN de Hack The Box |
| Herramientas | ping, nmap 7.991, rsync |

### 2.4 Clasificación de severidad

Las vulnerabilidades se puntúan con **CVSS v3.1** (ver tabla de criterios estándar).

---

## 3. Narrativa del ataque

### 3.1 Cadena de compromiso

```mermaid
flowchart LR
    A["Reconocimiento<br/>873/tcp"] --> B["rsync ::<br/>módulo public"]
    B --> C["HO-0006-01<br/>Acceso anónimo"]
    C --> D["Descarga de<br/>flag.txt"]
```

Un único hallazgo, por lo que no hay encadenamiento entre fallos.

### 3.2 Reconocimiento

Verificación de conectividad:

```bash
ping -c 1 10.129.228.37 | tee loot/ping.txt
```

El TTL de respuesta es 63; los sistemas Linux parten de 64 y el valor restante indica un
salto intermedio (VPN), por lo que se infiere un sistema **Linux**.

Descubrimiento de puertos abiertos:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n 10.129.228.37 -oN loot/puertos.txt
```

Detección de servicios y versiones:

```bash
nmap -p873 -sCV -Pn -n -T4 10.129.228.37 -oN loot/detallado.txt
```

| Puerto | Servicio | Versión | Observaciones |
|--------|----------|---------|---------------|
| 873/tcp | rsync | protocolo 31 | Único puerto abierto. `nmap` solo identifica la versión del protocolo, no la del software. |

> Salida completa en el [Anexo A](#a-salida-completa-de-escaneos).

### 3.3 Enumeración

Se comprobó si el servicio expone módulos y si exigen autenticación:

```bash
rsync 10.129.228.37::
```

```text
public         	Anonymous Share
```

El servicio lista sus módulos sin pedir credenciales; existe uno llamado `public`.

```bash
rsync 10.129.228.37::public
```

```text
drwxr-xr-x          4,096 2022/10/24 19:02:23 .
-rw-r--r--             33 2022/10/24 18:32:03 flag.txt
```

### 3.4 Acceso inicial

Descarga de `flag.txt` desde el módulo anónimo. Ver
**[HO-0006-01](#ho-0006-01--módulo-rsync-public-accesible-sin-autenticación)**.

### 3.5 Movimiento lateral

No aplica.

### 3.6 Escalada de privilegios

No se realizó: el objetivo de la máquina se cumple con el acceso inicial, que no incluye
ejecución de comandos. No se probó la escritura en el módulo ni se buscó una vía hacia una
shell.

---

## 4. Hallazgos técnicos

### HO-0006-01 — Módulo rsync `public` accesible sin autenticación

| | |
|---|---|
| **Severidad** | Alta |
| **CVSS v3.1** | 7.5 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N` |
| **CWE** | [CWE-306](https://cwe.mitre.org/data/definitions/306.html) — Missing Authentication for Critical Function |
| **CVE** | — |
| **Componente afectado** | rsync (protocolo 31) — `10.129.228.37:873/tcp`, módulo `public` |
| **Estado** | Explotada (solo lectura) |

#### Descripción

El servicio rsync enumera sus módulos y permite descargar el contenido de `public` sin
pedir usuario ni contraseña. La causa raíz es una configuración insegura del demonio, no
un defecto del software.

**Justificación del vector:** acceso por red, sin autenticación ni interacción y pérdida
total de confidencialidad sobre el módulo. La puntuación solo incluye confidencialidad
porque no se probó escritura ni borrado; si el módulo permitiera escribir, la severidad
subiría a Crítica (9.8).

#### Prueba de concepto

**Paso 1.** Listado de módulos y de su contenido sin credenciales (ver sección 3.3).

**Paso 2.** Descarga del módulo y lectura de la flag.

```bash
mkdir -p loot/public && rsync -av rsync://10.129.228.37/public/ loot/public/
cat loot/public/flag.txt
```

```text
receiving incremental file list
./

sent 27 bytes  received 81 bytes  11.37 bytes/sec
total size is 33  speedup is 0.31
```

No se subió ni se modificó ningún archivo en el servidor.

#### Impacto

- **Confidencialidad:** lectura de todo el contenido del módulo.
- **Integridad / disponibilidad:** no verificadas. Un módulo con escritura permitiría
  subir o reemplazar archivos y, en ciertas configuraciones, avanzar hacia la ejecución
  de código (por ejemplo, subiendo claves SSH a un directorio personal). Es una
  posibilidad **no confirmada**.

#### Remediación

- **Corto plazo:** exigir autenticación en el módulo y retirar el acceso anónimo en
  `/etc/rsyncd.conf`:

  ```ini
  [public]
      path = /srv/public
      read only = yes
      auth users = backup
      secrets file = /etc/rsyncd.secrets   # chmod 600
  ```

- **Largo plazo:** restringir con `hosts allow` y firewall el puerto 873 a los equipos que
  sincronizan, no exponer rsync a redes no confiables (o sincronizar sobre SSH) y revisar
  el registro de rsync (`log file`) en busca de transferencias desde IP desconocidas.

#### Referencias

- [rsyncd.conf(5)](https://download.samba.org/pub/rsync/rsyncd.conf.5)
- [CWE-306 — Missing Authentication for Critical Function](https://cwe.mitre.org/data/definitions/306.html)
- [HackTricks — 873 rsync](https://book.hacktricks.xyz/network-services-pentesting/873-pentesting-rsync)

---

## 5. Post-explotación

### 5.1 Acceso obtenido

| Nivel | Usuario | Método | Prueba |
|-------|---------|--------|--------|
| Lectura rsync (sin shell) | anónimo | HO-0006-01 | `flag.txt` — `72eaf534************************` |

> Synced pertenece a Starting Point: solo existe una flag y no hay `user.txt` / `root.txt`.
> No se obtuvo shell en el sistema.

### 5.2 Información sensible expuesta

| Tipo | Ubicación | Observación |
|------|-----------|-------------|
| Archivo reservado | rsync `public` — `flag.txt` | Legible sin autenticación. |

> Las flags se muestran parcialmente censuradas.

### 5.3 Limpieza

| Artefacto | Ubicación | Estado |
|-----------|-----------|--------|
| `flag.txt` descargada | Equipo del auditor — `loot/public/`, `loot/flag.txt` | Conservada como evidencia. |

---

## 6. Conclusiones

### 6.1 Conclusión técnica

El servicio de sincronización publica un módulo sin autenticación. Es un error de
configuración y no de software: el número de versión es irrelevante si el acceso está
abierto. Se separó lo confirmado (lectura) de lo no probado (escritura) para sustentar la
severidad asignada.

### 6.2 Aprendizajes del auditor

- Reconocer el servicio por su puerto estándar (`873` → rsync).
- `rsync <IP>::` lista los módulos y es la primera comprobación de acceso anónimo; el
  módulo se descarga con `rsync -av rsync://<IP>/<módulo>/`.
- Distinguir lo confirmado de lo no probado permite defender la severidad.

---

## 7. Anexos

### A. Salida completa de escaneos

<details>
<summary>nmap — todos los puertos</summary>

```text
# Nmap 7.991 scan initiated Sat Oct 17 15:50:30 2026 as: nmap -p- --min-rate=5000 -T4 -Pn -n -oN puertos.txt 10.129.228.37
Nmap scan report for 10.129.228.37
Host is up (0.24s latency).
Not shown: 65534 closed tcp ports (conn-refused)
PORT    STATE SERVICE
873/tcp open  rsync

# Nmap done at Sat Oct 17 15:50:48 2026 -- 1 IP address (1 host up) scanned in 17.94 seconds
```

</details>

<details>
<summary>nmap — escaneo de servicios</summary>

```text
# Nmap 7.991 scan initiated Sat Oct 17 15:51:21 2026 as: nmap -p873 -sCV -Pn -n -T4 -oN detallado.txt 10.129.228.37
Nmap scan report for 10.129.228.37
Host is up (0.24s latency).

PORT    STATE SERVICE VERSION
873/tcp open  rsync   (protocol version 31)

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sat Oct 17 15:51:27 2026 -- 1 IP address (1 host up) scanned in 6.33 seconds
```

</details>

### B. Scripts y exploits

No se utilizaron scripts ni exploits.

### C. Mapeo MITRE ATT&CK

| Táctica | Técnica | ID |
|---------|---------|----|
| Discovery | Network Service Discovery | [T1046](https://attack.mitre.org/techniques/T1046/) |
| Collection | Data from Network Shared Drive | [T1039](https://attack.mitre.org/techniques/T1039/) |

### D. Referencias generales

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/Synced)
- [PTES — Penetration Testing Execution Standard](http://www.pentest-standard.org/)
- [Calculadora CVSS v3.1 — FIRST](https://www.first.org/cvss/calculator/3.1)
- [MITRE ATT&CK](https://attack.mitre.org/)
