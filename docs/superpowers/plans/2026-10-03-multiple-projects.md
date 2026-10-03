# Multiple Knitting Projects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single `@AppStorage` row counter with a SwiftData-backed list of knitting projects, each with its own counter, reopening the last project at launch.

**Architecture:** A `KnittingProject` SwiftData model owns the counting rules (`addRow()`, `removeRow()`, `reset()`). `ContentView` becomes a `NavigationSplitView` that owns the `@Query` and the persisted selection; `ProjectListView` shows, creates, renames and deletes projects; `CounterView` is the existing counter screen driven by one project. Model rules are covered by a Swift Testing target; UI is verified on the simulator.

**Tech Stack:** Swift 5 language mode, SwiftUI, SwiftData, Swift Testing, Xcode 27 SDKs.

**Spec:** `docs/superpowers/specs/2026-10-03-multiple-projects-design.md`

## Global Constraints

- Deployment targets: iOS 27.0, macOS 27.0, visionOS 27.0. Every task must build for iOS Simulator, macOS and visionOS Simulator.
- App target settings that affect code: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (import every module whose members a file uses, e.g. `SwiftData` for `.modelContainer` / `\.modelContext`, `Foundation` for `trimmingCharacters`).
- UIKit does not exist on macOS: wrap UIKit imports and calls in `#if canImport(UIKit)`.
- Files in `Stitch/` and `StitchTests/` are picked up automatically (folder-synchronized groups). Never edit `project.pbxproj` to add files. Editing build settings in it is allowed where a task says so.
- Every view has a working `#Preview`; previews use the in-memory `PreviewData.container`, never the real store.
- English for code, identifiers, comments, UI strings and commit messages.
- No third-party dependencies.
- Commit messages end with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before each commit, run `git status --short` and stage only the files the task names (Xcode may have staged other files on its own).

Build commands used throughout (run from the repo root):

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=macOS' build
```

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'generic/platform=visionOS Simulator' build
```

Each must end with `** BUILD SUCCEEDED **`.

---

### Task 1: Test target, `KnittingProject` model and model tests

**Files:**
- Modify: `Stitch.xcodeproj/project.pbxproj` (build settings of the two `StitchTests` configurations only)
- Delete: `StitchTests/StitchTests.swift` (Xcode template)
- Create: `StitchTests/KnittingProjectTests.swift`
- Create: `Stitch/KnittingProject.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `final class KnittingProject` (`@Model`) with `var id: UUID`, `var name: String`, `private(set) var rowCount: Int`, `var createdAt: Date`, `var updatedAt: Date`, `init(name: String)`, `func addRow()`, `func removeRow()`, `func reset()`.

Context: the `StitchTests` target was created with Xcode's visionOS template, so it only supports visionOS (`SDKROOT = xros`, `SUPPORTED_PLATFORMS = "xros xrsimulator"`, `TARGETED_DEVICE_FAMILY = 7`) and lacks the app's MainActor default isolation. No visionOS simulator runtime is installed, so the tests cannot run until this is fixed.

- [ ] **Step 1: Fix the `StitchTests` build settings**

Run this script from the repo root. It edits only the build configuration blocks whose comment names the `StitchTests` target:

```bash
python3 - <<'EOF'
import re
path = "Stitch.xcodeproj/project.pbxproj"
text = open(path).read()
pattern = re.compile(r'(/\* (?:Debug|Release) configuration for PBXNativeTarget "StitchTests" \*/ = \{.*?\n\t\t\};)', re.S)
blocks = pattern.findall(text)
assert len(blocks) == 2, f"expected 2 StitchTests configurations, found {len(blocks)}"
for block in blocks:
    fixed = (block
        .replace("SDKROOT = xros;", "SDKROOT = auto;")
        .replace('SUPPORTED_PLATFORMS = "xros xrsimulator";',
                 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";')
        .replace("TARGETED_DEVICE_FAMILY = 7;", 'TARGETED_DEVICE_FAMILY = "1,2,7";'))
    if "SWIFT_DEFAULT_ACTOR_ISOLATION" not in fixed:
        fixed = fixed.replace("SWIFT_APPROACHABLE_CONCURRENCY = YES;",
                              "SWIFT_APPROACHABLE_CONCURRENCY = YES;\n\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;")
    text = text.replace(block, fixed)
open(path, "w").write(text)
EOF
```

Verify:

```bash
grep -nE "SDKROOT|SUPPORTED_PLATFORMS|TARGETED_DEVICE_FAMILY|SWIFT_DEFAULT_ACTOR_ISOLATION" Stitch.xcodeproj/project.pbxproj
```

Expected: no `xros;`, no `"xros xrsimulator"`, no `= 7;`; four `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;` lines (two app, two test).

- [ ] **Step 2: Replace the template test with the model tests**

```bash
rm StitchTests/StitchTests.swift
```

Create `StitchTests/KnittingProjectTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import Stitch

struct KnittingProjectTests {
    // SwiftData needs a container for a model type before instances of it are
    // created. Swift Testing makes a fresh suite instance (and so a fresh
    // in-memory store) for every test.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: KnittingProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProject(named name: String = "Scarf") -> KnittingProject {
        let project = KnittingProject(name: name)
        container.mainContext.insert(project)
        return project
    }

    @Test func newProjectStartsAtZero() {
        let project = makeProject(named: "Scarf")

        #expect(project.name == "Scarf")
        #expect(project.rowCount == 0)
        #expect(project.createdAt == project.updatedAt)
    }

    @Test func addRowIncrementsAndUpdatesTimestamp() {
        let project = makeProject()
        let before = Date.now

        project.addRow()

        #expect(project.rowCount == 1)
        // Two timestamps can be identical, so this is >= rather than >.
        #expect(project.updatedAt >= before)
    }

    @Test func removeRowDecrements() {
        let project = makeProject()
        project.addRow()
        project.addRow()

        project.removeRow()

        #expect(project.rowCount == 1)
    }

    @Test func removeRowAtZeroChangesNothing() {
        let project = makeProject()
        let updatedAt = project.updatedAt

        project.removeRow()

        #expect(project.rowCount == 0)
        #expect(project.updatedAt == updatedAt)
    }

    @Test func resetSetsCountToZero() {
        let project = makeProject()
        project.addRow()
        project.addRow()
        project.addRow()

        project.reset()

        #expect(project.rowCount == 0)
    }

    @Test func fetchSortsMostRecentlyUpdatedFirst() throws {
        let scarf = makeProject(named: "Scarf")
        let hat = makeProject(named: "Hat")
        let socks = makeProject(named: "Socks")
        scarf.updatedAt = Date(timeIntervalSince1970: 100)
        hat.updatedAt = Date(timeIntervalSince1970: 300)
        socks.updatedAt = Date(timeIntervalSince1970: 200)
        try container.mainContext.save()

        let descriptor = FetchDescriptor<KnittingProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let names = try container.mainContext.fetch(descriptor).map(\.name)

        #expect(names == ["Hat", "Socks", "Scarf"])
    }
}
```

- [ ] **Step 3: Run the tests and confirm they fail**

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Expected: `** TEST FAILED **` with a compile error like `cannot find 'KnittingProject' in scope`.

If instead xcodebuild reports that scheme `Stitch` is not configured for the test action, stop and ask the developer to open **Product › Scheme › Edit Scheme… › Test**, add `StitchTests`, and tick **Shared** (so the scheme is saved to `Stitch.xcodeproj/xcshareddata/xcschemes/Stitch.xcscheme` and can be committed). Then re-run.

- [ ] **Step 4: Create the model**

Create `Stitch/KnittingProject.swift`:

```swift
import Foundation
import SwiftData

@Model
final class KnittingProject {
    var id: UUID
    var name: String
    // Only the methods below change the count, so it can never go negative
    // and `updatedAt` is never forgotten.
    private(set) var rowCount: Int
    var createdAt: Date
    // The last time the count changed. Renaming does not update it.
    var updatedAt: Date

    init(name: String) {
        let now = Date.now
        id = UUID()
        self.name = name
        rowCount = 0
        createdAt = now
        updatedAt = now
    }

    func addRow() {
        rowCount += 1
        updatedAt = .now
    }

    func removeRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        updatedAt = .now
    }

    func reset() {
        rowCount = 0
        updatedAt = .now
    }
}
```

If the build rejects `private(set)` on a `@Model` property, change it to `var rowCount: Int` and replace the comment above it with `// Change only through addRow(), removeRow() and reset(): @Model does not support private(set).`

- [ ] **Step 5: Run the tests and confirm they pass**

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Expected: `** TEST SUCCEEDED **`, 6 tests passed. A single test can be run with `-only-testing:StitchTests/KnittingProjectTests/removeRowAtZeroChangesNothing()`.

- [ ] **Step 6: Build all three platforms**

Run the three build commands from Global Constraints. Expected: `** BUILD SUCCEEDED **` for each. The app's behavior is unchanged (it still uses `@AppStorage("rowCount")`).

- [ ] **Step 7: Commit**

```bash
git status --short
git add Stitch.xcodeproj/project.pbxproj StitchTests/KnittingProjectTests.swift Stitch/KnittingProject.swift
git commit -F - <<'EOF'
Add KnittingProject model and StitchTests target

Fix the StitchTests target, which Xcode created for visionOS only, to
build for all app platforms with MainActor default isolation. Add the
SwiftData model with its counting rules and Swift Testing coverage.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

`StitchTests/StitchTests.swift` was never committed, so deleting it needs no `git rm`.

---

### Task 2: `CounterView` driven by a project, plus preview data

**Files:**
- Create: `Stitch/PreviewData.swift`
- Create: `Stitch/CounterView.swift`
- `Stitch/ContentView.swift` stays unchanged in this task (the app keeps running the old counter until Task 3).

**Interfaces:**
- Consumes: `KnittingProject` (`rowCount`, `name`, `addRow()`, `removeRow()`, `reset()`).
- Produces: `enum PreviewData` with `static let container: ModelContainer` and `static var sampleProject: KnittingProject`; `struct CounterView: View` with `init(project: KnittingProject)`.

- [ ] **Step 1: Create the preview data helper**

Create `Stitch/PreviewData.swift`:

```swift
import SwiftData

/// Sample data for SwiftUI previews. Lives in memory only and never touches
/// the real store.
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: KnittingProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            // Created in this order so "Scarf" ends up the most recently updated.
            for (name, rows) in [("Socks", 0), ("Hat", 7), ("Scarf", 42)] {
                let project = KnittingProject(name: name)
                container.mainContext.insert(project)
                for _ in 0..<rows {
                    project.addRow()
                }
            }
            return container
        } catch {
            fatalError("Could not create the preview container: \(error)")
        }
    }()

    /// The most recently updated sample project ("Scarf", 42 rows).
    static var sampleProject: KnittingProject {
        let descriptor = FetchDescriptor<KnittingProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let project = try? container.mainContext.fetch(descriptor).first else {
            fatalError("The preview container has no projects")
        }
        return project
    }
}
```

- [ ] **Step 2: Create `CounterView`**

Create `Stitch/CounterView.swift`. It is the body of today's `ContentView` with `count` replaced by the project's count and methods:

```swift
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CounterView: View {
    // A plain `let` is enough: SwiftData models are observable, so SwiftUI
    // redraws this view whenever a property it reads (like rowCount) changes.
    let project: KnittingProject

    @State private var isShowingResetAlert = false

    private let buttonHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\(project.rowCount)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    project.removeRow()
                } label: {
                    Label("Remove row", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: buttonHeight, minHeight: buttonHeight)
                }
                .buttonStyle(.bordered)
                .disabled(project.rowCount == 0)

                Button {
                    project.addRow()
                } label: {
                    Label("Add row", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: buttonHeight)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.title2.weight(.semibold))
            .controlSize(.extraLarge)

            Button("Reset", role: .destructive) {
                isShowingResetAlert = true
            }
            .disabled(project.rowCount == 0)
        }
        .padding()
        .frame(maxWidth: 500)
        .navigationTitle(project.name)
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: project.rowCount) { oldValue, newValue in
            newValue > oldValue ? .impact(weight: .medium) : .impact(weight: .light)
        }
        #if canImport(UIKit)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        .alert("Reset the counter?", isPresented: $isShowingResetAlert) {
            Button("Reset", role: .destructive) {
                project.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The row count will go back to 0.")
        }
    }
}

#Preview {
    NavigationStack {
        CounterView(project: PreviewData.sampleProject)
    }
    .modelContainer(PreviewData.container)
}
```

If the macOS build rejects `.toolbarTitleDisplayMode(.inline)`, wrap that one line in `#if !os(macOS)` / `#endif`.

- [ ] **Step 3: Build all three platforms**

Run the three build commands. Expected: `** BUILD SUCCEEDED **` for each, no new warnings.

- [ ] **Step 4: Check the preview**

Ask the developer to open `CounterView.swift` in Xcode and confirm the canvas shows "Scarf" with 42 and that tapping **+**, **−** and **Reset** in the interactive preview works. (This cannot be automated from the command line.)

- [ ] **Step 5: Commit**

```bash
git status --short
git add Stitch/PreviewData.swift Stitch/CounterView.swift
git commit -F - <<'EOF'
Add CounterView driven by a KnittingProject

Copy the counter screen into CounterView, which reads and changes one
project's count through the model's methods. Add in-memory sample data
for previews. The app still shows the old counter until the list lands.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Model container, split view, project list and new-project sheet

**Files:**
- Modify: `Stitch/MyApp.swift`
- Replace: `Stitch/ContentView.swift` (entire file)
- Create: `Stitch/ProjectListView.swift`
- Create: `Stitch/NewProjectView.swift`

**Interfaces:**
- Consumes: `KnittingProject`, `CounterView(project:)`, `PreviewData.container`.
- Produces: `struct ProjectListView: View` with `init(projects: [KnittingProject], selection: Binding<UUID?>)`; `struct NewProjectView: View` with `init(onCreate: @escaping (KnittingProject) -> Void)`. Task 4 changes only `ContentView`; Task 5 replaces `ProjectListView` keeping this initializer.

- [ ] **Step 1: Attach the model container**

Replace `Stitch/MyApp.swift` with:

```swift
import SwiftData
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: KnittingProject.self)
    }
}
```

- [ ] **Step 2: Create the new-project sheet**

Create `Stitch/NewProjectView.swift`:

```swift
import Foundation
import SwiftData
import SwiftUI

struct NewProjectView: View {
    var onCreate: (KnittingProject) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .onSubmit {
                        if !trimmedName.isEmpty {
                            create()
                        }
                    }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        create()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func create() {
        let project = KnittingProject(name: trimmedName)
        modelContext.insert(project)
        onCreate(project)
        dismiss()
    }
}

#Preview {
    NewProjectView { _ in }
        .modelContainer(PreviewData.container)
}
```

- [ ] **Step 3: Create the project list**

Create `Stitch/ProjectListView.swift` (`SwiftData` is imported for the preview's `.modelContainer`):

```swift
import SwiftData
import SwiftUI

struct ProjectListView: View {
    let projects: [KnittingProject]
    @Binding var selection: UUID?

    @State private var isShowingNewProject = false

    var body: some View {
        List(selection: $selection) {
            ForEach(projects) { project in
                LabeledContent(project.name) {
                    Text(project.rowCount, format: .number)
                        .monospacedDigit()
                }
                .tag(project.id)
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "plus") {
                    isShowingNewProject = true
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "square.stack")
                } description: {
                    Text("Create a project to start counting rows.")
                } actions: {
                    Button("New Project") {
                        isShowingNewProject = true
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView { project in
                selection = project.id
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectListView(
            projects: [PreviewData.sampleProject],
            selection: .constant(nil)
        )
    }
    .modelContainer(PreviewData.container)
}
```

- [ ] **Step 4: Turn `ContentView` into the split view**

Replace the whole of `Stitch/ContentView.swift` with:

```swift
import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \KnittingProject.updatedAt, order: .reverse)
    private var projects: [KnittingProject]

    @State private var selection: UUID?

    private var selectedProject: KnittingProject? {
        projects.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            ProjectListView(projects: projects, selection: $selection)
        } detail: {
            if let selectedProject {
                CounterView(project: selectedProject)
                    // A new identity per project, so switching projects builds a
                    // fresh counter instead of reusing the old one (which would
                    // fire the haptic because rowCount "changed").
                    .id(selectedProject.id)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "list.bullet",
                    description: Text("Choose a project from the list, or create a new one.")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
```

This removes `@AppStorage("rowCount")`; the old value stays unused in `UserDefaults` (start-fresh decision).

- [ ] **Step 5: Build all three platforms**

Run the three build commands. Expected: `** BUILD SUCCEEDED **` for each.

- [ ] **Step 6: Run the model tests**

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Check on the iPhone simulator**

Build and run on iPhone 17 (iOS 27). Check:
1. First launch shows "No Projects" with a **New Project** button.
2. **New Project** opens the sheet; **Create** is disabled while the name is empty or only spaces.
3. Creating "Scarf" goes straight to its counter, titled "Scarf". **+**, **−** and **Reset** work; **−** and **Reset** are disabled at 0.
4. Back to the list: "Scarf" shows its count. Create "Hat", add a row there, go back: "Hat" is listed first.
5. Open "Scarf" again: its own count is shown, unchanged.

- [ ] **Step 8: Check on the iPad simulator**

Run on iPad Pro 13-inch (M5) (iOS 27). Check: list and counter side by side; with nothing selected the detail shows "Select a Project"; selecting projects switches the counter.

- [ ] **Step 9: Commit**

```bash
git status --short
git add Stitch/MyApp.swift Stitch/ContentView.swift Stitch/ProjectListView.swift Stitch/NewProjectView.swift
git commit -F - <<'EOF'
Add project list with SwiftData and a counter per project

Attach a model container, turn ContentView into a split view with a
project list and the selected project's counter, and add a sheet for
creating projects. The single @AppStorage count is no longer used.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 4: Reopen the last project at launch

**Files:**
- Modify: `Stitch/ContentView.swift` (entire file shown below)

**Interfaces:**
- Consumes: `ProjectListView(projects:selection:)`, `CounterView(project:)`, `KnittingProject.id`.
- Produces: the `"selectedProjectID"` `UserDefaults` key (a `UUID` string). Task 5 clears the selection through the same `selection` binding when the selected project is deleted.

- [ ] **Step 1: Persist the selection and choose the compact column**

Replace the whole of `Stitch/ContentView.swift` with:

```swift
import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \KnittingProject.updatedAt, order: .reverse)
    private var projects: [KnittingProject]

    // @AppStorage can't hold a UUID, so the selection is saved as a string.
    // It survives the app being swiped away, unlike @SceneStorage.
    @AppStorage("selectedProjectID") private var selectedProjectID: String?

    // Which column iPhone shows. Starts on the counter; falls back to the
    // list in onAppear when there is nothing to reopen.
    @State private var preferredColumn = NavigationSplitViewColumn.detail

    // A binding is just a get/set pair, so it can convert between the saved
    // string and the UUID the list uses as its selection.
    private var selection: Binding<UUID?> {
        Binding(
            get: { selectedProjectID.flatMap(UUID.init(uuidString:)) },
            set: { selectedProjectID = $0?.uuidString }
        )
    }

    private var selectedProject: KnittingProject? {
        projects.first { $0.id == selection.wrappedValue }
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            ProjectListView(projects: projects, selection: selection)
        } detail: {
            if let selectedProject {
                CounterView(project: selectedProject)
                    // A new identity per project, so switching projects builds a
                    // fresh counter instead of reusing the old one (which would
                    // fire the haptic because rowCount "changed").
                    .id(selectedProject.id)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "list.bullet",
                    description: Text("Choose a project from the list, or create a new one.")
                )
            }
        }
        .onAppear {
            if selectedProject == nil {
                preferredColumn = .sidebar
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
```

Note that `ProjectListView` now receives `selection` (already a `Binding`), not `$selection`.

- [ ] **Step 2: Build all three platforms**

Run the three build commands. Expected: `** BUILD SUCCEEDED **` for each.

- [ ] **Step 3: Check launch behavior on the iPhone simulator**

1. Open "Scarf", press Home (so SwiftData autosaves), then stop and relaunch the app: it opens directly on Scarf's counter with **‹ Projects** to go back, and the count is unchanged.
2. Go back to the list (selection stays Scarf), relaunch: still opens on Scarf.
3. Erase the app's data by uninstalling and reinstalling it (or on a fresh simulator), launch: it opens on the "No Projects" list, not on an empty counter.
4. Watch for a visible flash of the wrong screen at launch. If the counter or list flashes before switching, report it; do not add workarounds without asking.

- [ ] **Step 4: Check on the iPad simulator**

Select "Hat", relaunch: "Hat" is selected in the sidebar and its counter is shown.

- [ ] **Step 5: Commit**

```bash
git status --short
git add Stitch/ContentView.swift
git commit -F - <<'EOF'
Reopen the last selected project at launch

Save the selected project's ID with @AppStorage and start iPhone on
the counter when it still matches a project, otherwise on the list.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 5: Rename and delete projects

**Files:**
- Replace: `Stitch/ProjectListView.swift` (entire file)

**Interfaces:**
- Consumes: `KnittingProject` (`name`, `id`), `NewProjectView(onCreate:)`, the `selection` binding from `ContentView`.
- Produces: nothing new; `init(projects: [KnittingProject], selection: Binding<UUID?>)` is unchanged.

Notes for the implementer:
- Rename edits a `@State` draft, not the model directly, so Cancel discards changes and a blank name is never saved.
- The swipe action uses `.tint(.red)` instead of `role: .destructive`. A destructive swipe role makes `List` animate the row away immediately, even though the project is only deleted after the confirmation.
- The delete alert title is the static "Delete Project?" with the name in the message, so the title does not go blank while the alert animates away (refines the spec's wording).

- [ ] **Step 1: Replace `ProjectListView`**

Replace the whole of `Stitch/ProjectListView.swift` with:

```swift
import Foundation
import SwiftData
import SwiftUI

struct ProjectListView: View {
    let projects: [KnittingProject]
    @Binding var selection: UUID?

    @Environment(\.modelContext) private var modelContext
    @State private var isShowingNewProject = false
    @State private var projectToRename: KnittingProject?
    @State private var renameDraft = ""
    @State private var projectToDelete: KnittingProject?

    var body: some View {
        List(selection: $selection) {
            ForEach(projects) { project in
                LabeledContent(project.name) {
                    Text(project.rowCount, format: .number)
                        .monospacedDigit()
                }
                .tag(project.id)
                .contextMenu {
                    Button("Rename", systemImage: "pencil") {
                        startRenaming(project)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        projectToDelete = project
                    }
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash") {
                        projectToDelete = project
                    }
                    .tint(.red)
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "plus") {
                    isShowingNewProject = true
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "square.stack")
                } description: {
                    Text("Create a project to start counting rows.")
                } actions: {
                    Button("New Project") {
                        isShowingNewProject = true
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView { project in
                selection = project.id
            }
        }
        .alert("Rename Project", isPresented: isRenaming, presenting: projectToRename) { project in
            TextField("Name", text: $renameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                rename(project)
            }
        }
        .alert("Delete Project?", isPresented: isConfirmingDelete, presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) {
                delete(project)
            }
            Button("Cancel", role: .cancel) {}
        } message: { project in
            Text("“\(project.name)” and its row count will be lost.")
        }
    }

    // Alerts need a Bool binding; these derive one from the optional
    // "which project" state and clear it when the alert closes.
    private var isRenaming: Binding<Bool> {
        Binding(
            get: { projectToRename != nil },
            set: { if !$0 { projectToRename = nil } }
        )
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )
    }

    private func startRenaming(_ project: KnittingProject) {
        renameDraft = project.name
        projectToRename = project
    }

    private func rename(_ project: KnittingProject) {
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        project.name = name
    }

    private func delete(_ project: KnittingProject) {
        if selection == project.id {
            selection = nil
        }
        modelContext.delete(project)
    }
}

#Preview {
    NavigationStack {
        ProjectListView(
            projects: [PreviewData.sampleProject],
            selection: .constant(nil)
        )
    }
    .modelContainer(PreviewData.container)
}
```

- [ ] **Step 2: Build all three platforms**

Run the three build commands. Expected: `** BUILD SUCCEEDED **` for each.

- [ ] **Step 3: Run the model tests**

```bash
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Check on the iPhone simulator**

1. Long-press "Hat" › **Rename** shows the current name. Change it to "Beanie" › **Save**: the list shows "Beanie" and its position does not change (renaming does not touch `updatedAt`).
2. Rename again, clear the field, **Save**: the name stays "Beanie". Rename, type something, **Cancel**: unchanged.
3. Swipe "Beanie" › **Delete**: the row stays in place while the "Delete Project?" alert shows. **Cancel**: still there. Repeat › **Delete**: it is gone.
4. Open "Scarf", go back, delete it via the context menu: the list no longer shows it. Relaunch: the app opens on the list (or "No Projects"), not on an empty counter.

- [ ] **Step 5: Check on the iPad simulator**

With a project selected and its counter showing, delete it: the detail switches to "Select a Project".

- [ ] **Step 6: Commit**

```bash
git status --short
git add Stitch/ProjectListView.swift
git commit -F - <<'EOF'
Add rename and delete for projects

Rename through a context menu alert that edits a draft name, and
delete through swipe or context menu after a confirmation. Deleting
the selected project clears the selection.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 6: Update README and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the final file layout and test command from Tasks 1–5.
- Produces: nothing.

- [ ] **Step 1: Update `README.md`**

Make each replacement below. "Old" is the exact current text; "New" replaces it.

1. Intro paragraph.

   Old:
   ```text
   Stitch keeps track of rows while knitting: one big number, one big button to add a row, and nothing else in the way.
   ```
   New:
   ```text
   Stitch keeps track of rows while knitting: a list of your projects, and for each one a big number, one big button to add a row, and nothing else in the way.
   ```

2. Status paragraph (the whole paragraph under `## Status`).

   Old:
   ```text
   MVP complete: add and remove rows, reset with confirmation, a count that persists across launches, and a layout with large tap targets that adapts to iPad. Tested on iPhone and iPad simulators; iPhone landscape and Apple Vision are not verified yet. Next up is the roadmap below.
   ```
   New:
   ```text
   MVP complete, plus multiple projects: each knitting project has its own row count (stored with SwiftData), projects can be created, renamed and deleted, and the app reopens the last project at launch. Tested on iPhone and iPad simulators; iPhone landscape and Apple Vision are not verified yet.
   ```

3. MVP scope, last bullet.

   Old:
   ```text
   - The count persists across app launches (`@AppStorage` / `UserDefaults`)
   ```
   New:
   ```text
   - The count persists across app launches
   ```

4. Tech stack table, persistence row.

   Old:
   ```text
   | Persistence | `@AppStorage` for the MVP; SwiftData planned for multiple projects |
   ```
   New:
   ```text
   | Persistence | SwiftData (`KnittingProject`); `@AppStorage` only for the selected project |
   ```

5. Tech stack table, add a row directly after `| Dependencies | None |`:
   ```text
   | Tests | Swift Testing (`StitchTests` target) |
   ```

6. Project structure: replace the tree inside the code block with:
   ```text
   Stitch/
   ├── Stitch/
   │   ├── MyApp.swift            # App entry point (@main), SwiftData container
   │   ├── ContentView.swift      # Split view: project list + counter
   │   ├── ProjectListView.swift  # List, create, rename, delete
   │   ├── NewProjectView.swift   # New-project sheet
   │   ├── CounterView.swift      # Counter for one project
   │   ├── KnittingProject.swift  # SwiftData model and counting rules
   │   ├── PreviewData.swift      # In-memory sample data for previews
   │   ├── AppIcon.icon/          # App icon (Icon Composer)
   │   └── Assets.xcassets/       # Accent color
   ├── StitchTests/               # Swift Testing tests for the model
   ├── Design/AppIcon/            # Source SVG layers for the icon
   └── Stitch.xcodeproj/
   ```

7. Roadmap.

   Old:
   ```text
   - [ ] Multiple knitting projects, each with its own counter (SwiftData)
   ```
   New:
   ```text
   - [x] Multiple knitting projects, each with its own counter (SwiftData)
   ```

- [ ] **Step 2: Update `CLAUDE.md`**

1. Project section.

   Old:
   ```text
   The MVP is one screen with one counter: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert, and the count persisted via `@AppStorage`. Anything beyond that is out of scope until the MVP ships.
   ```
   New:
   ```text
   The app keeps a list of knitting projects (SwiftData), each with its own counter screen: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert.
   ```

2. Build and run, first sentence.

   Old:
   ```text
   No dependencies, no package manager, no test target yet. The scheme `Stitch` is auto-generated (not shared).
   ```
   New:
   ```text
   No dependencies, no package manager. The scheme `Stitch` builds the app and runs the `StitchTests` Swift Testing target.
   ```

3. Build and run, test sentence.

   Old:
   ```text
   If a test target is added later, run a single test with `-only-testing:<TestTarget>/<TestClass>/<testMethod>` on `xcodebuild test`.
   ```
   New (a paragraph, a `bash` code block, and a sentence):
   ````text
   Run the model tests (on the iOS simulator):

   ```bash
   xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
   ```

   Run a single test by appending its name, e.g. `-only-testing:StitchTests/KnittingProjectTests/removeRowAtZeroChangesNothing()`.
   ````

4. Architecture, first bullet (starts with `- Entry point is`). Replace that whole bullet with these four bullets:
   ```text
   - `MyApp` attaches `.modelContainer(for: KnittingProject.self)`. `ContentView` is a `NavigationSplitView` that owns the `@Query` (sorted by `updatedAt`, newest first) and the selection, saved as a UUID string under `@AppStorage("selectedProjectID")` so the last project reopens at launch. `ProjectListView` lists, creates (via `NewProjectView`), renames and deletes projects; `CounterView` is the counter for one project.
   - `KnittingProject` owns the counting rules: `rowCount` changes only through `addRow()`, `removeRow()` and `reset()`, which also update `updatedAt`. Views call these methods rather than setting properties.
   - `CounterView` takes a plain `let project` (SwiftData models are observable). `ContentView` gives it `.id(project.id)` so switching projects creates a fresh counter instead of firing the haptic.
   - Previews use `PreviewData.container` (in-memory sample projects). Create a `ModelContainer` before instantiating a model, in previews and in tests.
   ```

5. Platforms bullet.

   Old:
   ```text
   (see the idle-timer code in `ContentView`)
   ```
   New:
   ```text
   (see the idle-timer code in `CounterView`)
   ```

6. Add this bullet directly after the platforms bullet:
   ```text
   - `StitchTests` is hosted in the app, builds for the same platforms, and also uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
   ```

7. Conventions, persistence bullet.

   Old:
   ```text
   - Persistence: `@AppStorage` for the MVP; SwiftData is planned for multiple projects — don't introduce it early.
   ```
   New:
   ```text
   - Persistence: SwiftData for project data; `@AppStorage` only for small preferences such as the selected project.
   ```

- [ ] **Step 3: Check the docs**

```bash
grep -nE "rowCount\"|no test target|don't introduce it early|idle-timer code in .ContentView" README.md CLAUDE.md
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git status --short
git add README.md CLAUDE.md
git commit -F - <<'EOF'
Document multiple projects, SwiftData and tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

## Spec coverage

| Spec section | Task |
| --- | --- |
| Data model and rules | 1 |
| Testing (target setup, model tests, round trip) | 1 |
| Previews with in-memory data | 2 |
| `CounterView` with plain `let project` | 2 |
| Container, split view, list, empty state, new-project sheet | 3 |
| Start fresh (old `rowCount` unused) | 3 |
| Selection persisted with `@AppStorage`, launch behavior, stale ID | 4 |
| Rename with draft, delete with confirmation, clear selection | 5 |
| Docs (README, CLAUDE.md) | 6 |

Order differs slightly from the spec: the counter moves into `CounterView` (Task 2) before the list exists (Task 3), so every commit leaves a working app.
