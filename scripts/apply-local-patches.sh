#!/usr/bin/env bash
set -euo pipefail

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_TOP="${1:-/android/lineage16-mozart}"

if [[ ! -d "$ANDROID_TOP/.repo" ]]; then
    echo "error: $ANDROID_TOP does not look like an Android repo checkout" >&2
    exit 2
fi

require_patch_file_applied() {
    local repo="$1"
    local patch="$2"
    local label="$3"

    if git -C "$ANDROID_TOP/$repo" apply -R --check "$patch" >/dev/null 2>&1; then
        echo "ok: upstream patch already applied: $label"
        return
    fi

    echo "error: upstream patch is not applied: $label" >&2
    echo "run device/huawei/mozart/patches/install.sh before local patches" >&2
    exit 3
}

require_kirin930_hwbitmap() {
    local patch="$ANDROID_TOP/device/huawei/mozart/patches/mozart/frameworks/base/Hardware-bitmaps-support-workaround.patch"

    if [[ ! -f "$patch" ]]; then
        echo "error: missing kirin930-dev hardware bitmap patch in device tree" >&2
        echo "expected: ${patch#$ANDROID_TOP/}" >&2
        exit 3
    fi

    require_patch_file_applied \
        "frameworks/base" \
        "$patch" \
        "kirin930-dev Hardware bitmaps support workaround"
}

apply_once() {
    local repo="$1"
    local patch="$2"

    if git -C "$ANDROID_TOP/$repo" apply -R --check "$patch" >/dev/null 2>&1; then
        echo "skip: already applied: $repo/${patch#$PATCH_ROOT/}"
        return
    fi

    echo "apply: $repo/${patch#$PATCH_ROOT/}"
    git -C "$ANDROID_TOP/$repo" apply --check "$patch"
    git -C "$ANDROID_TOP/$repo" apply "$patch"
}

require_kirin930_hwbitmap

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/release-user-source-boot-webview.patch"

apply_once \
    "system/core" \
    "$PATCH_ROOT/patches/system/core/init-user-permissive-selinux.patch"

apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/legacy-private-sensor-type-compat.patch"

apply_once \
    "frameworks/base" \
    "$PATCH_ROOT/patches/frameworks/base/packageinstaller-webview-compat.patch"

echo "local mozart patches are applied"
