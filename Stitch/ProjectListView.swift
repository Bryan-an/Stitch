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
