import XCTest
@testable import ElementalCore

final class JourneyAndMotionTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    private func fresh(_ form:ElementForm = .ice)->AdventureState { var a=AdventureState(inventory:MonsterInventory(selectedForm:form));XCTAssertTrue(a.begin(with:a.inventory.selected));return a }
    private func finish(_ a:inout AdventureState,_ seconds:Double?,standard:Bool=true,id:UUID=UUID())->FinishReceipt? {
        a.finishRun(RunOutcome(attemptID:id,map:a.map,seconds:seconds,standardPhysics:standard,crystals:0,coins:0))
    }
    func testCampaignBranchesAndRejoinsWithoutUnlockingEverything() {
        var a=fresh();XCTAssertTrue(a.canVisit(.shore))
        for map in WorldMap.allCases.dropFirst() { XCTAssertFalse(a.canVisit(map),map.rawValue) }
        _=finish(&a,100);XCTAssertTrue(a.canVisit(.glacier));XCTAssertTrue(a.canVisit(.forge));XCTAssertFalse(a.canVisit(.windridge))
        a.map = .glacier;_=finish(&a,100);XCTAssertTrue(a.canVisit(.meadow));XCTAssertFalse(a.canVisit(.grotto))
        a.map = .meadow;_=finish(&a,100);XCTAssertTrue(a.canVisit(.windridge));XCTAssertFalse(a.canVisit(.sanctuary))
        a.map = .windridge;_=finish(&a,100);XCTAssertTrue(a.canVisit(.sanctuary))
        XCTAssertEqual(CampaignRoute.previous(.windridge),[.meadow,.grotto]);XCTAssertEqual(CampaignRoute.next(.sanctuary),[])
    }
    func testNewMapSpawnsAreDistinctAndCollectiblesAreNotInsideTerrain() {
        XCTAssertGreaterThan(Set(WorldMap.allCases.map { $0.definition.spawn.x }).count,3)
        for map in WorldMap.allCases {
            let d=map.definition
            for point in d.shards+d.coins {
                XCTAssertTrue(point.x>d.bounds.minX && point.x<d.bounds.maxX && point.y>d.bounds.minY && point.y<d.bounds.maxY)
                for p in d.platforms where !p.boundary {
                    XCTAssertFalse(abs(point.x-p.x)<p.width/2-0.08 && abs(point.y-p.y)<p.height/2-0.08,"\(map) collectible \(point) inside \(p)")
                }
            }
            let s=Simulation(map:map);s.waterEnabled=false;s.wind=0
            advance(s,0.5);XCTAssertGreaterThan(s.health,99);XCTAssertEqual(s.respawns,0)
            XCTAssertGreaterThan(s.cube.position.y,d.spawn.y-1.5,map.rawValue)
        }
    }
    func testMedalsAreInclusiveAndPayOnlyImprovementWithIdempotentFinish() throws {
        var a=fresh();let id=UUID()
        let bronze=try XCTUnwrap(finish(&a,240,id:id));XCTAssertEqual(bronze.medal,.bronze);XCTAssertEqual(bronze.goldAward,15);XCTAssertEqual(a.coins,6)
        XCTAssertEqual(finish(&a,40,id:id),bronze);XCTAssertEqual(a.gold,15)
        XCTAssertEqual(finish(&a,240)?.goldAward,0)
        XCTAssertEqual(finish(&a,150)?.speedGold,7);XCTAssertEqual(finish(&a,90)?.speedGold,8)
        XCTAssertEqual(a.gold,30);XCTAssertEqual(a.record(for:.shore)?.medal,.gold);XCTAssertEqual(a.record(for:.shore)?.bestTime,90)
        XCTAssertEqual(finish(&a,91)?.goldAward,0);XCTAssertEqual(a.coins,6)
        XCTAssertEqual(finish(&a,89)?.newBest,true);XCTAssertEqual(a.gold,30)
    }
    func testCustomPhysicsAndInvalidOutcomesCannotEarnSpeedMedals() {
        var a=fresh()
        for invalid in [Double.nan,Double.infinity,-1,604800] { XCTAssertNil(finish(&a,invalid));XCTAssertEqual(a.gold,0) }
        let custom=finish(&a,20,standard:false);XCTAssertEqual(custom?.goldAward,10);XCTAssertEqual(custom?.medal,SpeedMedal.none);XCTAssertNil(a.record(for:.shore)?.bestTime)
        XCTAssertEqual(finish(&a,0.3)?.medal,SpeedMedal.none);XCTAssertNil(a.record(for:.shore)?.bestTime)
        XCTAssertEqual(finish(&a,80)?.goldAward,20)
        XCTAssertNil(a.finishRun(RunOutcome(attemptID:UUID(),map:.glacier,seconds:30,standardPhysics:true,crystals:0,coins:0)))
    }
    func testActualFindCountsFilterInvalidIndicesAndRestoreWithoutFeedback() {
        var a=fresh();let shardCount=a.map.definition.shards.count,coinCount=a.map.definition.coins.count
        a.recordFinds(Set(-1...99),relic:false);a.recordCoins(Set(-1...99))
        XCTAssertEqual(a.foundCrystals(on:.shore).count,shardCount);XCTAssertEqual(a.coins,shardCount)
        XCTAssertEqual(a.gold,coinCount);a.recordCoins(Set(0..<coinCount));XCTAssertEqual(a.gold,coinCount)
        let s=Simulation();s.restoreFinds(crystals:a.foundCrystals(on:.shore),coins:a.foundCoins(on:.shore),relic:false)
        XCTAssertEqual(s.collected.count,shardCount);XCTAssertEqual(s.collectedCoins.count,coinCount);XCTAssertTrue(s.takeFeedback().isEmpty)
        s.placeCube(s.shards[0]);s.step();XCTAssertFalse(s.takeFeedback().contains(.collectedCrystal))
        a.map = .meadow;a.recordFinds(Set(0..<99),relic:true)
        XCTAssertEqual(a.foundCrystals(on:.meadow).count,10);XCTAssertFalse(a.inventory.selected.deepRelic)
        XCTAssertEqual(a.inventory.selected.crystals.count,shardCount+10)
        XCTAssertEqual(WorldMap.glacier.crystalOffset,100);XCTAssertEqual(WorldMap.forge.crystalOffset,200)
    }
    func testGoldBuysOnlyOnePointForTheSelectedMonsterAndSurvivesOldSaveMigration() throws {
        var a=fresh();let owner=a.inventory.selectedID,other=a.inventory.monsters.first { $0.id != owner }!.id
        XCTAssertFalse(a.buyStudyPoint(for:owner));_=finish(&a,60);XCTAssertEqual(a.gold,30)
        let points=a.inventory.selected.skillPoints;XCTAssertFalse(a.buyStudyPoint(for:other))
        XCTAssertTrue(a.buyStudyPoint(for:owner));XCTAssertEqual(a.gold,0);XCTAssertEqual(a.inventory.selected.skillPoints,points+1)
        let data=try JSONEncoder().encode(a);XCTAssertEqual(try JSONDecoder().decode(AdventureState.self,from:data),a)
        var old=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]);old.removeValue(forKey:"journey")
        let migrated=try JSONDecoder().decode(AdventureState.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertTrue(migrated.isValid);XCTAssertEqual(migrated.gold,0);XCTAssertEqual(migrated.inventory,a.inventory);XCTAssertEqual(migrated.completedMaps,a.completedMaps)
    }
    func testRelicUsesPhysicalReachabilityForEveryBodyIncludingFireAfterDraining() {
        for form in ElementForm.allCases {
            let s=Simulation(form:form);s.waterEnabled=false;s.wind=0
            s.placeCube(s.definition.relicPosition!);s.step()
            XCTAssertTrue(s.deepRelic,form.rawValue);XCTAssertTrue(s.takeFeedback().contains(.collectedRelic))
        }
    }
    func testIceSlidesFasterThanFireAndAirReallyFliesAboveTheFloor() {
        let ice=Simulation(),fire=Simulation(form:.fire),air=Simulation(form:.air)
        for s in [ice,fire,air] { s.waterEnabled=false;s.wind=0;s.placeCube(Vec(1,0.65));advance(s,0.6);s.movement = -1;advance(s,0.6) }
        XCTAssertGreaterThan(abs(ice.cube.velocity.x),abs(fire.cube.velocity.x)+0.8)
        XCTAssertGreaterThan(air.cube.position.y,1.15);XCTAssertFalse(air.cube.grounded);XCTAssertEqual(air.cube.angle,0,accuracy:0.001)
        for s in [ice,fire] { s.movement=0;advance(s,0.3) }
        XCTAssertLessThan(abs(fire.cube.velocity.x),abs(ice.cube.velocity.x)*0.8)
    }
    func testWaterWindupAndSlimeHopConserveVisualVolume() {
        let s=Simulation(form:.water);s.waterEnabled=false;s.wind=0;s.placeCube(Vec(1,0.65));advance(s,0.3);s.movement = -1
        var compressed=false,launched=false
        for _ in 0..<120 {
            s.step();let b=s.bodyStretch
            XCTAssertEqual(b.x*b.y*b.z,1,accuracy:0.001)
            if s.cube.grounded && b.y<0.85 { compressed=true }
            if !s.cube.grounded && s.cube.velocity.y>1 { launched=true }
        }
        XCTAssertTrue(compressed);XCTAssertTrue(launched);XCTAssertEqual(s.jumps,0);XCTAssertEqual(s.mana,100)
    }
    func testAirCanFinishWhileFlyingAndBasicJumpHasItsOwnLift() {
        let s=Simulation(form:.air,map:.meadow);s.waterEnabled=false;s.wind=0
        let goal=s.definition.goal;s.placeCube(Vec(goal.x,goal.y+s.hoverHeight));advance(s,0.3)
        XCTAssertTrue(s.won);XCTAssertFalse(s.cube.grounded)
        var impulses:[Float]=[]
        for form in ElementForm.allCases {
            let q=Simulation(form:form);q.waterEnabled=false;q.wind=0;advance(q,0.5)
            XCTAssertTrue(q.performJump(),form.rawValue);impulses.append(q.cube.velocity.y)
        }
        XCTAssertGreaterThan(impulses[2],impulses[0]+0.5)
        XCTAssertGreaterThan(impulses[0],impulses[1]+0.1)
    }
    func testMovementUpgradeChangesDifferentPhysicalTraitsForEveryForm() {
        for form in ElementForm.allCases {
            var m=MonsterRecord(form:form);m.recordFinds(crystals:[0,1],relic:false)
            XCTAssertTrue(m.learn(m.tree.first { $0.kind == .jump }!));let before=m
            XCTAssertTrue(m.learn(m.tree.first { $0.kind == .momentum }!))
            switch form {
            case .ice,.fire:XCTAssertGreaterThan(m.groundSpeed,before.groundSpeed)
            case .water:XCTAssertGreaterThan(m.hopImpulse,before.hopImpulse)
            case .air:XCTAssertGreaterThan(m.hoverHeight,before.hoverHeight)
            case .stone:XCTAssertGreaterThan(m.impactMultiplier,before.impactMultiplier)
            }
            XCTAssertEqual(m.effects(of:.momentum).count,2)
            let s=Simulation(form:form);s.applySkills(of:m);XCTAssertEqual(s.movementSpeed,m.groundSpeed);XCTAssertEqual(s.hoverHeight,m.hoverHeight)
        }
    }
    func testStrongStoneContactBreaksCrateIntoMassConservingPersistentBodies() {
        let s=Simulation(form:.stone);s.waterEnabled=false;s.wind=0;advance(s,0.25)
        let mass=s.crate.mass;s.placeCube(Vec(3.65,0.7),velocity:Vec(7,0));advance(s,0.15)
        XCTAssertFalse(s.crateExists);XCTAssertTrue(s.crateWasShattered);XCTAssertEqual(s.debris.filter { $0.origin=="crate" }.count,6)
        XCTAssertEqual(s.debris.reduce(Float(0)) { $0+$1.state.mass },mass,accuracy:0.001)
        let ids=Set(s.debris.map(\.id));XCTAssertTrue(ids.isSubset(of:Set(s.fluidBodies.map { Int32($0.id) })))
        advance(s,0.7);XCTAssertEqual(Set(s.debris.map(\.id)),ids)
        let xs=s.debris.map { $0.state.position.x }
        XCTAssertGreaterThan(xs.max()!-xs.min()!,1.05,"Fragments must visibly separate, not remain an intact-looking grid")
    }
    func testWeakOrMissingContactDoesNotBreakAnythingButStrongStoneBreaksBrick() {
        let weak=Simulation(form:.stone);weak.waterEnabled=false;weak.wind=0;advance(weak,0.25)
        weak.placeCube(Vec(3.65,0.7),velocity:Vec(2,0));advance(weak,0.15);XCTAssertTrue(weak.crateExists);XCTAssertTrue(weak.debris.isEmpty)
        let miss=Simulation(form:.stone);miss.waterEnabled=false;miss.wind=0
        miss.placeCube(Vec(3.65,4),velocity:Vec(8,0));advance(miss,0.15);XCTAssertTrue(miss.crateExists)
        let hit=Simulation(form:.stone);hit.waterEnabled=false;hit.wind=0
        let count=hit.obstacles.count;hit.placeCube(Vec(22.4,3.85),velocity:Vec(10,0));advance(hit,0.15)
        XCTAssertEqual(hit.obstacles.count,count-1);XCTAssertEqual(hit.debris.filter { $0.material == .brick }.count,6)
    }
}
