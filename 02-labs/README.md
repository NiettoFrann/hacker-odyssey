<div align="center">

# 🧪 Labs — Máquinas de práctica propias

*Máquinas vulnerables que construyo yo mismo, estilo Hack The Box, para correr en local con Docker.*

</div>

---

A diferencia de `01-machines/` (informes sobre máquinas de HTB), esta carpeta contiene
**laboratorios autocontenidos**: cada uno trae su `Dockerfile`, su `docker-compose.yml` y una
guía de resolución por pistas progresivas. Se levantan en segundos y se resetean en uno.

## 📖 Antes de empezar

Si estás reforzando estos conceptos, leé primero **[`teoria.md`](teoria.md)**: una guía
detallada (con ejemplos) sobre enumeración web, Basic Auth / `.htpasswd`, crackeo offline con
`john`/`hashcat`, acceso por SSH y escalada de privilegios. Sin spoilers de las máquinas.

## Máquinas

| Lab | SO | Dificultad | Cadena | Escalada |
|:----|:--:|:----------:|:-------|:---------|
| [🎭 backstage](backstage/) | Linux | Fácil | enum config web → `.htpasswd` filtrado → crack `john` → SSH | `sudo` (GTFOBin `find`) |

## Uso general

```bash
cd backstage            # (o el lab que quieras)
docker compose up -d --build     # levantar
# ... resolver ...
docker compose down              # apagar / resetear
```

Cada lab documenta su **punto de partida**, **qué archivos no abrir** (para no spoilearte)
y una `guia.md` con pistas colapsables + walkthrough final.

## ⚠️ Aviso

Estos labs son **deliberadamente vulnerables**. Corrélos solo en tu entorno local y aislado
(Docker en tu máquina). No los expongas a Internet ni a redes donde no tengas control.
