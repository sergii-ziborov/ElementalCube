import Foundation

/// Last distinct press wins; releasing it resumes any direction still held.
public struct MovementInput {
    private var held: [(source: String, direction: Float)] = []
    public init() {}
    public var value: Float { held.last?.direction ?? 0 }
    public mutating func press(source: String, direction: Float) {
        guard direction.isFinite, direction != 0 else { return }
        let normalized: Float = direction < 0 ? -1 : 1
        if let previous = held.first(where: { $0.source == source }), previous.direction == normalized {
            return // Key repeats and finger movement must not steal priority.
        }
        release(source:source)
        held.append((source,normalized))
    }
    public mutating func release(source: String) { held.removeAll { $0.source == source } }
    public mutating func clear() { held.removeAll(keepingCapacity:true) }
}
