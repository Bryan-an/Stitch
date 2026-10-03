import Foundation
import SwiftData

/// Sample data for SwiftUI previews. Lives in memory only and never touches
/// the real store.
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: KnittingProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            // Created in this order so "Scarf" ends up the most recently updated.
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

    /// The most recently updated sample project ("Scarf", 42 rows).
    static var sampleProject: KnittingProject {
        let descriptor = FetchDescriptor<KnittingProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let project = try? container.mainContext.fetch(descriptor).first else {
            fatalError("The preview container has no projects")
        }
        return project
    }
}
