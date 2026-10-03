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
