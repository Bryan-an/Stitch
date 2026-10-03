import Foundation
import SwiftData
import Testing
@testable import Stitch

struct KnittingProjectTests {
    // SwiftData needs a container for a model type before instances of it are
    // created. Swift Testing makes a fresh suite instance (and so a fresh
    // in-memory store) for every test.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: KnittingProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProject(named name: String = "Scarf") -> KnittingProject {
        let project = KnittingProject(name: name)
        container.mainContext.insert(project)
        return project
    }

    @Test func newProjectStartsAtZero() {
        let project = makeProject(named: "Scarf")

        #expect(project.name == "Scarf")
        #expect(project.rowCount == 0)
        #expect(project.createdAt == project.updatedAt)
    }

    @Test func addRowIncrementsAndUpdatesTimestamp() {
        let project = makeProject()
        let before = Date.now

        project.addRow()

        #expect(project.rowCount == 1)
        // Two timestamps can be identical, so this is >= rather than >.
        #expect(project.updatedAt >= before)
    }

    @Test func removeRowDecrements() {
        let project = makeProject()
        project.addRow()
        project.addRow()

        project.removeRow()

        #expect(project.rowCount == 1)
    }

    @Test func removeRowAtZeroChangesNothing() {
        let project = makeProject()
        let updatedAt = project.updatedAt

        project.removeRow()

        #expect(project.rowCount == 0)
        #expect(project.updatedAt == updatedAt)
    }

    @Test func resetSetsCountToZero() {
        let project = makeProject()
        project.addRow()
        project.addRow()
        project.addRow()

        project.reset()

        #expect(project.rowCount == 0)
    }

    @Test func fetchSortsMostRecentlyUpdatedFirst() throws {
        let scarf = makeProject(named: "Scarf")
        let hat = makeProject(named: "Hat")
        let socks = makeProject(named: "Socks")
        scarf.updatedAt = Date(timeIntervalSince1970: 100)
        hat.updatedAt = Date(timeIntervalSince1970: 300)
        socks.updatedAt = Date(timeIntervalSince1970: 200)
        try container.mainContext.save()

        let descriptor = FetchDescriptor<KnittingProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let names = try container.mainContext.fetch(descriptor).map(\.name)

        #expect(names == ["Hat", "Socks", "Scarf"])
    }
}
