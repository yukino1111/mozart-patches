#!/usr/bin/env bash
set -euo pipefail

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_TOP="${1:-/android/lineage18.1-mozart}"

if [[ ! -d "$ANDROID_TOP/.repo" ]]; then
    echo "error: $ANDROID_TOP does not look like an Android repo checkout" >&2
    exit 2
fi

apply_once() {
    local repo="$1"
    local patch="$2"

    if [[ ! -d "$ANDROID_TOP/$repo" ]]; then
        echo "error: missing Android repository: $repo" >&2
        exit 3
    fi

    if git -C "$ANDROID_TOP/$repo" apply -R --check "$patch" >/dev/null 2>&1; then
        echo "skip: already applied: $repo/${patch#$PATCH_ROOT/}"
        return
    fi

    echo "apply: $repo/${patch#$PATCH_ROOT/}"
    git -C "$ANDROID_TOP/$repo" apply --check "$patch"
    git -C "$ANDROID_TOP/$repo" apply "$patch"
}

apply_once \
    "build/make" \
    "$PATCH_ROOT/patches/build/make/lineage18-mozart-build-ota.patch"

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/lineage18-mozart-device.patch"

apply_once \
    "device/huawei/mozart" \
    "$PATCH_ROOT/patches/device/huawei/mozart/android11-emulated-primary-storage.patch"

apply_once \
    "frameworks/av" \
    "$PATCH_ROOT/patches/frameworks/av/legacy-audio-version-table.patch"

apply_once \
    "frameworks/base" \
    "$PATCH_ROOT/patches/frameworks/base/legacy-mali-egl-main-thread.patch"

apply_once \
    "frameworks/base" \
    "$PATCH_ROOT/patches/frameworks/base/legacy-install-media-gnss-stability.patch"

apply_once \
    "frameworks/native" \
    "$PATCH_ROOT/patches/frameworks/native/legacy-mali-region-lcd-power.patch"

apply_once \
    "hardware/broadcom/wlan" \
    "$PATCH_ROOT/patches/hardware/broadcom/wlan/legacy-bcmdhd-wifi-hal.patch"

apply_once \
    "hardware/interfaces" \
    "$PATCH_ROOT/patches/hardware/interfaces/legacy-composer-wifi.patch"

apply_once \
    "hardware/lineage/interfaces" \
    "$PATCH_ROOT/patches/hardware/lineage/interfaces/legacy-gnss-nmea-copy.patch"

apply_once \
    "hardware/libhardware" \
    "$PATCH_ROOT/patches/hardware/libhardware/legacy-mozart-gralloc-path.patch"

apply_once \
    "kernel/huawei/mozart" \
    "$PATCH_ROOT/patches/kernel/huawei/mozart/lineage18-kernel-compat.patch"

apply_once \
    "packages/apps/Bluetooth" \
    "$PATCH_ROOT/patches/packages/apps/Bluetooth/legacy-huawei-disable-scs.patch"

apply_once \
    "packages/modules/NetworkStack" \
    "$PATCH_ROOT/patches/packages/modules/NetworkStack/legacy-kernel-tcp-info.patch"

apply_once \
    "system/bt" \
    "$PATCH_ROOT/patches/system/bt/legacy-huawei-disable-scs.patch"

apply_once \
    "system/core" \
    "$PATCH_ROOT/patches/system/core/legacy-first-stage-mount.patch"

apply_once \
    "system/tools/mkbootimg" \
    "$PATCH_ROOT/patches/system/tools/mkbootimg/legacy-boot-addresses.patch"

apply_once \
    "vendor/huawei/mozart" \
    "$PATCH_ROOT/patches/vendor/huawei/mozart/lineage18-vendor-layout.patch"

apply_once \
    "vendor/lineage" \
    "$PATCH_ROOT/patches/vendor/lineage/disable-recovery-backuptool.patch"

"$PATCH_ROOT/scripts/prepare-proprietary-blobs.sh" "$ANDROID_TOP"

echo "LineageOS 18.1 mozart patches are applied"
