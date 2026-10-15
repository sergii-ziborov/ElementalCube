import Foundation

/// Local rule versions stored with a birth receipt. A nil policy is deliberate:
/// this prototype has no trained controller or official observation schema.
public struct ReleaseManifest:Codable,Equatable {
    public let schema:Int
    public let physics,forms,inheritance,balance,controls,maps,rigidBodies:String
    public let policy:String?,observations:String?
    public static let current=Self(schema:1,physics:"sim-v14.1",forms:FormCatalog.version,inheritance:InheritedGenome.version,balance:"progression-v14.1",controls:"gestures-v10.1",maps:"three-maps-v10.1",rigidBodies:"Box2D-3.1.1",policy:nil,observations:nil)
}
