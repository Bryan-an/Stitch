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
