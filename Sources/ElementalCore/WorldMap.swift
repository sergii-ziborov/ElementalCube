import Foundation

public enum WorldMap:String,CaseIterable,Codable,Identifiable {
    case shore,glacier,forge,meadow,grotto,windridge,sanctuary
    public var id:String { rawValue }
    public var name:String {
        switch self { case .shore:return "Тихий берег";case .glacier:return "Хрустальные высоты";case .forge:return "Сад тёплых искр";case .meadow:return "Тропа мхов";case .grotto:return "Забытые гроты";case .windridge:return "Ветреный перевал";case .sanctuary:return "Древний маяк" }
    }
    public var symbol:String {
        switch self { case .shore:return "leaf";case .glacier:return "snowflake";case .forge:return "flame";case .meadow:return "tree";case .grotto:return "mountain.2";case .windridge:return "wind";case .sanctuary:return "sun.horizon" }
    }
    public var subtitle:String {
        switch self {
        case .shore:return "Мост, вода и первый маленький секрет."
        case .glacier:return "Скользкие ступени ведут к облакам."
        case .forge:return "Тёплые камни ведут к забытым гротам."
        case .meadow:return "Лесные террасы. Западная ветка к перевалу."
        case .grotto:return "Каменные своды. Восточная ветка к перевалу."
        case .windridge:return "Пути сходятся. Дальше — к древнему маяку."
        case .sanctuary:return "Последний подъём. Зажги свет в конце пути."
        }
    }
    public var crystalOffset:Int { switch self { case .shore:return 0;case .glacier:return 100;case .forge:return 200;case .meadow:return 300;case .grotto:return 400;case .windridge:return 500;case .sanctuary:return 600 } }
    public var routePosition:Vec { switch self { case .shore:return Vec(0.5,0.12);case .glacier:return Vec(0.23,0.32);case .forge:return Vec(0.77,0.32);case .meadow:return Vec(0.23,0.54);case .grotto:return Vec(0.77,0.54);case .windridge:return Vec(0.5,0.75);case .sanctuary:return Vec(0.5,0.92) } }
    public var times:RouteTimes { switch self { case .shore:return RouteTimes(90,150,240);case .glacier:return RouteTimes(90,150,240);case .forge:return RouteTimes(80,140,220);case .meadow:return RouteTimes(65,110,180);case .grotto:return RouteTimes(75,125,200);case .windridge:return RouteTimes(100,165,260);case .sanctuary:return RouteTimes(110,180,280) } }
    public var windFactor:Float { self == .windridge ? 1.6 : (self == .grotto ? 0.3 : 1) }
    public var definition:WorldDefinition { WorldDefinition(self) }
}

/// All collision geometry, rewards and landmarks belong to the selected map.
/// The central basin retains its conservative fluid grid and bridge anchors.
public struct WorldDefinition {
    public let map:WorldMap
    public let bounds=WorldLayout.bounds
    public var spawn:Vec {
        switch map {
        case .shore:return Vec(2.7,0.75)
        case .meadow:return Vec(-2,0.75)
        case .forge,.grotto:return Vec(24.5,0.75)
        case .glacier,.windridge,.sanctuary:return Vec(22.6,3.95)
        }
    }
    public let goal:Vec
    public let platforms:[Platform]
    public let shards:[Vec]
    public let coins:[Vec]
    public var obstacles:[BreakableDefinition] {
        if map == .meadow { return [BreakableDefinition(Vec(-16.6,4.85),0.7,1.1,.wood)] }
        if map == .forge { return [BreakableDefinition(Vec(23.9,3.7),0.7,1,.brick),BreakableDefinition(Vec(37,-2.9),0.7,1.1,.wood)] }
        return [BreakableDefinition(Vec(23.9,3.7),0.7,1,.brick)]
    }
    public var relicPosition:Vec? { map == .shore || map == .grotto ? Vec(12,-3.3) : nil }
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
        case .meadow:
            // Western woodland route: sub-metre rises can be climbed by a
            // starter's basic jump, without buying a movement skill.
            shared.append(contentsOf:passage)
            for i in 0..<10 { shared.append(Platform(-4.2-Float(i)*3.1,0.35+Float(i)*0.9,3.0,0.7,surface:.grass)) }
            shared.append(Platform(-35,8.95,6,0.7,surface:.grass))
            shared.append(Platform(-18,3.2,3,0.4,surface:.wood))
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(-36,9.3)
            shards=[Vec(2,1.5),Vec(-4.2,1.8),Vec(-7.3,2.7),Vec(-10.4,3.6),Vec(-13.5,4.5),Vec(-16.6,5.4),Vec(-19.7,6.3),Vec(-25.9,8.1),Vec(-32.1,9.9),Vec(-36,10.8)]
            campfires=[]
        case .grotto:
            shared.append(contentsOf:passage)
            for i in 0..<9 { shared.append(Platform(26.5+Float(i)*3,-Float(i+1)*1.5-0.35,3.1,0.7)) }
            shared.append(Platform(55,-13.85,7,0.7))
            // Optional alcoves beneath stone roofs; neither roof is a fake
            // background platform. The common pond also has a relic passage.
            for i in 0..<4 { shared.append(Platform(30+Float(i)*6,-Float(i)*3+1.8,3.3,0.7)) }
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(56,-13.5)
            shards=[Vec(6.2,1.6),Vec(12,-2.8),Vec(19,1.8),Vec(26.5,-0.1),Vec(32.5,-3.1),Vec(38.5,-6.1),Vec(44.5,-9.1),Vec(50.5,-12.1),Vec(56,-12)]
            campfires=[]
        case .windridge:
            shared.append(contentsOf:passage)
            for i in 0..<10 { shared.append(Platform(26.5+Float(i)*3,0.65+Float(i)*0.95,2.7,0.5,surface:.grass)) }
            shared.append(Platform(59,10,7,0.6,surface:.grass))
            // A lower chain offers a sheltered alternate line of approach.
            for i in 0..<4 { shared.append(Platform(29+Float(i)*5,-1.6+Float(i)*0.7,4.2,0.5,surface:.wood)) }
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(60,10.3)
            shards=[Vec(6.2,1.6),Vec(19,1.8),Vec(26.5,2.3),Vec(32.5,4.2),Vec(38.5,6.1),Vec(44.5,8),Vec(50.5,9.9),Vec(56,11.5),Vec(60,11.8),Vec(34,0.5),Vec(44,1.9)]
            campfires=[]
        case .sanctuary:
            shared.append(contentsOf:passage)
            for i in 0..<12 { shared.append(Platform(26+Float(i)*2.8,0.55+Float(i)*1.0,2.65,0.5)) }
            shared.append(Platform(62,11.6,8,0.8,surface:.grass))
            for i in 0..<3 { shared.append(Platform(34+Float(i)*7,-2.4,5.5,0.7,surface:.grass)) }
            shared.append(Platform(bounds.center.x,(WorldLayout.floorHeight+bounds.minY)/2,bounds.width,WorldLayout.floorHeight-bounds.minY))
            goal=Vec(64,12)
            shards=[Vec(6.2,1.6),Vec(19,1.8),Vec(26,2),Vec(34.4,5),Vec(42.8,8),Vec(51.2,11),Vec(59.6,13.3),Vec(64,13.5)]
            campfires=[FireSource(Vec(34,-1.8),radius:0.8)]
        }
        platforms=shared
        // Currency follows supported routes, with no invented off-map finds.
        // Distinct short chains are separate from the skill crystals.
        let suitable=shared.filter { !$0.boundary && $0.width>=2 && $0.width<12 && $0.y+$0.height/2>WorldLayout.floorHeight+0.1 }
        coins=Array(suitable.enumerated().flatMap { index,p -> [Vec] in
            let top=p.y+p.height/2
            return [Vec(p.x-0.38,top+0.85),Vec(p.x+0.38,top+0.85)]
        }.prefix(24))
    }
}
