import XCTest
@testable import ElementalCore

final class DirectControlAndInventoryTests:XCTestCase {
    func testLongScreenSwipeStillJumpsWhileStationaryCubeHoldStillPets() {
        var input=DirectControl()
        input.begin(screen:Vec(100,900),worldX:0,onCube:false,canJump:true,time:0)
        input.update(screen:Vec(100,300),worldX:0,time:1.2)
        guard case .swipeJump(let jump)=input.end(time:1.3) else { return XCTFail("A tablet-sized upward stroke must not expire") }
        XCTAssertGreaterThan(jump.y,0)
        input.begin(screen:Vec(100,900),worldX:0,onCube:true,canJump:true,time:2)
        input.update(screen:Vec(100,900),worldX:0,time:2.4)
        input.update(screen:Vec(100,300),worldX:0,time:3)
        XCTAssertEqual(input.end(time:3.1),.pet)
    }

    func testDirectAimPreservesAllQuadrantsAndSkillLimit() {
        for d in [Vec(70,-90),Vec(-70,-90),Vec(70,90),Vec(-70,90),Vec(100,0),Vec(0,-100)] {
            let v=AimPlanner.directImpulse(dx:d.x,dy:d.y,maximumSpeed:9)
            XCTAssertEqual(v.x*d.y+v.y*d.x,0,accuracy:0.0001)
            XCTAssertGreaterThan(v.x*d.x-v.y*d.y,0)
            XCTAssertLessThanOrEqual(hypot(v.x,v.y),9.00001)
        }
        let tiny=AimPlanner.directImpulse(dx:4,dy:-4,maximumSpeed:12)
        XCTAssertEqual(tiny,Vec(0,0))
        var previous:Float=0
        for length in stride(from:Float(8),through:200,by:1) {
            let v=AimPlanner.directImpulse(dx:length,dy:0,maximumSpeed:10)
            XCTAssertGreaterThanOrEqual(v.x,previous);previous=v.x
        }
        XCTAssertEqual(previous,10)
    }
    func testMapTargetSurvivesReleaseAndCanReverseWithoutJumping() {
        var input=DirectControl()
        input.begin(screen:Vec(50,20),worldX:8,onCube:false,canJump:true)
        XCTAssertEqual(input.gesture,.move);XCTAssertEqual(input.end(),.none)
        XCTAssertEqual(input.movement(position:2,velocity:0),1)
        input.begin(screen:Vec(10,20),worldX:0,onCube:false,canJump:false)
        input.update(screen:Vec(0,20),worldX:-2);XCTAssertEqual(input.end(),.none)
        XCTAssertEqual(input.movement(position:2,velocity:0),-1)
        XCTAssertEqual(input.movement(position:-2,velocity:0),0);XCTAssertNil(input.destination)
    }
    func testAimOwnsGestureDoesNotFallThroughAndCancelClearsMotion() {
        var input=DirectControl()
        input.begin(screen:Vec(50,50),worldX:2,onCube:true,canJump:true,canAim:true,time:1)
        input.begin(screen:Vec(90,90),worldX:10,onCube:false,canJump:true,time:1.1)
        input.update(screen:Vec(100,0),worldX:9,time:1.4)
        XCTAssertEqual(input.drag,Vec(50,-50));XCTAssertEqual(input.movement(position:2,velocity:0),0)
        XCTAssertEqual(input.end(time:1.5),.aim(Vec(50,-50)));XCTAssertNil(input.destination)
        input.begin(screen:Vec(20,20),worldX:6,onCube:true,canJump:false,time:2)
        XCTAssertEqual(input.end(time:2.1),.pet);XCTAssertNil(input.destination)
        input.begin(screen:Vec(0,0),worldX:6,onCube:false,canJump:true);input.cancel()
        XCTAssertNil(input.destination);XCTAssertNil(input.gesture)
    }
    func testCubeTapsAndHoldsPetWhileCancelledAimsNeverJump() {
        var input=DirectControl()
        func begin() { input.begin(screen:Vec(50,50),worldX:2,onCube:true,canJump:true,canAim:true,time:10) }
        begin();input.update(screen:Vec(52,48),worldX:2,time:10.1)
        XCTAssertEqual(input.end(time:10.12),.pet);XCTAssertEqual(input.end(time:10.13),.none)
        begin();XCTAssertEqual(input.end(time:10.8),.pet)
        begin();input.update(screen:Vec(100,50),worldX:4,time:10.4);input.update(screen:Vec(50,50),worldX:2,time:10.5)
        XCTAssertEqual(input.end(time:10.6),.none,"Retracting an aim cancels it")
        begin();input.cancel();XCTAssertEqual(input.end(time:10.1),.none)
        input.begin(screen:Vec(50,50),worldX:6,onCube:false,canJump:true,time:10)
        XCTAssertEqual(input.end(time:10.1),.none);XCTAssertEqual(input.destination,6)
    }
    func testProjectionAndHitTestingAcrossRetinaIndependentOrientations() {
        for screen in [Vec(402,874),Vec(874,402),Vec(1032,1376),Vec(1280,800)] {
            let viewport=WorldViewport(center:Vec(-12,9),size:Vec(12,12*screen.y/screen.x),screen:screen)
            let body=Vec(-12,9),point=viewport.project(body,depth:1.1),roundTrip=viewport.unproject(point,depth:1.1)
            XCTAssertEqual(roundTrip.x,body.x,accuracy:0.0001);XCTAssertEqual(roundTrip.y,body.y,accuracy:0.0001)
            XCTAssertTrue(viewport.hitsCube(point,center:body,angle:0.7))
            XCTAssertFalse(viewport.hitsCube(Vec(point.x+screen.x/2,point.y),center:body,angle:0.7))
        }
    }
    func testWorldIsFourTimesInBothAxesAndHasRealSupportedRoutes() {
        XCTAssertEqual(WorldLayout.bounds.width,WorldLayout.originalBounds.width*4)
        XCTAssertEqual(WorldLayout.bounds.height,WorldLayout.originalBounds.height*4)
        XCTAssertGreaterThan(WorldLayout.shards.count,3)
        XCTAssertEqual(WorldLayout.platforms.filter(\.boundary).count,2)
        XCTAssertTrue(WorldLayout.terrain.contains { abs($0.y+$0.height/2-WorldLayout.summit.y)<0.01 && abs($0.x-WorldLayout.summit.x)<$0.width/2 })
        XCTAssertTrue(WorldLayout.terrain.contains { abs($0.y+$0.height/2-WorldLayout.goal.y)<0.01 && abs($0.x-WorldLayout.goal.x)<$0.width/2 })
        XCTAssertLessThan(CameraFraming.verticalTarget(cubeY:-20,velocityY:0,aimVelocityY:nil,worldHeight:12),-15)
        XCTAssertGreaterThan(CameraFraming.verticalTarget(cubeY:22,velocityY:0,aimVelocityY:nil,worldHeight:12),18)
    }
    func testTreePurchasesAffectOnlyOwnerAndRequireParentAndPoints() {
        var bag=MonsterInventory();let first=bag.selected,other=bag.monsters[1]
        XCTAssertNotEqual(first.treeIdentity,other.treeIdentity)
        let advanced=first.tree.first { $0.kind == .control }!
        XCTAssertFalse(bag.learn(advanced,monsterID:first.id))
        let node=first.tree.first { $0.kind == .mastery }!
        XCTAssertTrue(bag.learn(node,monsterID:first.id));XCTAssertFalse(bag.learn(node,monsterID:first.id))
        XCTAssertEqual(bag.selected.conductivity,1.25);XCTAssertEqual(bag.selected.skillPoints,0)
        XCTAssertEqual(bag.monsters[1],other)
        XCTAssertFalse(bag.learn(node,monsterID:other.id))
        bag.recordFinds(crystals:[0,1],relic:false);bag.recordFinds(crystals:[0,1],relic:false)
        XCTAssertEqual(bag.selected.skillPoints,2);XCTAssertEqual(bag.selected.quantity(of:.aetherShard),2)
    }
    func testHybridTreeHasItsOwnIdentityParentsAndIndependentProgress() {
        let ice=MonsterRecord(form:.ice),fire=MonsterRecord(form:.fire)
        var a=MonsterRecord.legacyOffspring(ice,fire,body:.water)
        let b=MonsterRecord.legacyOffspring(ice,fire,body:.water)
        XCTAssertEqual(a.parents.map(\.id),[ice.id,fire.id]);XCTAssertTrue(a.isHybrid)
        XCTAssertNotEqual(a.treeIdentity,b.treeIdentity)
        XCTAssertTrue(Set(a.tree.map(\.id)).isDisjoint(with:Set(ice.tree.map(\.id))))
        XCTAssertTrue(a.learn(a.tree.first { $0.kind == .jump }!))
        a.recordFinds(crystals:[0],relic:false)
        XCTAssertTrue(a.learn(a.tree.first { $0.kind == .momentum }!))
        XCTAssertFalse(b.learned.contains(.momentum));XCTAssertFalse(ice.learned.contains(.momentum))
    }
    func testPersonalEquipmentHasRealEffectsAndCannotEquipMissingItems() {
        var monster=MonsterRecord(form:.stone)
        XCTAssertFalse(monster.equip(.deepRelic));XCTAssertFalse(monster.equip(.aetherShard))
        XCTAssertTrue(monster.equip(.travelerCharm));XCTAssertEqual(monster.landingDamageMultiplier,0.9,accuracy:0.001)
        monster.recordFinds(crystals:[1],relic:true)
        XCTAssertTrue(monster.equip(.deepRelic));XCTAssertEqual(monster.landingDamageMultiplier,0.8,accuracy:0.001)
        XCTAssertEqual(monster.manaMultiplier,0.9,accuracy:0.001)
        let simulation=Simulation(form:.stone);simulation.applySkills(of:monster)
        XCTAssertEqual(simulation.landingDamageMultiplier,0.8,accuracy:0.001)
        XCTAssertTrue(monster.equip(nil));XCTAssertEqual(monster.landingDamageMultiplier,1)
    }
    func testInventoryPersistsSelectionFindsSkillsAndEquipment() {
        let suite="ElementalCube.InventoryTests."+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let store=MonsterInventoryStore(defaults:defaults);var bag=store.load()
        _=bag.select(bag.monsters[2].id);bag.recordFinds(crystals:[3,4],relic:false)
        _=bag.learn(bag.selected.tree.first { $0.kind == .momentum }!,monsterID:bag.selectedID)
        _=bag.equip(.travelerCharm);store.save(bag)
        XCTAssertEqual(store.load(),bag)
        defaults.set(Data("invalid".utf8),forKey:"elementalcube.monsters.v1")
        XCTAssertTrue(store.load().isValid)
    }
}
