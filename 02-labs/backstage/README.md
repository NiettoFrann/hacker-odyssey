<div align="center">

# 🎭 Backstage

**Lab personal · Linux · Dificultad: Fácil**

Enumeración de config web → `.htpasswd` filtrado → crackeo offline → SSH → escalada a root

</div>

---

## 🎯 Qué vas a practicar

Una cadena de tres eslabones, cada uno depende del anterior (sin adivinanzas):

| # | Concepto | Técnica |
|:-:|:---------|:--------|
| 1 | **Enumeración de config web** | Directorio protegido con *Basic Auth* + respaldo de `.htpasswd` filtrado |
| 2 | **Crackeo offline** | Identificar formato de hash/clave y romperlo con `john` + `rockyou.txt` |
| 3 | **Movimiento lateral + escalada** | Login por SSH con la credencial obtenida → `root` por `sudo` mal configurado |

Todo imita malas configuraciones reales de producción (respaldos olvidados en el *webroot*,
listado de directorio activo, una clave privada guardada donde no debía, `sudo` demasiado permisivo).

---

## 🚀 Despliegue

Requiere **Docker** con el plugin `compose`.

```bash
cd 02-labs/backstage

# Levantar el lab
docker compose up -d --build

# Ver que está arriba
docker ps --filter name=backstage
```

### Punto de partida

| Servicio | Acceso |
|:---------|:-------|
| 🌐 HTTP | `http://127.0.0.1:8080` |
| 🔑 SSH  | `ssh ... -p 2222 usuario@127.0.0.1` |

> Empezá por el **puerto 8080**. El SSH (2222) no te sirve hasta tener una credencial.

Si preferís tratarlo como una IP "de verdad" (estilo HTB) en vez de `localhost:puerto`:

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backstage
# usá esa IP con los puertos reales 80 y 22
```

### Resetear

El lab es *stateless*: cualquier cambio que hagas dentro se borra al recrearlo.

```bash
docker compose down            # apagar
docker compose up -d --build   # recrear desde cero (resetea flags, archivos, etc.)
```

### Destruir del todo

```bash
docker compose down --rmi local   # apaga y borra la imagen
```

---

## 🏴 Flags

- `user.txt` → en el home del usuario, tras el acceso inicial por SSH.
- `root.txt` → en `/root`, tras la escalada.

---

## 🚫 Archivos que NO debés abrir (spoilers)

Para no arruinarte el reto, **no abras**:

- `Dockerfile` — contiene toda la construcción y las credenciales en claro.
- `setup/` — entrypoint, config de Apache, flags y `authorized_keys`.
- La sección **Walkthrough** de [`guia.md`](guia.md) (está colapsada a propósito).

Podés abrir libremente **este `README.md`** y las **pistas por etapa** de `guia.md`
(también colapsadas: abrí solo la que necesites).

> El contenido dentro de `web/` es, justamente, lo que tenés que descubrir enumerando
> por HTTP. Enuméralo con tus herramientas en vez de leerlo del disco: así practicás de verdad.

---

## 📖 ¿Querés repasar la teoría primero?

Leé **[`../teoria.md`](../teoria.md)**: explica en detalle (con ejemplos) cada concepto de
esta cadena —enumeración web, Basic Auth / `.htpasswd`, crackeo con `john`/`hashcat`, SSH y
escalada— sin spoilear la solución.

## 🆘 ¿Trabado?

Abrí [`guia.md`](guia.md). Cada etapa tiene tres niveles de pista
(empujón conceptual → técnica → comando exacto) dentro de bloques colapsables.
