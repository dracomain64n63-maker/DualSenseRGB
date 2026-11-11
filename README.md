# DualSense RGB

An iOS starter app that discovers a paired game controller through Apple's GameController framework and attempts to set its device light color, including a continuously cycling rainbow.

## Pair the controller first

1. Put the PS5 DualSense into Bluetooth pairing mode: hold **PS + Create** until the light bar flashes.
2. On iPhone, open **Settings → Bluetooth**.
3. Select **DualSense Wireless Controller**.
4. Open the app after pairing.

## Build

This repository uses XcodeGen and GitHub Actions. Upload the repository to GitHub, then open **Actions → Build DualSense RGB IPA → Run workflow**. The workflow produces an **unsigned** IPA artifact.

An unsigned IPA is not directly installable. It must be signed with a provisioning profile before sideloading. A free Apple ID provisioning profile typically expires after 7 days; paid Apple Developer membership is not required for basic personal-device testing, but the signing method must support your device and iOS version.

## Important compatibility note

Apple's GameController API exposes `GCController.light` as an optional property. The app checks whether the connected controller exposes a writable light. If iOS does not expose it for a particular DualSense/firmware/iOS combination, the app will report that instead of claiming the light changed.

The rainbow runs while the app is in the foreground. Background execution is not implemented in this starter.
