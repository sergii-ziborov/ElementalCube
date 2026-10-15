import Foundation

public struct SkillNode:Identifiable,Equatable {
    public enum Kind:String,Codable { case passive,jump,momentum,mastery,control,affinity,doubleJump,resilience }
    public var id:String
    public var kind:Kind
    public var title:String
    public var explanation:String
    public var summary:String
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
        case .deepRelic:return "Скрыта под мостом. Доберись до неё любым телом: по дну или после осушения воды. Уменьшает урон от приземлений на 20% и расход маны активными приёмами на 10%. Занимает слот талисмана."
        }
    }
}
public struct MonsterAncestor:Codable,Equatable {
    public var id:UUID,name:String,form:ElementForm
    public var morphology:CreatureForm?=nil
    public var generation:Int?=nil
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
    public private(set) var morphology:CreatureForm?=nil
    public private(set) var lineageID:UUID
    public private(set) var generation:Int=0
    public private(set) var inheritance:InheritedGenome?=nil
    private var passportKinds:[SkillNode.Kind]?=nil
    private var aetherAmount=0,relicAmount=0,travelerAmount=1
    public var appearanceSeed:UInt64 {
        withUnsafeBytes(of:id.uuid) { $0.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 } }
    }
    private enum CodingKeys:String,CodingKey { case id,name,form,parents,learned,crystals,deepRelic,skillPoints,equippedCharm,evolutionStage,aetherAmount,relicAmount,travelerAmount,morphology,lineageID,generation,inheritance,passportKinds }
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decode(UUID.self,forKey:.id);name=try c.decode(String.self,forKey:.name);form=try c.decode(ElementForm.self,forKey:.form)
        parents=try c.decodeIfPresent([MonsterAncestor].self,forKey:.parents) ?? []
        morphology=try c.decodeIfPresent(CreatureForm.self,forKey:.morphology)
        if morphology == nil && parents.isEmpty { morphology=CreatureForm(form) }
        lineageID=try c.decodeIfPresent(UUID.self,forKey:.lineageID) ?? id
        generation=try c.decodeIfPresent(Int.self,forKey:.generation) ?? (parents.isEmpty ? 0 : 1)
        inheritance=try c.decodeIfPresent(InheritedGenome.self,forKey:.inheritance)
        passportKinds=try c.decodeIfPresent([SkillNode.Kind].self,forKey:.passportKinds)
        learned=try c.decode(Set<SkillNode.Kind>.self,forKey:.learned)
        crystals=try c.decode(Set<Int>.self,forKey:.crystals);deepRelic=try c.decode(Bool.self,forKey:.deepRelic)
        skillPoints=try c.decode(Int.self,forKey:.skillPoints);equippedCharm=try c.decodeIfPresent(MonsterItem.self,forKey:.equippedCharm)
        evolutionStage=min(3,max(0,try c.decodeIfPresent(Int.self,forKey:.evolutionStage) ?? 0))
        aetherAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.aetherAmount) ?? crystals.count)
        relicAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.relicAmount) ?? (deepRelic ? 1 : 0))
        travelerAmount=max(0,try c.decodeIfPresent(Int.self,forKey:.travelerAmount) ?? 1)
    }
    public init(form:ElementForm,name:String?=nil,id:UUID=UUID(),parents:[MonsterAncestor]=[]) {
        self.id=id;self.name=name ?? form.name;self.form=form;self.parents=parents;lineageID=id
        morphology=parents.isEmpty ? CreatureForm(form) : nil
        learned=[.passive];crystals=[];deepRelic=false;skillPoints=1;equippedCharm=nil
    }
    static func metamorphosed(_ plan:MergePlan,genome:InheritedGenome)->Self {
        let first=plan.receiver,second=plan.donor
        var child=Self(form:plan.result.body,name:plan.result.name,parents:[first,second].map { MonsterAncestor(id:$0.id,name:$0.name,form:$0.form,morphology:$0.currentForm,generation:$0.generation) })
        child.morphology=plan.result;child.lineageID=first.lineageID;child.generation=first.generation+1;child.inheritance=genome
        // A donor passes an imprint, never a second copy of items or points.
        child.crystals=first.crystals;child.deepRelic=first.deepRelic;child.aetherAmount=first.aetherAmount
        child.relicAmount=first.relicAmount;child.travelerAmount=first.travelerAmount;child.skillPoints=first.skillPoints
        child.equippedCharm=first.equippedCharm;child.evolutionStage=first.evolutionStage
        child.activateInheritedPotential()
        return child
    }
    @discardableResult public mutating func evolve()->Bool {
        guard evolutionStage<3,crystals.count>=evolutionRequirement else { return false }
        evolutionStage+=1;return true
    }
    public var evolutionRequirement:Int { (evolutionStage+1)*3 }
    public var evolutionCost:Int { (evolutionStage+1)*4 }
    public var stageName:String { ["Крошка","Росток","Искатель","Хранитель"][evolutionStage] }
    public var currentForm:CreatureForm { morphology ?? CreatureForm.legacy(form,style:hybridStyle) }
    public var hybridStyle:HybridStyle? { if let morphology=morphology { return morphology.style };return parents.isEmpty ? nil : HybridStyle(parents.map(\.form)) }
    public var secondaryForm:ElementForm? { if let morphology=morphology { return morphology.secondaryVisual };return parents.first { $0.form != form }?.form ?? (parents.isEmpty ? nil : form) }
    public var masteryChannel:MasteryChannel { if morphology == nil && hybridStyle == .crystal { return .cold };return currentForm.masteryChannel }
    public var freezesOnContact:Bool { morphology?.freezesOnContact ?? (form == .ice || hybridStyle == .crystal) }
    public var burnsOnContact:Bool { morphology?.burnsOnContact ?? (form == .fire || hybridStyle == .magma) }
    public var heatImmune:Bool { morphology?.heatImmune ?? (form.fireImmune || hybridStyle == .steam) }
    public var compresses:Bool { morphology?.compresses ?? (form == .water) }
    public var inheritanceLocks:Int { evolutionStage>=3 ? 2 : (evolutionStage>=1 ? 1 : 0) }
    public var inheritedPotential:Set<SkillNode.Kind> { inheritance?.potential ?? [] }
    public var availableImprints:[SkillNode.Kind] {
        [.jump,.mastery,.momentum,.doubleJump,.control,.affinity,.resilience].filter { learned.contains($0) || inheritedPotential.contains($0) }
    }
    public var inheritanceSelection:[SkillNode.Kind] { passportKinds ?? Array(availableImprints.prefix(4)) }
    @discardableResult public mutating func setInheritanceSelection(_ kinds:[SkillNode.Kind])->Bool {
        guard kinds.count<=4,Set(kinds).count==kinds.count,kinds.allSatisfy({ availableImprints.contains($0) }) else { return false }
        passportKinds=kinds;return true
    }
    private mutating func activateInheritedPotential() {
        var changed=true
        while changed {
            changed=false
            for node in tree where inheritedPotential.contains(node.kind) && !learned.contains(node.kind) {
                if node.prerequisite.map({ id in tree.contains { $0.id==id && learned.contains($0.kind) } }) ?? true { learned.insert(node.kind);changed=true }
            }
        }
    }
    var geneticsValid:Bool {
        guard generation>=0,generation<10000,morphology.map({ $0.body==form }) ?? true,
              inheritanceSelection.count<=4,Set(inheritanceSelection).count==inheritanceSelection.count,
              inheritanceSelection.allSatisfy({ availableImprints.contains($0) }) else { return false }
        guard let genome=inheritance else { return true }
        return genome.isValid && morphology==genome.resultForm && parents.count==2 && parents[0].id==genome.receiver.ownerID && parents[1].id==genome.donor.ownerID && lineageID==genome.receiver.lineageID && generation==genome.receiver.generation+1
    }
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
    fileprivate mutating func addStudyPoint() { skillPoints+=1 }
    public var isHybrid:Bool { morphology.map { $0.style != nil } ?? !parents.isEmpty }
    public var typeName:String { morphology?.name ?? (hybridStyle?.name ?? form.name) }
    public var treeIdentity:String { id.uuidString+"/"+form.rawValue+"/"+parents.map { $0.id.uuidString }.joined(separator:"+") }
    public var tree:[SkillNode] { SkillCatalog.tree(for:self) }
    // Used only to derive truthful before/after descriptions; purchases still
    // pass through canLearn and learn, including owner, cost and prerequisites.
    func learningPreview(_ kind:SkillNode.Kind,remove:Bool=false)->Self {
        var copy=self
        if remove { copy.learned.remove(kind) } else { copy.learned.insert(kind) }
        return copy
    }
    public func canLearn(_ node:SkillNode)->Bool {
        guard tree.contains(node),!learned.contains(node.kind),skillPoints>=node.cost else { return false }
        return node.prerequisite.map { prerequisite in tree.contains { $0.id==prerequisite && learned.contains($0.kind) } } ?? true
    }
    @discardableResult public mutating func learn(_ node:SkillNode)->Bool {
        guard canLearn(node) else { return false };skillPoints-=node.cost;learned.insert(node.kind);activateInheritedPotential();return true
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
        if morphology == .steam { return "Тёплая паровая оболочка плавает и не загорается от обычного огня. Ледяное касание и чистое пламя прежних форм недоступны. Не просачивается сквозь узкую щель, как жидкая Капля. Пассивная способность не расходует ману." }
        if morphology == .boiler { return "Паровое ядро в тяжёлой минеральной камере. Тонет и катится по дну, не замораживает воду и не поджигает касанием. Обычный огонь не поджигает оболочку; удар и жёсткая посадка всё ещё опасны." }
        guard let style=hybridStyle else { return form.explanation }
        let extra=style == .crystal ? " Холод постепенно замораживает воду вокруг камня." : (style == .magma ? " Жар обжигает траву и дерево, а в воде испарение расходует здоровье." : "")
        return style.explanation+" "+form.explanation+extra
    }
    public var conductivity:Float {
        guard form == .ice || hybridStyle == .crystal else { return 1 }
        return (hybridStyle == .blizzard ? 1.2 : (hybridStyle == .crystal ? 1.1 : 1))*(1+Float(masteryRanks)*0.25)*coldSignatureMultiplier
    }
    public var hopImpulse:Float { (hybridStyle == .geyser ? 2.7 : (hybridStyle == .mud ? 1.8 : (hybridStyle == .steam ? 2.0 : 2.35)))*(learned.contains(.momentum) ? 1.2 : 1)*(signature == .spring && learned.contains(.resilience) ? 1.35 : 1) }
    public var manaMultiplier:Float { (equippedCharm == .deepRelic ? 0.9 : 1)*(learned.contains(.affinity) ? 0.85 : 1) }
    public var airControlMultiplier:Float { form == .air ? 1+Float(masteryRanks)*0.2 : 1 }
    fileprivate mutating func migrateStarterJump() { learned.remove(.jump) }
    public var landingDamageMultiplier:Float { (form == .stone ? 1-Float(masteryRanks)*0.2 : 1)*(signature == .softLanding && learned.contains(.resilience) ? 0.65 : 1)*(equippedCharm == .deepRelic ? 0.8 : (equippedCharm == .travelerCharm ? 0.9 : 1)) }
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
    @discardableResult public mutating func setInheritanceSelection(_ kinds:[SkillNode.Kind])->Bool {
        guard let i=monsters.firstIndex(where:{ $0.id==selectedID }) else { return false };return monsters[i].setInheritanceSelection(kinds)
    }
    @discardableResult public mutating func addStudyPoint()->Bool {
        guard let i=monsters.firstIndex(where:{ $0.id==selectedID }) else { return false };monsters[i].addStudyPoint();return true
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
        !monsters.isEmpty && Set(monsters.map(\.id)).count==monsters.count && monsters.contains { $0.id==selectedID } && monsters.allSatisfy { $0.skillPoints>=0 && $0.learned.contains(.passive) && $0.geneticsValid && ($0.equippedCharm.map { $0.isEquipment } ?? true) }
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
