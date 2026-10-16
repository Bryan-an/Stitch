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
    // nil means no target. When set, it is always at least 1.
    private(set) var targetRowCount: Int?

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

    // The only way to change the target. 0, negatives and nil remove it.
    // It does not touch updatedAt, which tracks changes to the count.
    func setTarget(_ target: Int?) {
        if let target, target >= 1 {
            targetRowCount = target
        } else {
            targetRowCount = nil
        }
    }

    var isTargetReached: Bool {
        guard let targetRowCount else { return false }
        return rowCount >= targetRowCount
    }

    // 0...1 toward the target, or nil without one. Capped at 1 past the target.
    // Converted to Double first: Int division would truncate (60 / 120 is 0).
    var progress: Double? {
        guard let targetRowCount else { return nil }
        return min(Double(rowCount) / Double(targetRowCount), 1)
    }
}
