import SwiftData
import SwiftUI

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
