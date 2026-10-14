import Foundation

public struct PlaygroundSettings: Codable, Equatable {
    public var gravity: Double = 18
    public var power: Double = 1
    public var zoom: Double = 1
    public var water = true
    public var inverted = true
    public var debug = false
    public var haptics = true
    public init() {}

    public var validated: Self {
        var value = self
        value.gravity = gravity.isFinite ? min(26, max(10, gravity)) : 18
        value.power = power.isFinite ? min(1.3, max(0.7, power)) : 1
        value.zoom = zoom.isFinite ? min(1.6, max(0.85, zoom)) : 1
        return value
    }
}

public final class PlaygroundSettingsStore {
    private let defaults: UserDefaults
    private let key = "elementalcube.settings.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> PlaygroundSettings {
        guard let data = defaults.data(forKey:key),
              let value = try? JSONDecoder().decode(PlaygroundSettings.self,from:data) else {
            return PlaygroundSettings()
        }
        return value.validated
    }
    public func save(_ value: PlaygroundSettings) {
        if let data = try? JSONEncoder().encode(value.validated) { defaults.set(data,forKey:key) }
    }
}
