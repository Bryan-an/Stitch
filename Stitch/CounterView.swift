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
        .sheet(isPresented: $isShowingTargetSheet) {
            SetTargetView(project: project)
        }
    }

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

    private var targetButtonTitle: LocalizedStringKey {
        project.targetRowCount == nil ? "Set Target" : "Edit Target"
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
