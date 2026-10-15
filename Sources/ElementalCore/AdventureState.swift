import Foundation

public enum HybridStyle:String,Codable,CaseIterable {
    case steam,magma,geyser,crystal,slush,mud,ember,blizzard,mist,dust,resonance,boiler
    public init(_ forms:[ElementForm]) {
        let key=Set(forms).map(\.rawValue).sorted().joined(separator:"+")
        self=["fire+ice":Self.steam,"fire+stone":.magma,"fire+water":.geyser,"ice+stone":.crystal,"ice+water":.slush,"stone+water":.mud,"air+fire":.ember,"air+ice":.blizzard,"air+water":.mist,"air+stone":.dust][key] ?? .resonance
    }
    public var name:String {
        switch self {
        case .steam:return "Парик";case .magma:return "Лавик";case .geyser:return "Гейзик"
        case .crystal:return "Кристаллик";case .slush:return "Снежок";case .mud:return "Глинка"
        case .ember:return "Искровик";case .blizzard:return "Снежный вихрь";case .mist:return "Туманчик"
        case .dust:return "Пылинка";case .resonance:return "Резончик";case .boiler:return "Горнило"
        }
    }
    public var body:ElementForm {
        switch self {
        case .steam,.geyser,.mud:return .water
        case .magma,.crystal,.boiler:return .stone
        case .slush,.blizzard:return .ice
        case .ember:return .fire
        case .mist,.dust:return .air
        case .resonance:return .water
        }
    }
    public var passiveName:String {
        switch self {
        case .steam:return "Паровая нежность";case .magma:return "Лавовое сердце";case .geyser:return "Пружинка гейзера"
        case .crystal:return "Холодный кристалл";case .slush:return "Снежное касание";case .mud:return "Живая глина"
        case .ember:return "Танец искр";case .blizzard:return "Дыхание метели";case .mist:return "Облачная подушка"
        case .dust:return "Тихий вихрь";case .resonance:return "Резонанс стихий";case .boiler:return "Минеральная камера"
        }
    }
    public var explanation:String {
        switch self {
        case .steam:return "Тёплый пар: пружинит и оставляет лёгкое облачко, без шерсти."
        case .magma:return "Тяжёлое горячее сердце: катится и оставляет тлеющий след."
        case .geyser:return "Весёлая горячая капля: мелкие скачки и пар над водой."
        case .crystal:return "Кристальный камушек: вращается с холодным мерцанием."
        case .slush:return "Мягкий снежок: покачивается и замораживает касанием."
        case .mud:return "Пластичная глинка: переваливается и протискивается в щели."
        case .ember:return "Искорка на ветру: течёт с лёгким покачиванием пламени."
        case .blizzard:return "Маленькая метель: скользит, закручивая снежинки."
        case .mist:return "Живое облачко: плывёт над водой, оставляя туманный хвостик."
        case .dust:return "Воздушная пылинка: парит и лениво кружится."
        case .resonance:return "Родственные стихии нашли собственный ритм."
        case .boiler:return "Паровая камера в минеральном теле: тяжёлая форма с отдельной веткой."
        }
    }
}

/// Inventory, wallet and world rewards are saved as one atomic Codable value.
public struct AdventureState:Codable,Equatable {
    public var inventory:MonsterInventory
    public private(set) var started=false
    public private(set) var coins=0
    public private(set) var owned:Set<UUID>=[]
    public private(set) var claimedRewards:Set<String>=[]
    public private(set) var completedMaps:Set<WorldMap>=[]
    public var map:WorldMap = .shore
    private var lineageArchive:[MonsterRecord]?=nil
    public var archivedGenerations:[MonsterRecord] { lineageArchive ?? [] }
    public static let switchPrice=2,recruitPrice=4,mergePrice=4
    public init(inventory:MonsterInventory=MonsterInventory(),migratingLegacy:Bool=false) {
        self.inventory=inventory
        if migratingLegacy {
            owned=Set(inventory.monsters.filter { !$0.crystals.isEmpty || $0.equippedCharm != nil }.map(\.id))
            owned.insert(inventory.selectedID)
            let finds=inventory.monsters.reduce(into:Set<Int>()) { $0.formUnion($1.crystals) }
            claimedRewards=Set(finds.map { "shore/\($0)" });coins=finds.count
        }
    }
    public var collection:[MonsterRecord] { inventory.monsters.filter { owned.contains($0.id) } }
    public func price(toSelect id:UUID)->Int { id==inventory.selectedID && started ? 0 : (owned.contains(id) ? Self.switchPrice : Self.recruitPrice) }
    @discardableResult public mutating func begin(with candidate:MonsterRecord)->Bool {
        guard !started else { return false }
        if !inventory.monsters.contains(where:{ $0.id==candidate.id }) { inventory.add(candidate) }
        guard inventory.select(candidate.id) else { return false }
        started=true;owned.insert(candidate.id);return true
    }
    @discardableResult public mutating func select(_ id:UUID)->Bool {
        guard started,inventory.monsters.contains(where:{ $0.id==id }) else { return false }
        let cost=price(toSelect:id)
        guard coins>=cost,inventory.select(id) else { return false }
        coins-=cost;owned.insert(id);return true
    }
    @discardableResult public mutating func recruitRandom(_ monster:MonsterRecord)->Bool {
        guard started,coins>=Self.recruitPrice,!inventory.monsters.contains(where:{ $0.id==monster.id }) else { return false }
        coins-=Self.recruitPrice;inventory.add(monster);owned.insert(monster.id);return true
    }
    public mutating func recordFinds(_ indices:Set<Int>,relic:Bool) {
        guard started else { return }
        let keys=Set(indices.map { map.rawValue+"/"+String($0) })
        coins+=keys.subtracting(claimedRewards).count;claimedRewards.formUnion(keys)
        inventory.recordFinds(crystals:Set(indices.map { map.crystalOffset+$0 }),relic:relic)
    }
    public mutating func finishMap() {
        guard started,!completedMaps.contains(map) else { return }
        completedMaps.insert(map);coins+=6
    }
    public var canEvolve:Bool {
        let m=inventory.selected
        return started && m.evolutionStage<3 && m.crystals.count>=m.evolutionRequirement && coins>=m.evolutionCost
    }
    @discardableResult public mutating func evolve()->Bool {
        guard canEvolve else { return false }
        let cost=inventory.selected.evolutionCost
        guard inventory.evolveSelected() else { return false }
        coins-=cost;return true
    }
    public func prepareMerge(_ first:UUID,_ second:UUID)->MergePlan? {
        guard started,first != second,owned.contains(first),owned.contains(second),
              let a=inventory.monsters.first(where:{ $0.id==first }),let b=inventory.monsters.first(where:{ $0.id==second }) else { return nil }
        return MergePlan(a,b)
    }
    public func canCommit(_ plan:MergePlan,pins:Set<GenePin>=[])->Bool {
        started && coins>=Self.mergePrice && owned.contains(plan.receiver.id) && owned.contains(plan.donor.id) &&
        inventory.monsters.contains(plan.receiver) && inventory.monsters.contains(plan.donor) &&
        (try? InheritanceEngine.validate(plan,pins:pins)) != nil
    }
    @discardableResult public mutating func commitMerge(_ plan:MergePlan,pins:Set<GenePin>=[],seed:UInt64?=nil)->MonsterRecord? {
        // A repeated local confirmation returns the stored outcome, never a
        // new draw or a second payment. Retired outcomes remain archive-only.
        if let previous=(inventory.monsters+archivedGenerations).first(where:{ $0.inheritance?.operationID==plan.id }) {
            guard previous.inheritance?.receiver==plan.a,previous.inheritance?.donor==plan.b else { return nil };return previous
        }
        guard canCommit(plan,pins:pins),let genome=try? InheritanceEngine.draw(plan,pins:pins,seed:seed),genome.isValid else { return nil }
        let child=MonsterRecord.metamorphosed(plan,genome:genome)
        guard child.geneticsValid else { return nil }
        if lineageArchive == nil { lineageArchive=[] };lineageArchive!.append(plan.receiver)
        inventory.replaceParents([plan.receiver.id],with:child)
        coins-=Self.mergePrice;owned.remove(plan.receiver.id);owned.insert(child.id)
        return child
    }
    @discardableResult public mutating func merge(_ first:UUID,_ second:UUID,seed:UInt64?=nil)->MonsterRecord? {
        guard let plan=prepareMerge(first,second) else { return nil };return commitMerge(plan,seed:seed)
    }
    public var isValid:Bool {
        let active=Set(inventory.monsters.map(\.id)),retired=Set(archivedGenerations.map(\.id))
        return inventory.isValid && coins>=0 && owned.isSubset(of:active) && (!started || owned.contains(inventory.selectedID)) &&
        retired.count==archivedGenerations.count && active.isDisjoint(with:retired) && archivedGenerations.allSatisfy { $0.geneticsValid }
    }
}

public final class AdventureStore {
    private let defaults:UserDefaults
    private let key="elementalcube.adventure.v1"
    public init(defaults:UserDefaults = .standard) { self.defaults=defaults }
    public func load(fallback:MonsterInventory)->AdventureState {
        if let data=defaults.data(forKey:key),let save=try? JSONDecoder().decode(AdventureState.self,from:data),save.isValid { return save }
        return AdventureState(inventory:fallback,migratingLegacy:defaults.data(forKey:"elementalcube.monsters.v1") != nil)
    }
    public func save(_ value:AdventureState) {
        guard value.isValid,let data=try? JSONEncoder().encode(value) else { return }
        defaults.set(data,forKey:key)
    }
}
