import Foundation

public enum DevelopmentTrait:String,Codable,CaseIterable { case memory,diligence,impulseControl,channelEfficiency }
public enum GeneContent:Codable,Equatable,Hashable {
    case skill(SkillNode.Kind),trait(DevelopmentTrait),unrevealed
}
public enum GeneBlock:String,Codable { case skills,development }
public struct GeneCard:Codable,Equatable,Identifiable {
    public let ownerID:UUID,slot:Int,block:GeneBlock,form:CreatureForm,channel:MasteryChannel
    public let content:GeneContent,rank:Int,title:String
    public var id:String { ownerID.uuidString+"/"+block.rawValue+"/"+String(slot) }
    public var isValid:Bool {
        guard (0..<4).contains(slot),(0...3).contains(rank),!title.isEmpty,title.utf8.count<512 else { return false }
        switch content {
        case .unrevealed:return rank==0
        case .skill(let kind):return block == .skills && kind != .passive && rank>0
        case .trait:return block == .development && rank>0
        }
    }
}
public struct GenePassport:Codable,Equatable {
    public let ownerID:UUID,form:CreatureForm,skills:[GeneCard],development:[GeneCard]
    public let lineageID:UUID,generation:Int
    public init(_ monster:MonsterRecord) {
        let current=monster.currentForm
        ownerID=monster.id;form=current;lineageID=monster.lineageID;generation=monster.generation
        let selection=monster.inheritanceSelection
        skills=(0..<4).map { i in
            let kind=i<selection.count ? selection[i] : nil
            return GeneCard(ownerID:monster.id,slot:i,block:.skills,form:current,channel:monster.masteryChannel,content:kind.map { .skill($0) } ?? .unrevealed,rank:kind==nil ? 0 : 1,title:kind.flatMap { kind in monster.tree.first { $0.kind==kind }?.title } ?? "Нераскрытый отпечаток")
        }
        // Development learning is a later system. Empty imprints are genuine
        // entries in the quota, never invented memory/learning bonuses.
        development=(0..<4).map { i in GeneCard(ownerID:monster.id,slot:i,block:.development,form:current,channel:monster.masteryChannel,content:.unrevealed,rank:0,title:"Зачаток развития") }
    }
    public var isValid:Bool {
        func valid(_ cards:[GeneCard],_ block:GeneBlock)->Bool { cards.count==4 && cards.enumerated().allSatisfy { $0.offset==$0.element.slot && $0.element.ownerID==ownerID && $0.element.form==form && $0.element.block==block && $0.element.isValid } }
        return (0..<10000).contains(generation) && valid(skills,.skills) && valid(development,.development)
    }
}
public enum GeneParent:String,Codable { case receiver,donor }
public struct GenePin:Codable,Equatable,Hashable,Identifiable {
    public var parent:GeneParent,slot:Int
    public init(_ parent:GeneParent,_ slot:Int) { self.parent=parent;self.slot=slot }
    public var id:String { parent.rawValue+String(slot) }
}
public enum GeneDisposition:String,Codable { case preserved,transformed,lost,duplicate,unrevealed }
public struct GeneExpression:Codable,Equatable,Identifiable {
    public let source:GeneCard,disposition:GeneDisposition,result:GeneContent?,rank:Int,reason:String
    public var id:String { source.id }
    public var usable:Bool { disposition == .preserved || disposition == .transformed }
    public var label:String {
        switch disposition { case .preserved:return "Сохранено";case .transformed:return "Изменилось";case .lost:return "Потеряно";case .duplicate:return "Повтор";case .unrevealed:return "Зачаток" }
    }
}
public struct GeneSelection:Codable,Equatable {
    public let aSkills:[Int],bSkills:[Int],aDevelopment:[Int],bDevelopment:[Int]
}
public struct InheritedGenome:Codable,Equatable {
    public static let version="inheritance-v2.1"
    public private(set) var rulesVersion:String=Self.version
    public private(set) var manifest:ReleaseManifest = .current
    public let operationID:UUID,receiver:GenePassport,donor:GenePassport,resultForm:CreatureForm,selection:GeneSelection
    public let skills:[GeneExpression],development:[GeneExpression]
    public var potential:Set<SkillNode.Kind> {
        Set(skills.compactMap { expression in guard expression.usable,case .skill(let kind)?=expression.result else { return nil };return kind })
    }
    public var isValid:Bool {
        guard rulesVersion==Self.version,manifest.forms==FormCatalog.version,manifest.inheritance==Self.version,receiver.isValid,donor.isValid,receiver.ownerID != donor.ownerID,
              FormCatalog.result(receiver.form,donor.form)==resultForm,skills.count==4,development.count==4 else { return false }
        func pair(_ values:[Int])->Bool { values.count==2 && Set(values).count==2 && values.allSatisfy { (0..<4).contains($0) } }
        guard [selection.aSkills,selection.bSkills,selection.aDevelopment,selection.bDevelopment].allSatisfy(pair) else { return false }
        let rawSkills=selection.aSkills.map { receiver.skills[$0] }+selection.bSkills.map { donor.skills[$0] }
        let rawDevelopment=selection.aDevelopment.map { receiver.development[$0] }+selection.bDevelopment.map { donor.development[$0] }
        func matches(_ stored:[GeneExpression],_ expected:[GeneExpression])->Bool {
            zip(stored,expected).allSatisfy { a,b in a.source==b.source && a.disposition==b.disposition && a.result==b.result && a.rank==b.rank && a.reason.utf8.count<1024 }
        }
        return matches(skills,InheritanceEngine.compile(rawSkills,as:resultForm)) && matches(development,InheritanceEngine.compile(rawDevelopment,as:resultForm))
    }
}
public struct MergePlan:Identifiable,Equatable {
    public let id:UUID,receiver:MonsterRecord,donor:MonsterRecord,result:CreatureForm
    public var a:GenePassport { GenePassport(receiver) }
    public var b:GenePassport { GenePassport(donor) }
    public var lockBudget:Int { receiver.inheritanceLocks }
    public var lostProperties:[String] { receiver.currentForm.properties.filter { !result.properties.contains($0) } }
    public init?(_ receiver:MonsterRecord,_ donor:MonsterRecord,id:UUID=UUID()) {
        guard receiver.id != donor.id,let result=FormCatalog.result(receiver.currentForm,donor.currentForm) else { return nil }
        self.id=id;self.receiver=receiver;self.donor=donor;self.result=result
    }
    public func passport(_ parent:GeneParent)->GenePassport { parent == .receiver ? a : b }
    public func probability(_ pin:GenePin,pins:Set<GenePin>)->Double {
        let locked=Set(pins.filter { $0.parent==pin.parent }.map(\.slot))
        guard let choices=try? InheritanceEngine.choices(required:locked),!choices.isEmpty else { return 0 }
        return Double(choices.filter { $0.contains(pin.slot) }.count)/Double(choices.count)
    }
}
public enum InheritanceError:Error { case invalidPassport,unsupportedReaction,invalidPins,incompatiblePin,invalidSelection }

public enum InheritanceEngine {
    /// Exactly C(4,2) choices. Locks condition this set, never add a card.
    public static func choices(required:Set<Int>=[]) throws->[[Int]] {
        guard required.count<=2,required.allSatisfy({ (0..<4).contains($0) }) else { throw InheritanceError.invalidPins }
        return (0..<4).flatMap { i in ((i+1)..<4).compactMap { j in required.isSubset(of:[i,j]) ? [i,j] : nil } }
    }
    public static func expression(_ card:GeneCard,as form:CreatureForm)->GeneExpression {
        func out(_ state:GeneDisposition,_ result:GeneContent?,_ rank:Int,_ why:String)->GeneExpression { GeneExpression(source:card,disposition:state,result:result,rank:rank,reason:why) }
        switch card.content {
        case .unrevealed:return out(.unrevealed,nil,0,"Нераскрытый отпечаток не даёт изученного навыка")
        case .skill(let kind):
            let movement=SkillCatalog.movement.contains(kind)
            guard movement || card.channel==form.masteryChannel else { return out(.lost,nil,0,"Ветвь «\(card.channel.name)» недоступна новому телу") }
            return out(card.form==form ? .preserved : .transformed,.skill(kind),card.form==form ? min(3,card.rank) : min(1,card.rank),movement ? "Потенциал приёма; основы изучаются отдельно" : "Совместимое улучшение канала текущего тела")
        case .trait(let trait):
            guard trait != .channelEfficiency || card.channel==form.masteryChannel else { return out(.lost,nil,0,"Эффективность утраченного канала не переносится") }
            return out(card.form==form ? .preserved : .transformed,.trait(trait),min(3,card.rank),"Отпечаток развития; не дополнительная кнопка способности")
        }
    }
    static func compile(_ cards:[GeneCard],as form:CreatureForm)->[GeneExpression] {
        let expressions=cards.map { expression($0,as:form) }
        var best:[GeneContent:Int]=[:]
        for (i,e) in expressions.enumerated() where e.usable {
            guard let content=e.result else { continue }
            if let old=best[content],expressions[old].rank>=e.rank { continue };best[content]=i
        }
        return expressions.enumerated().map { i,e in
            guard e.usable,let content=e.result,best[content] != i else { return e }
            return GeneExpression(source:e.source,disposition:.duplicate,result:content,rank:0,reason:"Ранги не складываются; нового розыгрыша нет")
        }
    }
    public static func validate(_ plan:MergePlan,pins:Set<GenePin>) throws {
        guard plan.a.isValid,plan.b.isValid else { throw InheritanceError.invalidPassport }
        guard FormCatalog.result(plan.a.form,plan.b.form)==plan.result else { throw InheritanceError.unsupportedReaction }
        guard pins.count<=plan.lockBudget else { throw InheritanceError.invalidPins }
        for parent in [GeneParent.receiver,.donor] { _=try choices(required:Set(pins.filter { $0.parent==parent }.map(\.slot))) }
        for pin in pins {
            let card=plan.passport(pin.parent).skills[pin.slot]
            guard expression(card,as:plan.result).usable else { throw InheritanceError.incompatiblePin }
        }
    }
    public static func draw(_ plan:MergePlan,pins:Set<GenePin>=[],seed:UInt64?=nil)throws->InheritedGenome {
        try validate(plan,pins:pins)
        if let seed=seed { var rng=SeededInheritanceRandom(seed:seed);return try draw(plan,pins:pins,using:&rng) }
        var rng=SystemRandomNumberGenerator();return try draw(plan,pins:pins,using:&rng)
    }
    private static func draw<R:RandomNumberGenerator>(_ plan:MergePlan,pins:Set<GenePin>,using rng:inout R)throws->InheritedGenome {
        let a=try choices(required:Set(pins.filter { $0.parent == .receiver }.map(\.slot)))
        let b=try choices(required:Set(pins.filter { $0.parent == .donor }.map(\.slot)))
        let unpinned=try choices()
        let pick=GeneSelection(aSkills:a.randomElement(using:&rng)!,bSkills:b.randomElement(using:&rng)!,aDevelopment:unpinned.randomElement(using:&rng)!,bDevelopment:unpinned.randomElement(using:&rng)!)
        return try assemble(plan,selection:pick)
    }
    public static func assemble(_ plan:MergePlan,selection:GeneSelection)throws->InheritedGenome {
        guard plan.a.isValid,plan.b.isValid else { throw InheritanceError.invalidPassport }
        guard [selection.aSkills,selection.bSkills,selection.aDevelopment,selection.bDevelopment].allSatisfy({ $0.count==2 && Set($0).count==2 && $0.allSatisfy { (0..<4).contains($0) } }) else { throw InheritanceError.invalidSelection }
        let skills=selection.aSkills.map { plan.a.skills[$0] }+selection.bSkills.map { plan.b.skills[$0] }
        let development=selection.aDevelopment.map { plan.a.development[$0] }+selection.bDevelopment.map { plan.b.development[$0] }
        return InheritedGenome(operationID:plan.id,receiver:plan.a,donor:plan.b,resultForm:plan.result,selection:selection,skills:compile(skills,as:plan.result),development:compile(development,as:plan.result))
    }
}

private struct SeededInheritanceRandom:RandomNumberGenerator {
    var value:UInt64
    init(seed:UInt64) { value=seed==0 ? 1 : seed }
    mutating func next()->UInt64 { value ^= value<<13;value ^= value>>7;value ^= value<<17;return value }
}
