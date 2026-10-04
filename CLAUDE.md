# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Stitch is a minimal SwiftUI knitting row counter and a learning project for native iOS development. See `README.md` for MVP scope and roadmap. The app keeps a list of knitting projects (SwiftData), each with its own counter screen: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert.

## Build and run

No dependencies, no package manager. The scheme `Stitch` builds the app and runs the `StitchTests` Swift Testing target.

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```

Also check the other platforms compile by swapping the destination for `'platform=macOS'` or `'generic/platform=visionOS Simulator'` (no visionOS simulator runtime is installed, but the SDK is).

Deployment targets are iOS, macOS and visionOS 27.0, so the simulator runtime must be iOS 27+.

Run the model tests (on the iOS simulator):

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Run a single test by appending its name, e.g. `-only-testing:StitchTests/KnittingProjectTests/removeRowAtZeroChangesNothing()`.

SourceKit often reports "Cannot find '…' in scope" for types from other files in the target; trust `xcodebuild`, not those editor diagnostics.

## Architecture and build settings that matter

- `MyApp` attaches `.modelContainer(for: KnittingProject.self)`. `ContentView` is a `NavigationSplitView` that owns the `@Query` (sorted by `updatedAt`, newest first) and the selection, saved as a UUID string under `@AppStorage("selectedProjectID")`. On iPhone, going back to the list clears the selection, so the app reopens where the user left off (counter or list). `ProjectListView` lists, creates (via `NewProjectView`), renames and deletes projects; `CounterView` is the counter for one project.
- `KnittingProject` owns the counting rules: `rowCount` is `private(set)` and changes only through `addRow()`, `removeRow()` and `reset()`, which also update `updatedAt`. Views call these methods rather than setting properties.
- `CounterView` takes a plain `let project` (SwiftData models are observable). `ContentView` gives it `.id(project.id)` so switching projects creates a fresh counter instead of firing the haptic.
- Previews use `PreviewData.container` (in-memory sample projects). Create a `ModelContainer` before instantiating a model, in previews and in tests.
- SwiftData relies on autosave (no explicit `save()` calls). Changes made a few seconds before the process is killed can be lost; when checking persistence on the simulator, press Home before stopping the app.
- The project uses folder-synchronized groups (`PBXFileSystemSynchronizedRootGroup`): new files in `Stitch/` and `StitchTests/` are picked up automatically. Never edit `project.pbxproj` to add files.
- Swift 5 language mode, but with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are implicitly `@MainActor` unless marked otherwise (`nonisolated`).
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: each file must explicitly import the modules whose members it uses (e.g. `Foundation` for `SortDescriptor` or `trimmingCharacters`, `SwiftData` for `.modelContainer` and `\.modelContext`).
- Platforms: iPhone, iPad, Vision (`TARGETED_DEVICE_FAMILY = 1,2,7`) and native macOS (`SUPPORTED_PLATFORMS` includes `macosx`); layouts must work on all of them. UIKit does not exist on macOS, so wrap UIKit imports and calls in `#if canImport(UIKit)` (see the idle-timer code in `CounterView`).
- `StitchTests` is hosted in the app, builds for the same platforms, and also uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- App icon is `Stitch/AppIcon.icon`, an Icon Composer file selected by `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`; it covers iPhone, iPad and Mac but not visionOS. Its source SVG layers live in `Design/AppIcon/`, outside `Stitch/` so they aren't bundled into the app. Edit the icon in Icon Composer rather than hand-editing `icon.json`.
- Bundle identifier is an Xcode placeholder; signing team is not set.

## Conventions

- English everywhere: code, identifiers, comments, commit messages, docs. UI strings are English (development language); localization comes later via `Localizable.xcstrings`.
- Follow the Swift API Design Guidelines. Prefer Apple frameworks (SwiftUI, SwiftData, Observation) over third-party dependencies.
- Every view has a working `#Preview`.
- Persistence: SwiftData for project data; `@AppStorage` only for small preferences such as the selected project.

## Working style (learning project)

- Make small, incremental changes that build and run after each step.
- Explain the *why* behind SwiftUI concepts (state, bindings, persistence, view lifecycle) when introducing them.
- Favor code the developer can write and understand over large generated changes.
