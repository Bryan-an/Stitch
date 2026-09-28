# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Stitch is a minimal SwiftUI knitting row counter and a learning project for native iOS development. See `README.md` for MVP scope and roadmap. The MVP is one screen with one counter: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert, and the count persisted via `@AppStorage`. Anything beyond that is out of scope until the MVP ships.

## Build and run

No dependencies, no package manager, no test target yet. The scheme `Stitch` is auto-generated (not shared).

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```

The deployment target is iOS 27.0, so the simulator runtime must be iOS 27+. If a test target is added later, run a single test with `-only-testing:<TestTarget>/<TestClass>/<testMethod>` on `xcodebuild test`.

## Architecture and build settings that matter

- Entry point is `Stitch/MyApp.swift` (`@main struct MyApp`), which shows `ContentView`. `ContentView.swift` holds the whole MVP: the count is `@AppStorage("rowCount")` (persisted in `UserDefaults`), and transient UI state such as the reset alert flag is `@State`. Don't rename the `"rowCount"` key: existing saved counts would be lost.
- The project uses folder-synchronized groups (`PBXFileSystemSynchronizedRootGroup`): new files in `Stitch/` are picked up automatically. Never edit `project.pbxproj` to add files.
- Swift 5 language mode, but with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are implicitly `@MainActor` unless marked otherwise (`nonisolated`).
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: each file must explicitly import the modules whose members it uses.
- Device families: iPhone, iPad, Vision (`1,2,7`); layouts must work on all three.
- Bundle identifier is an Xcode placeholder; signing team is not set.

## Conventions

- English everywhere: code, identifiers, comments, commit messages, docs. UI strings are English (development language); localization comes later via `Localizable.xcstrings`.
- Follow the Swift API Design Guidelines. Prefer Apple frameworks (SwiftUI, SwiftData, Observation) over third-party dependencies.
- Every view has a working `#Preview`.
- Persistence: `@AppStorage` for the MVP; SwiftData is planned for multiple projects — don't introduce it early.

## Working style (learning project)

- Make small, incremental changes that build and run after each step.
- Explain the *why* behind SwiftUI concepts (state, bindings, persistence, view lifecycle) when introducing them.
- Favor code the developer can write and understand over large generated changes.
