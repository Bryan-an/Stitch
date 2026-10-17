# Target Row Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each knitting project have an optional target row count, show progress toward it under the count, and play a success haptic when the target is reached, while counting continues past it.

**Architecture:** `KnittingProject` gets `private(set) var targetRowCount: Int?`, one writer `setTarget(_:)` and two computed properties (`isTargetReached`, `progress`), all covered by Swift Testing. A new `SetTargetView` sheet sets, edits or removes the target; `CounterView` opens it from the toolbar and shows the status, the VoiceOver summary, the reset message variant and the haptic rule. View logic stays inline, as approved, and is checked by hand.

**Tech Stack:** Swift 5 language mode, SwiftUI, SwiftData, Swift Testing, Xcode 27 SDKs.

**Spec:** `docs/superpowers/specs/2026-10-14-target-rows-design.md` (sections 1 to 3 approved; the appendix holds the approved code sketch this plan follows). Tasks 1 to 10 are steps 2 to 11 of the spec's order of work; step 1 is the spec and this plan.

## Global Constraints

- Deployment targets: iOS 27.0, macOS 27.0, visionOS 27.0. Every task must build for iOS Simulator, macOS and visionOS Simulator.
- Build settings that affect code: Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (each file imports every module whose members it uses; `SwiftData` for `.modelContainer`, `Foundation` for `Date`).
- UIKit does not exist on macOS: UIKit calls stay inside `#if canImport(UIKit)`. `keyboardType` is unavailable on macOS, so it stays inside `#if os(iOS)` (approved; this also leaves visionOS on the default keyboard).
- Files in `Stitch/` and `StitchTests/` are picked up automatically. Never edit `project.pbxproj`.
- Every view keeps a working `#Preview`. Previews use in-memory containers only.
- English for code, identifiers, comments, UI strings and commit messages. UI strings exactly as written in this plan.
- No third-party dependencies. No `VersionedSchema`.
- `setTarget(_:)` never changes `updatedAt` or `rowCount`. Reset keeps the target. **+** is never disabled.
- Tests use parameterized tests (`@Test(arguments:)`) where several inputs share one rule (developer's choice).
- No physical iPhone is available: the haptic (M14) is not run and is documented as not verified.
- Use only the iOS 27.0 simulators; the iOS 26.5 copies with the same names cannot run the app. **Do not erase, reset or uninstall the app from any simulator.** The iPhone Air simulator (iOS 27.0, UDID `6F03EA22-E031-4563-869A-9DC35237165C`) holds the migration test store from Task 1 until Task 1's last step; no `xcodebuild` command in this plan targets it.
- Xcode 27 replaces Simulator.app with Device Hub. Home: click the Home button below the device bezel, or choose Controls › Home. Keyboard: Device › Keyboard › Simulate Hardware Keyboard (off means the software keyboard and number pad appear). To paste text into the simulator, put it on the simulator's clipboard with `printf '%s' 'TEXT' | xcrun simctl pbcopy booted`, then long-press the field and choose Paste.
- When checking persistence, go Home before stopping the app (SwiftData autosave).
- On iOS a toolbar `Label` shows only its icon, so the Set Target / Edit Target title is not visible; it is the button's accessibility label (checked in Task 7). In the simulator, tell the states apart by what the sheet shows.
- Before each commit, run `git status --short` and stage only the files the task names.
- Commit messages are imperative, sentence case, no prefix, and end with these two lines (the first names the model that runs the plan; Opus 5.5 wrote it):

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze
```

Commands used throughout (run from the repo root). Builds must end with `** BUILD SUCCEEDED **`, tests with `** TEST SUCCEEDED **`:

```bash
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'platform=macOS' build
xcodebuild -project Stitch.xcodeproj -scheme Stitch -destination 'generic/platform=visionOS Simulator' build
xcodebuild test -project Stitch.xcodeproj -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:StitchTests/KnittingProjectTests
```

"Three builds" below means the first three commands. `xcodebuild test` prints no Swift Testing summary, only one `Test case ... passed` line per run, so a parameterized test adds one line per argument; the counts below give both.

## Review Focus

Inputs and conditions the spec implies but no unit test can reach (the logic is inline in views). Each has a manual check in the task that owns the code:

1. **Pasted text in the target field** ("120 rows", "1,200", more than 4 digits, leading zeros): only digits survive, at most 4, so "00012" becomes "0001" and saves 1. Checked in Task 5, Step 4 (M5).
2. **Target equal to the current count:** the sheet footer says the target is reached, and the counter shows "Target reached" with no "0 past target" line. Checked in Task 5, Step 4 (footer) and Task 6, Step 6 (counter, M4).
3. **A store saved by the version before this change:** existing projects open with their counts and no target, with no crash. Checked in Task 1, Steps 1 and 9 (M1, M2).
4. **Switching projects while one has a target:** each counter shows its own project's target, never the previous one's. Checked in Task 10, Step 2 (M9).
5. **Large numbers and large text on the smallest iPhone:** "9999 to go" next to "target 9999", and the sheet with the number pad up, stay readable at the largest accessibility text size. Checked in Task 10, Step 2 (M10).

---

### Task 1: Stored target and `setTarget(_:)`, tests first

**Files:**
- Modify: `StitchTests/KnittingProjectTests.swift`
- Modify: `Stitch/KnittingProject.swift`

**Interfaces:**
- Consumes: the existing `KnittingProject` (`init(name:)`, `addRow()`, `removeRow()`, `reset()`, `rowCount`, `updatedAt`).
- Produces: `private(set) var targetRowCount: Int?` and `func setTarget(_ target: Int?)` on `KnittingProject`; test helper `makeProject(named: String = "Scarf", rows: Int = 0, target: Int? = nil) -> KnittingProject`.

Concepts to explain while doing this task: an optional stored property means "no value" without a magic number, and SwiftData adds it to existing stores automatically (lightweight migration); a `ModelContext` is a scratchpad of objects, so a second context proves what was really saved; a parameterized test is one function run once per argument, each run with a fresh suite instance and so a fresh store.

- [ ] **Step 1: Create the migration test store (M1)**

On the current code, before any change. In Xcode, choose the destination **iPhone Air** under iOS 27.0 and press ⌘R. In the app, create a project "Scarf" and tap **+** 5 times, then create a project "Hat" with 0 rows. Go Home (Home button below the bezel, or Controls › Home), wait 5 seconds, then stop the app in Xcode (⌘.). Do not erase or uninstall anything on this simulator: this store is what Step 9 checks.

Then switch the Xcode destination back to **iPhone 17**. Until Step 9, never press ⌘R or ⌘U with iPhone Air selected, because that would install the new build and migrate the store early; run tests only with the test command.

- [ ] **Step 2: Extend the test helper**

In `StitchTests/KnittingProjectTests.swift`, replace the helper:

```swift
    private func makeProject(named name: String = "Scarf") -> KnittingProject {
        let project = KnittingProject(name: name)
        container.mainContext.insert(project)
        return project
    }
```

with:

```swift
    // Insert first, then change: a model must belong to a context before it
    // is used. The defaults keep the older tests' calls unchanged.
    private func makeProject(
        named name: String = "Scarf",
        rows: Int = 0,
        target: Int? = nil
    ) -> KnittingProject {
        let project = KnittingProject(name: name)
        container.mainContext.insert(project)
        project.setTarget(target)
        for _ in 0..<rows {
            project.addRow()
        }
        return project
    }
```

- [ ] **Step 3: Write the failing tests**

Add these tests at the end of `KnittingProjectTests`, after `fetchSortsMostRecentlyUpdatedFirst()` and before the struct's closing brace:

```swift

    @Test func newProjectHasNoTarget() {
        let project = makeProject()

        #expect(project.targetRowCount == nil)
    }

    @Test func setTargetStoresTarget() {
        let project = makeProject()

        project.setTarget(120)
        #expect(project.targetRowCount == 120)

        project.setTarget(80)
        #expect(project.targetRowCount == 80)
    }

    // One test function, run once per argument. Each run gets its own suite
    // instance, so its own in-memory store.
    @Test(arguments: [nil, 0, -5] as [Int?])
    func setTargetBelowOneRemovesTarget(target: Int?) {
        // Start with a target, otherwise there would be nothing to remove.
        let project = makeProject(target: 120)

        project.setTarget(target)

        #expect(project.targetRowCount == nil)
    }

    @Test func setTargetChangesNeitherRowCountNorUpdatedAt() {
        let project = makeProject(rows: 42)
        // A fixed date makes the check exact instead of depending on timing.
        let updatedAt = Date(timeIntervalSince1970: 100)
        project.updatedAt = updatedAt

        project.setTarget(120)
        project.setTarget(nil)

        #expect(project.rowCount == 42)
        #expect(project.updatedAt == updatedAt)
    }

    @Test func resetKeepsTarget() {
        let project = makeProject(rows: 3, target: 120)

        project.reset()

        #expect(project.rowCount == 0)
        #expect(project.targetRowCount == 120)
    }

    @Test func savedTargetIsReadByAnotherContext() throws {
        let scarf = makeProject(named: "Scarf", rows: 42, target: 120)
        let hat = makeProject(named: "Hat")
        try container.mainContext.save()

        // mainContext would hand back the same objects, still holding their
        // values in memory. A new context has its own instances, so it can
        // only see what was actually stored.
        let otherContext = ModelContext(container)
        let fetched = try otherContext.fetch(FetchDescriptor<KnittingProject>())
        let savedScarf = try #require(fetched.first(where: { $0.name == "Scarf" }))
        let savedHat = try #require(fetched.first(where: { $0.name == "Hat" }))

        #expect(savedScarf !== scarf)
        #expect(savedScarf.rowCount == 42)
        #expect(savedScarf.targetRowCount == 120)
        #expect(savedHat !== hat)
        #expect(savedHat.targetRowCount == nil)
    }
```

- [ ] **Step 4: Run the tests to see them fail**

Run the test command. Expected: the build fails with errors like `value of type 'KnittingProject' has no member 'setTarget'` and `has no member 'targetRowCount'`. A missing member stops the whole test target from compiling, so the six older tests do not run either; that is the "red" state.

- [ ] **Step 5: Add the stored property**

In `Stitch/KnittingProject.swift`, after these lines:

```swift
    // The last time the count changed. Renaming does not update it.
    var updatedAt: Date
```

add:

```swift
    // nil means no target. When set, it is always at least 1.
    private(set) var targetRowCount: Int?
```

`init(name:)` does not change: an optional stored property starts as `nil`.

- [ ] **Step 6: Add `setTarget(_:)`**

In the same file, after `reset()`:

```swift
    func reset() {
        rowCount = 0
        updatedAt = .now
    }
```

add:

```swift

    // The only way to change the target. 0, negatives and nil remove it.
    // It does not touch updatedAt, which tracks changes to the count.
    func setTarget(_ target: Int?) {
        if let target, target >= 1 {
            targetRowCount = target
        } else {
            targetRowCount = nil
        }
    }
```

- [ ] **Step 7: Run the tests to see them pass**

Run the test command. Expected: `** TEST SUCCEEDED **`. 12 test functions pass (6 older, 6 new), shown as 14 `Test case ... passed` lines because `setTargetBelowOneRemovesTarget(target:)` runs 3 times. Xcode's Test navigator shows the 12 functions.

- [ ] **Step 8: Run the three builds**

Expected: `** BUILD SUCCEEDED **` for iOS Simulator, macOS and visionOS.

- [ ] **Step 9: Check the migration (M2)**

In Xcode, choose **iPhone Air** (iOS 27.0) again and press ⌘R: this installs the new build over the store from Step 1. Expected: no crash at launch, Scarf shows 5 and Hat shows 0, and both counters open. If the app crashes at launch, copy the error from the Xcode console and stop; do not erase the simulator.

- [ ] **Step 10: Commit**

```bash
git status --short
git add Stitch/KnittingProject.swift StitchTests/KnittingProjectTests.swift
git commit -m "Add an optional row target to KnittingProject" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 2: `isTargetReached` and `progress`, tests first

**Files:**
- Modify: `StitchTests/KnittingProjectTests.swift`
- Modify: `Stitch/KnittingProject.swift`

**Interfaces:**
- Consumes: `targetRowCount`, `setTarget(_:)`, `makeProject(named:rows:target:)` from Task 1.
- Produces: `var isTargetReached: Bool` (false without a target) and `var progress: Double?` (nil without a target, otherwise `min(rowCount / target, 1)`).

Concepts: computed properties are derived state, worked out on every read, so they can never fall out of step with the stored values; `Double` conversion before dividing, because `Int` division truncates (`60 / 120` is `0`); tuple arguments in a parameterized test map onto several parameters.

- [ ] **Step 1: Write the failing tests**

Add at the end of `KnittingProjectTests`, after `savedTargetIsReadByAnotherContext()`:

```swift

    @Test func projectWithoutTargetIsNotReachedAndHasNoProgress() {
        let project = makeProject(rows: 5)

        #expect(!project.isTargetReached)
        #expect(project.progress == nil)
    }

    // Each tuple becomes one run: (rows, target, expected).
    @Test(arguments: [
        (119, 120, false),
        (120, 120, true),
        (121, 120, true),
        (0, 1, false),
        (1, 1, true),
    ])
    func isTargetReachedAtOrPastTarget(rows: Int, target: Int, expected: Bool) {
        let project = makeProject(rows: rows, target: target)

        #expect(project.isTargetReached == expected)
    }

    // Every expected value is exact in binary floating point, so == is safe.
    @Test(arguments: [
        (0, 120, 0.0),
        (60, 120, 0.5),
        (120, 120, 1.0),
        (180, 120, 1.0),
    ])
    func progressIsFractionCappedAtOne(rows: Int, target: Int, expected: Double) {
        let project = makeProject(rows: rows, target: target)

        #expect(project.progress == expected)
    }

    @Test func targetBelowCountIsAlreadyReached() {
        let project = makeProject(rows: 50)

        project.setTarget(30)

        #expect(project.targetRowCount == 30)
        #expect(project.isTargetReached)
        #expect(project.progress == 1.0)
    }

    @Test func targetIsReachedAgainAfterRemovingARow() {
        let project = makeProject(rows: 120, target: 120)

        project.removeRow()
        #expect(!project.isTargetReached)

        project.addRow()
        #expect(project.isTargetReached)
    }
```

- [ ] **Step 2: Run the tests to see them fail**

Run the test command. Expected: build fails with `value of type 'KnittingProject' has no member 'isTargetReached'` and `has no member 'progress'`.

- [ ] **Step 3: Add the computed properties**

In `Stitch/KnittingProject.swift`, after `setTarget(_:)` and before the class's closing brace, add:

```swift

    var isTargetReached: Bool {
        guard let targetRowCount else { return false }
        return rowCount >= targetRowCount
    }

    // 0...1 toward the target, or nil without one. Capped at 1 past the target.
    // Converted to Double first: Int division would truncate (60 / 120 is 0).
    var progress: Double? {
        guard let targetRowCount else { return nil }
        return min(Double(rowCount) / Double(targetRowCount), 1)
    }
```

- [ ] **Step 4: Run the tests to see them pass**

Run the test command. Expected: `** TEST SUCCEEDED **`. 17 test functions pass (6 older, 11 new), shown as 26 `Test case ... passed` lines (the three parameterized tests run 3 + 5 + 4 times).

- [ ] **Step 5: Run the three builds**

Expected: `** BUILD SUCCEEDED **` three times.

- [ ] **Step 6: Commit**

```bash
git status --short
git add Stitch/KnittingProject.swift StitchTests/KnittingProjectTests.swift
git commit -m "Add target progress to KnittingProject" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 3: `SetTargetView` sheet and preview helper

**Files:**
- Create: `Stitch/SetTargetView.swift`
- Modify: `Stitch/PreviewData.swift`

**Interfaces:**
- Consumes: `targetRowCount`, `setTarget(_:)`, `rowCount`; `PreviewData.container` and `PreviewData.sampleProject`.
- Produces: `struct SetTargetView: View` with `init(project: KnittingProject)`; `static func projectWithTarget(rows: Int, target: Int) -> (container: ModelContainer, project: KnittingProject)` on `PreviewData`.

Concepts: `State(initialValue:)` in `init` seeds the draft once per view identity, so the field opens with the saved target; `@FocusState` focuses the field when the sheet appears; `presentationDetents([.medium])` asks for a half-height sheet; `@Environment(\.dismiss)` closes it. The field is a `String`, not an `Int`, because it can be empty or half-typed. `keyboardType` exists only on UIKit-based platforms and not on macOS, so it sits inside `#if os(iOS)`, a platform check like the `#if canImport(UIKit)` already in `CounterView`.

- [ ] **Step 1: Add the preview helper**

In `Stitch/PreviewData.swift`, after the `sampleProject` property and before the enum's closing brace, add:

```swift

    /// One project with `rows` counted toward `target`, in its own in-memory
    /// store. Keep the returned container alive while the project is used.
    static func projectWithTarget(rows: Int, target: Int) -> (container: ModelContainer, project: KnittingProject) {
        do {
            let container = try ModelContainer(
                for: KnittingProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let project = KnittingProject(name: "Scarf")
            // Insert first, then change: the model must belong to a context.
            container.mainContext.insert(project)
            project.setTarget(target)
            for _ in 0..<rows {
                project.addRow()
            }
            return (container, project)
        } catch {
            fatalError("Could not create the preview container: \(error)")
        }
    }
```

- [ ] **Step 2: Create `Stitch/SetTargetView.swift`**

The footer is fixed for now; Task 5 makes it live and adds the digit filter and Remove Target.

```swift
import SwiftData
import SwiftUI

struct SetTargetView: View {
    let project: KnittingProject

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    // Text, because the field can be empty or half-typed. `newTarget` turns it into a number.
    @State private var draft: String

    init(project: KnittingProject) {
        self.project = project
        // Seeded here, so the field never shows empty before the saved value.
        _draft = State(initialValue: project.targetRowCount.map { String($0) } ?? "")
    }

    private var newTarget: Int? {
        guard let value = Int(draft), value >= 1 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Rows", text: $draft)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .focused($isFieldFocused)
                        .onSubmit(save)
                } header: {
                    Text("Target rows")
                } footer: {
                    Text("Type the number of rows in your pattern.")
                }
            }
            .navigationTitle("Target")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(newTarget == nil)
                }
            }
            .onAppear {
                isFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let newTarget else { return }
        project.setTarget(newTarget)
        dismiss()
    }
}

#Preview("New target") {
    SetTargetView(project: PreviewData.sampleProject)
        .modelContainer(PreviewData.container)
}

#Preview("Edit target") {
    let preview = PreviewData.projectWithTarget(rows: 42, target: 120)
    return SetTargetView(project: preview.project)
        .modelContainer(preview.container)
}
```

`import SwiftData` is needed only for the previews' `.modelContainer` (`MemberImportVisibility`).

- [ ] **Step 3: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines). The running app is unchanged: nothing presents the sheet yet.

- [ ] **Step 4: Check the previews (M3, sheet half)**

Open `SetTargetView.swift` in Xcode and show the canvas. Expected: "New target" renders with an empty field and Save disabled; "Edit target" renders with 120 in the field and Save enabled. No "Preview failed" message.

- [ ] **Step 5: Commit**

```bash
git status --short
git add Stitch/SetTargetView.swift Stitch/PreviewData.swift
git commit -m "Add SetTargetView for entering a row target" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 4: Open the sheet from the counter

**Files:**
- Modify: `Stitch/CounterView.swift`

**Interfaces:**
- Consumes: `SetTargetView(project:)` from Task 3; `targetRowCount`.
- Produces: `CounterView` state `isShowingTargetSheet`, a toolbar button titled by `targetButtonTitle` (`"Set Target"` / `"Edit Target"`), and the `.sheet`.

Concepts: the parent owns a `Bool` that drives the sheet; the sheet receives the same model object (a class), so its changes reach the counter without a binding. `targetButtonTitle` returns `LocalizedStringKey`, not `String`, so `Label` treats it as a localizable key for the String Catalog later; a string literal becomes a key automatically, and `\(value)` inside one becomes a format argument. Tasks 5 and 7 reuse this.

- [ ] **Step 1: Add the sheet state**

In `Stitch/CounterView.swift`, replace:

```swift
    @State private var isShowingResetAlert = false
```

with:

```swift
    @State private var isShowingResetAlert = false
    @State private var isShowingTargetSheet = false
```

- [ ] **Step 2: Add the toolbar button**

Replace:

```swift
        .toolbarTitleDisplayMode(.inline)
```

with:

```swift
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingTargetSheet = true
                } label: {
                    Label(targetButtonTitle, systemImage: "target")
                }
            }
        }
```

- [ ] **Step 3: Present the sheet**

Replace the end of `body`:

```swift
        } message: {
            Text("The row count will go back to 0.")
        }
    }
```

with:

```swift
        } message: {
            Text("The row count will go back to 0.")
        }
        .sheet(isPresented: $isShowingTargetSheet) {
            SetTargetView(project: project)
        }
    }

    private var targetButtonTitle: LocalizedStringKey {
        project.targetRowCount == nil ? "Set Target" : "Edit Target"
    }
```

- [ ] **Step 4: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 5: Try it on the iPhone 17 simulator**

Make sure Device › Keyboard › Simulate Hardware Keyboard is off, so the number pad appears. In Xcode choose **iPhone 17** (iOS 27.0) and press ⌘R. Open a project. Expected: the toolbar shows a new target-icon button; it opens the sheet at medium height with the field focused and the number pad up; Save is disabled while the field is empty; saving 3 closes the sheet; tapping the button again opens the sheet with 3 in the field (Edit Target); changing it and tapping Cancel keeps 3.

- [ ] **Step 6: Check persistence (M7)**

With a target saved, go Home (Home button or Controls › Home), wait 5 seconds, stop the app (⌘.), and run it again. Expected: the same project opens with its count, and tapping the toolbar button shows the saved target in the field.

- [ ] **Step 7: Commit**

```bash
git status --short
git add Stitch/CounterView.swift
git commit -m "Open the target sheet from the counter" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 5: Digit filter, live footer and Remove Target

**Files:**
- Modify: `Stitch/SetTargetView.swift`

**Interfaces:**
- Consumes: `rowCount`, `targetRowCount`, `setTarget(_:)`; the Task 3 view.
- Produces: no new names used by other tasks.

Concepts: `onChange(of:)` runs after each edit, so it can clean the text as you type; changing `draft` inside it triggers it once more, and that second run changes nothing, so it settles. A `Section` inside `if` appears only when its condition holds.

- [ ] **Step 1: Add the digit limit and the live footer text**

In `Stitch/SetTargetView.swift`, replace:

```swift
    @State private var draft: String

    init(project: KnittingProject) {
```

with:

```swift
    @State private var draft: String

    // 4 digits (9999 rows) is more than any pattern needs.
    private let maxDigits = 4

    init(project: KnittingProject) {
```

Then replace:

```swift
    private var newTarget: Int? {
        guard let value = Int(draft), value >= 1 else { return nil }
        return value
    }
```

with:

```swift
    private var newTarget: Int? {
        guard let value = Int(draft), value >= 1 else { return nil }
        return value
    }

    private var footer: LocalizedStringKey {
        guard let newTarget else {
            return "Type the number of rows in your pattern."
        }
        let remaining = newTarget - project.rowCount
        if remaining > 0 {
            return "You are at \(project.rowCount), so \(remaining) to go."
        }
        return "You are already at \(project.rowCount), so this target is reached. You can keep counting."
    }
```

- [ ] **Step 2: Filter the field and use the live footer**

Replace:

```swift
                        .onSubmit(save)
                } header: {
                    Text("Target rows")
                } footer: {
                    Text("Type the number of rows in your pattern.")
                }
            }
```

with:

```swift
                        .onSubmit(save)
                        .onChange(of: draft) { _, newValue in
                            // Keep only up to `maxDigits` ASCII digits; letters, spaces and pasted text are dropped.
                            let digits = newValue.filter { $0.isASCII && $0.isNumber }
                            draft = String(digits.prefix(maxDigits))
                        }
                } header: {
                    Text("Target rows")
                } footer: {
                    Text(footer)
                }

                if project.targetRowCount != nil {
                    Section {
                        Button("Remove Target", role: .destructive) {
                            // No confirmation: the row count is kept, so nothing is lost.
                            project.setTarget(nil)
                            dismiss()
                        }
                    }
                }
            }
```

- [ ] **Step 3: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 4: Check the sheet on the iPhone 17 simulator (M5)**

Run on **iPhone 17** (iOS 27.0) with the software keyboard (Device › Keyboard › Simulate Hardware Keyboard off). Create a new project "Test" (no target, 0 rows) and use it for this step. To paste, put each text on the simulator's clipboard from Terminal, e.g. `printf '%s' '120 rows' | xcrun simctl pbcopy booted`, then long-press the field and choose Paste. Expected:
- With no target, the sheet shows no Remove Target section.
- Save is disabled for empty, `0` and `0000`.
- Pasting `120 rows` gives `120`; `1,200` gives `1200`; `1234567` gives `1234`; `00012` gives `0001`, and saving stores 1 (the 4-digit cap; reopen the sheet: the field shows 1); `0012` saves 12.
- At a count of 5 (tap **+** 5 times first): an empty field shows "Type the number of rows in your pattern."; `6` shows "You are at 5, so 1 to go."; `5` and `3` show "You are already at 5, so this target is reached. You can keep counting."
- With a target saved, Remove Target appears; tapping it closes the sheet with no alert and keeps the count; opening the sheet again shows an empty field and no Remove Target.

- [ ] **Step 5: Check with a hardware keyboard (M8)**

Turn on Device › Keyboard › Simulate Hardware Keyboard. Open the sheet. Expected: typing `12a 3` shows `123`; Return saves a valid target and closes the sheet; with the field empty, Return does nothing. Then, in an empty field, paste non-ASCII digits (`printf '%s' '١٢٣４２' | xcrun simctl pbcopy booted`, then ⌘V): the field stays empty and Save stays disabled. Turn Simulate Hardware Keyboard back off afterwards. The software number pad has no Return key, so on iPhone the Save button is the only way to save.

- [ ] **Step 6: Commit**

```bash
git status --short
git add Stitch/SetTargetView.swift
git commit -m "Filter target input and allow removing the target" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 6: Status under the count

**Files:**
- Modify: `Stitch/CounterView.swift`

**Interfaces:**
- Consumes: `targetRowCount`, `isTargetReached`, `progress`; `PreviewData.projectWithTarget(rows:target:)` from Task 3.
- Produces: `countDisplay` (Task 7 adds accessibility to it) and `targetStatus(target:progress:)`.

Concepts: `ProgressView(value:)` takes a `Double` from 0 to 1; the status is display state derived from the model, so the view only reads it.

- [ ] **Step 1: Replace the count text with `countDisplay`**

In `body`, replace:

```swift
            Text("\(project.rowCount)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            Spacer()
```

with:

```swift
            countDisplay

            Spacer()
```

- [ ] **Step 2: Add `countDisplay` and `targetStatus`**

After `body`'s closing brace and before `targetButtonTitle`, add:

```swift

    // The count and, when a target is set, its status.
    private var countDisplay: some View {
        VStack(spacing: 12) {
            Text("\(project.rowCount)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            if let target = project.targetRowCount, let progress = project.progress {
                targetStatus(target: target, progress: progress)
            }
        }
    }

    private func targetStatus(target: Int, progress: Double) -> some View {
        VStack(spacing: 8) {
            if project.isTargetReached {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Target reached")
                }
                .font(.title2.weight(.semibold))

                if project.rowCount > target {
                    Text("\(project.rowCount - target) past target")
                        .font(.title3)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Text("\(target - project.rowCount) to go")
                        .font(.title2.weight(.semibold))
                    Text("target \(target)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }

            ProgressView(value: progress)
                .tint(project.isTargetReached ? .green : .accentColor)
                .frame(maxWidth: 280)
        }
    }
```

- [ ] **Step 3: Name the existing preview and add two more**

Replace the preview at the end of the file:

```swift
#Preview {
    NavigationStack {
        CounterView(project: PreviewData.sampleProject)
    }
    .modelContainer(PreviewData.container)
}
```

with:

```swift
#Preview("No target") {
    NavigationStack {
        CounterView(project: PreviewData.sampleProject)
    }
    .modelContainer(PreviewData.container)
}

#Preview("42 of 120") {
    let preview = PreviewData.projectWithTarget(rows: 42, target: 120)
    return NavigationStack {
        CounterView(project: preview.project)
    }
    .modelContainer(preview.container)
}

#Preview("Target reached") {
    let preview = PreviewData.projectWithTarget(rows: 120, target: 120)
    return NavigationStack {
        CounterView(project: preview.project)
    }
    .modelContainer(preview.container)
}
```

- [ ] **Step 4: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 5: Check the previews (M3, counter half)**

Expected in the canvas: "No target" looks like the app before this feature, plus the new toolbar button; "42 of 120" shows "78 to go", "target 120" and a bar about a third full; "Target reached" shows the green seal, "Target reached", a full green bar and no "past target" line.

- [ ] **Step 6: Check the counter states on the iPhone 17 simulator (M4)**

Run on **iPhone 17** (iOS 27.0). On a project at 0 rows, set target 3. Expected:
- 0 of 3: "3 to go", "target 3", empty bar. A project with no target shows no status at all.
- 1 of 3: "2 to go". 2 of 3: "1 to go".
- 3 of 3: green seal, "Target reached", full green bar, no "past target" line.
- 4 of 3: "1 past target"; **+** stays enabled.
- 4 → 2 with **−**: the seal disappears and "1 to go" returns; **+** to 3 shows Target reached again.
- Edit the target to 4 at 4 rows: Target reached with no "past target" line; edit to 2: "2 past target".

- [ ] **Step 7: Commit**

```bash
git status --short
git add Stitch/CounterView.swift
git commit -m "Show target progress under the row count" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 7: VoiceOver summary

**Files:**
- Modify: `Stitch/CounterView.swift`

**Interfaces:**
- Consumes: `countDisplay` from Task 6; `targetRowCount`, `isTargetReached`.
- Produces: `rowCountSummary: LocalizedStringKey`.

Concept: `accessibilityElement(children: .ignore)` turns the count and its status into one element, so VoiceOver reads one phrase from the label and value instead of each text separately.

- [ ] **Step 1: Make `countDisplay` one accessibility element**

Replace:

```swift
    // The count and, when a target is set, its status.
    private var countDisplay: some View {
```

with:

```swift
    // The count and, when a target is set, its status. VoiceOver reads it as one element.
    private var countDisplay: some View {
```

Then, in the same property, replace:

```swift
            if let target = project.targetRowCount, let progress = project.progress {
                targetStatus(target: target, progress: progress)
            }
        }
    }
```

with:

```swift
            if let target = project.targetRowCount, let progress = project.progress {
                targetStatus(target: target, progress: progress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Row count")
        .accessibilityValue(rowCountSummary)
    }
```

- [ ] **Step 2: Add `rowCountSummary`**

After `targetButtonTitle`, add:

```swift

    private var rowCountSummary: LocalizedStringKey {
        guard let target = project.targetRowCount else {
            return "\(project.rowCount)"
        }
        if project.isTargetReached {
            return "\(project.rowCount) of \(target) rows, target reached"
        }
        return "\(project.rowCount) of \(target) rows, \(target - project.rowCount) to go"
    }
```

- [ ] **Step 3: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 4: Check with Accessibility Inspector (M11)**

Run on **iPhone 17** (iOS 27.0). Open Xcode › Open Developer Tool › Accessibility Inspector, pick the simulator as the target and point at the count. Expected: one element labeled "Row count". Value: with no target, just the count; with target 3 at 2 rows, "2 of 3 rows, 1 to go"; at 3, "3 of 3 rows, target reached"; at 4, "4 of 3 rows, target reached". The Add row and Remove row buttons stay separate elements. Then point at the toolbar button: label "Set Target" with no target, "Edit Target" with one.

- [ ] **Step 5: Commit**

```bash
git status --short
git add Stitch/CounterView.swift
git commit -m "Read the row count and target status as one element" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 8: Reset message keeps the target

**Files:**
- Modify: `Stitch/CounterView.swift`

**Interfaces:**
- Consumes: `targetRowCount`.
- Produces: nothing new.

Concept: an alert's message builder can hold an `if`, like any view builder.

- [ ] **Step 1: Make the message depend on the target**

Replace:

```swift
        } message: {
            Text("The row count will go back to 0.")
        }
```

with:

```swift
        } message: {
            if project.targetRowCount == nil {
                Text("The row count will go back to 0.")
            } else {
                Text("The row count will go back to 0. Your target is kept.")
            }
        }
```

- [ ] **Step 2: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 3: Check on the iPhone 17 simulator (M6)**

With target 3 and a few rows, tap Reset. Expected: the message reads "The row count will go back to 0. Your target is kept."; after Reset the count is 0 and the status shows "3 to go". On a project with no target and at least one row (Reset is disabled at 0), the message is only "The row count will go back to 0."

- [ ] **Step 4: Commit**

```bash
git status --short
git add Stitch/CounterView.swift
git commit -m "Say the target is kept when resetting" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 9: Success haptic at the target

**Files:**
- Modify: `Stitch/CounterView.swift`

**Interfaces:**
- Consumes: `targetRowCount`, `rowCount`.
- Produces: nothing new.

Concept: `.sensoryFeedback(trigger:_:)` passes the old and new values of the trigger, so the closure can tell the step that crosses the target from any other step. A closure with more than one statement needs explicit `return`s.

- [ ] **Step 1: Replace the feedback closure**

Replace:

```swift
        .sensoryFeedback(trigger: project.rowCount) { oldValue, newValue in
            newValue > oldValue ? .impact(weight: .medium) : .impact(weight: .light)
        }
```

with:

```swift
        .sensoryFeedback(trigger: project.rowCount) { oldCount, newCount in
            // Success only on the step that crosses the target. Setting a target never changes rowCount, so it never fires.
            if let target = project.targetRowCount, oldCount < target, newCount >= target {
                return .success
            }
            return newCount > oldCount ? .impact(weight: .medium) : .impact(weight: .light)
        }
```

- [ ] **Step 2: Run the three builds and the tests**

Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` (17 test functions, 26 lines).

- [ ] **Step 3: Smoke check on the iPhone 17 simulator**

The Simulator plays no haptics, so this only checks nothing else changed: with target 3, counting 0 → 4, back to 2 and up to 3 again works with no crash. M14 (the real haptic check) is not run: no physical iPhone is available. Record that the haptic is not verified.

- [ ] **Step 4: Commit**

```bash
git status --short
git add Stitch/CounterView.swift
git commit -m "Play a success haptic when the target is reached" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

---

### Task 10: Platform pass and docs

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-10-14-target-rows-design.md`
- Modify: `docs/superpowers/specs/2026-10-03-multiple-projects-design.md`
- Modify (only if a check below forces a fix): `Stitch/CounterView.swift`, `Stitch/SetTargetView.swift`

**Interfaces:**
- Consumes: everything above.
- Produces: docs that match what shipped and what was verified.

- [ ] **Step 1: Previews in dark mode (M3)**

In the canvas, switch the five previews (counter: No target, 42 of 120, Target reached; sheet: New target, Edit target) to dark appearance (canvas Variants › Color Scheme Variants, or the canvas device settings). Expected: the green seal, green bar and secondary text are readable.

- [ ] **Step 2: iPad and smallest iPhone (M9, M10)**

- **iPad Pro 11-inch (M5)** simulator (iOS 27.0): the split view shows the status in the detail column; give two projects different targets and switch between them: each shows its own target; the sheet fits, and Save and the footer stay reachable.
- **iPhone 17e** simulator (iOS 27.0), portrait: set target 9999 on a project at 0 rows ("9999 to go" next to "target 9999"). Check at the default text size and at the largest accessibility size (`xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`, and `xcrun simctl ui booted content_size large` afterwards to restore it): nothing is clipped. Then tap **+** once, open the sheet with the number pad up (Simulate Hardware Keyboard off; the saved 9999 keeps Remove Target visible), replace the field with `1`, and check the long footer "You are already at 1, so this target is reached. You can keep counting.": the field, footer and Remove Target are reachable by scrolling at both text sizes.
- iPhone 17e, landscape: note what is clipped with no target and with a target, and report it in the final summary. Do not fix it here; landscape stays listed as not verified, and nothing is committed for it.
- A 4-digit count cannot be reached by tapping. To see it, temporarily add `#Preview("9999") { let preview = PreviewData.projectWithTarget(rows: 9999, target: 9999); return NavigationStack { CounterView(project: preview.project) }.modelContainer(preview.container) }` to `CounterView.swift`, view it on the iPhone 17e canvas device, then delete it. Do not commit it.

- [ ] **Step 3: Native Mac and visionOS (M12, M13)**

Run the macOS destination (My Mac) from Xcode. Expected: the toolbar shows the target button; the sheet opens at a usable size (detents may not apply); typed letters are dropped; Return saves; the counter shows the status. visionOS is build-only: the visionOS build from the three builds is the check.

- [ ] **Step 4: Fix only what the checks force**

If Steps 1 to 3 show a clipped or unreachable element on a supported layout (portrait iPhone, iPad, Mac), make the smallest fix in the view that owns it, run the three builds and the tests, and describe it in the commit message body. Landscape clipping is recorded, not fixed.

- [ ] **Step 5: Update `README.md`**

Replace line 13:

```
MVP complete, plus multiple projects: each knitting project has its own row count (stored with SwiftData), projects can be created, renamed and deleted, and the app reopens where you left off. Tested on iPhone and iPad simulators; iPhone landscape and Apple Vision are not verified yet.
```

with:

```
MVP complete, plus multiple projects and row targets: each knitting project has its own row count (stored with SwiftData) and an optional target with progress, projects can be created, renamed and deleted, and the app reopens where you left off. Tested on iPhone and iPad simulators and on the Mac; iPhone landscape, Apple Vision and the success haptic at the target (no physical iPhone yet) are not verified.
```

If Step 3 was not run, drop "and on the Mac" and list the Mac app as not verified: "iPhone landscape, the Mac app, Apple Vision and the success haptic at the target (no physical iPhone yet) are not verified."

In the project tree, after:

```
│   ├── CounterView.swift      # Counter for one project
```

add:

```
│   ├── SetTargetView.swift    # Sheet to set or remove a target
```

In the roadmap, replace:

```
- [ ] Target row count and pattern-repeat reminders
```

with:

```
- [x] Target row count
- [ ] Pattern-repeat reminders
```

- [ ] **Step 6: Update `CLAUDE.md`**

In the Project paragraph, replace:

```
each with its own counter screen: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert.
```

with:

```
each with its own counter screen: large row count, **+** (primary, largest tap target), **−** (disabled at 0), **Reset** with a confirmation alert (it keeps the target), and an optional target row count with progress, set in a sheet from the toolbar.
```

In the first Architecture bullet, replace:

```
`CounterView` is the counter for one project.
```

with:

```
`CounterView` is the counter for one project; its toolbar opens `SetTargetView` in a sheet to set, edit or remove the target.
```

Replace the `KnittingProject` bullet:

```
- `KnittingProject` owns the counting rules: `rowCount` is `private(set)` and changes only through `addRow()`, `removeRow()` and `reset()`, which also update `updatedAt`. Views call these methods rather than setting properties.
```

with:

```
- `KnittingProject` owns the counting rules: `rowCount` is `private(set)` and changes only through `addRow()`, `removeRow()` and `reset()`, which also update `updatedAt`. `targetRowCount` is `private(set)` too and changes only through `setTarget(_:)` (nil or a value below 1 removes it), which does not touch `updatedAt`; `isTargetReached` and `progress` are computed from the two. Views call these methods rather than setting properties.
```

Replace the previews bullet:

```
- Previews use `PreviewData.container` (in-memory sample projects). Create a `ModelContainer` before instantiating a model, in previews and in tests.
```

with:

```
- Previews use `PreviewData.container` (in-memory sample projects), or `PreviewData.projectWithTarget(rows:target:)`, which returns a project with a target in its own in-memory container (keep the container alive while the project is used). Create a `ModelContainer` before instantiating a model, in previews and in tests.
```

After the SwiftData autosave bullet (the one ending "press Home before stopping the app."), add:

```
- New stored properties on `KnittingProject` should be optional: SwiftData then migrates existing stores automatically (verified with `targetRowCount`). A non-optional property needs its default declared on the property itself, not only in `init`; that case is not verified here, so check any schema change against a store saved by the previous build before committing.
- The iOS Simulator plays no haptics; `.sensoryFeedback` can only be checked on a physical iPhone.
```

- [ ] **Step 7: Update the specs**

In `docs/superpowers/specs/2026-10-14-target-rows-design.md`, replace `Status: approved design, not yet implemented` with `Status: implemented`, and replace the paragraph under "## Appendix: approved section 2 code sketch" that starts with "Builds with `xcodebuild`" with:

```
The original sketch from the design. The shipped files in `Stitch/` are the source of truth.
```

In the same spec's Docs section, replace:

```
The multiple-projects spec still says "approved design, not yet implemented" (line 3); update it to "implemented" in the same commit.
```

with:

```
The multiple-projects spec's status (line 3) was updated to "implemented" in the same commit.
```

In `docs/superpowers/specs/2026-10-03-multiple-projects-design.md`, replace line 3, `Status: approved design, not yet implemented`, with `Status: implemented`.

- [ ] **Step 8: Final verification**

Run the three builds and the test command. Expected: `** BUILD SUCCEEDED **` three times and `** TEST SUCCEEDED **` with 17 test functions (26 lines). Then `git diff --stat` shows only the files listed for this task.

- [ ] **Step 9: Commit**

```bash
git status --short
git add README.md CLAUDE.md docs/superpowers/specs/2026-10-14-target-rows-design.md docs/superpowers/specs/2026-10-03-multiple-projects-design.md
git commit -m "Document the target row count" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FpgwXm7hxCxEfAvJHed3ze"
```

If Step 4 changed a view, also add that file and describe the fix in a body paragraph before the trailer lines.

---

## Spec coverage

| Spec item | Task |
| --- | --- |
| Section 1: `targetRowCount`, `setTarget(_:)`, `isTargetReached`, `progress`; `updatedAt` untouched | 1, 2 |
| Section 1: existing stores migrate to `nil` | 1 (M1, M2) |
| Section 3 tests, step 2 table | 1 |
| Section 3 tests, step 3 table | 2 |
| Section 2: sheet (field, seeded draft, focus, number pad, Save/Cancel, Return, medium detent) | 3 |
| Section 2: `PreviewData.projectWithTarget`, sheet previews | 3 |
| Section 2: toolbar Set Target / Edit Target, sheet presentation | 4 |
| Section 2: digit filter, 4-digit cap, live footer, Remove Target without confirmation | 5 |
| Section 2: status under the count, seal, past target, progress bar, **+** never disabled, counter previews | 6 |
| Section 2: VoiceOver reads count and status as one element | 7 |
| Section 2: Reset keeps the target, alert sentence only with a target | 8 (model rule tested in 1) |
| Section 2: success haptic on every upward crossing | 9 (model side tested in 2) |
| Section 3 manual checks M1 to M13 | 1, 3 to 10 (M14 not run: no physical iPhone) |
| Section 3 docs edits | 10 |
