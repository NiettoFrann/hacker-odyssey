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

### Regla: actualizar el README principal después de cada informe

Un informe **no está terminado** hasta que el `README.md` raíz lo refleja. Después de crear
el informe de una máquina o lab, actualizar el README **sin esperar a que se pida**, en la
misma rama y el mismo PR que el informe, en commits propios:
`docs(readme): index <Machine> and bump counters` y `docs(assets): update severity chart and roadmap`.

Qué tocar en el `README.md` raíz:

1. **Tabla de su categoría** en *📚 Informes* (Starting Point → su Tier, *Machines — <Dificultad>*
   o *Labs propios*): fila nueva ordenada por ID con `HO-XXXX`, link al informe, badge de
   dificultad (mismo color que las filas vecinas), técnica clave como cadena con `→` y riesgo
   (= nivel de riesgo global del informe: 🔴 Crítico, 🟠 Alto, 🟡 Medio, 🔵 Bajo). Si es la
   primera máquina de una dificultad, crear la sección copiando la estructura de *Easy*.
2. **Badges del encabezado:** `informes-N` y `hallazgos-N`.
3. **Tabla de *Estadísticas*:** total de informes y hallazgos por severidad, sumando la
   tabla *1.3 Distribución de hallazgos* del informe nuevo.
4. ***Vulnerabilidades que más se repiten*:** agregar la máquina a los patrones que aplique.
5. ***Ruta de entrenamiento*:** estado de la categoría si cambia (pendiente → en curso…).
6. **SVG:** `assets/diagrams/severidad.svg` (totales, barras, porcentajes) y
   `assets/diagrams/roadmap.svg` (progreso de la categoría).
7. **Labs:** además, fila en la tabla de `02-labs/README.md`.

Antes de commitear, verificar que cuadren los números: el badge de informes = filas de las
tablas, el de hallazgos = suma de la tabla de estadísticas = total del SVG.

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
# tag + release si corresponde (ver "Tags y releases")
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

El repo se versiona como producto con [SemVer](https://semver.org/): tags **anotados**
`vMAJOR.MINOR.PATCH`, siempre sobre `main` **después de mergear** el PR, nunca sobre una rama.

| Bump | Cuándo | Ejemplo |
|------|--------|---------|
| **MAJOR** | Reestructuración de carpetas, cambio incompatible de la plantilla o de los IDs `HO-` | `v2.0.0` |
| **MINOR** | Informe o lab nuevo; funcionalidad nueva en `utils/` o en la skill | `v1.1.0` |
| **PATCH** | Correcciones de datos, links, typos, assets o formato | `v1.0.1` |

- Se crea un tag al mergear cada PR que cambie el contenido. Si se mergean varios PR seguidos,
  un solo tag con el bump más alto. Los cambios solo internos (`CLAUDE.md`, CI) no necesitan
  tag propio: entran en el siguiente.
- Cada tag lleva su **release** en GitHub, con las notas generadas a partir de los PR.
- Mensaje del tag y título de la release en inglés: `Add Sau report`, `v1.1.0 — Sau`.
- Los tags `v*` están protegidos por el ruleset **"Proteger tags de versión"**: no se pueden
  borrar ni mover. Si un tag sale mal, se corrige con un PATCH nuevo, nunca reetiquetando.
- Después de mergear un PR, Claude propone el bump que corresponde y crea el tag y la release
  si se le confirma.

```bash
git switch main && git pull
git describe --tags --abbrev=0                 # último tag
git tag -a v1.1.0 -m "Add Sau report"
git push origin v1.1.0
gh release create v1.1.0 --title "v1.1.0 — Sau" --generate-notes
```

Historial: `v1.0.0` es la línea base (17 informes, 3 labs y README rediseñado), creada sobre
el `main` del 2026-10-24, antes de adoptar este flujo.

## CI

`update-portfolio.yml` dispara el deploy hook de Vercel (`PORTFOLIO_DEPLOY_HOOK`) en cada
push a `main` que toque un `README.md` o `informe.md`. Mergear un PR cuenta como push a
`main`, así que no hay que hacer nada extra.

## Qué no commitear

Ver `.gitignore`: `.env`, claves (`*.key`, `*.pem`), `*.ovpn`, capturas de red (`*.pcap`),
comprimidos y salidas crudas de nmap (`*.nmap`, `*.gnmap`, `scans/`). Las salidas útiles van
como `.txt` en `loot/`.
