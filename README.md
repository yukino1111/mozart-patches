# mozart-patches

Patch set for Huawei MediaPad M2 8.0 (`mozart`).

This repository contains the patches used to build based on [kirin930-dev](https://github.com/kirin930-dev).

## Experimental DSS overlay

`patches/hardware/interfaces/hwc2onfbadapter-hisi-dss-overlay-fallback.patch`
adds an opt-in DSS overlay path to AOSP `HWC2OnFbAdapter` for mozart video
playback testing. It does not enable Huawei's proprietary
`hwcomposer.hi3635.so`.

The overlay path is disabled by default. Enable the conservative YUV-only path
on a flashed build with:

```sh
adb shell setprop persist.debug.mozart.hwc_overlay 1
adb reboot
```

RGB/RGBA app layers are intentionally not handled by this path. A temporary
RGB experiment caused tearing during app scrolling, so the maintained patch stays YUV-only.

If the DSS ioctl fails, SurfaceFlinger falls back to the existing fbdev/client
composition path for that process. `dumpsys SurfaceFlinger` includes a
`mozart_dss_overlay` line for quick status checks.

## Acknowledgements

Thanks to [kirin930-dev](https://github.com/kirin930-dev) and Codex.

## License

Unless otherwise noted, this repository's scripts, documentation, and local text
patches are licensed under the Apache License 2.0. This license does not apply
to third-party proprietary binaries, which are not included here.

Kernel-related patches, if added later, should be marked separately and follow
the upstream kernel license, `GPL-2.0-only`.
