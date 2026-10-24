<div align="center">

# ☎️ Switchboard

**Lab personal · Linux · Dificultad: Fácil**

Enumeración web (Apache) → `.git/` expuesto en el webroot → credencial filtrada en el **historial** → SSH → escalada a root por **abuso del grupo `shadow`**

</div>

---

## 🎯 Qué vas a practicar

Una cadena de tres eslabones, cada uno depende del anterior (sin adivinanzas):

| # | Concepto | Técnica |
|:-:|:---------|:--------|
| 1 | **Enumeración web** | Carpeta `.git/` desplegada dentro del *webroot* (con listado activo) |
| 2 | **Arqueología de git** | Dump del repo y lectura del **historial**: un secreto "borrado" sigue vivo en un commit |
| 3 | **Acceso + escalada** | SSH con la credencial filtrada → `root` por pertenecer al **grupo `shadow`** (leer `/etc/shadow` → crackear el hash de root → `su`) |

> **Diferencia con [Backstage](../backstage/) y [Foundry](../foundry/):** el foothold no es un
> hash ni un ZIP, sino **git**: hay que recuperar un secreto del historial de commits. Y la
> escalada **no** es `sudo` ni *capabilities*, sino el **abuso de un grupo especial**
> (`shadow`), que te deja leer `/etc/shadow` y romper la contraseña de root offline.

Todo imita malas configuraciones reales: la carpeta `.git` subida a producción, un secreto
versionado y luego "quitado" (pero no del historial), reutilización de contraseñas y un
usuario de servicio metido en un grupo sensible que no le correspondía.

---

## 🚀 Despliegue

Requiere **Docker** con el plugin `compose`.

```bash
cd 02-labs/switchboard

# Levantar el lab
docker compose up -d --build

# Ver que está arriba
docker ps --filter name=switchboard
```

### Punto de partida

| Servicio | Acceso |
|:---------|:-------|
| 🌐 HTTP | `http://127.0.0.1:8082` |
| 🔑 SSH  | `ssh ... -p 2224 usuario@127.0.0.1` |

> Empezá por el **puerto 8082**. El SSH (2224) no te sirve hasta tener la credencial.

Si preferís tratarlo como una IP "de verdad" (estilo HTB) en vez de `localhost:puerto`:

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' switchboard
# usá esa IP con los puertos reales 80 y 22
```

### Resetear / destruir

El lab es *stateless*: todo cambio interno se borra al recrearlo.

```bash
docker compose down              # apagar / resetear
docker compose up -d --build     # recrear desde cero
docker compose down --rmi local  # apagar y borrar la imagen
```

---

## 🏴 Flags

- `user.txt` → en el home del usuario, tras el acceso inicial por SSH.
- `root.txt` → en `/root`, tras la escalada.

---

## 🚫 Archivos que NO debés abrir (spoilers)

Para no arruinarte el reto, **no abras**:

- `Dockerfile` — contiene toda la construcción, el secreto versionado y las credenciales.
- `setup/` — entrypoint, config de Apache y flags.
- La sección **Walkthrough** de [`guia.md`](guia.md) (está colapsada a propósito).

> El `.git/` que tenés que descubrir vive en el *webroot* y lo sirve el propio Apache:
> enuméralo y "dumpéalo" con tus herramientas en vez de leerlo del disco.

---

## 📖 Teoría

Repasá **[`../teoria.md`](../teoria.md)** para los fundamentos de enumeración web, crackeo
offline con `john`/`hashcat` y acceso por SSH. Los vectores propios de este lab —**dump de
`.git`** y **abuso del grupo `shadow`**— están explicados paso a paso en la `guia.md`.

## 🆘 ¿Trabado?

Abrí [`guia.md`](guia.md). Cada etapa tiene tres niveles de pista
(empujón conceptual → técnica → comando exacto) dentro de bloques colapsables.
