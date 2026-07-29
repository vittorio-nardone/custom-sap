#!/usr/bin/env bash
#
# save-kernel-abi.sh — snapshot kernel symbols for a specific hardware target
#
# Saves symbols.txt, symbols.asm, kernel-rom.bin, and manifest.json under
# kernel/abi/v<KERNEL_VERSION>/ so apps can be rebuilt for EEPROMs that still
# run that kernel.
#
# Run after ./generate-all.sh (or when kernel/symbols.asm is up to date).
#
# Usage:
#   ./scripts/save-kernel-abi.sh              # use KERNEL_VERSION from kernel.asm
#   ./scripts/save-kernel-abi.sh v1.2.162     # explicit version label
#   ./scripts/save-kernel-abi.sh --force      # overwrite existing snapshot
#   ./scripts/save-kernel-abi.sh --list       # list saved ABIs
#
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kernel-abi.sh
source "${SCRIPTS_DIR}/lib/kernel-abi.sh"

FORCE=0
VERSION=""
ACTION="save"

usage() {
    cat <<'EOF'
Usage: ./scripts/save-kernel-abi.sh [options] [version]

Options:
  --force       Overwrite an existing kernel/abi/v<version>/ snapshot
  --list        List saved kernel ABI versions
  -h, --help    Show this help

Examples:
  ./scripts/save-kernel-abi.sh
  ./scripts/save-kernel-abi.sh v1.2.162
  ./scripts/save-kernel-abi.sh --force
  ./scripts/save-kernel-abi.sh --list
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --list)
            ACTION="list"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        v*|[0-9]*)
            VERSION="${1#v}"
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ "$ACTION" = "list" ]; then
    echo "Saved kernel ABIs:"
    otto_abi_list | sed 's/^/  /' || true
    exit 0
fi

if otto_abi_save "$VERSION" "$FORCE"; then
    saved="$(otto_abi_version_dir "${VERSION:-$(otto_kernel_version_from_asm)}")"
    echo ""
    echo "Build apps for this kernel with:"
    echo "  ./scripts/build-apps.sh --abi v$(basename "$saved" | sed 's/^v//')"
fi
