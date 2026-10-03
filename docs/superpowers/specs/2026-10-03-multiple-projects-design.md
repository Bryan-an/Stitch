# Multiple knitting projects with SwiftData

Status: approved design, not yet implemented
Date: 2026-10-03

## Goal

Replace the single row counter with a list of knitting projects, each with its own persisted row count. This is the "Multiple knitting projects, each with its own counter (SwiftData)" roadmap item.

## Decisions

| Topic | Decision |
| --- | --- |
| Project data | Name, row count, created date, last-updated date. Target rows, notes and repeat reminders are out of scope. |
| Existing data | Start fresh. The old `@AppStorage("rowCount")` value is not imported; the key is left unused in `UserDefaults`. |
| Navigation | `NavigationSplitView`: sidebar list + counter detail on iPad and Mac, collapsing to list → counter on iPhone. |
| Launch | Reopen the last selected project. |
| Where rules live | In the model (approach A). Views call model methods; no separate store or view-model layer. |
| Testing | New Swift Testing target `StitchTests` for the model; simulator checks for the UI. |

## Data model

New file `Stitch/KnittingProject.swift`:

```swift
import Foundation
import SwiftData

@Model
final class KnittingProject {
    var id: UUID
    var name: String
    private(set) var rowCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        let now = Date.now
        id = UUID()
        self.name = name
        rowCount = 0
        createdAt = now
        updatedAt = now
    }

    func addRow() { rowCount += 1; updatedAt = .now }
    func removeRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        updatedAt = .now
    }
    func reset() { rowCount = 0; updatedAt = .now }
}
```

Rules:

- `rowCount` is only changed through `addRow()`, `removeRow()` and `reset()`, so it can never go negative and `updatedAt` is never forgotten. If `@Model` rejects `private(set)`, fall back to `var` and note it in the code.
- `updatedAt` means "last time the count changed". Renaming does not change it.
- `removeRow()` at 0 is a no-op and leaves `updatedAt` unchanged.
- `id` is a stored `UUID` used to remember the selected project.
- The model does not validate names; the creation UI does.

## Screens and navigation

| File | Responsibility |
| --- | --- |
| `MyApp.swift` | Adds `.modelContainer(for: KnittingProject.self)` to the `WindowGroup`. |
| `ContentView.swift` | Root `NavigationSplitView`. Owns `@Query(sort: \KnittingProject.updatedAt, order: .reverse)` and the persisted selection. Sidebar: `ProjectListView`. Detail: `CounterView` for the selected project, or `ContentUnavailableView` ("Select a project") when none is selected. |
| `ProjectListView.swift` | Receives the projects and the selection binding. Rows show name and row count, tagged with `project.id`. Toolbar **+** opens `NewProjectView`. Empty state: `ContentUnavailableView` ("No Projects") with a **New Project** button. Context menu: Rename, Delete. Swipe action: Delete. |
| `CounterView.swift` | The current counter screen moved out of `ContentView`, taking `let project: KnittingProject`. Calls the model methods. Keeps the layout, haptics, keep-awake (`#if canImport(UIKit)`) and the reset confirmation alert. Navigation title is the project name. |
| `NewProjectView.swift` | Sheet with a name `TextField`, Cancel and Create. Create is disabled until the trimmed name is non-empty. Creating inserts the project into the model context, selects it and dismisses. |

Actions:

- **Rename:** alert with a `TextField` bound to a `@State` draft string, prefilled with the current name, plus Cancel and Save. Save assigns the trimmed draft to `project.name` only if it is non-empty; Cancel discards it. A draft is used instead of binding the field directly to the model, because a direct binding would write every keystroke (including a blank name) and Cancel could not undo it.
- **Delete:** confirmation alert ("Delete '<name>'? Its row count will be lost."), consistent with Reset. Deleting the selected project clears the selection.

`CounterView` uses a plain `let project` because SwiftData models are observable: SwiftUI tracks the properties a view reads and redraws when they change. `@Bindable` is only needed for a `$` binding directly to a model property, which this design does not use.

## Selection and launch

`ContentView` persists the selection as a string and exposes it to `List(selection:)` as a `UUID?` binding:

```swift
@AppStorage("selectedProjectID") private var selectedProjectID: String?

private var selection: Binding<UUID?> {
    Binding(
        get: { selectedProjectID.flatMap(UUID.init(uuidString:)) },
        set: { selectedProjectID = $0?.uuidString }
    )
}
```

The selected project is `projects.first { $0.id == selection.wrappedValue }`.

Launch behavior:

- Saved ID matches a project: that project is selected and its counter is shown. On iPhone the app opens directly on the counter; this is set explicitly with `NavigationSplitView(preferredCompactColumn:)` and verified on the simulator.
- Saved ID matches nothing (deleted project, stale value): treated as no selection. iPhone shows the list; iPad and Mac show the placeholder.
- Creating a project selects it, so iPhone navigates straight to its counter.

`@AppStorage` is used instead of `@SceneStorage` because scene storage is discarded when the user swipes the app away, which would break "reopen last project" on iPhone.

Known limitation: the selection is shared across windows, so two windows on iPad or Mac follow the same selection. Accepted for now.

## Testing

Setup (done by the developer in Xcode, because adding a target by hand-editing `project.pbxproj` is error-prone): **File › New › Target › Unit Testing Bundle**, name `StitchTests`, Testing System **Swift Testing**, target to be tested **Stitch**.

`StitchTests/KnittingProjectTests.swift`:

- A new project has `rowCount == 0` and `createdAt == updatedAt`.
- `addRow()` increments the count and sets `updatedAt` to a time no earlier than a timestamp taken just before the call (timestamps can tie, so the check is `>=`, not `>`).
- `removeRow()` decrements the count; at 0 the count stays 0 and `updatedAt` does not change.
- `reset()` sets the count to 0.
- Persistence round trip with an in-memory `ModelContainer`: insert projects with explicitly assigned, distinct `updatedAt` values, save, fetch sorted by `updatedAt` descending, and check the order.

Run all model tests:

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Append `/<testName>()` to run a single test.

Previews: every view keeps a working `#Preview`, backed by an in-memory container with sample projects so previews never touch real data.

Simulator checks: create, count, rename, delete and cancel delete; relaunch reopens the last project; deleting the open project returns to the list; split view on iPad; macOS and visionOS builds compile.

## Order of work

Each step builds, runs and is committed on its own.

1. **Model and tests:** `KnittingProject`, `StitchTests`, all tests passing. App behavior unchanged.
2. **Container and list:** model container in `MyApp`, split view in `ContentView`, `ProjectListView` with empty state, `NewProjectView`. Projects can be created.
3. **Counter per project:** `CounterView(project:)` using the model methods; remove `@AppStorage("rowCount")`.
4. **Reopen last project:** persisted selection and launch behavior.
5. **Rename and delete:** context menu, swipe to delete, delete confirmation.
6. **Docs:** README (status, roadmap tick, project structure, persistence row) and CLAUDE.md (architecture, test commands, remove the `rowCount` note and the "don't introduce SwiftData early" rule).

## Out of scope

- Importing the old single count.
- Target row count, pattern-repeat reminders, notes.
- iCloud sync.
- Per-window selection on iPad and Mac.
- A visionOS app icon.
