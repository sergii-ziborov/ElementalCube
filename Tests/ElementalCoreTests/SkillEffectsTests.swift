import XCTest
@testable import ElementalCore

final class SkillEffectsTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    private func skilled(_ form:ElementForm,_ kinds:[SkillNode.Kind])->MonsterRecord {
        var m=MonsterRecord(form:form);m.recordFinds(crystals:Set(0..<18),relic:false)
        for kind in kinds { XCTAssertTrue(m.learn(m.tree.first { $0.kind==kind }!)) };return m
    }
    func testEveryElementHasTwoCompleteChainsAndTruthfulNonMutatingPreviews() {
        for form in ElementForm.allCases {
            var m=MonsterRecord(form:form),saved=m
            XCTAssertEqual(m.tree.count,8);XCTAssertEqual(Set(m.tree.map(\.kind)).count,8)
            XCTAssertEqual(m.learned,[.passive]);XCTAssertTrue(m.tree.allSatisfy { !$0.summary.isEmpty && !$0.explanation.isEmpty })
            for node in m.tree { XCTAssertFalse(m.effects(of:node.kind).isEmpty) }
            XCTAssertEqual(m,saved)
            let final=m.tree.first { $0.kind == .resilience }!
            XCTAssertFalse(m.learn(final));XCTAssertEqual(m,saved)
            m.recordFinds(crystals:Set(0..<12),relic:false)
            for kind in SkillCatalog.elemental.dropFirst() { XCTAssertTrue(m.learn(m.tree.first { $0.kind==kind }!)) }
            XCTAssertTrue(m.learned.contains(.resilience));saved=m
            XCTAssertFalse(m.learn(final));XCTAssertEqual(m,saved)
            XCTAssertEqual(try! JSONDecoder().decode(MonsterRecord.self,from:JSONEncoder().encode(m)),m)
        }
    }
    func testWaterMasteryStrengthensTheActualStrokeRatherThanOnlyAnUnusedCap() {
        let trained=skilled(.water,[.mastery]),plain=MonsterRecord(form:.water)
        let a=Simulation(form:.water),b=Simulation(form:.water)
        for (s,m) in [(a,plain),(b,trained)] { s.wind=0;s.applySkills(of:m);s.placeCube(Vec(12,-2.4)) }
        XCTAssertTrue(a.inWater);XCTAssertTrue(b.inWater)
        XCTAssertTrue(a.jump(Vec(2,4),buffered:false));XCTAssertTrue(b.jump(Vec(2,4),buffered:false))
        XCTAssertEqual(b.cube.velocity.x/a.cube.velocity.x,1.15,accuracy:0.001)
        XCTAssertEqual(b.cube.velocity.y/a.cube.velocity.y,1.15,accuracy:0.001)
        for s in [a,b] { s.placeCube(Vec(12,-2.4));s.movement=1 };advance(a,0.3);advance(b,0.3)
        XCTAssertGreaterThan(b.cube.velocity.x,a.cube.velocity.x+0.1)
        XCTAssertEqual(a.mana,100);XCTAssertEqual(b.mana,100)
    }
    func testAirManeuverChangesHorizontalMomentumWithoutRemovingGravityOrGrantingAJump() {
        let m=skilled(.ice,[.jump,.momentum,.doubleJump,.control])
        let a=Simulation(),b=Simulation()
        for s in [a,b] { s.wind=0;s.waterEnabled=false;s.placeCube(Vec(2,8));s.movement=1 }
        b.applySkills(of:m);advance(a,0.3);advance(b,0.3)
        XCTAssertLessThan(abs(a.cube.velocity.x),0.01)
        XCTAssertGreaterThan(b.cube.velocity.x,1)
        XCTAssertEqual(b.cube.position.y,a.cube.position.y,accuracy:0.001)
        XCTAssertEqual(b.cube.velocity.y,a.cube.velocity.y,accuracy:0.001)
        XCTAssertEqual(b.jumps,0);XCTAssertEqual(b.mana,100)
    }
    func testLearnedWaterRecoveryNeedsWaterAndCannotRevive() {
        let m=skilled(.water,[.mastery,.affinity,.resilience])
        let a=Simulation(form:.water),b=Simulation(form:.water)
        for s in [a,b] { s.wind=0;s.placeCube(Vec(12,-2.4));s.damage(20) };b.applySkills(of:m)
        advance(a,0.5);advance(b,0.5)
        XCTAssertEqual(a.health,80,accuracy:0.001);XCTAssertEqual(b.health,80.75,accuracy:0.02)
        b.placeCube(Vec(2.7,0.7));let health=b.health;advance(b,0.5);XCTAssertEqual(b.health,health,accuracy:0.001)
        b.damage(100);b.placeCube(Vec(12,-2.4));advance(b,0.5);XCTAssertEqual(b.health,0);XCTAssertEqual(b.mana,100)
    }
    func testFireSignatureEvaporatesMoreRealWaterForTheSameHealthCost() {
        var m=skilled(.fire,[.mastery,.affinity]);let a=Simulation(form:.fire),b=Simulation(form:.fire)
        a.applySkills(of:m);XCTAssertTrue(m.learn(m.tree.first { $0.kind == .resilience }!));b.applySkills(of:m)
        for s in [a,b] { s.wind=0;s.placeCube(Vec(12,-2.5)) }
        let initial=a.waterField.volume;advance(a,0.15);advance(b,0.15)
        XCTAssertEqual((initial-b.waterField.volume)/(initial-a.waterField.volume),1.25,accuracy:0.02)
        XCTAssertEqual(a.health,b.health,accuracy:0.01);XCTAssertEqual(b.mana,100)
        XCTAssertEqual(b.waterField.representedVolume,b.waterField.volume,accuracy:0.0001)
    }
    func testSnowSignatureDriesRealWetnessFaster() {
        let m=skilled(.ice,[.mastery,.affinity,.resilience]);let a=Simulation(),b=Simulation();b.applySkills(of:m)
        for s in [a,b] { s.wind=0;s.equipPassive(false);s.placeCube(Vec(12,-2.5));advance(s,0.7);s.placeCube(Vec(2,0.7));s.equipPassive(true) }
        advance(a,1);advance(b,1)
        XCTAssertGreaterThan(a.wetness-b.wetness,0.03);XCTAssertEqual(b.mana,100)
    }
    func testAirSignatureReducesActualLandingDamage() {
        var m=skilled(.air,[.mastery,.affinity]);let a=Simulation(form:.air),b=Simulation(form:.air);a.applySkills(of:m)
        XCTAssertTrue(m.learn(m.tree.first { $0.kind == .resilience }!));b.applySkills(of:m)
        for s in [a,b] { s.wind=0;s.waterEnabled=false;s.placeCube(Vec(1.5,15));advance(s,2) }
        XCTAssertLessThan(a.health,99)
        XCTAssertEqual(100-b.health,(100-a.health)*0.65,accuracy:0.1)
    }
    func testStoneSignatureChangesTheActualRollingMotor() {
        var m=skilled(.stone,[.mastery,.affinity]);let a=Simulation(form:.stone),b=Simulation(form:.stone);a.applySkills(of:m)
        XCTAssertTrue(m.learn(m.tree.first { $0.kind == .resilience }!));b.applySkills(of:m)
        for s in [a,b] { s.wind=0;s.waterEnabled=false;advance(s,0.5);s.movement=1;advance(s,0.12) }
        XCTAssertGreaterThan(abs(b.cube.angularVelocity),abs(a.cube.angularVelocity)+0.03)
    }
    func testHybridFinisherKeepsItsOwnIdentityAndInheritedPrerequisites() {
        let a=skilled(.fire,[.mastery,.affinity,.resilience]),b=skilled(.stone,[.mastery,.affinity,.resilience])
        var inherited=false
        for seed:UInt64 in 1...20 {
            let child=MonsterRecord.offspring(a,b,body:.stone,seed:seed)
            XCTAssertEqual(child.signature,.boilingHeart)
            XCTAssertEqual(child.tree.first { $0.kind == .resilience }!.title,"Вулканическое кипение")
            if child.learned.contains(.resilience) { inherited=true;XCTAssertTrue(child.learned.isSuperset(of:[.mastery,.affinity])) }
            XCTAssertNotEqual(child.treeIdentity,a.treeIdentity)
        }
        XCTAssertTrue(inherited)
    }
    func testMistRecoveryAndDustWindGuardHaveRealHybridEffects() {
        func child(_ second:ElementForm)->MonsterRecord {
            var m=MonsterRecord.offspring(MonsterRecord(form:.air),MonsterRecord(form:second),body:.air,seed:1)
            m.recordFinds(crystals:Set(0..<18),relic:false)
            for kind in [SkillNode.Kind.mastery,.affinity,.resilience] { XCTAssertTrue(m.learn(m.tree.first { $0.kind==kind }!)) };return m
        }
        let mist=Simulation(form:.air);mist.wind=0;mist.applySkills(of:child(.water));mist.damage(20);mist.placeCube(Vec(9.2,0.1));advance(mist,0.5)
        XCTAssertGreaterThan(mist.health,80.25);let recovered=mist.health
        mist.placeCube(Vec(2.7,0.8));advance(mist,0.3);XCTAssertEqual(mist.health,recovered,accuracy:0.001)
        let dust=child(.stone),a=Simulation(form:.air),b=Simulation(form:.air)
        a.applySkills(of:dust.learningPreview(.resilience,remove:true));b.applySkills(of:dust)
        for s in [a,b] { s.wind=3;s.placeCube(Vec(12,8));advance(s,0.2) }
        XCTAssertGreaterThan(a.cube.velocity.x,0.1)
        XCTAssertEqual(b.cube.velocity.x/a.cube.velocity.x,0.25,accuracy:0.01)
        XCTAssertEqual(b.mana,100)
    }
}
