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
