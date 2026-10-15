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
    public private(set) var evolutionStage:Int=0
    private var aetherAmount=0,relicAmount=0,travelerAmount=1
    public var appearanceSeed:UInt64 {
        withUnsafeBytes(of:id.uuid) { $0.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 } }
    }
    private enum CodingKeys:String,CodingKey { case id,name,form,parents,learned,crystals,deepRelic,skillPoints,equippedCharm,evolutionStage,aetherAmount,relicAmount,travelerAmount }
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decode(UUID.self,forKey:.id);name=try c.decode(String.self,forKey:.name);form=try c.decode(ElementForm.self,forKey:.form)
        parents=try c.decodeIfPresent([MonsterAncestor].self,forKey:.parents) ?? []
        learned=try c.decode(Set<SkillNode.Kind>.self,forKey:.learned)
        crystals=try c.decode(Set<Int>.self,forKey:.crystals);deepRelic=try c.decode(Bool.self,forKey:.deepRelic)
        skillPoints=try c.decode(Int.self,forKey:.skillPoints);equippedCharm=try c.decodeIfPresent(MonsterItem.self,forKey:.equippedCharm)
        evolutionStage=min(3,max(0,try c.decodeIfPresent(Int.self,forKey:.evolutionStage) ?? 0))
        aetherAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.aetherAmount) ?? crystals.count)
        relicAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.relicAmount) ?? (deepRelic ? 1 : 0))
        travelerAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.travelerAmount) ?? 1)
    }
    public init(form:ElementForm,name:String?=nil,id:UUID=UUID(),parents:[MonsterAncestor]=[]) {
        self.id=id;self.name=name ?? form.name;self.form=form;self.parents=parents
        learned=[.passive];crystals=[];deepRelic=false;skillPoints=1;equippedCharm=nil
    }
    public static func offspring(_ first:Self,_ second:Self,body:ElementForm,seed:UInt64=UInt64.random(in:1...UInt64.max))->Self {
        var child=Self(form:body,parents:[first,second].map { MonsterAncestor(id:$0.id,name:$0.name,form:$0.form) })
        child.name=child.hybridStyle?.name ?? "Пушистый микс"
        child.crystals=first.crystals.union(second.crystals);child.deepRelic=first.deepRelic || second.deepRelic
        child.aetherAmount=first.aetherAmount+second.aetherAmount;child.relicAmount=first.relicAmount+second.relicAmount;child.travelerAmount=first.travelerAmount+second.travelerAmount
        child.skillPoints=first.skillPoints+second.skillPoints
        child.equippedCharm=first.equippedCharm ?? second.equippedCharm
        child.evolutionStage=max(first.evolutionStage,second.evolutionStage)
        var random=seed==0 ? 1 : seed
        func inherits()->Bool { random ^= random<<13;random ^= random>>7;random ^= random<<17;return random&1==0 }
        for kind in [SkillNode.Kind.jump,.momentum,.mastery,.doubleJump,.control,.affinity] {
            let a=first.learned.contains(kind) && inherits(),b=second.learned.contains(kind) && inherits()
            if a || b { child.learned.insert(kind) }
        }
        // An inherited advanced technique brings its prerequisite chain.
        if child.learned.contains(.control) { child.learned.insert(.doubleJump) }
        if child.learned.contains(.doubleJump) { child.learned.insert(.momentum) }
        if child.learned.contains(.momentum) { child.learned.insert(.jump) }
        if child.learned.contains(.affinity) { child.learned.insert(.mastery) }
        return child
    }
    @discardableResult public mutating func evolve()->Bool {
        guard evolutionStage<3,crystals.count>=evolutionRequirement else { return false }
        evolutionStage+=1;return true
    }
    public var evolutionRequirement:Int { (evolutionStage+1)*3 }
    public var evolutionCost:Int { (evolutionStage+1)*4 }
    public var stageName:String { ["Крошка","Росток","Искатель","Хранитель"][evolutionStage] }
    public var hybridStyle:HybridStyle? { parents.isEmpty ? nil : HybridStyle(parents.map(\.form)) }
    public var secondaryForm:ElementForm? { parents.first { $0.form != form }?.form ?? (parents.isEmpty ? nil : form) }
    public static func randomStarter()->Self {
        let form=ElementForm.allCases.randomElement()!
        let names:[ElementForm:[String]]=[.ice:["Снежик","Пломбир","Фростик"],.water:["Булька","Капелька","Лужик"],.air:["Зефир","Пушок","Вжух"],.stone:["Галька","Крош","Гранитик"],.fire:["Искорка","Уголёк","Огоняш"]]
        return Self(form:form,name:names[form]!.randomElement()!)
    }
    public func quantity(of item:MonsterItem)->Int {
        switch item { case .travelerCharm:return travelerAmount;case .aetherShard:return aetherAmount;case .deepRelic:return relicAmount }
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
        let mobility:(String,String)
        var mastery:(String,String),affinity:(String,String)
        switch form {
        case .ice:
            mobility=("Ледяной разбег","Сила прицельного прыжка +1,7 м/с.")
            mastery=("Глубокий холод","Теплопроводность морозного касания +25%: лёд быстрее нарастает в глубину и в стороны.")
            affinity=("Сердце зимы","Ещё +25% к теплопроводности и −15% к расходу маны активными приёмами.")
        case .water:
            mobility=("Упругая капля","Сила прицельного прыжка +1,7 м/с.")
            mastery=("Сильная волна","Предельная скорость толчка в воде +15%.")
            affinity=("Течение","Ещё +15% к пределу толчка в воде и −15% к расходу маны активными приёмами.")
        case .air:
            mobility=("Попутный ветер","Сила прицельного прыжка +1,7 м/с.")
            mastery=("Тихое парение","Управляемость и сила воздушной подушки +20%.")
            affinity=("Долгий полёт","Ещё +20% к управляемости подушкой и −15% к расходу маны активными приёмами.")
        case .stone:
            mobility=("Разгон валуна","Сила прицельного прыжка +1,7 м/с.")
            mastery=("Крепкая порода","Урон от жёстких приземлений снижен на 20%.")
            affinity=("Монолит","Ещё −20% к урону от приземлений и −15% к расходу маны активными приёмами.")
        case .fire:
            mobility=("Искра ввысь","Сила прицельного прыжка +1,7 м/с.")
            mastery=("Жаркое ядро","Испарение воды расходует на 15% меньше здоровья.")
            affinity=("Неугасимый","Ещё −15% к потере здоровья при испарении и −15% к расходу маны активными приёмами.")
        }
        if let style=hybridStyle {
            switch style {
            case .crystal,.slush,.blizzard:
                mastery=("Растущий кристалл","Теплопроводность собственного холодного касания +25%.")
                affinity=("Память снежинки","Ещё +25% к теплопроводности и −15% к мане активных приёмов.")
            case .magma:
                mastery=("Сердце вулкана","Горячий камень испаряет воду с потерей на 15% меньше здоровья.")
                affinity=("Живая лава","Ещё −15% к потере здоровья при испарении и −15% к мане активных приёмов.")
            default:break
            }
        }
        let lineage=isHybrid ? " · "+parents.map(\.form.name).joined(separator:"/") : ""
        return [node(.passive,passiveName,passiveExplanation,form.symbol,0,nil),
                node(.jump,"Направленный прыжок", "Удержи кубика и потяни: пунктир задаёт направление и силу. Начальный предел 8 м/с, дальнейшие узлы усиливают прыжок. Расход: 6 маны. Базовый свайп вверх по экрану доступен без изучения и бесплатен.","arrow.up.right",1,nil),
                node(.momentum,mobility.0+lineage,mobility.1,"arrow.up.forward",1,.jump),
                node(.mastery,mastery.0+lineage,mastery.1,form.symbol,1,.passive),
                node(.doubleJump,"Двойной прыжок","После обычного или направленного прыжка позволяет один дополнительный толчок в воздухе. Второй свайп вверх — дополнительный толчок. Расход дополнительного толчка: 10 маны; восстанавливается при приземлении.","arrow.up",2,.momentum),
                node(.control,"Свободная траектория"+lineage,"Ещё +1,7 м/с к пределу прицельного прыжка.","point.topleft.down.to.point.bottomright.curvepath",2,.doubleJump),
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
        let fresh=found.subtracting(crystals).count
        skillPoints+=fresh;aetherAmount+=fresh;crystals.formUnion(found)
        if relic && !deepRelic { relicAmount+=1 };deepRelic = deepRelic || relic
    }
    public var jumpSkill:JumpSkill {
        let ranks=(learned.contains(.momentum) ? 1 : 0)+(learned.contains(.control) ? 1 : 0)
        let waterRanks=form == .water ? (learned.contains(.mastery) ? 1 : 0)+(learned.contains(.affinity) ? 1 : 0) : 0
        return JumpSkill(maximumSpeed:(form == .air ? 8.4 : 8)+Float(ranks)*1.7+Float(evolutionStage)*0.8,strokeMaximumSpeed:15*(1+Float(waterRanks)*0.15))
    }
    public var masteryRanks:Int { (learned.contains(.mastery) ? 1 : 0)+(learned.contains(.affinity) ? 1 : 0) }
    public var passiveName:String { hybridStyle?.passiveName ?? form.ability }
    public var passiveExplanation:String {
        guard let style=hybridStyle else { return form.explanation }
        let extra=style == .crystal ? " Холод постепенно замораживает воду вокруг камня." : (style == .magma ? " Жар обжигает траву и дерево, а в воде испарение расходует здоровье." : "")
        return style.explanation+" "+form.explanation+extra
    }
    public var conductivity:Float {
        guard form == .ice || hybridStyle == .crystal else { return 1 }
        return (hybridStyle == .blizzard ? 1.2 : (hybridStyle == .crystal ? 1.1 : 1))*(1+Float(masteryRanks)*0.25)
    }
    public var hopImpulse:Float { hybridStyle == .geyser ? 2.0 : (hybridStyle == .mud ? 1.2 : (hybridStyle == .steam ? 1.45 : 1.6)) }
    public var manaMultiplier:Float { (equippedCharm == .deepRelic ? 0.9 : 1)*(learned.contains(.affinity) ? 0.85 : 1) }
    public var airControlMultiplier:Float { form == .air ? 1+Float(masteryRanks)*0.2 : 1 }
    fileprivate mutating func migrateStarterJump() { learned.remove(.jump) }
    public var landingDamageMultiplier:Float { (form == .stone ? 1-Float(masteryRanks)*0.2 : 1)*(equippedCharm == .deepRelic ? 0.8 : (equippedCharm == .travelerCharm ? 0.9 : 1)) }
    public var fireDamageMultiplier:Float { (form == .fire || hybridStyle == .magma) ? 1-Float(masteryRanks)*0.15 : 1 }
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
    public mutating func add(_ monster:MonsterRecord,select:Bool=true) {
        guard !monsters.contains(where:{ $0.id==monster.id }) else { return }
        monsters.append(monster);if select { selectedID=monster.id }
    }
    @discardableResult public mutating func evolveSelected()->Bool {
        guard let i=monsters.firstIndex(where:{ $0.id==selectedID }) else { return false }
        return monsters[i].evolve()
    }
    public mutating func replaceParents(_ ids:Set<UUID>,with child:MonsterRecord) {
        monsters.removeAll { ids.contains($0.id) };monsters.append(child);selectedID=child.id
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
