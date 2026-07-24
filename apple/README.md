# ZotEats — native iOS app

This directory contains the native SwiftUI app and its data layer.

- `ZotEatsKit/` — Swift package: models, services (dining, campus retail, busyness, gym), typical-busyness engine, and tests. Builds and tests on Linux and macOS: `swift test --package-path apple/ZotEatsKit`.
- `App/` — SwiftUI app sources (iOS 17+), organized by tab: Dining (Eat), Campus, Gym, Busyness (Study), plus the shared design system in `App/Design/`.
- `UITests/` — the scripted demo tour that CI records as a video on every demo build.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; the Xcode project is generated, never committed: `xcodegen generate --spec apple/project.yml --project apple/`.
- `AppStore/` — listing metadata and privacy policy.

CI (`.github/workflows/ios.yml`) runs package tests on every push; the macOS build + simulator screenshots + demo recording run on demand (commits containing `[demo]`, or manual dispatch). TestFlight uploads run via the `testflight-*` tag or manual dispatch (`.github/workflows/testflight.yml`).

### TestFlight external testers (auto, one behind)

After each successful upload of build **N** (what you dogfood on Internal Testing), CI promotes the previous VALID build (**N−1**) to the External Testing group and submits/notifies. Example: you just pushed **1.0.9** for yourself; the next `testflight-*` / dispatch upload will auto-ship **1.0.9** to externals while you take **1.0.10**.

One-time App Store Connect setup: create an External Testing group named `External Testers` (or set repo variable `TESTFLIGHT_EXTERNAL_GROUP_NAME`). Add testers there. First external build of a marketing version still needs Apple Beta App Review.
