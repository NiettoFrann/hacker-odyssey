#!/usr/bin/env bash
# new-machine.sh — arma la estructura de una máquina nueva
#
# Uso:
#   ./new-machine.sh <ruta-relativa-de-la-maquina> [OS] [dificultad] [IP]
#
# La ruta es relativa a la raíz del repo (el padre de utils/) y se puede correr desde
# cualquier directorio. Si el nombre no trae prefijo NN-, se le asigna el siguiente libre.
#
# Ejemplos:
#   ./utils/new-machine.sh 00-starting-point/tier-1/appointment Linux "Very Easy"
#   ./utils/new-machine.sh 01-machines/01-easy/shocker Linux Easy 10.10.10.56
#
# Variables opcionales:
#   AUTHOR   nombre del autor (por defecto queda el del template)

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: $0 <ruta-relativa-de-la-maquina> [OS] [dificultad] [IP]"
  echo 'Ejemplo: ./utils/new-machine.sh 01-machines/01-easy/shocker Linux Easy 10.10.10.56'
  exit 1
fi

MACHINE_PATH="${1#./}"
MACHINE_PATH="${MACHINE_PATH%/}"
OS="${2:-Linux}"
DIFFICULTY="${3:-Easy}"
IP="${4:-10.10.11.XXX}"
TODAY="$(date +%Y-%m-%d)"
OS_TAG="${OS,,}"
DIFF_TAG="$(echo "${DIFFICULTY,,}" | tr ' ' '-')"
AUTHOR="${AUTHOR:-}"

# Este script vive en <repo>/utils; la raíz del repo es el directorio padre.
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$UTILS_DIR")"
TEMPLATE="$UTILS_DIR/_template/informe-maquina.md"

# Solo máquinas de HTB; los labs de 02-labs/ se arman a mano
if [[ ! "$MACHINE_PATH" =~ ^(00-starting-point/tier-[0-9]+|01-machines/[0-9]{2}-[a-z]+)/[^/]+$ ]]; then
  echo "Ruta inválida: $MACHINE_PATH"
  echo "Tiene que ser 00-starting-point/tier-N/<maquina> o 01-machines/NN-dificultad/<maquina>."
  exit 1
fi

PARENT_PATH="$(dirname "$MACHINE_PATH")"
MACHINE_NAME="$(basename "$MACHINE_PATH")"

# Sin prefijo numérico: reutiliza la carpeta NN-nombre si ya existe (Starting Point tiene
# placeholders) o le asigna el siguiente número libre de la categoría
if [[ ! "$MACHINE_NAME" =~ ^[0-9]+- ]]; then
  SIBLINGS="$(find "$REPO_ROOT/$PARENT_PATH" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || true)"
  EXISTING="$(echo "$SIBLINGS" | grep -E "^[0-9]+-${MACHINE_NAME}$" | head -1 || true)"
  if [ -n "$EXISTING" ]; then
    MACHINE_NAME="$EXISTING"
  else
    LAST_NN="$(echo "$SIBLINGS" | grep -oE '^[0-9]+' | sort -n | tail -1 || true)"
    NEXT_NN=0
    [ -n "$LAST_NN" ] && NEXT_NN=$((10#$LAST_NN + 1))
    MACHINE_NAME="$(printf '%02d' "$NEXT_NN")-$MACHINE_NAME"
  fi
fi

MACHINE_PATH="$PARENT_PATH/$MACHINE_NAME"
TARGET_DIR="$REPO_ROOT/$MACHINE_PATH"

# Nombre "lindo" para el título: saca el prefijo numérico (00-, 01-...), cambia -/_ por espacios
# y pone mayúscula inicial a cada palabra (04-nombre-prueba -> "Nombre Prueba")
DISPLAY_NAME="$(echo "$MACHINE_NAME" | sed -E 's/^[0-9]+-//; s/[-_]+/ /g')"
DISPLAY_NAME="$(echo "$DISPLAY_NAME" | sed -E 's/(^| )(.)/\1\u\2/g')"

if [ ! -f "$TEMPLATE" ]; then
  echo "No encuentro $TEMPLATE."
  exit 1
fi

if [ -f "$TARGET_DIR/README.md" ]; then
  echo "Ya existe $TARGET_DIR/README.md, no piso nada. Borralo a mano si querés rehacerlo."
  exit 1
fi

# Próximo número de informe: el mayor report_id HO-NNNN-00 del repo + 1
# (las máquinas usan README.md y los labs informe.md)
LAST_ID="$(grep -rhoE --include=README.md --include=informe.md '^report_id: HO-[0-9]{4}' "$REPO_ROOT" 2>/dev/null \
  | grep -oE '[0-9]{4}$' | sort -n | tail -1 || true)"
REPORT_NUM="$(printf '%04d' $((10#${LAST_ID:-0} + 1)))"

# Las imágenes del informe se referencian como ./img/ (relativo al README)
mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/loot" "$TARGET_DIR/img"

# Escapa \, & y | para usar el valor como reemplazo en sed (delimitador |)
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

# El template trae valores de ejemplo en lugar de {{placeholders}}:
# NombreMaquina, HO-NNNN, AAAA-MM-DD, 10.10.11.XXX y los datos de os/difficulty/tags.
sed -e "s|NombreMaquina|$(esc "$DISPLAY_NAME")|g" \
    -e "s|HO-NNNN|HO-$REPORT_NUM|g" \
    -e "s|ho-nnnn|ho-$REPORT_NUM|g" \
    -e "s|AAAA-MM-DD|$TODAY|g" \
    -e "s|10\.10\.11\.XXX|$(esc "$IP")|g" \
    -e "s|^os: .*|os: $(esc "$OS")|" \
    -e "s|^difficulty: .*|difficulty: $(esc "$DIFFICULTY")|" \
    -e "s|^tags: .*|tags: [htb, $(esc "$OS_TAG"), $(esc "$DIFF_TAG")]|" \
    ${AUTHOR:+-e "s|^author: .*|author: $(esc "$AUTHOR")|"} \
    ${AUTHOR:+-e "s|^\| \*\*Autor\*\* \| Francisco Nieto|\| **Autor** \| $(esc "$AUTHOR")|"} \
    "$TEMPLATE" > "$TARGET_DIR/README.md"

touch "$TARGET_DIR/scripts/.gitkeep" "$TARGET_DIR/img/.gitkeep"

echo "Listo: $TARGET_DIR"
echo "  - README.md generado desde el template (HO-$REPORT_NUM-00)"
echo "  - scripts/, loot/ e img/ listos para usar"
