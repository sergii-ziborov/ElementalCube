import Foundation

public enum ElementForm: String, CaseIterable, Identifiable, Codable {
    case ice, water, air, stone, fire
    public var id: String { rawValue }
    public var name: String {
        switch self { case .ice: return "Льдинка"; case .water: return "Капля"; case .air: return "Ветерок"; case .stone: return "Камушек"; case .fire: return "Огонёк" }
    }
    public var symbol: String {
        switch self { case .ice: return "snowflake"; case .water: return "drop.fill"; case .air: return "wind"; case .stone: return "mountain.2.fill"; case .fire: return "flame.fill" }
    }
    public var ability: String {
        switch self { case .ice: return "Морозное касание"; case .water: return "Лёгкая волна"; case .air: return "Воздушная подушка"; case .stone: return "Тяжёлая поступь"; case .fire: return "Живое пламя" }
    }
    public var explanation: String {
        switch self {
        case .ice: return "При первом касании воды сразу создаёт под кубом ледяную опору и не даёт погрузиться. Чем дольше куб стоит, тем толще становится лёд: холод постепенно идёт от места контакта в стороны и в глубину. Толстая корка растёт медленнее тонкой. Лёд не возникает внутри тела. Касание покрывает дерево и камень скользким инеем; вдали от холода лёд медленно тает."
        case .water: return "Живой куб из воды с мягкими углами, без шерсти. Пассивная волна помогает плыть и снижает сопротивление воды. Касание карты задаёт направление, прыжок помогает выйти на берег. В низком проходе водное тело сплющивается, сохраняя объём."
        case .air: return "Скользит без качения. Воздушная подушка автоматически поддерживает над водой и сушей, без расхода маны. При прыжке подушка отпускает куб, затем ловит у поверхности. Ветер особенно сильно влияет на лёгкое тело и его завихрения."
        case .stone: return "Тяжёлое тело без шерсти тонет и проходит по дну под мостом. Пассивная устойчивость помогает идти против сопротивления воды. Под подвесным мостом спрятана глубинная реликвия. Вода не поддержит камень у поверхности — выходи по склону."
        case .fire: return "Поджигает траву и деревянный ящик при контакте, оставляя обугленный след. В воде пламя испаряет воду вокруг куба: уровень падает, расходуется здоровье. Небольшой водоём можно осушить, если хватит здоровья. К огню эта форма невосприимчива; испарение воды всё равно расходует здоровье."
        }
    }
    public var density: Float {
        switch self { case .ice: return 0.75; case .water: return 0.82; case .air: return 0.18; case .stone: return 3.1; case .fire: return 0.52 }
    }
    public var manaCost:Float { 0 }
    public var fireImmune:Bool { self == .fire || self == .stone }
    public var hasFur: Bool { self == .ice }
}

public struct IceCell: Equatable {
    public var center: Vec
    public var size: Float
    public var height:Float = 0.4
    public var cold: Float
    public var solid: Bool
}
public struct MaterialPatch {
    public var surface:Surface = .grass
    public var x: Float
    public var y:Float = 0
    public var frost: Float = 0
    public var fuel: Float = 1
    public var burning: Float = 0
}
public struct FrostMark {
    public var position: Vec
    public var cold: Float = 0
}

public struct FireSource {
    public var position:Vec
    public var radius:Float
    public var intensity:Float
    public init(_ position:Vec,radius:Float=1,intensity:Float=1) { self.position=position;self.radius=radius;self.intensity=intensity }
}
