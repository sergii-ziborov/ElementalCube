import Foundation

public enum WorldMap:String,CaseIterable,Codable,Identifiable {
    case shore,glacier,forge
    public var id:String { rawValue }
    public var name:String {
        switch self { case .shore:return "Тихий берег";case .glacier:return "Хрустальные высоты";case .forge:return "Сад тёплых искр" }
    }
    public var symbol:String {
        switch self { case .shore:return "leaf";case .glacier:return "snowflake";case .forge:return "flame" }
    }
    public var subtitle:String {
        switch self {
        case .shore:return "Мост, вода и первый маленький секрет."
        case .glacier:return "Скользкие ступени ведут к облакам."
        case .forge:return "Тёплые камни, огоньки и глубокие проходы."
        }
    }
    public var crystalOffset:Int { Self.allCases.firstIndex(of:self)!*100 }
    public var definition:WorldDefinition { WorldDefinition(self) }
}

/// All collision geometry, rewards and landmarks belong to the selected map.
/// The central basin retains its conservative fluid grid and bridge anchors.
public struct WorldDefinition {
    public let map:WorldMap
    public let bounds=WorldLayout.bounds
    public let spawn=Vec(2.7,0.75)
    public let goal:Vec
    public let platforms:[Platform]
    public let shards:[Vec]
    public let campfires:[FireSource]
    public var terrain:[Platform] { platforms.enumerated().compactMap { i,p in !p.boundary && i != 5 && i != 6 ? p : nil } }
    public var floorHeight:Float { WorldLayout.floorHeight }
    public init(_ map:WorldMap) {
        self.map=map
        var shared=Array(WorldLayout.platforms.prefix(7))
        // A 0.60 m clearance. Water can flatten to 0.56 m; solid cubes use
        // the two stepping stones and the upper route instead.
        let passage=[Platform(18.9,0.9,1,0.4),Platform(20.3,1.95,1,0.4),Platform(23,1.9,2.5,2.6)]
        switch map {
        case .shore:
            shared=WorldLayout.platforms.filter { !(abs($0.x-23)<0.01 && $0.height<0.12) }
            shared.append(contentsOf:passage)
            shared.append(Platform(23,3.255,0.9,0.11))
            goal=WorldLayout.goal;shards=WorldLayout.shards
            campfires=[FireSource(Vec(23,3.5),radius:0.95)]
        case .glacier:
            shared=shared.map { Platform($0.x,$0.y,$0.width,$0.height,surface:$0.boundary ? .stone : .ice,boundary:$0.boundary) }
            shared.append(contentsOf:passage)
            for i in 0..<9 {
                shared.append(Platform(27+Float(i)*3,Float(i+1)*1.2-0.25,2.4,0.5,surface:.ice))
            }
            shared.append(Platform(56,10.7,6,0.6,surface:.ice))
            shared.append(Platform(-8,2,4,0.5,surface:.ice))
            shared.append(Platform(-13,3.3,4,0.5,surface:.ice))
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(57,11)
            shards=[Vec(6.2,1.6),Vec(12,2.1),Vec(19,1.8),Vec(23,4.6),Vec(28,2.5),Vec(34,4.8),Vec(40,7.2),Vec(46,9.6),Vec(52,12),Vec(57,12.3),Vec(-8,3.5),Vec(-13,4.8)]
            campfires=[]
        case .forge:
            shared.append(contentsOf:passage)
            for i in 0..<10 {
                shared.append(Platform(27+Float(i)*3.2,-Float(i+1)*1.8-0.3,2.5,0.6))
            }
            shared.append(Platform(62,-18.3,8,0.6))
            shared.append(Platform(37,-3.7,3,0.5,surface:.wood))
            shared.append(Platform(44,-6.7,3.4,0.5,surface:.wood))
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(64,-18)
            shards=[Vec(6.2,1.6),Vec(12,2.1),Vec(23,4.6),Vec(27,-0.2),Vec(33.4,-3.8),Vec(39.8,-7.4),Vec(46.2,-11),Vec(52.6,-14.6),Vec(59,-16.4),Vec(64,-16.7),Vec(37,-2.2),Vec(44,-5.2)]
            campfires=[FireSource(Vec(23,3.5),radius:0.95),FireSource(Vec(36.6,-6.9),radius:0.8),FireSource(Vec(52.6,-15.9),radius:0.9)]
        }
        platforms=shared
    }
}
