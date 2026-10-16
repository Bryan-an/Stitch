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

    // Insert first, then change: a model must belong to a context before it
    // is used. The defaults keep the older tests' calls unchanged.
    private func makeProject(
        named name: String = "Scarf",
        rows: Int = 0,
        target: Int? = nil
    ) -> KnittingProject {
        let project = KnittingProject(name: name)
        container.mainContext.insert(project)
        project.setTarget(target)
        for _ in 0..<rows {
            project.addRow()
        }
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

    @Test func newProjectHasNoTarget() {
        let project = makeProject()

        #expect(project.targetRowCount == nil)
    }

    @Test func setTargetStoresTarget() {
        let project = makeProject()

        project.setTarget(120)
        #expect(project.targetRowCount == 120)

        project.setTarget(80)
        #expect(project.targetRowCount == 80)
    }

    // One test function, run once per argument. Each run gets its own suite
    // instance, so its own in-memory store.
    @Test(arguments: [nil, 0, -5] as [Int?])
    func setTargetBelowOneRemovesTarget(target: Int?) {
        // Start with a target, otherwise there would be nothing to remove.
        let project = makeProject(target: 120)

        project.setTarget(target)

        #expect(project.targetRowCount == nil)
    }

    @Test func setTargetChangesNeitherRowCountNorUpdatedAt() {
        let project = makeProject(rows: 42)
        // A fixed date makes the check exact instead of depending on timing.
        let updatedAt = Date(timeIntervalSince1970: 100)
        project.updatedAt = updatedAt

        project.setTarget(120)
        project.setTarget(nil)

        #expect(project.rowCount == 42)
        #expect(project.updatedAt == updatedAt)
    }

    @Test func resetKeepsTarget() {
        let project = makeProject(rows: 3, target: 120)

        project.reset()

        #expect(project.rowCount == 0)
        #expect(project.targetRowCount == 120)
    }

    @Test func savedTargetIsReadByAnotherContext() throws {
        let scarf = makeProject(named: "Scarf", rows: 42, target: 120)
        let hat = makeProject(named: "Hat")
        try container.mainContext.save()

        // mainContext would hand back the same objects, still holding their
        // values in memory. A new context has its own instances, so it can
        // only see what was actually stored.
        let otherContext = ModelContext(container)
        let fetched = try otherContext.fetch(FetchDescriptor<KnittingProject>())
        let savedScarf = try #require(fetched.first(where: { $0.name == "Scarf" }))
        let savedHat = try #require(fetched.first(where: { $0.name == "Hat" }))

        #expect(savedScarf !== scarf)
        #expect(savedScarf.rowCount == 42)
        #expect(savedScarf.targetRowCount == 120)
        #expect(savedHat !== hat)
        #expect(savedHat.targetRowCount == nil)
    }
}
