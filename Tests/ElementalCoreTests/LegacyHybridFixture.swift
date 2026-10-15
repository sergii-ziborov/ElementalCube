import Foundation
@testable import ElementalCore

/// Alpha 13 save fixture for migration and the already shipped physical styles.
/// Production births go exclusively through AdventureState.commitMerge.
extension MonsterRecord {
    static func legacyOffspring(_ a:Self,_ b:Self,body:ElementForm,seed:UInt64=22)->Self {
        let base=Self(form:body,parents:[a,b].map { MonsterAncestor(id:$0.id,name:$0.name,form:$0.form) })
        var row=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(base)) as! [String:Any]
        var learned:Set<SkillNode.Kind>=[.passive],random=seed==0 ? 1 : seed
        func pick()->Bool { random ^= random<<13;random ^= random>>7;random ^= random<<17;return random&1==0 }
        for kind in [SkillNode.Kind.jump,.momentum,.mastery,.doubleJump,.control,.affinity,.resilience] {
            let x=a.learned.contains(kind) && pick(),y=b.learned.contains(kind) && pick()
            if x || y { learned.insert(kind) }
        }
        if learned.contains(.control) { learned.insert(.doubleJump) }
        if learned.contains(.doubleJump) { learned.insert(.momentum) }
        if learned.contains(.momentum) { learned.insert(.jump) }
        if learned.contains(.resilience) { learned.insert(.affinity) }
        if learned.contains(.affinity) { learned.insert(.mastery) }
        row["name"]=HybridStyle([a.form,b.form]).name;row["learned"]=learned.map(\.rawValue)
        row["crystals"]=Array(a.crystals.union(b.crystals));row["deepRelic"]=a.deepRelic || b.deepRelic
        row["skillPoints"]=a.skillPoints+b.skillPoints;row["evolutionStage"]=max(a.evolutionStage,b.evolutionStage)
        row["aetherAmount"]=a.quantity(of:.aetherShard)+b.quantity(of:.aetherShard)
        row["relicAmount"]=a.quantity(of:.deepRelic)+b.quantity(of:.deepRelic)
        row["travelerAmount"]=a.quantity(of:.travelerCharm)+b.quantity(of:.travelerCharm)
        if let charm=a.equippedCharm ?? b.equippedCharm { row["equippedCharm"]=charm.rawValue }
        return try! JSONDecoder().decode(Self.self,from:JSONSerialization.data(withJSONObject:row))
    }
}
