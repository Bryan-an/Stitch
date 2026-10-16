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

    /// One project with `rows` counted toward `target`, in its own in-memory
    /// store. Keep the returned container alive while the project is used.
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
