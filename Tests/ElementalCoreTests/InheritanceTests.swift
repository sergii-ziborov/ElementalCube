import XCTest
@testable import ElementalCore

final class InheritanceTests:XCTestCase {
    private func grown(_ form:ElementForm)->MonsterRecord {
        var m=MonsterRecord(form:form);m.recordFinds(crystals:Set(0..<24),relic:true)
        for kind in [SkillNode.Kind.jump,.momentum,.doubleJump,.control,.mastery,.affinity,.resilience] { XCTAssertTrue(m.learn(m.tree.first { $0.kind==kind }!)) }
        XCTAssertTrue(m.evolve());return m
    }
    private func funded()->AdventureState {
        var s=AdventureState();_ = s.begin(with:s.inventory.selected);s.recordFinds(Set(0..<12),relic:true)
        let fire=s.inventory.monsters.first { $0.form == .fire }!;_ = s.select(fire.id)
        return s
    }
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testOnlyExplicitSymmetricReactionsAndSameFormIdentitiesExist() {
        XCTAssertEqual(FormCatalog.reactions.count,22)
        var keys=Set<String>()
        for row in FormCatalog.reactions {
            XCTAssertTrue(keys.insert([row.a.rawValue,row.b.rawValue].sorted().joined(separator:"+")).inserted)
            XCTAssertEqual(FormCatalog.result(row.a,row.b),row.result);XCTAssertEqual(FormCatalog.result(row.b,row.a),row.result)
        }
        for form in CreatureForm.allCases { XCTAssertEqual(FormCatalog.result(form,form),form) }
        XCTAssertEqual(FormCatalog.result(.water,.fire),.steam);XCTAssertEqual(FormCatalog.result(.ice,.fire),.steam)
        XCTAssertEqual(FormCatalog.result(.steam,.fire),.fire);XCTAssertEqual(FormCatalog.result(.ice,.water),.water)
        XCTAssertEqual(FormCatalog.result(.ice,.stone),.clay);XCTAssertNil(FormCatalog.result(.lava,.steam))
    }
    func testAll1296LabelledOutcomesHaveExactQuotasAndHalfMarginals() throws {
        let plan=try XCTUnwrap(MergePlan(grown(.ice),grown(.fire))),choices=try InheritanceEngine.choices()
        XCTAssertEqual(choices.count,6)
        var seen=Set<String>(),aSkills=[Int](repeating:0,count:4),bSkills=aSkills,aTraits=aSkills,bTraits=aSkills
        for a in choices { for b in choices { for at in choices { for bt in choices {
            let selection=GeneSelection(aSkills:a,bSkills:b,aDevelopment:at,bDevelopment:bt)
            let genome=try InheritanceEngine.assemble(plan,selection:selection)
            XCTAssertTrue(genome.isValid);XCTAssertEqual(genome.skills.count,4);XCTAssertEqual(genome.development.count,4)
            for owner in [plan.receiver.id,plan.donor.id] {
                XCTAssertEqual(genome.skills.filter { $0.source.ownerID==owner }.count,2)
                XCTAssertEqual(genome.development.filter { $0.source.ownerID==owner }.count,2)
            }
            seen.insert([a,b,at,bt].map { $0.map(String.init).joined() }.joined(separator:"/"))
            for i in a { aSkills[i]+=1 };for i in b { bSkills[i]+=1 };for i in at { aTraits[i]+=1 };for i in bt { bTraits[i]+=1 }
        } } } }
        XCTAssertEqual(seen.count,1296)
        for count in aSkills+bSkills+aTraits+bTraits { XCTAssertEqual(count,648) }
    }
    func testLocksConditionTheRealDistributionAndCannotKeepAnIncompatibleBranch() throws {
        var a=grown(.ice),b=grown(.fire)
        XCTAssertTrue(a.setInheritanceSelection([.mastery,.affinity,.resilience,.jump]))
        let plan=try XCTUnwrap(MergePlan(a,b))
        XCTAssertEqual(plan.lockBudget,1)
        XCTAssertThrowsError(try InheritanceEngine.draw(plan,pins:[GenePin(.receiver,0)],seed:1))
        let pin=GenePin(.receiver,3)
        XCTAssertNoThrow(try InheritanceEngine.validate(plan,pins:[pin]))
        XCTAssertEqual(plan.probability(pin,pins:[pin]),1)
        XCTAssertEqual(plan.probability(GenePin(.receiver,0),pins:[pin]),1.0/3,accuracy:0.000001)
        XCTAssertEqual(plan.probability(GenePin(.donor,0),pins:[pin]),0.5)
        XCTAssertThrowsError(try InheritanceEngine.draw(plan,pins:[GenePin(.receiver,3),GenePin(.donor,0)],seed:1))
        XCTAssertThrowsError(try InheritanceEngine.draw(plan,pins:[GenePin(.receiver,-1)],seed:1))
        XCTAssertThrowsError(try InheritanceEngine.assemble(plan,selection:GeneSelection(aSkills:[0,4],bSkills:[0,1],aDevelopment:[0,1],bDevelopment:[0,1])))
        for seed:UInt64 in 1...30 { XCTAssertTrue(try InheritanceEngine.draw(plan,pins:[pin],seed:seed).selection.aSkills.contains(3)) }
    }
    func testDuplicatesAndLostImprintsKeepTheirOriginsWithoutRerollOrExtraPrerequisites() throws {
        var a=grown(.ice),b=grown(.fire)
        XCTAssertTrue(a.setInheritanceSelection([.control,.mastery]));XCTAssertTrue(b.setInheritanceSelection([.control,.mastery]))
        let plan=try XCTUnwrap(MergePlan(a,b))
        let genome=try InheritanceEngine.assemble(plan,selection:GeneSelection(aSkills:[0,1],bSkills:[0,1],aDevelopment:[0,1],bDevelopment:[2,3]))
        XCTAssertEqual(genome.skills.map(\.disposition),[.transformed,.lost,.duplicate,.lost])
        XCTAssertEqual(genome.potential,[.control]);XCTAssertEqual(genome.skills.count,4)
        var child=MonsterRecord.metamorphosed(plan,genome:genome)
        XCTAssertEqual(child.learned,[.passive]);XCTAssertEqual(child.tree.first { $0.kind == .control }?.cost,0)
        XCTAssertTrue(child.learn(child.tree.first { $0.kind == .jump }!));XCTAssertTrue(child.learn(child.tree.first { $0.kind == .momentum }!))
        XCTAssertFalse(child.learned.contains(.control));XCTAssertTrue(child.learn(child.tree.first { $0.kind == .doubleJump }!))
        XCTAssertTrue(child.learned.contains(.control));XCTAssertFalse(child.learned.contains(.mastery))
    }
    func testReceiverIsArchivedDonorAndItemsStayAndConfirmationIsIdempotentAfterRelaunch() throws {
        var s=funded();let receiver=s.inventory.monsters.first { $0.form == .ice }!,donor=s.inventory.selected
        let plan=try XCTUnwrap(s.prepareMerge(receiver.id,donor.id)),coins=s.coins
        let child=try XCTUnwrap(s.commitMerge(plan,seed:14))
        XCTAssertEqual(child.currentForm,.steam);XCTAssertEqual(child.form,.water);XCTAssertEqual(child.lineageID,receiver.lineageID);XCTAssertEqual(child.generation,1)
        XCTAssertEqual(s.coins,coins-4);XCTAssertEqual(s.archivedGenerations,[receiver]);XCTAssertFalse(s.owned.contains(receiver.id))
        XCTAssertFalse(s.inventory.monsters.contains { $0.id==receiver.id });XCTAssertTrue(s.inventory.monsters.contains(donor))
        XCTAssertEqual(s.collection.count,2);XCTAssertEqual(child.skillPoints,receiver.skillPoints)
        for item in MonsterItem.allCases { XCTAssertEqual(child.quantity(of:item),receiver.quantity(of:item)) }
        let before=s;XCTAssertEqual(s.commitMerge(plan,seed:999),child);XCTAssertEqual(s,before)
        let suite="ElementalCube.genetics."+UUID().uuidString,defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let store=AdventureStore(defaults:defaults);store.save(s);var restored=store.load(fallback:MonsterInventory())
        XCTAssertEqual(restored,s);XCTAssertEqual(restored.commitMerge(plan,seed:4),child);XCTAssertEqual(restored,s)
        let second=try XCTUnwrap(restored.prepareMerge(child.id,donor.id));let fire=try XCTUnwrap(restored.commitMerge(second,seed:15))
        XCTAssertEqual(fire.currentForm,.fire);XCTAssertNil(fire.hybridStyle);XCTAssertNil(fire.secondaryForm);XCTAssertEqual(fire.generation,2)
        XCTAssertTrue(restored.inventory.monsters.contains(donor));XCTAssertFalse(fire.freezesOnContact)
        let after=restored;XCTAssertEqual(restored.commitMerge(plan,seed:777),child);XCTAssertEqual(restored,after);XCTAssertEqual(restored.inventory.selectedID,fire.id)
        XCTAssertFalse(restored.inventory.select(receiver.id));XCTAssertTrue(restored.isValid)
    }
    func testInvalidOrStalePlanLeavesEverythingUntouched() throws {
        var s=funded();let receiver=s.inventory.monsters.first { $0.form == .ice }!,donor=s.inventory.selected
        let plan=try XCTUnwrap(s.prepareMerge(receiver.id,donor.id)),before=s
        XCTAssertNil(s.commitMerge(plan,pins:[GenePin(.receiver,0)],seed:1));XCTAssertEqual(s,before)
        s.recordFinds([0],relic:false);let changed=s
        XCTAssertNil(s.commitMerge(plan,seed:1));XCTAssertEqual(s,changed)
        let new=try XCTUnwrap(s.prepareMerge(receiver.id,donor.id));let first=try XCTUnwrap(s.commitMerge(new,seed:1))
        _ = s.merge(first.id,donor.id,seed:2)
        let noMoney=s;XCTAssertNil(s.merge(s.inventory.selectedID,donor.id));XCTAssertEqual(s,noMoney)
    }
    func testSteamHasNoIceOrFireContactAndReallyResistsFireAndCannotSqueeze() throws {
        let plan=try XCTUnwrap(MergePlan(grown(.ice),grown(.fire)))
        let child=MonsterRecord.metamorphosed(plan,genome:try InheritanceEngine.draw(plan,seed:7))
        XCTAssertEqual(child.currentForm,.steam);XCTAssertTrue(child.heatImmune);XCTAssertFalse(child.freezesOnContact);XCTAssertFalse(child.burnsOnContact);XCTAssertFalse(child.compresses)
        let s=Simulation(form:child.form);s.applySkills(of:child);s.wind=0;s.placeCube(Vec(12,-2.5));advance(s,0.25)
        XCTAssertTrue(s.iceCells.isEmpty);XCTAssertEqual(s.boilingStrength,0)
        s.waterEnabled=false;s.placeCube(Vec(2.7,0.7));s.fireSources=[FireSource(Vec(2.7,0.7),radius:2)];advance(s,1.8)
        XCTAssertEqual(s.burning,0);XCTAssertEqual(s.health,100,accuracy:0.001)
        s.fireSources=[];s.placeCube(Vec(17.6,0.57));s.movement=1;advance(s,2)
        XCTAssertFalse(s.compressed);XCTAssertLessThan(s.cube.position.x,24.5)
        XCTAssertEqual(s.cubeHeight,1.12,accuracy:0.001)
    }
    func testOldSaveKeepsProgressAndLegacyAppearanceWhileNewGenerationUsesCurrentForms() throws {
        let old=MonsterRecord.legacyOffspring(grown(.ice),grown(.stone),body:.stone,seed:12)
        var row=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(old)) as? [String:Any])
        for key in ["morphology","lineageID","generation","inheritance","passportKinds"] { row.removeValue(forKey:key) }
        let restored=try JSONDecoder().decode(MonsterRecord.self,from:JSONSerialization.data(withJSONObject:row))
        XCTAssertNil(restored.morphology);XCTAssertEqual(restored.hybridStyle,.crystal);XCTAssertEqual(restored.learned,old.learned);XCTAssertEqual(restored.crystals,old.crystals)
        XCTAssertTrue(restored.geneticsValid)
        let plan=try XCTUnwrap(MergePlan(restored,MonsterRecord(form:.fire)))
        XCTAssertEqual(plan.result,.lava)
        XCTAssertEqual(try JSONDecoder().decode(MonsterRecord.self,from:JSONEncoder().encode(restored)),restored)
    }
    func testPassportHasOnlyFourChosenImprintsAndCannotIncludeTheInnatePassive() throws {
        var a=grown(.ice)
        XCTAssertTrue(a.setInheritanceSelection([.control,.resilience]))
        let passport=GenePassport(a);XCTAssertTrue(passport.isValid)
        XCTAssertEqual(passport.skills.map(\.content),[.skill(.control),.skill(.resilience),.unrevealed,.unrevealed])
        let before=a
        XCTAssertFalse(a.setInheritanceSelection([.passive]));XCTAssertFalse(a.setInheritanceSelection([.jump,.jump]));XCTAssertEqual(a,before)
        XCTAssertEqual(try JSONDecoder().decode(MonsterRecord.self,from:JSONEncoder().encode(a)).inheritanceSelection,[.control,.resilience])
        XCTAssertTrue(a.setInheritanceSelection([]));XCTAssertTrue(GenePassport(a).skills.allSatisfy { $0.rank==0 })
    }
    func testTwoPinsStillSelectOnlyTwoCardsAndDuplicatesStayDuplicates() throws {
        var a=grown(.fire);XCTAssertTrue(a.evolve());XCTAssertTrue(a.evolve())
        let plan=try XCTUnwrap(MergePlan(a,grown(.fire))),pins:Set<GenePin>=[GenePin(.receiver,0),GenePin(.receiver,1)]
        XCTAssertEqual(plan.lockBudget,2);XCTAssertEqual(plan.probability(GenePin(.receiver,2),pins:pins),0)
        let genome=try InheritanceEngine.draw(plan,pins:pins,seed:42)
        XCTAssertEqual(genome.selection.aSkills,[0,1]);XCTAssertEqual(genome.skills.count,4)
        let duplicate=try InheritanceEngine.assemble(plan,selection:GeneSelection(aSkills:[0,1],bSkills:[0,1],aDevelopment:[0,1],bDevelopment:[0,1]))
        XCTAssertEqual(duplicate.skills.filter { $0.disposition == .duplicate }.count,2);XCTAssertEqual(duplicate.potential.count,2)
    }
    func testUnsupportedHybridPairIsRejectedBeforePaymentOrChangingEitherLine() throws {
        func make(_ a:ElementForm,_ b:ElementForm)throws->MonsterRecord {
            let plan=try XCTUnwrap(MergePlan(MonsterRecord(form:a),MonsterRecord(form:b)))
            return MonsterRecord.metamorphosed(plan,genome:try InheritanceEngine.draw(plan,seed:4))
        }
        let steam=try make(.water,.fire),lava=try make(.stone,.fire)
        var inventory=MonsterInventory();inventory.add(steam);inventory.add(lava,select:false)
        var save=AdventureState(inventory:inventory);XCTAssertTrue(save.begin(with:steam));save.recordFinds(Set(0..<12),relic:false);XCTAssertTrue(save.select(lava.id))
        let before=save
        XCTAssertNil(save.prepareMerge(steam.id,lava.id));XCTAssertNil(save.merge(steam.id,lava.id,seed:9));XCTAssertEqual(save,before)
    }
}
