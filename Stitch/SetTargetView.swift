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
