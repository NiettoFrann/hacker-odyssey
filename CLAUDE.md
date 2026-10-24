# CLAUDE.md

Guía para trabajar en **hacker-odyssey**: portfolio de informes de pentest (Hack The Box
y labs propios con Docker). El contenido de los informes está en **español**; todo lo
relacionado con git (commits, ramas, tags, PRs) va en **inglés**.

## Estructura

```text
00-starting-point/tier-N/NN-maquina/   # Starting Point de HTB
01-machines/NN-dificultad/NN-maquina/  # Máquinas de HTB (01-easy, 02-medium, 03-hard, 04-insane)
02-labs/<lab>/                         # Labs propios: Dockerfile, docker-compose.yml, setup/, web/,
                                       # README.md, guia.md (pistas), informe.md, loot/ o resolucion/
assets/                                # SVG de branding, diagramas e íconos, capturas
utils/new-machine.sh                   # Genera la carpeta de una máquina nueva
utils/_template/informe-maquina.md     # Plantilla del informe
.claude/skills/informe-pentest/        # Skill que convierte evidencia en informe
.github/workflows/update-portfolio.yml # Redeploy del portfolio (Vercel)
```

Cada máquina sigue la forma `NN-slug/` con `README.md` (el informe), `loot/` (salidas de
herramientas, flags), `scripts/` (exploits) e `img/` (capturas, referenciadas como `./img/`).
`NN` es el siguiente número correlativo dentro de su carpeta.

## Crear una máquina nueva

```bash
./utils/new-machine.sh <ruta-relativa-a-la-raiz> [OS] [dificultad] [IP]
./utils/new-machine.sh 01-machines/01-easy/sau Linux "" 10.10.11.224   # -> 01-easy/07-sau, Easy
./utils/new-machine.sh 00-starting-point/tier-1/appointment            # -> reutiliza 00-appointment
AUTHOR="Otro Nombre" ./utils/new-machine.sh ...   # opcional, cambia el autor del template
```

- Funciona desde cualquier directorio; la ruta es relativa a la raíz del repo y tiene que
  ser `00-starting-point/tier-N/<maquina>` o `01-machines/NN-dificultad/<maquina>`.
- **Número de carpeta:** si el nombre no trae prefijo `NN-`, reutiliza la carpeta
  `NN-nombre` si ya existe (los placeholders de Starting Point) o asigna el siguiente libre.
- **Dificultad y tags:** sin 3er argumento (o con `""`), Starting Point queda `Very Easy` +
  tag `starting-point`; las máquinas toman la dificultad de su carpeta (`02-medium` → `Medium`).
- **ID `HO-NNNN`:** el mayor `report_id` del repo + 1, contando `README.md` e `informe.md`.
- Crea `README.md` desde la plantilla, y `scripts/`, `loot/` e `img/` con `.gitkeep`. No pisa
  un `README.md` existente. Al terminar muestra los próximos pasos (rama, skill, PR).
- Los tags del front matter quedan en `[htb, <os>, <dificultad>]`: sumar a mano los de la
  técnica (`xxe`, `cve-2019-16278`, `sudo`…) al redactar el informe.
- Los labs no tienen script: se arman a mano copiando la estructura de uno existente.

## Redactar un informe

Usar la skill **`informe-pentest`** (`.claude/skills/informe-pentest/SKILL.md`) a partir
de la evidencia de `loot/`, `scripts/` y notas. Reglas clave:

- **No inventar** IPs, versiones, flags, credenciales, CVEs ni comandos. Lo que falte va
  como `⚠️ PENDIENTE: <qué falta>`.
- Formato fijo de la plantilla: IDs `HO-NNNN-00` (informe) y `HO-NNNN-01`, `-02`… (hallazgos),
  CVSS v3.1 con vector completo, CWE, MITRE ATT&CK.
- Flags y credenciales **parcialmente censuradas** en el informe.
- Español neutro y profesional; resumen ejecutivo sin tecnicismos.

### Checklist después de publicar un informe

- [ ] Fila nueva en la tabla de **Informes** del `README.md` raíz con su `HO-XXXX`.
- [ ] Badges de informes/hallazgos y tabla de **Estadísticas** actualizados.
- [ ] `assets/diagrams/severidad.svg` (totales, barras, porcentajes).
- [ ] `assets/diagrams/roadmap.svg` (progreso de la categoría).
- [ ] En labs: fila en la tabla de `02-labs/README.md`.

## Flujo de trabajo con git

`main` está protegida por el ruleset **"Proteger main"** en GitHub: PR obligatorio,
conversaciones resueltas, historial lineal, merge solo **squash** o **rebase**, sin force
push ni borrado, sin bypass. Las ramas se borran solas al mergear.

**Nunca hacer push directo a `main`.** Siempre:

```bash
git switch main && git pull
git switch -c docs/valentine-report
# ... commits atómicos ...
git push -u origin docs/valentine-report
gh pr create --fill          # o con título/cuerpo explícitos
gh pr merge --squash         # tras revisar el diff en el PR
git switch main && git pull
```

### Ramas

`<type>/<short-kebab-description>`, en inglés, con los mismos tipos que los commits:
`docs/traverxec-report`, `feat/lab-switchboard`, `fix/bounty-hunter-date`,
`chore/update-new-machine-script`, `ci/portfolio-redeploy`.

### Commits

[Conventional Commits](https://www.conventionalcommits.org/), en **inglés**.

```text
<type>(<scope>): <subject>

[body opcional: el porqué del cambio, no el qué]
```

- **Atómicos:** un cambio lógico por commit. Que cada commit se entienda solo y deje el
  repo en un estado coherente. No mezclar, por ejemplo, el informe con el índice del README.
- **Subject:** modo imperativo (`add`, `fix`, `update`), minúscula inicial, sin punto final,
  máximo ~72 caracteres.
- **Scope:** en minúscula y kebab-case. El slug de la máquina o lab (`traverxec`,
  `bounty-hunter`, `switchboard`) o el área (`readme`, `assets`, `labs`, `utils`).
- Nunca commitear con mensajes genéricos (`update README`) ni restos como `--amend`.

| Tipo | Uso en este repo |
|------|------------------|
| `docs` | Informes, READMEs, guías, assets de documentación (SVG, capturas) |
| `feat` | Infraestructura o contenido vulnerable de un lab, funcionalidad nueva en `utils/` |
| `fix` | Corrección de datos, links o rutas rotas, bugs en scripts |
| `chore` | Artefactos de resolución, loot, mantenimiento sin impacto en el contenido |
| `ci` | Workflows de `.github/` |
| `refactor` | Reorganizar carpetas o scripts sin cambiar el resultado |
| `style` | Formato puro (alineación de tablas, espacios) |

Secuencias de referencia:

```text
# Máquina de HTB
chore(valentine): add recon and exploitation artifacts
docs(valentine): add penetration test report
docs(readme): index Valentine and bump counters
docs(assets): update severity chart and roadmap

# Lab propio
feat(foundry): add vulnerable lab infrastructure
feat(foundry): add vulnerable web content
docs(foundry): add lab README and progressive hints guide
chore(foundry): add resolution artifacts
docs(foundry): add penetration test report
docs(labs): add foundry to labs index
```

Breaking changes (reestructurar carpetas, cambiar el formato de la plantilla): `!` tras el
tipo/scope y un footer `BREAKING CHANGE: <descripción>`.

### Pull requests

- **Título:** en formato Conventional Commit, en inglés. Con squash se convierte en el
  mensaje del commit en `main`, así que tiene que valer como tal.
  Ej.: `docs(valentine): add Valentine penetration test report`.
- **Un PR = una unidad de trabajo** (una máquina, un lab, un ajuste del README). Dentro,
  varios commits atómicos.
- **Cuerpo** en inglés:

  ```markdown
  ## Summary
  What this PR does and why, in 1-3 sentences.

  ## Changes
  - Bullet list of the relevant changes.

  ## Checklist
  - [ ] Report follows the template and has no invented data
  - [ ] README index, stats and SVG diagrams updated (if a report was added)
  - [ ] No uncensored flags or credentials in the report
  ```

- Revisar el diff en GitHub antes de mergear y resolver todas las conversaciones.
- Merge con **squash** por defecto; **rebase** solo si los commits del PR merecen quedar
  separados en `main` (por ejemplo, la secuencia completa de un lab).

### Tags y releases

Tags **anotados** con [SemVer](https://semver.org/) `vMAJOR.MINOR.PATCH`, creados sobre
`main` después de mergear:

- **MAJOR:** reestructuración del repo o cambio incompatible del formato de informe.
- **MINOR:** informe(s) o lab(s) nuevos.
- **PATCH:** correcciones (datos, links, typos, assets).

```bash
git switch main && git pull
git tag -a v1.4.0 -m "Add Valentine report"
git push origin v1.4.0
gh release create v1.4.0 --generate-notes   # opcional
```

El mensaje del tag va en inglés, en imperativo y breve.

## CI

`update-portfolio.yml` dispara el deploy hook de Vercel (`PORTFOLIO_DEPLOY_HOOK`) en cada
push a `main` que toque un `README.md` o `informe.md`. Mergear un PR cuenta como push a
`main`, así que no hay que hacer nada extra.

## Qué no commitear

Ver `.gitignore`: `.env`, claves (`*.key`, `*.pem`), `*.ovpn`, capturas de red (`*.pcap`),
comprimidos y salidas crudas de nmap (`*.nmap`, `*.gnmap`, `scans/`). Las salidas útiles van
como `.txt` en `loot/`.
