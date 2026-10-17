---
title: {{MACHINE}}
os: {{OS}}
dificultad: {{DIFFICULTY}}
ip: {{IP}}
fecha: {{DATE}}
categoria: {{CATEGORY}}
estado: en-progreso
tags: [htb, {{OS_TAG}}]
---

# {{MACHINE}} — Informe de Pentest

> Writeup de la máquina **{{MACHINE}}** de [Hack The Box](https://www.hackthebox.com/). Documento con fines educativos, realizado en un entorno de laboratorio autorizado.

## Información general

| Campo                  | Detalle         |
| ---------------------- | --------------- |
| **Máquina**            | {{MACHINE}}     |
| **Sistema operativo**  | {{OS}}          |
| **Dificultad**         | {{DIFFICULTY}}  |
| **Categoría**          | {{CATEGORY}}    |
| **Dirección IP**       | `{{IP}}`        |
| **Fecha de resolución**| {{DATE}}        |
| **Autor del informe**  | {{AUTHOR}}      |
| **Estado**             | En progreso     |

## Índice

1. [Resumen ejecutivo](#resumen-ejecutivo)
2. [Alcance y metodología](#alcance-y-metodología)
3. [Cadena de ataque](#cadena-de-ataque)
4. [Reconocimiento](#reconocimiento)
5. [Enumeración](#enumeración)
6. [Explotación (Foothold)](#explotación-foothold)
7. [Escalada de privilegios](#escalada-de-privilegios)
8. [Flags](#flags)
9. [Vulnerabilidades identificadas](#vulnerabilidades-identificadas)
10. [Recomendaciones de mitigación](#recomendaciones-de-mitigación)
11. [Lecciones aprendidas](#lecciones-aprendidas)
12. [Herramientas utilizadas](#herramientas-utilizadas)
13. [Referencias](#referencias)

---

## Resumen ejecutivo

<!-- 3-5 líneas: qué es la máquina, qué se encontró, cómo se comprometió y nivel de impacto final. -->

## Alcance y metodología

- **Objetivo:** `{{IP}}` ({{MACHINE}})
- **Tipo de prueba:** caja negra, sin credenciales previas.
- **Metodología:** Reconocimiento → Enumeración → Explotación → Post-explotación / Escalada de privilegios → Documentación.
- **Entorno:** conexión a la VPN de HTB desde Linux.

## Cadena de ataque

<!-- Resumen en pasos de cómo se llegó de cero a root. -->

```text
Reconocimiento -> [hallazgo 1] -> [hallazgo 2] -> Foothold (usuario) -> [vector de escalada] -> Root
```

---

## Reconocimiento

### Escaneo de puertos

```bash
nmap -p- --min-rate 5000 -sS -n -Pn -oN scans/allports {{IP}}
nmap -p<PUERTOS> -sCV -oN scans/targeted {{IP}}
```

| Puerto | Estado | Servicio | Versión |
| ------ | ------ | -------- | ------- |
|        |        |          |         |

<!-- Salida relevante de nmap y análisis -->

![Escaneo nmap]({{SCREENSHOTS}}/nmap.png)

## Enumeración

### Servicio / puerto

<!-- Qué se enumeró, con qué herramienta y qué se encontró. -->

```bash

```

![Enumeración]({{SCREENSHOTS}}/enum.png)

## Explotación (Foothold)

- **Vulnerabilidad:**
- **Referencia (CVE / técnica):**
- **Impacto:**

### Procedimiento

```bash

```

![Foothold]({{SCREENSHOTS}}/foothold.png)

### Estabilización de la shell

```bash
script /dev/null -c bash
# Ctrl+Z
stty raw -echo; fg
reset xterm
export TERM=xterm SHELL=bash
```

## Escalada de privilegios

- **Vector:**
- **Referencia (CVE / técnica / GTFOBins):**
- **Impacto:**

### Enumeración local

```bash
id; sudo -l
find / -perm -4000 -type f 2>/dev/null
```

### Procedimiento

```bash

```

![Privesc]({{SCREENSHOTS}}/privesc.png)

---

## Flags

| Flag     | Valor                 |
| -------- | --------------------- |
| `user.txt` | `<redactada>`       |
| `root.txt` | `<redactada>`       |


## Vulnerabilidades identificadas

| # | Vulnerabilidad | Severidad | CVSS | Componente | Mitigación |
| - | -------------- | --------- | ---- | ---------- | ---------- |
| 1 |                |           |      |            |            |

> Severidad: Crítica / Alta / Media / Baja / Informativa.

## Recomendaciones de mitigación

- [ ] Mantener el software y los servicios actualizados.
- [ ] Aplicar el principio de mínimo privilegio.
- [ ] No reutilizar ni dejar credenciales en archivos accesibles.
- [ ]

## Lecciones aprendidas

-
-

## Herramientas utilizadas

| Herramienta | Uso                        |
| ----------- | -------------------------- |
| nmap        | Escaneo de puertos y servicios |
|             |                            |

## Referencias

- [Página de la máquina en HTB](https://app.hackthebox.com/machines/{{MACHINE}})
- [HackTricks](https://book.hacktricks.xyz/)
- [GTFOBins](https://gtfobins.github.io/)
-
