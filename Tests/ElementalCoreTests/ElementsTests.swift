import XCTest
@testable import ElementalCore

final class ElementsTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testFiveMaterialsStartWithAssignedPassiveHealthAndMana() {
        for form in ElementForm.allCases {
            let s=Simulation(form:form)
            XCTAssertEqual(s.health,100);XCTAssertEqual(s.mana,100);XCTAssertTrue(s.passiveEquipped)
            s.equipPassive(true);advance(s,1)
            XCTAssertTrue(s.passiveWorking);XCTAssertEqual(s.mana,100)
            s.equipPassive(false);advance(s,1);XCTAssertEqual(s.mana,100,accuracy:0.1)
        }
    }
    func testWaterFloatsAndStoneSinksThroughRealUnderpass() {
        let water=Simulation(form:.water),stone=Simulation(form:.stone)
        for s in [water,stone] { s.wind=0;s.placeCube(Vec(10,-1));s.equipPassive(true);advance(s,3) }
        XCTAssertGreaterThan(water.cube.position.y,-1.3)
        XCTAssertLessThan(stone.cube.position.y,-3)
        XCTAssertGreaterThan(stone.cube.mass,water.cube.mass*3)
        stone.movement=1;advance(stone,2)
        XCTAssertTrue(stone.deepRelic,"\(stone.cube.position)")
        XCTAssertFalse(water.deepRelic)
    }
    func testStoneCanReturnFromBottomAlongTheBank() {
        let s=Simulation(form:.stone);s.wind=0;s.equipPassive(true);s.placeCube(Vec(10,-1));advance(s,3)
        s.movement = -1;advance(s,12)
        XCTAssertLessThan(s.cube.position.x,7,"\(s.cube.position)");XCTAssertGreaterThan(s.cube.position.y,0)
    }
    func testPhaseUpdatesAndEvaporationConserveRepresentedWater() {
        let s=Simulation(),field=s.waterField,initial=field.volume
        for _ in 0..<300 { field.step(dt:0.1,coldSource:nil,heatSource:nil,occupied:[]) }
        XCTAssertEqual(field.surface(at:10),-0.72,accuracy:0.001)
        XCTAssertEqual(field.surface(at:14),-0.72,accuracy:0.001)
        XCTAssertEqual(field.surface(at:12),-0.72,accuracy:0.001)
        XCTAssertEqual(field.volume,initial,accuracy:0.001)
        XCTAssertEqual(field.representedVolume,initial,accuracy:0.0001)
        _=field.evaporate(around:Vec(10,-1),amount:1)
        XCTAssertEqual(field.surface(at:10),field.surface(at:14),accuracy:0.001)
        XCTAssertEqual(field.volume+field.evaporated,initial,accuracy:0.001)
        XCTAssertEqual(field.representedVolume,field.volume,accuracy:0.0001)
    }
    func testBurnedCrateLosesItsCollider() {
        let s=Simulation(form:.fire);s.wind=0;s.equipPassive(true);s.placeCube(Vec(3.9,0.7));advance(s,10)
        XCTAssertFalse(s.crateExists)
        XCTAssertFalse(s.intersectsSolid(at:Vec(5.1,0.7)))
    }
    func testAirSlidesWithoutRollingAndSkimsWater() {
        let s=Simulation(form:.air);s.wind=0;s.equipPassive(true);s.placeCube(Vec(9.4,0.1));advance(s,4)
        XCTAssertLessThan(s.wetness,0.1);XCTAssertEqual(s.cube.position.y,s.waterLevel+0.76,accuracy:0.2)
        s.movement=1;advance(s,1)
        XCTAssertGreaterThan(s.cube.position.x,11)
        XCTAssertEqual(s.cube.angle,0,accuracy:0.001);XCTAssertEqual(s.cube.angularVelocity,0,accuracy:0.001)
        XCTAssertTrue(s.jump(Vec(0,7),buffered:false))
    }
    func testNoPassiveMeansNoEnvironmentalFreezeOrBurn() {
        let ice=Simulation();ice.equipPassive(false);ice.placeCube(Vec(10,-1));advance(ice,3)
        XCTAssertTrue(ice.iceCells.isEmpty)
        let fire=Simulation(form:.fire);fire.equipPassive(false);advance(fire,3)
        XCTAssertTrue(fire.patches.allSatisfy { $0.fuel==1 });XCTAssertEqual(fire.crateFuel,1)
    }
    func testFireConsumesLocalFuelAndLeavesPersistentChar() {
        let s=Simulation(form:.fire);s.wind=0;s.equipPassive(true);advance(s,6)
        let scorched=s.patches.filter { $0.fuel<0.1 }
        XCTAssertFalse(scorched.isEmpty)
        XCTAssertTrue(s.patches.filter { abs($0.x-2.7)>2 }.allSatisfy { $0.fuel==1 })
        s.equipPassive(false);advance(s,1)
        XCTAssertTrue(scorched.allSatisfy { old in s.patches.first { $0.x==old.x }!.fuel<=old.fuel })
    }
    func testWoodIgnitesButSubmergedWoodDoesNot() {
        let s=Simulation(form:.fire);s.wind=0;s.equipPassive(true);s.placeCube(Vec(3.9,0.7));advance(s,3)
        XCTAssertLessThan(s.crateFuel,1)
        let wet=Simulation(form:.fire);wet.placeCube(Vec(10,-1));wet.equipPassive(true);advance(wet,3)
        XCTAssertEqual(wet.crateFuel,1)
    }
    func testFireCanDrainFinitePoolAtHealthCost() {
        let deep=Simulation(form:.fire);deep.equipPassive(true);deep.placeCube(Vec(10,-2.8))
        let deepVolume=deep.waterField.volume;XCTAssertTrue(deep.inWater);deep.step()
        XCTAssertLessThan(deep.waterField.volume,deepVolume);XCTAssertLessThan(deep.health,100)
        let s=Simulation(form:.fire);s.wind=0;s.equipPassive(true);s.placeCube(Vec(10,-1))
        let initial=s.waterField.volume
        advance(s,2)
        XCTAssertLessThan(s.waterField.volume,initial-1);XCTAssertLessThan(s.health,100)
        XCTAssertEqual(s.waterField.volume+s.waterField.evaporated,initial,accuracy:0.001)
        // Follow the receding surface into both sides of the connected basin.
        for _ in 0..<80 {
            if s.waterField.volume<0.0001 { break }
            guard let marker=s.waterField.liquid.particles.first else { break }
            s.placeCube(marker.position);advance(s,0.5)
        }
        XCTAssertLessThan(s.waterField.volume,0.0001)
        XCTAssertGreaterThan(s.health,0)
    }
    func testInsufficientHealthStopsEvaporationAndJump() {
        let s=Simulation(form:.fire);s.equipPassive(true);s.damage(99);s.placeCube(Vec(10,-1));advance(s,3)
        XCTAssertTrue(s.dead);XCTAssertFalse(s.passiveWorking);XCTAssertFalse(s.jump(Vec(0,8)))
        let remaining=s.waterField.volume;advance(s,2);XCTAssertEqual(s.waterField.volume,remaining,accuracy:0.001)
        XCTAssertEqual(s.takeFeedback().filter { $0 == .died }.count,1)
    }
    func testIceGrowsUpDownAndConservesWaterVolume() {
        let field=WaterField(platforms:[]),initial=field.volume,source=Vec(10,-2)
        field.step(dt:0.1,coldSource:source,heatSource:nil,occupied:[source]);XCTAssertFalse(field.ice.contains { $0.solid })
        for _ in 0..<40 { field.step(dt:0.1,coldSource:source,heatSource:nil,occupied:[source]) }
        let solid=field.ice.filter { $0.solid }
        XCTAssertFalse(solid.isEmpty)
        XCTAssertTrue(solid.contains { $0.center.y>source.y+0.5 });XCTAssertTrue(solid.contains { $0.center.y<source.y-0.5 })
        XCTAssertTrue(solid.allSatisfy { hypot($0.center.x-source.x,$0.center.y-source.y)<1.45 })
        XCTAssertEqual(field.volume,initial,accuracy:0.001)
        XCTAssertFalse(solid.contains { abs($0.center.x-source.x)<0.78 && abs($0.center.y-source.y)<0.78 })
    }
    func testColdCoatsContactWood() {
        let s=Simulation();s.wind=0;s.equipPassive(true);s.placeCube(Vec(3.9,0.7));advance(s,2)
        XCTAssertGreaterThan(s.crateFrost,0.5)
    }
    func testPassiveRemainsFreeAfterAnActiveJumpSpendsMana() {
        var monster=MonsterRecord(form:.air)
        XCTAssertTrue(monster.learn(monster.tree.first { $0.kind == .jump }!))
        let s=Simulation(form:.air);s.wind=0;s.applySkills(of:monster);advance(s,1)
        XCTAssertTrue(s.performJump(Vec(3,7),directed:true));XCTAssertEqual(s.mana,94,accuracy:0.001)
        advance(s,0.5);XCTAssertTrue(s.passiveWorking);XCTAssertEqual(s.mana,94+Float(Int(Float(0.5)/Simulation.timestep))*Simulation.timestep*4,accuracy:0.001)
        advance(s,2);XCTAssertTrue(s.passiveWorking);XCTAssertEqual(s.mana,100,accuracy:0.01)
    }
    func testStoneHasNoFurAndFrontFurExistsForWaterAndIce() {
        XCTAssertTrue(FurPhysics(form:.stone).strands.isEmpty)
        XCTAssertTrue(FurPhysics(form:.fire).strands.isEmpty)
        for form in [ElementForm.ice,.water] {
            let fur=FurPhysics(form:form)
            XCTAssertGreaterThan(fur.strands.filter { $0.face==0 }.count,30)
            XCTAssertEqual(Set(fur.strands.map(\.face)).count,6)
        }
    }
    func testRetainedWaterAddsRealBodyMassAndDriesAway() {
        let s=Simulation();s.wind=0;let dryMass=s.cube.mass
        s.placeCube(Vec(10,-1));advance(s,3)
        XCTAssertGreaterThan(s.cube.mass,dryMass*1.1)
        s.placeCube(Vec(2,0.7));advance(s,20)
        XCTAssertEqual(s.cube.mass,dryMass,accuracy:0.002)
    }
    func testConstrainedFurRespondsToWindWaterAndBodyMotion() {
        let still=FurPhysics(form:.ice),windy=FurPhysics(form:.ice),wet=FurPhysics(form:.ice)
        for _ in 0..<120 {
            for (f,wind,water) in [(still,Float(0),false),(windy,Float(6),false),(wet,Float(6),true)] {
                f.step(dt:1/60,center:SIMD3(0,1,0),angle:0,stretch:SIMD3(repeating:1),wind:wind,water:{ _ in water },solid:{ _ in false })
            }
        }
        let a=still.strands.first { $0.face==3 }!,b=windy.strands.first { $0.face==3 }!,c=wet.strands.first { $0.face==3 }!
        XCTAssertGreaterThan(b.points[3].x,a.points[3].x+0.01)
        XCTAssertEqual(c.wetness,1,accuracy:0.001)
        XCTAssertGreaterThan(abs(c.points[3].y-b.points[3].y),0.002)
        for strand in windy.strands {
            for j in 1...3 {
                let v=strand.points[j]-strand.points[j-1],length=sqrt(v.x*v.x+v.y*v.y+v.z*v.z)
                XCTAssertTrue(length.isFinite);XCTAssertEqual(length,strand.length/3,accuracy:0.018)
            }
        }
        windy.step(dt:1/60,center:SIMD3(2,3,0),angle:0.7,stretch:SIMD3(repeating:1),wind:0,water:{ _ in false },solid:{ _ in false })
        XCTAssertGreaterThan(windy.strands[0].points[0].y,2)
    }
}
