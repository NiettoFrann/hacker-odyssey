#!/usr/bin/env bash
# new-machine.sh — arma la estructura de una máquina nueva
#
# Uso:
#   ./new-machine.sh <ruta-relativa-de-la-maquina> [OS] [dificultad] [IP]
#
# La ruta es relativa a la raíz del repo (el padre de utils/).
#
# Ejemplos (desde utils/):
#   ./new-machine.sh 00-starting-point/tier-0/00-meow Linux "Tier 0"
#   ./new-machine.sh 01-machines/01-easy/shocker Linux Easy 10.10.10.56
#
# Variables opcionales:
#   AUTHOR   nombre para el informe (por defecto: git config user.name)

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: $0 <ruta-relativa-de-la-maquina> [OS] [dificultad] [IP]"
  echo 'Ejemplo: ./new-machine.sh 01-machines/01-easy/shocker Linux Easy 10.10.10.56'
  exit 1
fi

MACHINE_PATH="${1%/}"
OS="${2:-Linux}"
DIFFICULTY="${3:-Easy}"
IP="${4:-10.10.10.XX}"
MACHINE_NAME="$(basename "$MACHINE_PATH")"

# Nombre "lindo" para el título: saca el prefijo numérico (00-, 01-...) y pone mayúscula inicial
DISPLAY_NAME="$(echo "$MACHINE_NAME" | sed -E 's/^[0-9]+-//')"
DISPLAY_NAME="${DISPLAY_NAME^}"
TODAY="$(date +%Y-%m-%d)"
OS_TAG="${OS,,}"
AUTHOR="${AUTHOR:-$(git config user.name 2>/dev/null || echo "")}"
AUTHOR="${AUTHOR:-N/A}"

# Este script vive en <repo>/utils; la raíz del repo es el directorio padre.
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$UTILS_DIR")"
TEMPLATE="$UTILS_DIR/_template/README.md"
TARGET_DIR="$REPO_ROOT/$MACHINE_PATH"
ASSETS_DIR="$REPO_ROOT/assets/images/screenshots/$MACHINE_NAME"

# Categoría según la ruta (starting-point / machines)
case "$MACHINE_PATH" in
  00-starting-point/*) CATEGORY="Starting Point" ;;
  01-machines/*)       CATEGORY="Machine" ;;
  *)                   CATEGORY="Machine" ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "No encuentro $TEMPLATE."
  exit 1
fi

if [ -f "$TARGET_DIR/README.md" ]; then
  echo "Ya existe $TARGET_DIR/README.md, no piso nada. Borralo a mano si querés rehacerlo."
  exit 1
fi

mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/loot" "$ASSETS_DIR"

# Ruta relativa de los screenshots, vista desde el README de la máquina
SCREENSHOTS_REL="$(realpath --relative-to="$TARGET_DIR" "$ASSETS_DIR")"

# Escapa \, & y | para usar el valor como reemplazo en sed (delimitador |)
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

sed -e "s|{{MACHINE}}|$(esc "$DISPLAY_NAME")|g" \
    -e "s|{{OS_TAG}}|$(esc "$OS_TAG")|g" \
    -e "s|{{OS}}|$(esc "$OS")|g" \
    -e "s|{{DIFFICULTY}}|$(esc "$DIFFICULTY")|g" \
    -e "s|{{IP}}|$(esc "$IP")|g" \
    -e "s|{{DATE}}|$TODAY|g" \
    -e "s|{{CATEGORY}}|$(esc "$CATEGORY")|g" \
    -e "s|{{AUTHOR}}|$(esc "$AUTHOR")|g" \
    -e "s|{{SCREENSHOTS}}|$(esc "$SCREENSHOTS_REL")|g" \
    "$TEMPLATE" > "$TARGET_DIR/README.md"

touch "$TARGET_DIR/scripts/.gitkeep"

echo "Listo: $TARGET_DIR"
echo "  - README.md generado desde el template"
echo "  - scripts/ y loot/ listos para usar"
echo "  - Screenshots: $ASSETS_DIR"
