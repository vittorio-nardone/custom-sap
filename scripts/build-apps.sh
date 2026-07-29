#!/usr/bin/env bash
#
# build-apps.sh — compile Otto apps (and optional Pascal examples)
#
# By default uses the current kernel/symbols.asm (latest ./generate-all.sh).
# Use --abi to compile against a saved kernel ABI snapshot for hardware that
# still runs an older kernel EEPROM image.
#
# Usage:
#   ./scripts/build-apps.sh
#   ./scripts/build-apps.sh --abi v1.2.101
#   ./scripts/build-apps.sh --abi v1.2.101 --pascal
#   ./scripts/build-apps.sh apps/helloworld.asm
#   ./scripts/build-apps.sh --abi v1.2.101 apps/helloworld.asm apps/prime.asm
#
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"
# shellcheck source=lib/kernel-abi.sh
source "${SCRIPTS_DIR}/lib/kernel-abi.sh"

cd "$REPO_ROOT"

KERNEL_ABI=""
BUILD_PASCAL=0
APP_FILES=()

usage() {
    cat <<'EOF'
Usage: ./scripts/build-apps.sh [options] [app.asm ...]

Options:
  --abi VERSION   Compile against kernel/abi/v<VERSION>/symbols.asm
  --pascal        Also compile pascal/examples/*.pas
  --list-abi      List saved kernel ABI versions
  -h, --help      Show this help

Output directories:
  Current symbols:  roms/apps/current/asm/  and  roms/apps/current/pascal/
  ABI target:       roms/apps/v<VERSION>/asm/  and  roms/apps/v<VERSION>/pascal/

Examples:
  ./scripts/build-apps.sh
  ./scripts/build-apps.sh --abi v1.2.101
  ./scripts/build-apps.sh --abi v1.2.101 apps/helloworld.asm
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --abi)
            shift
            KERNEL_ABI="${1:-}"
            if [ -z "$KERNEL_ABI" ]; then
                echo "ERROR: --abi requires a version (e.g. v1.2.101)" >&2
                exit 1
            fi
            shift
            ;;
        --pascal)
            BUILD_PASCAL=1
            shift
            ;;
        --list-abi)
            echo "Saved kernel ABIs:"
            otto_abi_list | sed 's/^/  /' || true
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *.asm)
            APP_FILES+=("$1")
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -n "$KERNEL_ABI" ] && ! otto_abi_exists "$KERNEL_ABI"; then
    echo "ERROR: kernel ABI '${KERNEL_ABI}' not found under kernel/abi/" >&2
    echo "       Saved ABIs: $(otto_abi_list | tr '\n' ' ')" >&2
    exit 1
fi

SYMBOLS_BACKUP=""
if [ -n "$KERNEL_ABI" ]; then
    SYMBOLS_BACKUP="$(otto_abi_apply_symbols "$KERNEL_ABI")"
    trap 'otto_abi_restore_symbols "$SYMBOLS_BACKUP"' EXIT
    echo "Using kernel ABI: v${KERNEL_ABI#v}"
fi

ASM_OUT="$(otto_abi_output_dir "$KERNEL_ABI")"
PASCAL_OUT="$(otto_abi_pascal_output_dir "$KERNEL_ABI")"
mkdir -p "$ASM_OUT" "$PASCAL_OUT"

if [ ${#APP_FILES[@]} -eq 0 ]; then
    for app in "${REPO_ROOT}/apps"/*.asm; do
        [ -e "$app" ] || continue
        [ "$(basename "$app")" = "istructions.asm" ] && continue
        APP_FILES+=("$app")
    done
fi

APP_COUNT=0
OT_COUNT=0
PASCAL_COUNT=0
for app in "${APP_FILES[@]}"; do
    if [ ! -f "$app" ]; then
        echo "ERROR: app not found: $app" >&2
        exit 1
    fi
    base="$(basename "$app" .asm)"
    if ! customasm "$app" -f binary -o "${ASM_OUT}/${base}.bin"; then
        echo "WARN: skipped ${base} (build failed for this kernel ABI)" >&2
        continue
    fi
    addr="$(awk '/@load-address/{print $3; exit}' "$app")"
    if [ -n "$addr" ]; then
        python3.11 "${SCRIPTS_DIR}/python/add_header.py" "${ASM_OUT}/${base}.bin" --address "$addr"
        OT_COUNT=$((OT_COUNT + 1))
    fi
    APP_COUNT=$((APP_COUNT + 1))
done

if [ "$BUILD_PASCAL" = "1" ]; then
    PASCAL_COUNT=0
    SYMBOLS_ARG=""
    if [ -n "$KERNEL_ABI" ]; then
        SYMBOLS_ARG="--symbols $(otto_abi_symbols_asm "$KERNEL_ABI")"
    fi
    for pas in "${REPO_ROOT}"/pascal/examples/*.pas; do
        [ -e "$pas" ] || continue
        base="$(basename "$pas" .pas)"
        # shellcheck disable=SC2086
        if ! python3.11 "${REPO_ROOT}/pascal_compiler.py" $SYMBOLS_ARG \
            "$pas" -o "${PASCAL_OUT}/${base}.bin"; then
            echo "WARN: skipped ${base} (pascal build failed for this kernel ABI)" >&2
            continue
        fi
        PASCAL_COUNT=$((PASCAL_COUNT + 1))
    done
fi

echo ""
if [ -n "$KERNEL_ABI" ]; then
    echo "=== Apps built for kernel ABI v${KERNEL_ABI#v} ==="
else
    echo "=== Apps built (current kernel symbols) ==="
fi
echo "  Assembly: ${APP_COUNT} compiled (${OT_COUNT} with OT header) -> ${ASM_OUT}/"
if [ "$BUILD_PASCAL" = "1" ]; then
    echo "  Pascal:   ${PASCAL_COUNT} compiled -> ${PASCAL_OUT}/"
fi

SUMMARY_FILE="${REPO_ROOT}/.otto-build-apps.summary"
cat > "$SUMMARY_FILE" <<EOF
APP_COUNT=${APP_COUNT}
OT_COUNT=${OT_COUNT}
PASCAL_COUNT=${PASCAL_COUNT}
BUILD_PASCAL=${BUILD_PASCAL}
ASM_OUT=${ASM_OUT}
PASCAL_OUT=${PASCAL_OUT}
EOF

python3.11 "${SCRIPTS_DIR}/python/update_app_catalog.py" 2>/dev/null || true
