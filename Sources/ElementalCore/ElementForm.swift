import Foundation

public enum ElementForm: String, CaseIterable, Identifiable {
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
        case .ice: return "Постепенно замораживает воду в радиусе 1,45 м во все стороны. Лёд растёт от касания и соседних льдин, не запечатывая куб внутри. Покрывает холодным скользким инеем дерево и камень. После ухода тепло возвращается и лёд медленно тает."
        case .water: return "Мягкое водное тело держится на поверхности. Пассивная волна помогает плыть и снижает сопротивление воды. Стрелки задают направление, прыжок помогает выйти на берег. Шерсть намокает и слипается."
        case .air: return "Скользит без качения. Активная подушка поддерживает над водой и сушей, пока хватает маны. При прыжке подушка отпускает куб, затем ловит у поверхности. Ветер особенно сильно влияет на лёгкое тело и его волокна."
        case .stone: return "Тяжёлое тело без шерсти тонет и проходит по дну под мостом. Пассивная устойчивость помогает идти против сопротивления воды. Под центральной опорой спрятана глубинная реликвия. Вода не поддержит камень у поверхности — выходи по склону."
        case .fire: return "Поджигает траву и деревянный ящик при контакте, оставляя обугленный след. В воде пламя испаряет воду вокруг куба: уровень падает, расходуются здоровье и мана. Небольшой водоём можно осушить, если хватит здоровья. Без экипированной способности вода быстро гасит огонь."
        }
    }
    public var density: Float {
        switch self { case .ice: return 0.75; case .water: return 0.82; case .air: return 0.18; case .stone: return 3.1; case .fire: return 0.52 }
    }
    public var manaCost: Float {
        switch self { case .ice: return 2.2; case .water: return 0.6; case .air: return 1.6; case .stone: return 0.4; case .fire: return 1.8 }
    }
    public var hasFur: Bool { self == .ice || self == .water || self == .air }
}

public struct IceCell: Equatable {
    public var center: Vec
    public var size: Float
    public var cold: Float
    public var solid: Bool
}
public struct MaterialPatch {
    public var x: Float
    public var frost: Float = 0
    public var fuel: Float = 1
    public var burning: Float = 0
}
public struct FrostMark {
    public var position: Vec
    public var cold: Float = 0
}
