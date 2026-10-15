import XCTest
@testable import ElementalCore

final class AlphaTenTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testSwipeUpAnywhereIsBasicWhileCubeTapAndStrokesAreAffection() {
        for cube in [false,true] {
            var input=DirectControl()
            input.begin(screen:Vec(100,400),worldX:8,onCube:cube,canJump:true,canAim:true,time:1)
            input.update(screen:Vec(130,320),worldX:9,time:1.12)
            XCTAssertEqual(input.end(time:1.2),.swipeJump(Vec(1.65,7.2)))
            XCTAssertNil(input.destination);XCTAssertEqual(input.end(),.none)
        }
        var input=DirectControl()
        input.begin(screen:Vec(0,0),worldX:2,onCube:true,canJump:true,canAim:true,time:1)
        XCTAssertEqual(input.end(time:1.1),.pet)
        input.begin(screen:Vec(0,0),worldX:2,onCube:true,canJump:true,time:2)
        input.update(screen:Vec(40,3),worldX:3,time:2.2);input.update(screen:Vec(-30,3),worldX:1,time:2.4)
        XCTAssertEqual(input.end(time:2.6),.pet)
    }
    func testPreciseAimRequiresAnUnlockedSkillAndAStationaryHold() {
        for learned in [false,true] {
            var input=DirectControl()
            input.begin(screen:Vec(0,0),worldX:2,onCube:true,canJump:true,canAim:learned,time:1)
            input.update(screen:Vec(-70,-90),worldX:1,time:1.4)
            XCTAssertEqual(input.end(time:1.5),learned ? .aim(Vec(-70,-90)) : .pet)
        }
        var input=DirectControl()
        input.begin(screen:Vec(0,0),worldX:2,onCube:true,canJump:true,canAim:true,time:1)
        input.update(screen:Vec(35,-60),worldX:3,time:1.1)
        input.update(screen:Vec(35,-70),worldX:3,time:1.4)
        XCTAssertEqual(input.end(time:1.45),.swipeJump(Vec(1.925,7.2)),"A swipe cannot turn into aim halfway through")
    }
    func testBaseSwipeHasLimitedSteeringAndNewAimStartsWeakThenGrows() {
        var monster=MonsterRecord(form:.ice)
        let s=Simulation();s.wind=0;s.waterEnabled=false;s.applySkills(of:monster);advance(s,0.5)
        XCTAssertTrue(s.performJump(Vec(100,7.2)));XCTAssertEqual(s.cube.velocity.x,3.2,accuracy:0.001);XCTAssertEqual(s.mana,100)
        XCTAssertFalse(s.directionalJumpUnlocked)
        XCTAssertTrue(monster.learn(monster.tree.first { $0.kind == .jump }!))
        XCTAssertEqual(monster.jumpSkill.maximumSpeed,8,accuracy:0.001)
        monster.recordFinds(crystals:[0],relic:false)
        XCTAssertTrue(monster.learn(monster.tree.first { $0.kind == .momentum }!))
        XCTAssertGreaterThan(monster.jumpSkill.maximumSpeed,9)
    }
    func testWaterPhysicallyFitsHalfHeightPassageConservesMassAndExpandsOutside() {
        let s=Simulation(form:.water);s.wind=0;s.waterEnabled=false;s.placeCube(Vec(17.6,0.57));s.movement=1
        let mass=s.cube.mass
        var compressed=false,crossed=false
        for _ in 0..<600 {
            s.step()
            if s.compressed {
                compressed=true;XCTAssertEqual(s.cubeWidth*s.cubeHeight,1.12*1.12,accuracy:0.001)
                XCTAssertEqual(s.cubeHeight,0.56,accuracy:0.001);XCTAssertEqual(s.cube.mass,mass,accuracy:0.001)
            }
            if s.cube.position.x>24.5 { crossed=true;break }
        }
        XCTAssertTrue(compressed);XCTAssertTrue(crossed,"\(s.cube.position)")
        s.placeCube(Vec(3,0.57));s.movement=0;advance(s,0.2)
        XCTAssertFalse(s.compressed);XCTAssertEqual(s.cubeHeight,1.12,accuracy:0.001)
        XCTAssertEqual(s.cube.mass,mass,accuracy:0.001)
    }
    func testElementsUseDistinctRealMotionAndPetDoesNotJump() {
        let ice=Simulation(),stone=Simulation(form:.stone),water=Simulation(form:.water)
        for s in [ice,stone,water] { s.wind=0;s.waterEnabled=false;s.placeCube(Vec(2,0.57));s.movement = -1 }
        var low:Float=10,high:Float = -10,maxStoneAngle:Float=0
        for _ in 0..<180 {
            ice.step();stone.step();water.step()
            low=min(low,water.cube.position.y);high=max(high,water.cube.position.y);maxStoneAngle=max(maxStoneAngle,abs(stone.cube.angle))
        }
        XCTAssertEqual(ice.cube.angle,0,accuracy:0.001)
        XCTAssertGreaterThan(maxStoneAngle,1)
        XCTAssertGreaterThan(high-low,0.035)
        XCTAssertTrue(ice.trails.contains { $0.form == .ice })
        let jumps=ice.jumps;ice.pet();XCTAssertEqual(ice.jumps,jumps);XCTAssertEqual(ice.mood,.delighted)
        XCTAssertTrue(ice.particles.contains { $0.kind==6 })
    }
    func testMapsHaveDistinctRoutesAndReachableSupportedFinishes() {
        XCTAssertEqual(Set(WorldMap.allCases.map { $0.definition.goal.x.description+","+$0.definition.goal.y.description }).count,3)
        for map in WorldMap.allCases {
            let s=Simulation(map:map);s.wind=0
            XCTAssertEqual(s.definition.map,map);XCTAssertEqual(s.shards.count,12)
            XCTAssertTrue(s.platforms.contains { !$0.boundary && abs($0.x-s.definition.goal.x)<$0.width/2 && abs($0.y+$0.height/2-s.definition.goal.y)<0.01 })
            s.placeCube(Vec(s.definition.goal.x,s.definition.goal.y+0.75));advance(s,0.75)
            XCTAssertTrue(s.won,"\(map)")
        }
    }
    func testStarterIsFreeSwitchingCostsCurrencyAndWorldRewardsCannotBeFarmed() {
        var save=AdventureState();let first=save.inventory.selected,second=save.inventory.monsters[1]
        XCTAssertTrue(save.begin(with:first));XCTAssertFalse(save.begin(with:second));XCTAssertEqual(save.collection.count,1)
        XCTAssertFalse(save.select(second.id));XCTAssertEqual(save.inventory.selectedID,first.id)
        save.recordFinds([0,1,2,3],relic:false);XCTAssertEqual(save.coins,4)
        save.recordFinds([0,1,2,3],relic:false);XCTAssertEqual(save.coins,4)
        XCTAssertTrue(save.select(second.id));XCTAssertEqual(save.coins,0);XCTAssertEqual(save.collection.count,2)
        save.recordFinds([0,1,2,3],relic:false);XCTAssertEqual(save.coins,0)
        save.recordFinds([4,5],relic:false);XCTAssertTrue(save.select(first.id));XCTAssertEqual(save.coins,0)
        save.finishMap();save.finishMap();XCTAssertEqual(save.coins,6)
        save.map = .glacier;save.recordFinds([0,1],relic:false);XCTAssertEqual(save.coins,8)
        XCTAssertTrue(save.isValid)
    }
    func testMergeKeepsAllMaterialCopiesWhileDeduplicatingWorldFinds() {
        var a=MonsterRecord(form:.ice),b=MonsterRecord(form:.fire)
        a.recordFinds(crystals:[0,1],relic:true);b.recordFinds(crystals:[0,1],relic:true)
        let child=MonsterRecord.offspring(a,b,body:.water,seed:22)
        XCTAssertEqual(child.crystals,[0,1]);XCTAssertEqual(child.quantity(of:.aetherShard),4)
        XCTAssertEqual(child.quantity(of:.deepRelic),2);XCTAssertEqual(child.quantity(of:.travelerCharm),2)
        var updated=child;updated.recordFinds(crystals:[0,1],relic:true)
        XCTAssertEqual(updated.quantity(of:.aetherShard),4)
    }
    func testEvolutionPreservesIdentityAndMergeIsAChargedAtomicBirth() throws {
        var save=AdventureState();let first=save.inventory.selected
        XCTAssertTrue(save.begin(with:first));save.recordFinds(Set(0..<12),relic:true)
        XCTAssertTrue(save.evolve());XCTAssertEqual(save.inventory.selectedID,first.id);XCTAssertEqual(save.inventory.selected.evolutionStage,1)
        let other=save.inventory.monsters[1]
        XCTAssertTrue(save.select(other.id));XCTAssertEqual(save.coins,4)
        let child=try XCTUnwrap(save.merge(first.id,other.id,seed:123))
        XCTAssertEqual(save.coins,0);XCTAssertEqual(save.collection.map(\.id),[child.id])
        XCTAssertFalse(save.inventory.monsters.contains { $0.id==first.id || $0.id==other.id })
        XCTAssertEqual(Set(child.parents.map(\.id)),[first.id,other.id]);XCTAssertTrue(child.isHybrid)
        XCTAssertEqual(child.crystals,Set(0..<12));XCTAssertTrue(child.deepRelic)
        XCTAssertNil(save.merge(child.id,child.id));XCTAssertTrue(save.isValid)
        let data=try JSONEncoder().encode(save)
        XCTAssertEqual(try JSONDecoder().decode(AdventureState.self,from:data),save)
    }
    func testHybridTreesAndTraitsBelongToTheirParentsAndSaveAtomically() throws {
        let suite="ElementalCube.alpha10."+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        var ice=MonsterRecord(form:.ice),stone=MonsterRecord(form:.stone)
        ice.recordFinds(crystals:[0,1,2],relic:false);stone.recordFinds(crystals:[0,1,2],relic:false)
        var crystal=MonsterRecord.offspring(ice,stone,body:.stone,seed:22)
        XCTAssertEqual(crystal.hybridStyle,.crystal);XCTAssertEqual(crystal.passiveName,"Холодный кристалл")
        XCTAssertNotEqual(crystal.tree.first?.id,stone.tree.first?.id)
        let initial=crystal.conductivity
        XCTAssertTrue(crystal.learn(crystal.tree.first { $0.kind == .mastery }!));XCTAssertGreaterThan(crystal.conductivity,initial)
        var save=AdventureState();XCTAssertTrue(save.begin(with:crystal));save.recordFinds([3,4],relic:false)
        let store=AdventureStore(defaults:defaults);store.save(save)
        XCTAssertEqual(store.load(fallback:MonsterInventory()),save)
        let legacyData=try JSONEncoder().encode(ice)
        var legacy=try XCTUnwrap(JSONSerialization.jsonObject(with:legacyData) as? [String:Any])
        for key in ["evolutionStage","aetherAmount","relicAmount","travelerAmount"] { legacy.removeValue(forKey:key) }
        let restored=try JSONDecoder().decode(MonsterRecord.self,from:JSONSerialization.data(withJSONObject:legacy))
        XCTAssertEqual(restored.evolutionStage,0);XCTAssertEqual(restored.quantity(of:.aetherShard),3)
    }

}
