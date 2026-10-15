import XCTest
@testable import ElementalCore

final class AlphaNineTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) {
        for _ in 0..<Int(seconds/Simulation.timestep) { s.step() }
    }
    private func learn(_ kind:SkillNode.Kind,_ monster:inout MonsterRecord) {
        XCTAssertTrue(monster.learn(monster.tree.first { $0.kind==kind }!))
    }
    func testNewMonstersOnlyKnowTheirPassiveAndLegacyMigrationKeepsPaidProgress() throws {
        let bag=MonsterInventory()
        XCTAssertTrue(bag.monsters.allSatisfy { $0.learned == [.passive] })
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(bag)) as? [String:Any])
        json.removeValue(forKey:"schemaVersion")
        var monsters=try XCTUnwrap(json["monsters"] as? [[String:Any]])
        monsters[0]["learned"]=["passive","jump","momentum"]
        monsters[0]["crystals"]=[3,4]
        monsters[0]["skillPoints"]=2
        json["monsters"]=monsters
        let migrated=try JSONDecoder().decode(MonsterInventory.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(migrated.monsters[0].learned,[.passive,.momentum])
        XCTAssertEqual(migrated.monsters[0].crystals,[3,4]);XCTAssertEqual(migrated.monsters[0].skillPoints,2)
        XCTAssertEqual(migrated.selectedID,bag.selectedID);XCTAssertTrue(migrated.isValid)
        XCTAssertEqual(try JSONDecoder().decode(MonsterInventory.self,from:JSONEncoder().encode(migrated)),migrated)
    }
    func testBasicJumpIsFreeAndDirectedJumpRequiresLearning() {
        let s=Simulation();s.wind=0;s.waterEnabled=false
        var monster=MonsterRecord(form:.ice);s.applySkills(of:monster);advance(s,0.5)
        XCTAssertFalse(s.performJump(Vec(4,8),directed:true));XCTAssertEqual(s.jumps,0)
        XCTAssertTrue(s.performJump());XCTAssertEqual(s.mana,100)
        advance(s,0.25);XCTAssertFalse(s.performJump(),"A new monster cannot jump in mid-air")
        advance(s,2)
        learn(.jump,&monster);s.applySkills(of:monster)
        XCTAssertTrue(s.performJump(Vec(4,8),directed:true));XCTAssertEqual(s.mana,94,accuracy:0.001)
        XCTAssertGreaterThan(s.cube.velocity.x,3)
        XCTAssertLessThanOrEqual(hypot(s.cube.velocity.x,s.cube.velocity.y),monster.jumpSkill.maximumSpeed+0.001)
    }
    func testLearnedDoubleJumpAllowsOneAirBoostAndResetsOnLanding() {
        var monster=MonsterRecord(form:.ice)
        monster.recordFinds(crystals:[0,1,2],relic:false)
        learn(.jump,&monster);learn(.momentum,&monster);learn(.doubleJump,&monster)
        let s=Simulation();s.wind=0;s.waterEnabled=false;s.applySkills(of:monster);advance(s,0.5)
        XCTAssertTrue(s.performJump());advance(s,0.25)
        XCTAssertTrue(s.nextJumpIsAirJump)
        XCTAssertTrue(s.performJump());XCTAssertEqual(s.mana,90,accuracy:0.001)
        advance(s,0.25);XCTAssertFalse(s.performJump(),"No third airborne jump")
        advance(s,3);XCTAssertTrue(s.cube.grounded)
        XCTAssertTrue(s.performJump());advance(s,0.25);XCTAssertTrue(s.performJump())
    }
    func testFireAndStoneAreImmuneWhileOtherDryFormsIgniteAndWaterExtinguishes() {
        for form in ElementForm.allCases {
            let s=Simulation(form:form);s.wind=0;s.waterEnabled=false
            s.fireSources=[FireSource(Vec(2.7,0.7),radius:2)]
            advance(s,2)
            if form.fireImmune {
                XCTAssertEqual(s.burning,0,"\(form)");XCTAssertEqual(s.health,100,"\(form)")
            } else {
                XCTAssertGreaterThan(s.burning,0.8,"\(form)");XCTAssertLessThan(s.health,99,"\(form)")
                s.fireSources=[];s.waterEnabled=true;s.placeCube(Vec(10,-2.5));advance(s,0.1)
                XCTAssertEqual(s.burning,0,"\(form)")
                let health=s.health;advance(s,0.2);XCTAssertEqual(s.health,health,accuracy:0.001)
            }
            s.resetCube();XCTAssertEqual(s.burning,0);XCTAssertEqual(s.health,100)
        }
    }
    func testAnImpactDetachesConservedBallisticWaterAndProducesFoam() {
        let s=Simulation(form:.water);s.wind=0
        s.placeCrate(Vec(10,1.2),angle:0.1,velocity:Vec(0,-5))
        let mass=s.waterField.representedVolume,count=s.waterField.liquid.particles.count
        var maxDrops=0,maxFoam=0,checkedBallistic=false
        var peakHeight:Float=0,peakVy:Float=0
        for _ in 0..<240 {
            let fluid=s.waterField.liquid
            if !checkedBallistic,let index=fluid.particles.firstIndex(where:{ p in
                p.isSpray && p.position.y>fluid.surfaceHeight(at:p.position.x)+0.35 && p.velocity.y>0.5 &&
                s.fluidBodies.allSatisfy { !$0.contains(p.position,margin:0.35) }
            }) {
                let old=fluid.particles[index]
                s.step()
                let next=fluid.particles[index]
                XCTAssertTrue(next.isSpray)
                XCTAssertEqual(next.velocity.y,old.velocity.y-s.gravity*Simulation.timestep,accuracy:0.001)
                checkedBallistic=true
            } else { s.step() }
            maxDrops=max(maxDrops,fluid.particles.filter(\.isSpray).count);maxFoam=max(maxFoam,fluid.foam.count)
            for p in fluid.particles where p.isSpray { peakHeight=max(peakHeight,p.position.y-fluid.surfaceHeight(at:p.position.x));peakVy=max(peakVy,p.velocity.y) }
        }
        XCTAssertGreaterThan(maxDrops,3);XCTAssertTrue(checkedBallistic,"Peak elevation: \(peakHeight), upward velocity: \(peakVy), drops: \(maxDrops)")
        XCTAssertGreaterThan(maxFoam,3)
        XCTAssertEqual(s.waterField.liquid.particles.count,count)
        XCTAssertEqual(s.waterField.representedVolume,mass,accuracy:0.0001)
        advance(s,3)
        XCTAssertLessThan(s.waterField.liquid.particles.filter(\.isSpray).count,maxDrops)
    }
    func testSurfaceIceAdvancesWithPartialWidthAndThickerIceSurvivesLonger() {
        let field=WaterField(platforms:[]),mass=field.representedVolume
        field.freezeContact(at:10,bottom:-0.71)
        let source=Vec(10,-0.16),initialWidth=field.ice.filter(\.solid).reduce(Float(0)) { $0+$1.size }
        let initialTop=field.ice.filter(\.solid).map { $0.center.y+$0.height/2 }.max()!
        let original=Set(field.ice.indices.filter { field.ice[$0].solid })
        var sawAdvancingEdge=false
        for _ in 0..<240 {
            field.step(dt:1/30,coldSource:source,heatSource:nil,occupied:[source],coldFoot:-0.72)
            sawAdvancingEdge = sawAdvancingEdge || field.ice.indices.contains { !original.contains($0) && field.ice[$0].solid && field.ice[$0].size<field.cell-0.02 }
        }
        let frozen=field.ice.filter(\.solid),thickness=frozen.map(\.height).max()!
        XCTAssertGreaterThan(frozen.reduce(Float(0)) { $0+$1.size },initialWidth+0.25)
        XCTAssertTrue(sawAdvancingEdge)
        XCTAssertGreaterThan(thickness,0.6)
        XCTAssertEqual(frozen.map { $0.center.y+$0.height/2 }.max()!,initialTop,accuracy:0.001)
        for _ in 0..<400 { field.step(dt:0.1,coldSource:nil,heatSource:nil,occupied:[]) }
        XCTAssertTrue(field.ice.contains { $0.solid && $0.height>0.4 })
        XCTAssertEqual(field.representedVolume,mass,accuracy:0.0001)
    }
}
