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

require_kirin930_surfaceflinger_lcd_wake() {
    local patch="$ANDROID_TOP/device/huawei/mozart/patches/mozart/frameworks/native/Surfaceflinger-wake-up-the-LCD-manually.patch"
    local local_patch="$PATCH_ROOT/patches/frameworks/native/surfaceflinger-powerdown-lcd-on-off.patch"

    if git -C "$ANDROID_TOP/frameworks/native" apply -R --check "$local_patch" >/dev/null 2>&1; then
        echo "ok: local patch already applied: SurfaceFlinger LCD powerdown workaround"
        return
    fi

    if [[ ! -f "$patch" ]]; then
        echo "error: missing kirin930-dev SurfaceFlinger LCD wake patch in device tree" >&2
        echo "expected: ${patch#$ANDROID_TOP/}" >&2
        exit 3
    fi

    require_patch_file_applied \
        "frameworks/native" \
        "$patch" \
        "kirin930-dev SurfaceFlinger LCD wake workaround"
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
require_kirin930_surfaceflinger_lcd_wake

# Device identity and bring-up defaults.
apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/release-user-source-boot-webview.patch"

# EMUI 3.1 GPU and IMG MSVDX codec recovery.
apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/restore-graphics-hal-properties.patch"

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/restore-img-omx-media-codecs.patch"

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/restore-huawei-media-flags.patch"

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/label-gpu-vdec-device-nodes.patch"

apply_once \
    "vendor/huawei/mozart" \
    "$PATCH_ROOT/patches/vendor/huawei/mozart/restore-emui31-gpu-omx-vendor-paths.patch"

BLOB_CACHE="$PATCH_ROOT/proprietary-blobs/huawei/mozart"
if [[ -d "$BLOB_CACHE" ]] && [[ -n "$(find "$BLOB_CACHE" -type f -print -quit)" ]]; then
    "$PATCH_ROOT/scripts/extract-proprietary-blobs.sh" "$ANDROID_TOP"
else
    echo "note: proprietary blob cache is absent"
    echo "      run scripts/extract-proprietary-blobs.sh with a stock /system extraction before building"
fi

# Core boot image and SELinux compatibility.
apply_once \
    "system/core" \
    "$PATCH_ROOT/patches/system/core/init-user-permissive-selinux.patch"

apply_once \
    "system/core" \
    "$PATCH_ROOT/patches/system/core/mkbootimg-uint32-tags-offset.patch"

# Framework/HAL compatibility shims.
apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/legacy-private-sensor-type-compat.patch"

apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/audio-null-master-volume-compat.patch"

apply_once \
    "frameworks/base" \
    "$PATCH_ROOT/patches/frameworks/base/packageinstaller-webview-compat.patch"

apply_once \
    "frameworks/av" \
    "$PATCH_ROOT/patches/frameworks/av/img-msvdx-decoder-framerate-compat.patch"

apply_once \
    "frameworks/native" \
    "$PATCH_ROOT/patches/frameworks/native/surfaceflinger-powerdown-lcd-on-off.patch"

# Opt-in display composition experiment. Disabled at runtime by default.
apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/hwc2onfbadapter-hisi-dss-overlay-fallback.patch"

echo "local mozart patches are applied"
