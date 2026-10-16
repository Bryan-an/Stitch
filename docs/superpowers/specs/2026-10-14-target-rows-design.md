# Target row count

Status: implemented
Date: 2026-10-14

## Goal

Let each knitting project have an optional target row count (the number of rows in the pattern), show progress toward it on the counter screen, and signal when it is reached. Counting keeps going past the target. This is the "Target row count" half of the README roadmap item "Target row count and pattern-repeat reminders".

## Decisions

| Topic | Decision |
| --- | --- |
| Scope | Target rows only. Pattern-repeat reminders are a separate feature. |
| Storage | Approach A: an optional property on `KnittingProject` (`nil` = no target). Rejected: a plain `Int` with 0 meaning "no target" (magic value), and a separate `Goal` model (relationship and real migration for one number). |
| Setting it | A toolbar button on the counter screen opens a sheet. |
| At the target | A visual signal and a success haptic; counting continues past it and **+** is never disabled. |
| Reset | Keeps the target. |
| Tests | Swift Testing, with parameterized tests (`@Test(arguments:)`) where several inputs share one rule. |
| Haptics check | No physical iPhone is available, so the success haptic is built but recorded as not verified (M14 is not run). |

## Section 1: Model (approved)

Additions to `Stitch/KnittingProject.swift`:

```swift
// nil means no target. When set, it is always at least 1.
private(set) var targetRowCount: Int?

func setTarget(_ target: Int?) {
    if let target, target >= 1 {
        targetRowCount = target
    } else {
        targetRowCount = nil
    }
}

var isTargetReached: Bool {
    guard let targetRowCount else { return false }
    return rowCount >= targetRowCount
}

// 0...1 toward the target, or nil without one. Capped at 1 past the target.
var progress: Double? {
    guard let targetRowCount else { return nil }
    return min(Double(rowCount) / Double(targetRowCount), 1)
}
```

Rules:

- The pattern matches `rowCount`: `private(set)` plus one method that enforces the rule. A target of 0 or less cannot be stored; `setTarget(0)`, `setTarget(-5)` and `setTarget(nil)` remove it.
- `setTarget` does not change `updatedAt`, which still means "last time the count changed", so setting a target does not move the project up the list.
- Existing saved projects get no target: SwiftData migrates them automatically (lightweight migration) to `targetRowCount == nil`. To be checked on the simulator with existing data.
- `isTargetReached` and `progress` are computed, not stored, so they can never fall out of step with `rowCount` and `targetRowCount`.

Tests promised in section 1 (`StitchTests/KnittingProjectTests.swift`):

- A new project has no target, `isTargetReached` is false and `progress` is `nil`.
- `setTarget(120)` stores 120. `setTarget(0)`, `setTarget(-5)` and `setTarget(nil)` remove the target.
- `isTargetReached` is false below the target, true exactly at it and true above it.
- `progress` is 0.5 halfway and 1.0 past the target, never above 1.
- `setTarget` does not change `updatedAt`.

## Section 2: Counter screen and target sheet (approved)

```
42 / 120                         120 / 120 or past it
┌──────────────────────────┐     ┌──────────────────────────┐
│ Scarf             (target)│     │ Scarf             (target)│
│            42             │     │           125             │
│   78 to go   target 120   │     │  ✓ Target reached         │
│   [=========---------]    │     │     5 past target         │
│                           │     │   [==================]    │  green
│  [ − ]   [      +      ]  │     │  [ − ]   [      +      ]  │
│          Reset            │     │          Reset            │
└──────────────────────────┘     └──────────────────────────┘
```

### Counter screen (`Stitch/CounterView.swift`)

- A **Set Target** toolbar button (**Edit Target** once a target exists) opens the sheet. Without a target the screen looks exactly as it does today.
- Under the count: "N to go" and "target T", plus a `ProgressView`. At the target: a green seal with **Target reached**; past it, "N past target". **+** is never disabled.
- VoiceOver reads the count and the status as one element, e.g. "Row count, 42 of 120 rows, 78 to go".
- **Reset** keeps the target. The alert adds "Your target is kept." only when a target is set.
- Haptics: still one `.sensoryFeedback`. It returns `.success` on the step that crosses the target upward and the existing impacts otherwise. Success plays on every upward crossing (120 → 119 → 120 fires again); playing it once per target would need another stored property. Setting or lowering a target never fires because `rowCount` does not change; switching projects does not fire thanks to the existing `.id(project.id)`.

```swift
.sensoryFeedback(trigger: project.rowCount) { oldCount, newCount in
    if let target = project.targetRowCount, oldCount < target, newCount >= target {
        return .success
    }
    return newCount > oldCount ? .impact(weight: .medium) : .impact(weight: .light)
}
```

### Target sheet (new file `Stitch/SetTargetView.swift`)

- Same Cancel/Save toolbar as `NewProjectView`. Opens at `.presentationDetents([.medium])`.
- One number field, prefilled with the current target and focused when the sheet opens (`@FocusState` set in `onAppear`). iPhone shows the number pad; Return (`onSubmit`) saves.
- Digits only, at most 4 (9999 rows), filtered in `onChange`: pasted "120 rows" becomes 120 and "1,200" becomes 1200. Save is disabled while the field is empty or 0.
- Live footer: "You are at 42, so 78 to go." or "You are already at 130, so this target is reached. You can keep counting."
- **Remove Target** appears only when a target exists, with no confirmation (the count is kept).
- The draft is seeded in `init` with `State(initialValue:)` so the field never shows empty before the saved value.

### New concepts

`onChange(of:)` to clean input, `@FocusState` to focus the field, `State(initialValue:)` in `init`, `presentationDetents`, `ProgressView(value:)`, and `accessibilityElement(children: .ignore)` to read the count and status as one VoiceOver phrase.

### Previews

New helper `PreviewData.projectWithTarget(rows:target:)`. `CounterView` gets three previews (no target, 42/120, 120/120); `SetTargetView` gets two (new target, edit target).

### Cut from section 2 (can come back later)

A second Save above the number pad, bounce and scale animations, a UIKit VoiceOver announcement on reaching the target, a `.help` tooltip.

## Section 3: Testing, order of work and docs (approved)

### Automated tests

All in `StitchTests/KnittingProjectTests.swift`. The helper grows to `makeProject(named:rows:target:)` with defaults (`rows: 0`, `target: nil`), so existing calls still compile. It inserts the project first, then sets the target, then adds the rows.

Added with the stored target (order of work, step 2):

| Test | Checks |
| --- | --- |
| `newProjectHasNoTarget()` | `targetRowCount` is `nil`. |
| `setTargetStoresTarget()` | `setTarget(120)` stores 120; a later `setTarget(80)` replaces it (the Edit path). |
| `setTargetBelowOneRemovesTarget(target:)` | Parameterized over `[nil, 0, -5] as [Int?]`. Starts from target 120, otherwise removing from `nil` would test nothing. |
| `setTargetChangesNeitherRowCountNorUpdatedAt()` | 42 rows, `updatedAt` fixed to `Date(timeIntervalSince1970: 100)` so the check is exact; `setTarget(120)` then `setTarget(nil)` leave both unchanged. Also backs the haptic rule (setting a target never changes `rowCount`). |
| `resetKeepsTarget()` | 3 rows, target 120, `reset()`: count 0, target still 120. Backs the "Your target is kept." alert. |
| `savedTargetIsReadByAnotherContext()` | Scarf (42 rows, target 120) and Hat (no target), `mainContext.save()`, then fetch through a new `ModelContext(container)` and check the fetched objects are different instances with the saved values. A fetch on `mainContext` returns the same in-memory objects and would pass even if the value were never stored. |

Added with the computed properties (step 3):

| Test | Checks |
| --- | --- |
| `projectWithoutTargetIsNotReachedAndHasNoProgress()` | No target, even after 5 rows: `isTargetReached` false, `progress` `nil`. |
| `isTargetReachedAtOrPastTarget(rows:target:expected:)` | Parameterized: (119, 120, false), (120, 120, true), (121, 120, true), (0, 1, false), (1, 1, true). |
| `progressIsFractionCappedAtOne(rows:target:expected:)` | Parameterized: (0, 120, 0.0), (60, 120, 0.5), (120, 120, 1.0), (180, 120, 1.0). All exact in binary floating point, so `==` with no tolerance. |
| `targetBelowCountIsAlreadyReached()` | 50 rows, `setTarget(30)`: reached, `progress == 1.0`. Model state only; the sheet's footer text is checked in M5. |
| `targetIsReachedAgainAfterRemovingARow()` | 120 of 120, `removeRow()` → not reached, `addRow()` → reached again. Model side of "every upward crossing plays success". |

Result: 6 existing + 11 new test functions.

Checked before implementation, in a scratch Swift package on macOS with the app's settings (Swift 5 mode, default `MainActor` isolation, `MemberImportVisibility`):

- Adding `targetRowCount: Int?` to the model opens a store written by the current model with no `VersionedSchema`: rows keep their values, the target reads `nil`, and SwiftData adds the column in place.
- `savedTargetIsReadByAnotherContext()` really guards storage: with `targetRowCount` marked `@Transient` it fails, while a `mainContext` fetch returns the same object still holding 120 and would pass.
- `@Test(arguments: [nil, 0, -5] as [Int?])` and arrays of 3-tuples mapped onto three parameters compile and run one case each, and every case gets its own suite instance and store, also without `@Suite`.
- The section 2 sketch, split into its real files, builds for iOS Simulator, macOS and visionOS with `xcodebuild`. The only fix needed: `SetTargetView.swift` must `import SwiftData` as well as `SwiftUI`, because its previews use `.modelContainer`.

Not unit tested, because section 2 keeps this logic inline in the views: the haptic rule, the digit filter, the footer and status strings, focus on appear, the VoiceOver summary and the reset message variant. Neither is the migration of an existing on-disk store (the test store starts empty in memory). The manual checks cover them.

### Manual checks

Use the iOS 27.0 simulators only; the iOS 26.5 copies with the same names cannot run the app. There is no iPhone SE simulator, so iPhone 17e is the smallest, and no visionOS simulator runtime, so visionOS is compile-only. The iOS Simulator plays no haptics.

For the runtime counter checks, set a small target such as 3 in the sheet so every state takes a few taps; the previews keep 120.

| # | Where | Check |
| --- | --- | --- |
| M1 | iPhone Air sim (iOS 27.0), before any code | On current `main`, create Scarf (5 rows) and Hat (0). Press Home, stop. Do not erase or uninstall: this store is the migration test. No `xcodebuild` command in this plan uses this simulator, so nothing migrates the store before M2. |
| M2 | Same iPhone Air sim, after step 2 | Run the new build over the same install: no crash at launch, Scarf 5 and Hat 0 kept, both counters open. |
| M3 | Xcode canvas | The previews render: the two sheet previews from step 4, the three counter previews from step 7. Light and dark at step 11. |
| M4 | iPhone 17 sim, target 3 | 0/3: "3 to go", "target 3", empty bar. 2/3: "1 to go". 3/3: seal, green bar, no "past target" line. 4/3: "1 past target", **+** enabled. 4 → 2 → 3 goes back and forth. |
| M5 | iPhone 17 sim, software keyboard (Device Hub: Device › Keyboard › Simulate Hardware Keyboard off) | Field focused with the number pad on open. Save disabled for empty, 0 and 0000. Paste (text put on the simulator clipboard with `xcrun simctl pbcopy booted`): "120 rows" gives 120, "1,200" gives 1200, "1234567" gives 1234, "00012" gives 0001 and saves 1 (the 4-digit cap), "0012" saves 12. Footer at count 5: empty shows the prompt; 6 shows "You are at 5, so 1 to go."; 5 and 3 show the "already reached" text. Cancel discards; Edit Target opens prefilled; Remove Target is absent when there is no target, and when present closes with no confirmation and keeps the count; the toolbar button's accessibility label switches between Set Target and Edit Target (iOS shows only its icon). |
| M6 | iPhone 17 sim | Reset with a target: message ends with "Your target is kept." and the target stays; without a target the sentence is absent. |
| M7 | iPhone 17 sim | Persistence: set a target, press Home, stop, relaunch: same project, count and target (before step 7, the target shows as Edit Target and the prefilled field). |
| M8 | iPhone 17 sim with Simulate Hardware Keyboard on | Typing "12a 3" gives 123 and non-ASCII digits are dropped; Return saves a valid target and does nothing when empty. The software number pad has no Return key, so Save is the iPhone path. |
| M9 | iPad sim | Split view shows the status; switching projects shows each project's own target; the sheet fits and Save and the footer stay reachable. |
| M10 | iPhone 17e sim | Target 9999 at 0 rows ("9999 to go" next to "target 9999", the widest status line) in portrait and at the largest accessibility text size: nothing clipped. The sheet with the number pad up, an existing target (Remove Target shown) and the long "already reached" footer, at default and largest text: everything reachable. Landscape: record the baseline (no target) and with a target; README already lists landscape as unverified, and fixing it is out of scope. A 4-digit count needs a throwaway, uncommitted preview on the 17e canvas device, `PreviewData.projectWithTarget(rows: 9999, target: 9999)`. |
| M11 | Accessibility Inspector on the sim | The count is one element labeled "Row count". Value: no target, the bare count; below target "2 of 3 rows, 1 to go"; at target "3 of 3 rows, target reached"; past it "4 of 3 rows, target reached". Add row and Remove row stay separate. |
| M12 | Native Mac | Toolbar button, sheet at a usable size (detents may not apply), Return saves, letters dropped. |
| M13 | visionOS | Build only (`generic/platform=visionOS Simulator`). |
| M14 | Physical iPhone on iOS 27, if available | Needs a Team and a real bundle identifier (README, "Running on a physical device"); set them in Xcode and do not commit the resulting `project.pbxproj` change. With target 3: 2 → 3 success; 3 → 4 medium; 4 → 3 light; 2 → 3 success again; Reset light; saving or removing a target plays nothing; switching to a project already at or past its target plays nothing. VoiceOver reads the counter as in M11. Without a device, M14 is recorded as unverified. |

Every step runs the iOS build and `KnittingProjectTests`; steps that touch views also build macOS and visionOS.

### Order of work

Each step builds, runs and is committed on its own. Steps 2 and 3 are test-first: write the tests, see the build fail, then add the code. The sheet comes before the status display, so every UI step after step 4 can be tried in the running app.

1. **Spec and plan:** this document and the implementation plan. Commits: "Add design spec for target row count", "Add implementation plan for target row count".
2. **Stored target (tests first):** M1 first. `targetRowCount` and `setTarget(_:)` plus the step 2 tests; then M2. Concepts: an optional stored property and SwiftData lightweight migration; what a `ModelContext` is and why a second one proves the save; parameterized tests (`@Test(arguments:)`: one function, one run per argument, each with a fresh store). Commit: "Add an optional row target to KnittingProject".
3. **Reached and progress (tests first):** `isTargetReached` and `progress` plus the step 3 tests. Concepts: computed properties as derived state; `Double` conversion to avoid integer division; parameterized tests with tuples mapped onto several parameters. Commit: "Add target progress to KnittingProject".
4. **Target sheet:** new `SetTargetView.swift` importing `SwiftUI` and `SwiftData`: form, seeded draft, focus on appear, Cancel and Save, `onSubmit`, medium detent, and a fixed footer for now. Add `PreviewData.projectWithTarget(rows:target:)` for the "Edit target" preview. M3 for the two sheet previews. Concepts: `State(initialValue:)` in `init`, `@FocusState`, `presentationDetents`, `@Environment(\.dismiss)`. Commit: "Add SetTargetView for entering a row target".
5. **Open the sheet:** toolbar button (Set Target / Edit Target) and `.sheet` in `CounterView`. First runtime change: set, edit and cancel a target; M7. Concepts: a sheet driven by a `Bool` the parent owns; the sheet edits the same model object, so no binding is needed. Commit: "Open the target sheet from the counter".
6. **Input rules:** digit filter, live footer, Remove Target; M5 and M8. Concepts: `onChange(of:)` cleaning input as you type; a section shown only when a target exists. Commit: "Filter target input and allow removing the target".
7. **Status under the count:** `countDisplay` and `targetStatus`, and the three named counter previews (the current unnamed `#Preview` becomes "No target"); M3 for those previews and M4. Concepts: `ProgressView(value:)` and display state derived from the model. Commit: "Show target progress under the row count".
8. **VoiceOver summary:** `accessibilityElement(children: .ignore)`, label and `rowCountSummary`; M11. Concept: one accessibility element for the count and its status. Commit: "Read the row count and target status as one element".
9. **Reset message:** the alert variant; M6. Commit: "Say the target is kept when resetting".
10. **Success haptic:** the crossing rule in `.sensoryFeedback`. No physical iPhone is available, so M14 is not run and the haptic is recorded as not verified. Concept: a feedback closure that compares the old and new values. Commit: "Play a success haptic when the target is reached".
11. **Platform pass and docs:** M3 in dark mode, M9, M10, M12 and M13; only fixes these checks force. Then the doc edits below, stating only what was verified. Commit: "Document the target row count".

### Docs

- `README.md`: Status (line 13) mentions the optional target and lists what is still unverified, including the success haptic (no physical iPhone). The project tree gets `│   ├── SetTargetView.swift    # Sheet to set or remove a target` right after the `CounterView.swift` line. The roadmap line "Target row count and pattern-repeat reminders" splits into a ticked "Target row count" and an open "Pattern-repeat reminders".
- `CLAUDE.md`: the project paragraph mentions the target and that Reset keeps it. The `KnittingProject` bullet adds that `targetRowCount` is `private(set)`, changes only through `setTarget(_:)` and does not touch `updatedAt`, and that `isTargetReached` and `progress` are computed. The `CounterView` bullet adds that its toolbar opens `SetTargetView`. The previews bullet adds `projectWithTarget(rows:target:)`. New note: new stored properties should be optional (verified with `targetRowCount`, M1 and M2); a non-optional one needs its default declared on the property itself, not only in `init`, is not verified here, and must be checked against a store from the previous build. New note: the Simulator plays no haptics.
- This spec's status becomes "implemented", and the appendix is described as the original sketch, with the shipped files as the source of truth. The multiple-projects spec's status (line 3) was updated to "implemented" in the same commit.

### Out of scope

- Pattern-repeat reminders.
- Showing the target in the project list.
- Notifications, celebrations or a VoiceOver announcement when the target is reached.
- Multiple targets per project, or targets imported from a pattern.
- Moving the inline view logic (digit filter, haptic rule, strings) into testable helpers, a UI test target or snapshot tests.
- A `VersionedSchema` or migration plan.
- Localizing the new strings (comes with the String Catalog).
- Landscape layout fixes and Dynamic Type for the 160 pt number.
- Sharing the Xcode scheme (there is no `Stitch.xcodeproj/xcshareddata/xcschemes`; Xcode generates the `Stitch` scheme).
- A model-level upper bound (the 4-digit cap is a UI rule only).

## Appendix: approved section 2 code sketch

The original sketch from the design. The shipped files in `Stitch/` are the source of truth.

```swift
import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ---- Stub of Stitch/KnittingProject.swift with the section-1 additions ----

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

    // nil means no target. When set, it is always at least 1.
    private(set) var targetRowCount: Int?

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

    func setTarget(_ target: Int?) {
        if let target, target >= 1 {
            targetRowCount = target
        } else {
            targetRowCount = nil
        }
    }

    var isTargetReached: Bool {
        guard let targetRowCount else { return false }
        return rowCount >= targetRowCount
    }

    var progress: Double? {
        guard let targetRowCount else { return nil }
        return min(Double(rowCount) / Double(targetRowCount), 1)
    }
}

// ---- Stub of Stitch/PreviewData.swift with projectWithTarget added ----

enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: KnittingProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
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

    static var sampleProject: KnittingProject {
        let descriptor = FetchDescriptor<KnittingProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let project = try? container.mainContext.fetch(descriptor).first else {
            fatalError("The preview container has no projects")
        }
        return project
    }

    /// One project with `rows` counted toward `target`, in its own in-memory store.
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
}

// ---- Stitch/CounterView.swift (full file) ----

struct CounterView: View {
    let project: KnittingProject

    @State private var isShowingResetAlert = false
    @State private var isShowingTargetSheet = false

    private let buttonHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            countDisplay

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingTargetSheet = true
                } label: {
                    Label(targetButtonTitle, systemImage: "target")
                }
            }
        }
        .sensoryFeedback(trigger: project.rowCount) { oldCount, newCount in
            // Success only on the step that crosses the target. Setting a target never changes rowCount, so it never fires.
            if let target = project.targetRowCount, oldCount < target, newCount >= target {
                return .success
            }
            return newCount > oldCount ? .impact(weight: .medium) : .impact(weight: .light)
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
            if project.targetRowCount == nil {
                Text("The row count will go back to 0.")
            } else {
                Text("The row count will go back to 0. Your target is kept.")
            }
        }
        .sheet(isPresented: $isShowingTargetSheet) {
            SetTargetView(project: project)
        }
    }

    // The count and, when a target is set, its status. VoiceOver reads it as one element.
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Row count")
        .accessibilityValue(rowCountSummary)
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

    private var targetButtonTitle: LocalizedStringKey {
        project.targetRowCount == nil ? "Set Target" : "Edit Target"
    }

    private var rowCountSummary: LocalizedStringKey {
        guard let target = project.targetRowCount else {
            return "\(project.rowCount)"
        }
        if project.isTargetReached {
            return "\(project.rowCount) of \(target) rows, target reached"
        }
        return "\(project.rowCount) of \(target) rows, \(target - project.rowCount) to go"
    }
}

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

// ---- Stitch/SetTargetView.swift (new file, full content) ----

struct SetTargetView: View {
    let project: KnittingProject

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    // Text, because the field can be empty or half-typed. `newTarget` turns it into a number.
    @State private var draft: String

    // 4 digits (9999 rows) is more than any pattern needs.
    private let maxDigits = 4

    init(project: KnittingProject) {
        self.project = project
        // Seeded here, so the field never shows empty before the saved value.
        _draft = State(initialValue: project.targetRowCount.map { String($0) } ?? "")
    }

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
