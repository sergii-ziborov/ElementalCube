import Foundation

/// Current morphology, distinct from the five reusable physical body meshes.
/// An ancestor's channels never expand this profile.
public enum CreatureForm:String,Codable,CaseIterable,Identifiable {
    case fire,water,ice,air,stone,steam,emberGale,frostGale,lava,clay,dust,cloud,boiler
    public var id:String { rawValue }
    public init(_ base:ElementForm) { self=Self(rawValue:base.rawValue)! }
    public var name:String {
        switch self {
        case .fire:return "Огонёк";case .water:return "Капля";case .ice:return "Льдинка";case .air:return "Ветерок";case .stone:return "Камушек"
        case .steam:return "Парик";case .emberGale:return "Жарокрыл";case .frostGale:return "Инеевик";case .lava:return "Лавовый голем"
        case .clay:return "Глиняш";case .dust:return "Пыльник";case .cloud:return "Туманчик";case .boiler:return "Горнило"
        }
    }
    public var body:ElementForm {
        switch self {
        case .fire,.emberGale:return .fire
        case .water,.steam,.clay:return .water
        case .ice,.frostGale:return .ice
        case .air,.dust,.cloud:return .air
        case .stone,.lava,.boiler:return .stone
        }
    }
    public var style:HybridStyle? {
        switch self {
        case .steam:return .steam;case .emberGale:return .ember;case .frostGale:return .blizzard;case .lava:return .magma
        case .clay:return .mud;case .dust:return .dust;case .cloud:return .mist;case .boiler:return .boiler
        default:return nil
        }
    }
    public var secondaryVisual:ElementForm? {
        switch self {
        case .steam,.lava:return .fire;case .emberGale,.frostGale:return .air
        case .clay,.dust:return .stone;case .cloud,.boiler:return .water
        default:return nil
        }
    }
    public var freezesOnContact:Bool { self == .ice || self == .frostGale }
    public var burnsOnContact:Bool { self == .fire || self == .emberGale || self == .lava }
    public var heatImmune:Bool { [.fire,.stone,.steam,.emberGale,.lava,.boiler].contains(self) }
    public var compresses:Bool { self == .water || self == .clay }
    public var masteryChannel:MasteryChannel {
        switch self { case .ice,.frostGale:return .cold;case .fire,.emberGale,.lava:return .heat;case .water,.steam,.clay:return .water;case .air,.dust,.cloud:return .air;case .stone,.boiler:return .mineral }
    }
    public var properties:[String] {
        var values=["Базовый прыжок"]
        if body == .stone { values.append("Тяжёлое минеральное тело") }
        if body == .water { values.append("Плавучее тело") }
        if body == .air { values.append("Воздушная подушка") }
        if freezesOnContact { values.append("Морозное касание") }
        if burnsOnContact { values.append("Поджигание горючих поверхностей") }
        if heatImmune { values.append("Защита от обычного огня") }
        if compresses { values.append("Проход через низкие щели") }
        return values
    }
    /// Explicit aliases for already shipped experimental appearances. Existing
    /// records keep their physical progress; only a new generation uses v2.
    static func legacy(_ body:ElementForm,style:HybridStyle?)->Self {
        switch style {
        case .steam,.geyser:return .steam;case .magma:return .lava;case .mud:return .clay
        case .ember:return .emberGale;case .blizzard:return .frostGale;case .mist:return .cloud;case .dust:return .dust;case .boiler:return .boiler
        default:return Self(body)
        }
    }
}

public enum MasteryChannel:String,Codable {
    case cold,heat,water,air,mineral
    public var name:String { switch self { case .cold:return "холод";case .heat:return "жар";case .water:return "вода";case .air:return "воздух";case .mineral:return "минерал" } }
}

public enum FormCatalog {
    public static let version="forms-v2.1"
    public struct Reaction:Equatable {
        public let a:CreatureForm,b:CreatureForm,result:CreatureForm
        public init(_ a:CreatureForm,_ b:CreatureForm,_ result:CreatureForm) { self.a=a;self.b=b;self.result=result }
    }
    public static let reactions:[Reaction]=[
        .init(.fire,.water,.steam),.init(.fire,.air,.emberGale),.init(.fire,.stone,.lava),
        .init(.water,.air,.cloud),.init(.water,.stone,.clay),.init(.air,.stone,.dust),
        .init(.ice,.fire,.steam),.init(.ice,.air,.frostGale),.init(.ice,.water,.water),.init(.ice,.stone,.clay),
        .init(.steam,.fire,.fire),.init(.steam,.water,.water),.init(.steam,.stone,.boiler),.init(.steam,.air,.cloud),
        .init(.emberGale,.fire,.fire),.init(.emberGale,.air,.air),
        .init(.lava,.fire,.fire),.init(.lava,.stone,.stone),.init(.lava,.water,.stone),
        .init(.boiler,.steam,.steam),.init(.boiler,.stone,.stone),.init(.boiler,.fire,.lava)
    ]
    public static func result(_ a:CreatureForm,_ b:CreatureForm)->CreatureForm? {
        if a==b { return a }
        return reactions.first { ($0.a==a && $0.b==b) || ($0.a==b && $0.b==a) }?.result
    }
}
