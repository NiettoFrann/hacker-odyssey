<div align="center">

# 🏭 Foundry

**Lab personal · Linux · Dificultad: Fácil**

Enumeración web (nginx) → `.zip` publicado con listado de directorio → crackeo de la contraseña del ZIP → clave SSH adentro → escalada a root por **capabilities**

</div>

---

## 🎯 Qué vas a practicar

Una cadena de tres eslabones, cada uno depende del anterior (sin adivinanzas):

| # | Concepto | Técnica |
|:-:|:---------|:--------|
| 1 | **Enumeración web** | `robots.txt` que delata una ruta + directorio con *autoindex* activo |
| 2 | **Crackeo offline** | Un `.zip` protegido con contraseña débil → `zip2john` + `rockyou.txt` |
| 3 | **Acceso + escalada** | Clave SSH **sin passphrase** dentro del ZIP → `root` por una **capability** (`cap_setuid`) en el intérprete de Python |

> **Diferencia con [Backstage](../backstage/):** acá no hay *Basic Auth* ni hash APR1,
> la clave SSH **no** tiene passphrase, y la escalada **no** es por `sudo` sino por
> **capabilities** — un vector distinto que se descubre con `getcap`, no con `sudo -l`.

Todo imita malas configuraciones reales: un artefacto de CI publicado por error, una
contraseña de ZIP de diccionario, una clave privada viajando dentro de un backup y una
*capability* de más puesta sobre un binario que no la necesitaba.

---

## 🚀 Despliegue

Requiere **Docker** con el plugin `compose`.

```bash
cd 02-labs/foundry

# Levantar el lab
docker compose up -d --build

# Ver que está arriba
docker ps --filter name=foundry
```

### Punto de partida

| Servicio | Acceso |
|:---------|:-------|
| 🌐 HTTP | `http://127.0.0.1:8081` |
| 🔑 SSH  | `ssh ... -p 2223 usuario@127.0.0.1` |

> Empezá por el **puerto 8081**. El SSH (2223) no te sirve hasta tener la clave.

Si preferís tratarlo como una IP "de verdad" (estilo HTB) en vez de `localhost:puerto`:

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' foundry
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

- `Dockerfile` — contiene toda la construcción y las credenciales en claro.
- `setup/` — entrypoint, config de nginx y flags.
- La sección **Walkthrough** de [`guia.md`](guia.md) (está colapsada a propósito).

> El `.zip` de `web/artifacts/` lo genera el `Dockerfile` en tiempo de build: no está en el
> repo, tenés que descubrirlo y bajarlo enumerando por HTTP. Enuméralo con tus herramientas.

---

## 📖 Teoría

Repasá **[`../teoria.md`](../teoria.md)** para los fundamentos de enumeración web, crackeo
offline con `john`/`hashcat` y acceso por SSH. El vector de escalada de este lab
—**Linux capabilities**— lo tenés explicado paso a paso en la `guia.md`.

## 🆘 ¿Trabado?

Abrí [`guia.md`](guia.md). Cada etapa tiene tres niveles de pista
(empujón conceptual → técnica → comando exacto) dentro de bloques colapsables.
