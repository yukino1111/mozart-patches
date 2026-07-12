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

require_kirin930_patch() {
    local repo="$1"
    local patch_rel="$2"
    local label="$3"
    local patch="$ANDROID_TOP/device/huawei/mozart/patches/mozart/$patch_rel"

    if [[ ! -f "$patch" ]]; then
        echo "error: missing kirin930-dev patch in device tree: $label" >&2
        echo "expected: ${patch#$ANDROID_TOP/}" >&2
        exit 3
    fi

    require_patch_file_applied "$repo" "$patch" "$label"
}

require_kirin930_surfaceflinger_lcd_wake() {
    local local_patch="$PATCH_ROOT/patches/frameworks/native/surfaceflinger-powerdown-lcd-on-off.patch"

    if git -C "$ANDROID_TOP/frameworks/native" apply -R --check "$local_patch" >/dev/null 2>&1; then
        echo "ok: local patch already applied: SurfaceFlinger LCD powerdown workaround"
        return
    fi

    require_kirin930_patch \
        "frameworks/native" \
        "frameworks/native/Surfaceflinger-wake-up-the-LCD-manually.patch" \
        "kirin930-dev SurfaceFlinger LCD wake workaround"
}

require_kirin930_patches() {
    require_kirin930_patch \
        "build/make" \
        "build/make/Do-not-check-device-assert-signature.patch" \
        "kirin930-dev device assert signature workaround"

    require_kirin930_patch \
        "frameworks/base" \
        "frameworks/base/Hardware-bitmaps-support-workaround.patch" \
        "kirin930-dev hardware bitmap workaround"

    require_kirin930_surfaceflinger_lcd_wake

    require_kirin930_patch \
        "hardware/broadcom/wlan" \
        "hardware/broadcom/wlan/WifiHAL-Do-not-error-check-on-initialization.patch" \
        "kirin930-dev Broadcom Wi-Fi HAL initialization workaround"

    require_kirin930_patch \
        "hardware/interfaces" \
        "hardware/interfaces/Audio-skip-setMasterVolume-if-not-implement.patch" \
        "kirin930-dev audio master volume workaround"

    require_kirin930_patch \
        "lineage-sdk" \
        "lineage-sdk/Hardcode-Vendor-Security-Patchlevel.patch" \
        "kirin930-dev vendor security patch level workaround"

    require_kirin930_patch \
        "system/bt" \
        "system/bt/Hci-dont-crash-if-some-checks-fail.patch" \
        "kirin930-dev Bluetooth HCI parser workaround"

    require_kirin930_patch \
        "system/core" \
        "system/core/Support-mkbootimg-0xffb88000-as-tags-offset.patch" \
        "kirin930-dev mkbootimg tags offset workaround"
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

require_kirin930_patches

# Release and OTA tooling.
apply_once \
    "build/make" \
    "$PATCH_ROOT/patches/build/make/mozart-release-ota-build-tools.patch"

# Device identity, media, source boot and SELinux compatibility.
apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/mozart-device-bringup-media-selinux.patch"

apply_once \
    "kernel/huawei/mozart" \
    "$PATCH_ROOT/patches/kernel/huawei/mozart/disable-debug-info.patch"

apply_once \
    "vendor/lineage" \
    "$PATCH_ROOT/patches/vendor/lineage/disable-backuptool-and-hudson-fetch.patch"

# EMUI 3.1 GPU and IMG MSVDX codec recovery.
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

# Framework/HAL compatibility shims.
apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/legacy-private-sensor-type-compat.patch"

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
