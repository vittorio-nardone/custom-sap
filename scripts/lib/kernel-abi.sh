#!/usr/bin/env bash
# Shared helpers for kernel ABI snapshots (kernel/abi/<version>/).
#
# Apps link statically to kernel routine addresses from symbols.asm at compile
# time. Save a snapshot whenever you flash EEPROMs so apps can be rebuilt for
# hardware that still runs an older kernel.

otto_repo_root() {
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "${lib_dir}/../.." && pwd)"
}

otto_abi_root() {
    echo "$(otto_repo_root)/kernel/abi"
}

otto_abi_version_dir() {
    local version="$1"
    version="${version#v}"
    echo "$(otto_abi_root)/v${version}"
}

otto_kernel_version_from_asm() {
    local kernel_asm="${1:-$(otto_repo_root)/kernel/kernel.asm}"
    grep -E '^#const KERNEL_VERSION = ' "$kernel_asm" \
        | head -1 \
        | sed -E 's/.*"([^"]+)".*/\1/'
}

otto_kernel_build_date_from_asm() {
    local kernel_asm="${1:-$(otto_repo_root)/kernel/kernel.asm}"
    grep -E '^#const KERNEL_BUILDDATE = ' "$kernel_asm" \
        | head -1 \
        | sed -E 's/.*"([^"]+)".*/\1/'
}

otto_build_debug_from_symbols() {
    local symbols_txt="${1:-$(otto_repo_root)/symbols.txt}"
    if [ -f "$symbols_txt" ]; then
        awk -F' = ' '/^BUILD_DEBUG = / { print $2; exit }' "$symbols_txt"
    else
        grep -E '^#const BUILD_DEBUG = ' "$(otto_repo_root)/kernel/build_config.asm" \
            | head -1 \
            | awk '{ print $4 }'
    fi
}

otto_abi_manifest_path() {
    echo "$(otto_abi_version_dir "$1")/manifest.json"
}

otto_abi_symbols_asm() {
    echo "$(otto_abi_version_dir "$1")/symbols.asm"
}

otto_abi_exists() {
    [ -f "$(otto_abi_symbols_asm "$1")" ]
}

otto_abi_list() {
    local root
    root="$(otto_abi_root)"
    if [ ! -d "$root" ]; then
        return 0
    fi
    find "$root" -mindepth 1 -maxdepth 1 -type d -name 'v*' \
        | sed 's|.*/||' \
        | sort -V
}

otto_abi_update_catalog() {
    local repo catalog_py
    repo="$(otto_repo_root)"
    catalog_py="${repo}/scripts/python/update_app_catalog.py"
    if [ -f "$catalog_py" ]; then
        python3.11 "$catalog_py" || true
    fi
}

otto_abi_save() {
    local version="${1:-}"
    local force="${2:-0}"
    local repo symbols_txt symbols_asm kernel_rom dest

    repo="$(otto_repo_root)"
    symbols_txt="${repo}/symbols.txt"
    symbols_asm="${repo}/kernel/symbols.asm"
    kernel_rom="${repo}/roms/system/kernel-rom.bin"

    if [ -z "$version" ]; then
        version="$(otto_kernel_version_from_asm)"
    fi
    version="${version#v}"

    if [ -z "$version" ]; then
        echo "ERROR: could not determine KERNEL_VERSION from kernel/kernel.asm" >&2
        return 1
    fi

    if [ ! -f "$symbols_txt" ]; then
        echo "ERROR: ${symbols_txt} not found — run ./generate-all.sh first" >&2
        return 1
    fi

    if [ ! -f "$symbols_asm" ]; then
        echo "ERROR: ${symbols_asm} not found — run ./generate-all.sh first" >&2
        return 1
    fi

    if [ ! -f "$kernel_rom" ]; then
        echo "ERROR: ${kernel_rom} not found — run ./generate-all.sh first" >&2
        return 1
    fi

    dest="$(otto_abi_version_dir "v${version}")"
    if [ -d "$dest" ] && [ "$force" != "1" ]; then
        echo "ERROR: ABI snapshot already exists: ${dest}" >&2
        echo "       Use --force to overwrite." >&2
        return 1
    fi

    mkdir -p "$dest"
    cp "$symbols_txt" "${dest}/symbols.txt"
    cp "$symbols_asm" "${dest}/symbols.asm"
    cp "$kernel_rom" "${dest}/kernel-rom.bin"

    local build_date git_commit saved_at rom_size build_debug
    build_date="$(otto_kernel_build_date_from_asm)"
    git_commit="$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown)"
    saved_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    rom_size="$(stat -f%z "$kernel_rom" 2>/dev/null || stat -c%s "$kernel_rom")"
    build_debug="$(otto_build_debug_from_symbols "$symbols_txt")"

    cat > "${dest}/manifest.json" <<EOF
{
  "kernel_version": "v${version}",
  "kernel_build_date": "${build_date}",
  "build_debug": ${build_debug},
  "git_commit": "${git_commit}",
  "saved_at": "${saved_at}",
  "rom_size": ${rom_size},
  "files": {
    "symbols_txt": "symbols.txt",
    "symbols_asm": "symbols.asm",
    "kernel_rom": "kernel-rom.bin"
  }
}
EOF

    echo "Saved kernel ABI v${version} -> ${dest}"
    otto_abi_update_catalog
}

# Swap kernel/symbols.asm for an ABI build. Prints backup path on stdout.
otto_abi_apply_symbols() {
    local version="$1"
    local repo symbols_file live backup

    repo="$(otto_repo_root)"
    symbols_file="$(otto_abi_symbols_asm "$version")"
    live="${repo}/kernel/symbols.asm"

    if [ ! -f "$symbols_file" ]; then
        echo "ERROR: ABI symbols not found: ${symbols_file}" >&2
        echo "       Available: $(otto_abi_list | tr '\n' ' ')" >&2
        return 1
    fi

    backup="$(mktemp "${TMPDIR:-/tmp}/otto-symbols.XXXXXX")"
    if [ -f "$live" ]; then
        cp "$live" "$backup"
    else
        : > "$backup"
    fi

    cp "$symbols_file" "$live"
    echo "$backup"
}

otto_abi_restore_symbols() {
    local backup="$1"
    local live
    live="$(otto_repo_root)/kernel/symbols.asm"

    if [ -z "$backup" ] || [ ! -f "$backup" ]; then
        return 0
    fi

    if [ -s "$backup" ]; then
        cp "$backup" "$live"
    fi
    rm -f "$backup"
}

otto_abi_apps_root() {
    local version="${1:-}"
    local repo
    repo="$(otto_repo_root)"
    if [ -n "$version" ]; then
        version="${version#v}"
        echo "${repo}/roms/apps/v${version}"
    else
        echo "${repo}/roms/apps/current"
    fi
}

otto_abi_output_dir() {
    echo "$(otto_abi_apps_root "$1")/asm"
}

otto_abi_pascal_output_dir() {
    echo "$(otto_abi_apps_root "$1")/pascal"
}
