import Foundation

public struct SkillNode:Identifiable,Equatable {
    public enum Kind:String,Codable { case passive,jump,momentum,mastery,control,affinity,doubleJump }
    public var id:String
    public var kind:Kind
    public var title:String
    public var explanation:String
    public var symbol:String
    public var cost:Int
    public var prerequisite:String?
}
public enum MonsterItem:String,Codable,CaseIterable,Identifiable {
    case travelerCharm,aetherShard,deepRelic
    public var id:String { rawValue }
    public var isEquipment:Bool { self != .aetherShard }
    public var name:String { switch self { case .travelerCharm:return "Каменный оберег";case .aetherShard:return "Эфирный кристалл";case .deepRelic:return "Сердце глубин" } }
    public var symbol:String { switch self { case .travelerCharm:return "hexagon";case .aetherShard:return "diamond.fill";case .deepRelic:return "seal.fill" } }
    public var explanation:String {
        switch self {
        case .travelerCharm:return "Стартовый оберег. Уменьшает урон от жёстких приземлений на 10%. Занимает слот талисмана."
        case .aetherShard:return "Найден в мире этим монстром. При первом сборе также даёт одно очко для его дерева навыков."
        case .deepRelic:return "Добыта каменным кубом под мостом. Уменьшает урон от приземлений на 20% и расход маны активными приёмами на 10%. Занимает слот талисмана."
        }
    }
}
public struct MonsterAncestor:Codable,Equatable {
    public var id:UUID,name:String,form:ElementForm
}
/// Progress belongs to an individual, never to a global element-type switch.
public struct MonsterRecord:Identifiable,Codable,Equatable {
    public var id:UUID
    public var name:String
    public var form:ElementForm
    public private(set) var parents:[MonsterAncestor]
    public private(set) var learned:Set<SkillNode.Kind>
    public private(set) var crystals:Set<Int>
    public private(set) var deepRelic:Bool
    public private(set) var skillPoints:Int
    public private(set) var equippedCharm:MonsterItem?
    public init(form:ElementForm,name:String?=nil,id:UUID=UUID(),parents:[MonsterAncestor]=[]) {
        self.id=id;self.name=name ?? form.name;self.form=form;self.parents=parents
        learned=[.passive];crystals=[];deepRelic=false;skillPoints=1;equippedCharm=nil
    }
    public static func offspring(_ first:Self,_ second:Self,body:ElementForm)->Self {
        Self(form:body,name:first.name+" · "+second.name,parents:[first,second].map { MonsterAncestor(id:$0.id,name:$0.name,form:$0.form) })
    }
    public func quantity(of item:MonsterItem)->Int {
        switch item { case .travelerCharm:return 1;case .aetherShard:return crystals.count;case .deepRelic:return deepRelic ? 1 : 0 }
    }
    @discardableResult public mutating func equip(_ item:MonsterItem?)->Bool {
        if let item=item,(!item.isEquipment || quantity(of:item)==0) { return false }
        equippedCharm=item;return true
    }
    public var isHybrid:Bool { !parents.isEmpty }
    public var typeName:String { isHybrid ? parents.map { $0.form.name }.joined(separator:" + ") : form.name }
    public var treeIdentity:String { id.uuidString+"/"+form.rawValue+"/"+parents.map { $0.id.uuidString }.joined(separator:"+") }
    public var tree:[SkillNode] {
        func node(_ kind:SkillNode.Kind,_ title:String,_ text:String,_ symbol:String,_ cost:Int,_ prerequisite:SkillNode.Kind?)->SkillNode {
            SkillNode(id:treeIdentity+"/"+kind.rawValue,kind:kind,title:title,explanation:text,symbol:symbol,cost:cost,prerequisite:prerequisite.map { treeIdentity+"/"+$0.rawValue })
        }
        let mobility:(String,String),mastery:(String,String),affinity:(String,String)
        switch form {
        case .ice:
            mobility=("Ледяной разбег","Предел скорости прыжка +8%.")
            mastery=("Глубокий холод","Теплопроводность морозного касания +25%: лёд быстрее нарастает в глубину и в стороны.")
            affinity=("Сердце зимы","Ещё +25% к теплопроводности и −15% к расходу маны активными приёмами.")
        case .water:
            mobility=("Упругая капля","Предел скорости прыжка +8%.")
            mastery=("Сильная волна","Предельная скорость толчка в воде +15%.")
            affinity=("Течение","Ещё +15% к пределу толчка в воде и −15% к расходу маны активными приёмами.")
        case .air:
            mobility=("Попутный ветер","Предел скорости прыжка +8%.")
            mastery=("Тихое парение","Управляемость и сила воздушной подушки +20%.")
            affinity=("Долгий полёт","Ещё +20% к управляемости подушкой и −15% к расходу маны активными приёмами.")
        case .stone:
            mobility=("Разгон валуна","Предел скорости прыжка +8%.")
            mastery=("Крепкая порода","Урон от жёстких приземлений снижен на 20%.")
            affinity=("Монолит","Ещё −20% к урону от приземлений и −15% к расходу маны активными приёмами.")
        case .fire:
            mobility=("Искра ввысь","Предел скорости прыжка +8%.")
            mastery=("Жаркое ядро","Испарение воды расходует на 15% меньше здоровья.")
            affinity=("Неугасимый","Ещё −15% к потере здоровья при испарении и −15% к расходу маны активными приёмами.")
        }
        let lineage=isHybrid ? " · "+parents.map(\.form.name).joined(separator:"/") : ""
        return [node(.passive,form.ability+lineage,form.explanation,form.symbol,0,nil),
                node(.jump,"Направленный прыжок", "Открывает прицеливание перетягиванием кубика: выбирай направление и силу по пунктиру. Расход: 6 маны. Обычный прыжок коротким тапом доступен без изучения и бесплатен.","arrow.up.right",1,nil),
                node(.momentum,mobility.0+lineage,mobility.1,"arrow.up.forward",1,.jump),
                node(.mastery,mastery.0+lineage,mastery.1,form.symbol,1,.passive),
                node(.doubleJump,"Двойной прыжок","После обычного или направленного прыжка позволяет один дополнительный толчок в воздухе. Второй короткий тап — вверх. Расход дополнительного толчка: 10 маны; восстанавливается при приземлении.","arrow.up",2,.momentum),
                node(.control,"Свободная траектория"+lineage,"Ещё +8% к предельной скорости направленного прыжка.","point.topleft.down.to.point.bottomright.curvepath",2,.doubleJump),
                node(.affinity,affinity.0+lineage,affinity.1,"sparkles",2,.mastery)]
    }
    public func canLearn(_ node:SkillNode)->Bool {
        guard tree.contains(node),!learned.contains(node.kind),skillPoints>=node.cost else { return false }
        return node.prerequisite.map { prerequisite in tree.contains { $0.id==prerequisite && learned.contains($0.kind) } } ?? true
    }
    @discardableResult public mutating func learn(_ node:SkillNode)->Bool {
        guard canLearn(node) else { return false };skillPoints-=node.cost;learned.insert(node.kind);return true
    }
    /// Each world crystal awards this individual once, including after restarting.
    public mutating func recordFinds(crystals found:Set<Int>,relic:Bool) {
        skillPoints+=found.subtracting(crystals).count;crystals.formUnion(found);deepRelic = deepRelic || relic
    }
    public var jumpSkill:JumpSkill {
        let ranks=(learned.contains(.momentum) ? 1 : 0)+(learned.contains(.control) ? 1 : 0)
        let waterRanks=form == .water ? (learned.contains(.mastery) ? 1 : 0)+(learned.contains(.affinity) ? 1 : 0) : 0
        return JumpSkill(maximumSpeed:JumpSkill.initial(for:form).maximumSpeed*(1+Float(ranks)*0.08),strokeMaximumSpeed:15*(1+Float(waterRanks)*0.15))
    }
    public var masteryRanks:Int { (learned.contains(.mastery) ? 1 : 0)+(learned.contains(.affinity) ? 1 : 0) }
    public var conductivity:Float { form == .ice ? 1+Float(masteryRanks)*0.25 : 1 }
    public var manaMultiplier:Float { (equippedCharm == .deepRelic ? 0.9 : 1)*(learned.contains(.affinity) ? 0.85 : 1) }
    public var airControlMultiplier:Float { form == .air ? 1+Float(masteryRanks)*0.2 : 1 }
    fileprivate mutating func migrateStarterJump() { learned.remove(.jump) }
    public var landingDamageMultiplier:Float { (form == .stone ? 1-Float(masteryRanks)*0.2 : 1)*(equippedCharm == .deepRelic ? 0.8 : (equippedCharm == .travelerCharm ? 0.9 : 1)) }
    public var fireDamageMultiplier:Float { form == .fire ? 1-Float(masteryRanks)*0.15 : 1 }
}
public struct MonsterInventory:Codable,Equatable {
    public private(set) var monsters:[MonsterRecord]
    public private(set) var selectedID:UUID
    public private(set) var schemaVersion=2
    private enum CodingKeys:String,CodingKey { case monsters,selectedID,schemaVersion }
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        monsters=try c.decode([MonsterRecord].self,forKey:.monsters);selectedID=try c.decode(UUID.self,forKey:.selectedID)
        let storedVersion=try c.decodeIfPresent(Int.self,forKey:.schemaVersion) ?? 1
        if storedVersion<2 { for i in monsters.indices { monsters[i].migrateStarterJump() } }
        schemaVersion=2
    }
    public init(selectedForm:ElementForm = .ice) {
        monsters=ElementForm.allCases.map { MonsterRecord(form:$0) }
        selectedID=monsters.first { $0.form==selectedForm }!.id
    }
    public var selected:MonsterRecord { monsters.first { $0.id==selectedID } ?? monsters[0] }
    @discardableResult public mutating func select(_ id:UUID)->Bool {
        guard monsters.contains(where:{ $0.id==id }) else { return false };selectedID=id;return true
    }
    @discardableResult public mutating func learn(_ node:SkillNode,monsterID:UUID)->Bool {
        guard let i=monsters.firstIndex(where:{ $0.id==monsterID }) else { return false };return monsters[i].learn(node)
    }
    @discardableResult public mutating func equip(_ item:MonsterItem?)->Bool {
        guard let i=monsters.firstIndex(where:{ $0.id==selectedID }) else { return false };return monsters[i].equip(item)
    }
    public mutating func recordFinds(crystals:Set<Int>,relic:Bool) {
        guard let i=monsters.firstIndex(where:{ $0.id==selectedID }) else { return };monsters[i].recordFinds(crystals:crystals,relic:relic)
    }
    public var isValid:Bool {
        !monsters.isEmpty && Set(monsters.map(\.id)).count==monsters.count && monsters.contains { $0.id==selectedID } && monsters.allSatisfy { $0.skillPoints>=0 && $0.learned.contains(.passive) && ($0.equippedCharm.map { $0.isEquipment } ?? true) }
    }
}
public final class MonsterInventoryStore {
    private let defaults:UserDefaults
    private let key="elementalcube.monsters.v1"
    public init(defaults:UserDefaults = .standard) { self.defaults=defaults }
    public func load(selectedForm:ElementForm = .ice)->MonsterInventory {
        guard let data=defaults.data(forKey:key),let result=try? JSONDecoder().decode(MonsterInventory.self,from:data),result.isValid else { return MonsterInventory(selectedForm:selectedForm) };return result
    }
    public func save(_ inventory:MonsterInventory) {
        guard inventory.isValid,let data=try? JSONEncoder().encode(inventory) else { return };defaults.set(data,forKey:key)
    }
}
