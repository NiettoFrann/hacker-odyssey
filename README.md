<div align="center">

# 🛡️ Hacker Odyssey

### Informes de pentest sobre Hack The Box

*Cada máquina documentada como una auditoría real: resumen ejecutivo, narrativa del ataque, hallazgos con severidad y remediación.*

<br>

![Hack The Box](https://img.shields.io/badge/Hack%20The%20Box-9FEF00?style=for-the-badge&logo=hackthebox&logoColor=black)
![Informes](https://img.shields.io/badge/informes-10-blue?style=for-the-badge)
![Hallazgos](https://img.shields.io/badge/hallazgos-24-red?style=for-the-badge)
![Idioma](https://img.shields.io/badge/idioma-espa%C3%B1ol-orange?style=for-the-badge)
![Markdown](https://img.shields.io/badge/formato-Markdown-lightgrey?style=for-the-badge&logo=markdown&logoColor=black)

<br>

[**Informes**](#-informes) ·
[**Estadísticas**](#-estadísticas) ·
[**Estructura**](#-estructura-del-repositorio) ·
[**Flujo de trabajo**](#-flujo-de-trabajo) ·
[**Aviso legal**](#%EF%B8%8F-aviso-legal)

</div>

---

## 🎯 Sobre el proyecto

Este repositorio es mi bitácora de práctica ofensiva en **Hack The Box**. No son *write-ups* de
"pegá este comando y listo": cada máquina se entrega como un **informe de prueba de penetración**
con el formato que recibiría un cliente.

| | |
|---|---|
| 🧾 **Formato profesional** | Resumen ejecutivo para no técnicos + detalle técnico para el equipo |
| 🔎 **Evidencia real** | Salidas de herramientas, capturas y *loot* guardados junto a cada informe |
| 🧮 **Hallazgos clasificados** | Severidad, CVSS y recomendación de mitigación por cada vulnerabilidad |
| 🗺️ **Narrativa del ataque** | Reconocimiento → acceso inicial → escalada, paso a paso |
| 🧱 **Estructura reproducible** | Plantilla única y script que arma cada máquina nueva |

---

## 📚 Informes

### 🟢 Starting Point — Tier 0

| ID | Máquina | Dificultad | Técnica clave | Riesgo |
|:--:|---------|:----------:|---------------|:------:|
| `HO-0001` | [Meow](00-starting-point/tier-0/00-meow/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | Telnet con credenciales por defecto | 🔴 Crítico |
| `HO-0002` | [Fawn](00-starting-point/tier-0/01-fawn/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | FTP con login anónimo | 🟠 Alto |
| `HO-0003` | [Redeemer](00-starting-point/tier-0/03-redeemer/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | Redis sin autenticación | 🔴 Crítico |
| `HO-0004` | [Preignition](00-starting-point/tier-0/05-preignition/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | Panel web con credenciales por defecto | 🔴 Crítico |
| `HO-0005` | [Mongod](00-starting-point/tier-0/06-mongod/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | MongoDB sin autenticación | 🔴 Crítico |
| `HO-0006` | [Synced](00-starting-point/tier-0/07-synced/README.md) | ![](https://img.shields.io/badge/Very%20Easy-brightgreen) | Rsync sin autenticación | 🟠 Alto |

### 🟡 Machines — Easy

| ID | Máquina | Dificultad | Técnica clave | Riesgo |
|:--:|---------|:----------:|---------------|:------:|
| `HO-0007` | [Cap](01-machines/01-easy/00-cap/README.md) | ![](https://img.shields.io/badge/Easy-yellowgreen) | IDOR → PCAP con credenciales FTP → *Linux capabilities* | 🔴 Crítico |
| `HO-0008` | [FriendZone](01-machines/01-easy/01-frienzone/README.md) | ![](https://img.shields.io/badge/Easy-yellowgreen) | Transferencia de zona DNS → SMB → LFI → *module hijacking* | 🔴 Crítico |
| `HO-0009` | [Inject](01-machines/01-easy/02-inject/README.md) | ![](https://img.shields.io/badge/Easy-yellowgreen) | LFI → Spring Cloud Function RCE → Ansible privesc | 🔴 Crítico |
| `HO-0010` | [Shocker](01-machines/01-easy/03-shocker/README.md) | ![](https://img.shields.io/badge/Easy-yellowgreen) | Shellshock en `cgi-bin` → `sudo` mal configurado | 🔴 Crítico |

> [!NOTE]
> Medium, Hard e Insane ya tienen su carpeta lista; se irán completando.
> Los Tiers 1 y 2 de Starting Point están creados y pendientes de documentar.

---

## 📊 Estadísticas

<div align="center">

| Informes | Hallazgos totales | 🔴 Críticos | 🟠 Altos | 🟡 Medios | 🔵 Bajos | ⚪ Informativos |
|:--------:|:-----------------:|:----------:|:-------:|:--------:|:-------:|:--------------:|
| **10** | **24** | **8** | **8** | **6** | **1** | **1** |

</div>

```mermaid
pie showData title Hallazgos por severidad
    "Crítica" : 8
    "Alta" : 8
    "Media" : 6
    "Baja" : 1
    "Informativa" : 1
```

<details>
<summary><b>🧩 Vulnerabilidades que más se repiten</b></summary>

<br>

| Patrón | Dónde aparece |
|--------|---------------|
| **Servicio expuesto sin autenticación** | Fawn, Redeemer, Mongod, Synced |
| **Credenciales por defecto o débiles** | Meow, Preignition |
| **Ejecución de código remoto (RCE)** | Inject, Shocker, FriendZone |
| **Escalada de privilegios por mala configuración** | Cap, Shocker, Inject, FriendZone |
| **Divulgación de información / LFI** | Cap, FriendZone, Inject |

</details>

---

## 🗂️ Estructura del repositorio

```text
hack-the-box/
├── 00-starting-point/        # Starting Point (Tier 0, 1 y 2)
│   └── tier-0/
│       └── 00-meow/
│           ├── README.md     # 📄 Informe completo
│           ├── loot/         # 🧰 Salidas de nmap, ping, flags, etc.
│           └── scripts/      # 🐍 Exploits y herramientas usadas
├── 01-machines/              # Máquinas por dificultad
│   ├── 01-easy/
│   ├── 02-medium/
│   ├── 03-hard/
│   └── 04-insane/
├── assets/
│   └── images/screenshots/   # 📸 Capturas referenciadas en los informes
├── utils/
│   ├── new-machine.sh        # ⚙️ Genera la estructura de una máquina nueva
│   └── _template/            # 📝 Plantilla del informe
└── .claude/skills/           # 🤖 Skill que convierte evidencia en informe
```

---

## 📝 Anatomía de un informe

Todos los informes comparten la misma estructura, con metadatos en *front matter* (ID, objetivo, OS, dificultad, etiquetas).

```mermaid
flowchart LR
    A[1. Resumen<br/>ejecutivo] --> B[2. Alcance y<br/>metodología]
    B --> C[3. Narrativa<br/>del ataque]
    C --> D[4. Hallazgos<br/>técnicos]
    D --> E[5. Post-<br/>explotación]
    E --> F[6. Conclusiones]
    F --> G[7. Anexos]
```

| Sección | Qué contiene |
|---------|--------------|
| **Resumen ejecutivo** | Resultado en lenguaje claro, nivel de riesgo global y distribución de hallazgos |
| **Alcance y metodología** | Objetivo, tipo de prueba (caja negra) y herramientas |
| **Narrativa del ataque** | Reconocimiento, acceso inicial y escalada con evidencia |
| **Hallazgos técnicos** | Descripción, impacto, CVSS y remediación de cada vulnerabilidad |
| **Post-explotación** | Estado final del sistema y cómo se obtuvo cada flag |
| **Conclusiones y anexos** | Recomendaciones generales, comandos y referencias |

---

## ⚙️ Flujo de trabajo

**1. Crear la estructura de una máquina nueva**

```bash
cd utils
./new-machine.sh 01-machines/01-easy/04-nombre Linux Easy 10.10.10.XX
```

Genera `README.md` desde la plantilla, junto con las carpetas `loot/` y `scripts/` y el directorio de capturas.

**2. Documentar la evidencia** en `loot/` y `scripts/` mientras se trabaja la máquina.

**3. Redactar el informe** con la skill `informe-pentest` de Claude Code, que convierte comandos, salidas y notas en un informe terminado y **no inventa datos**: lo que falta queda marcado como `⚠️ PENDIENTE`.

---

## 🧰 Herramientas habituales

![Nmap](https://img.shields.io/badge/Nmap-0E83CD?style=flat-square&logo=nmap&logoColor=white)
![Gobuster](https://img.shields.io/badge/Gobuster-333?style=flat-square)
![Burp Suite](https://img.shields.io/badge/Burp%20Suite-FF6633?style=flat-square&logo=burpsuite&logoColor=white)
![Wireshark](https://img.shields.io/badge/Wireshark-1679A7?style=flat-square&logo=wireshark&logoColor=white)
![pspy](https://img.shields.io/badge/pspy-444?style=flat-square)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)

---

## ⚠️ Aviso legal

> [!WARNING]
> Todo el contenido de este repositorio se produjo sobre **entornos de laboratorio autorizados**
> (Hack The Box) y, en el caso de las máquinas, sobre **máquinas retiradas**. Tiene fines
> **exclusivamente educativos**. Ninguna técnica aquí descrita debe aplicarse sobre sistemas
> sin autorización expresa y por escrito de su propietario.

---

<div align="center">

**Francisco Nieto** · [@NiettoFrann](https://github.com/NiettoFrann)

*Aprender atacando, para aprender a defender.* 🔐

</div>

