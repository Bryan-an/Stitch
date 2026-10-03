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
