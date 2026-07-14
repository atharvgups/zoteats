# ZotEats — native iOS app

This directory contains the native SwiftUI app and its data layer.

- `ZotEatsKit/` — Swift package: models, services (dining, campus retail, busyness, gym), typical-busyness engine, and tests. Builds and tests on Linux and macOS: `swift test --package-path apple/ZotEatsKit`.
- `App/` — SwiftUI app sources (iOS 17+), organized by tab: Dining (Eat), Campus, Gym, Busyness (Study), plus the shared design system in `App/Design/`.
- `UITests/` — the scripted demo tour that CI records as a video on every demo build.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; the Xcode project is generated, never committed: `xcodegen generate --spec apple/project.yml --project apple/`.
- `AppStore/` — listing metadata and privacy policy.

CI (`.github/workflows/ios.yml`) runs package tests on every push; the macOS build + simulator screenshots + demo recording run on demand (commits containing `[demo]`, or manual dispatch). TestFlight uploads run via the `testflight-*` tag or manual dispatch (`.github/workflows/testflight.yml`).
