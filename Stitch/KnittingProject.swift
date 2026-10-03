import Foundation
import SwiftData

@Model
final class KnittingProject {
    var id: UUID
    var name: String
    // Only the methods below change the count, so it can never go negative
    // and `updatedAt` is never forgotten.
    private(set) var rowCount: Int
    var createdAt: Date
    // The last time the count changed. Renaming does not update it.
    var updatedAt: Date

    init(name: String) {
        let now = Date.now
        id = UUID()
        self.name = name
        rowCount = 0
        createdAt = now
        updatedAt = now
    }

    func addRow() {
        rowCount += 1
        updatedAt = .now
    }

    func removeRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        updatedAt = .now
    }

    func reset() {
        rowCount = 0
        updatedAt = .now
    }
}
