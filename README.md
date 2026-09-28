# Stitch

A minimal row counter for knitting, built with SwiftUI.

Stitch keeps track of rows while knitting: one big number, one big button to add a row, and nothing else in the way. It is a small personal project and a hands-on way to practice native iOS development.

## Status

MVP complete: add and remove rows, reset with confirmation, a count that persists across launches, and a layout with large tap targets that adapts to iPad. Tested on iPhone and iPad simulators; iPhone landscape and Apple Vision are not verified yet. Next up is the roadmap below.

## MVP scope

- Large, easy-to-read row count
- **+** button to add a row (primary action, largest tap target)
- **−** button to undo a row; disabled at 0 so the count never goes negative
- **Reset** button with a confirmation alert, so progress is never lost by accident
- The count persists across app launches (`@AppStorage` / `UserDefaults`)

One screen, one counter. Everything else is out of scope for the first version.

## Tech stack

| Area | Choice |
| --- | --- |
| Language | Swift (Swift 5 language mode) |
| UI | SwiftUI |
| Persistence | `@AppStorage` for the MVP; SwiftData planned for multiple projects |
| Deployment target | iOS 27.0 |
| Device families | iPhone, iPad, Apple Vision (`TARGETED_DEVICE_FAMILY = 1,2,7`) |
| Dependencies | None |

The project uses Xcode's folder-synchronized groups (`PBXFileSystemSynchronizedRootGroup`): any file added to the `Stitch/` folder on disk is picked up automatically, so `project.pbxproj` never needs to be edited by hand.

## Project structure

```
Stitch/
├── Stitch/
│   ├── MyApp.swift          # App entry point (@main)
│   ├── ContentView.swift    # Main (and currently only) screen
│   └── Assets.xcassets/     # App icon and accent color
└── Stitch.xcodeproj/
```

## Getting started

1. Open `Stitch.xcodeproj` in Xcode.
2. Select an iPhone simulator as the run destination.
3. Press **⌘R** to build and run.

### Running on a physical device

- Select your **Team** under *Target → Signing & Capabilities*.
- The bundle identifier is currently an Xcode-generated placeholder; replace it with a real reverse-DNS identifier (e.g. `com.<your-name>.stitch`).
- The device must run iOS 27 or later.
- With a free Apple developer account, the installed app stops launching after 7 days and must be reinstalled from Xcode.

## Roadmap

Ideas for after the MVP, roughly in order. None of them are commitments.

- [ ] Haptic feedback on each tap (`.sensoryFeedback`)
- [ ] Keep the screen awake while counting
- [ ] Custom app icon
- [ ] Multiple knitting projects, each with its own counter (SwiftData)
- [ ] Target row count and pattern-repeat reminders
- [ ] Spanish localization through a String Catalog

## Conventions

- **English everywhere:** code, identifiers, comments, commit messages, and documentation.
- UI strings are written in English as the development language; other languages are added later through a String Catalog (`Localizable.xcstrings`).
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Prefer Apple's native frameworks (SwiftUI, SwiftData, Observation) over third-party dependencies.
- Every view has a working `#Preview`.

## Development approach

This is a learning project: the goal is to understand native iOS development, not only to ship features. When contributing, including AI assistants:

- Work in small, incremental steps that build and run after each change.
- Explain the *why* behind SwiftUI concepts (state, bindings, persistence, view lifecycle) when introducing them.
- Favor code the developer writes and understands over large generated changes.
