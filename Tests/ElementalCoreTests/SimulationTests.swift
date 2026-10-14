import XCTest
@testable import ElementalCore

final class SimulationTests:XCTestCase {
    func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testGroundStopsGravityAndAllowsJump() {
        let s=Simulation();advance(s,1)
        XCTAssertTrue(s.cube.grounded);XCTAssertEqual(s.cube.position.y,0.56,accuracy:0.06)
        XCTAssertTrue(s.jump(Vec(5,8),buffered:false));advance(s,0.1)
        XCTAssertGreaterThan(s.cube.position.y,1);XCTAssertGreaterThan(s.cube.velocity.x,4)
        XCTAssertFalse(s.jump(Vec(5,8),buffered:false));XCTAssertEqual(s.jumps,1)
    }
    func testBuoyancyAndWetness() {
        let s=Simulation();s.placeCube(Vec(9,-1.8));advance(s,3)
        XCTAssertGreaterThan(s.wetness,0.9);XCTAssertGreaterThan(s.cube.position.y,-1.6);XCTAssertLessThan(s.cube.position.y,0)
        s.placeCube(Vec(2,1));advance(s,8);XCTAssertLessThan(s.wetness,0.65)
    }
    func testFreezeCreatesSupportAndExpires() {
        let s=Simulation();s.placeCube(Vec(6,0.6));advance(s,0.5)
        XCTAssertTrue(s.frost());XCTAssertLessThan(s.energy,72);XCTAssertFalse(s.frost())
        s.placeCube(Vec(13.5,0.4));advance(s,1)
        XCTAssertTrue(s.cube.grounded);XCTAssertGreaterThan(s.cube.position.y,-0.1)
        advance(s,Simulation.iceDuration+1);XCTAssertEqual(s.iceTime,0);XCTAssertFalse(s.cube.grounded);XCTAssertGreaterThan(s.wetness,0.2)
    }
    func testNoRemoteFreezeAndGoal() {
        let s=Simulation();advance(s,1);XCTAssertFalse(s.frost());XCTAssertEqual(s.energy,100)
        s.placeCube(Vec(23,0.7));advance(s,1);XCTAssertTrue(s.won)
    }
    func testCollectibleAndWall() {
        let s=Simulation();s.placeCube(s.shards[0]);advance(s,0.1);XCTAssertTrue(s.collected.contains(0))
        s.placeCube(Vec(24.4,1));advance(s,0.5);_ = s.jump(Vec(8,4),buffered:false);advance(s,1)
        XCTAssertLessThan(s.cube.position.x,25);XCTAssertTrue(s.cube.position.x.isFinite)
    }
    func testLargeImpulseIsClampedAndSimulationRepeatable() {
        let a=Simulation(),b=Simulation();advance(a,1);advance(b,1)
        _=a.jump(Vec(100,100),buffered:false);_=b.jump(Vec(100,100),buffered:false)
        advance(a,0.25);advance(b,0.25)
        XCTAssertLessThan(hypot(a.cube.velocity.x,a.cube.velocity.y),13)
        XCTAssertEqual(a.cube.position.x,b.cube.position.x,accuracy:0.00001)
        XCTAssertEqual(a.cube.position.y,b.cube.position.y,accuracy:0.00001)
    }
    func testWaterStrokeCanReachShoreWithoutIce() {
        let s=Simulation();s.placeCube(Vec(10,-1));advance(s,1)
        XCTAssertTrue(s.inWater);XCTAssertFalse(s.cube.grounded);XCTAssertTrue(s.jump(Vec(-6,9.5),buffered:false))
        advance(s,0.25);XCTAssertFalse(s.jump(Vec(-5.5,9),buffered:false))
        advance(s,2);XCTAssertLessThan(s.cube.position.x,7);XCTAssertTrue(s.cube.grounded)
    }
    func testFreezeWhileImmersedLeavesAnExit() {
        for x:Float in [9,10.4] {
            let s=Simulation();s.placeCube(Vec(x,-1));advance(s,1)
            XCTAssertTrue(s.frost());XCTAssertEqual(s.iceSegments.count,2)
            XCTAssertGreaterThan(s.iceSegments[1].x-s.iceSegments[0].y,3.5)
            XCTAssertTrue(s.jump(Vec(-6,9.5),buffered:false));advance(s,2)
            XCTAssertTrue(s.cube.grounded,"frozen exit from \(x): \(s.cube.position)")
            XCTAssertGreaterThan(s.cube.position.y,0,"frozen exit from \(x): \(s.cube.position)")
        }
    }
    func testRollingMovesAndRotatesTheRigidBody() {
        let s=Simulation();advance(s,1);s.movement = -1;advance(s,1)
        XCTAssertLessThan(s.cube.position.x,1);XCTAssertGreaterThan(abs(s.cube.angle),1)
        s.movement=0;advance(s,2);XCTAssertLessThan(abs(s.cube.velocity.x),0.2)
    }
    func testSwimmingCanExitAlongTheShallowBank() {
        let s=Simulation();s.placeCube(Vec(9.8,-1));advance(s,1)
        s.movement = -1;advance(s,6)
        XCTAssertLessThan(s.cube.position.x,7);XCTAssertTrue(s.cube.grounded)
    }
    func testIcePreservesMoreMomentumThanGrass() {
        let grass=Simulation(),ice=Simulation();advance(grass,1)
        ice.placeCube(Vec(6,0.7));advance(ice,0.5);XCTAssertTrue(ice.frost())
        ice.placeCube(Vec(13.5,0.8));advance(ice,0.7)
        _=grass.jump(Vec(3,4),buffered:false);_=ice.jump(Vec(3,4),buffered:false)
        advance(grass,1);advance(ice,1)
        XCTAssertGreaterThan(abs(ice.cube.velocity.x),abs(grass.cube.velocity.x)+0.5)
    }
    func testLandingHardnessDependsOnSurface() {
        func impactAt(_ x:Float)->Float {
            let s=Simulation();s.placeCube(Vec(x,5))
            for _ in 0..<300 { s.step();if s.landingAge<0.02 { return s.impact } }
            return -1
        }
        let soft=impactAt(2),hard=impactAt(12)
        XCTAssertGreaterThan(soft,0);XCTAssertGreaterThan(hard,soft+0.2)
    }
    func testAimDirectionsAndRadialPowerAreStable() {
        let tap=AimPlanner.impulse(dx:0,dy:0);XCTAssertEqual(tap.x,0)
        let edge=AimPlanner.impulse(dx:-8.1,dy:0)
        XCTAssertLessThan(hypot(edge.x-tap.x,edge.y-tap.y),0.1)
        let right=AimPlanner.impulse(dx:-80,dy:80),left=AimPlanner.impulse(dx:80,dy:80)
        XCTAssertGreaterThan(right.x,0);XCTAssertLessThan(left.x,0)
        XCTAssertEqual(right.x,-left.x,accuracy:0.001);XCTAssertEqual(right.y,left.y,accuracy:0.001)
        let vertical=AimPlanner.impulse(dx:0,dy:100)
        XCTAssertEqual(vertical.x,0,accuracy:0.001);XCTAssertGreaterThan(vertical.y,10)
        let direct=AimPlanner.impulse(dx:80,dy:-80,inverted:false)
        XCTAssertEqual(direct.x,right.x,accuracy:0.001);XCTAssertEqual(direct.y,right.y,accuracy:0.001)
    }
    func testPreviewAndExecutedVelocityMatchIncludingInertia() {
        let s=Simulation();advance(s,1);s.movement = -1;advance(s,0.6)
        let input=Vec(3,7.5),prediction=s.launchVelocity(for:input)
        XCTAssertTrue(s.jump(input,buffered:false))
        XCTAssertEqual(s.cube.velocity.x,prediction.x,accuracy:0.0001)
        XCTAssertEqual(s.cube.velocity.y,prediction.y,accuracy:0.0001)
    }
    func testTrajectoryQueriesUseTheActualSolidsAndIgnoreThePlayer() {
        let s=Simulation()
        XCTAssertFalse(s.intersectsSolid(at:s.cube.position))
        XCTAssertTrue(s.intersectsSolid(at:s.crate.position))
        XCTAssertTrue(s.intersectsSolid(at:Vec(12,-0.7)))
        XCTAssertFalse(s.intersectsSolid(at:Vec(12,4)))
    }
    func testMapCanBeCrossedWithPhysicalJumps() {
        let s=Simulation();advance(s,1)
        func landAt(_ target:Vec) {
            let vertical:Float=8.5
            let flight=(vertical+sqrt(vertical*vertical-2*s.gravity*(target.y-s.cube.position.y)))/s.gravity
            let impulse=Vec((target.x-s.cube.position.x)/flight-s.cube.velocity.x,vertical-s.cube.velocity.y)
            XCTAssertTrue(s.jump(impulse,buffered:false));advance(s,0.2)
            for _ in 0..<300 { s.step();if s.cube.grounded { return } }
            XCTFail("Did not land at x=\(s.cube.position.x), y=\(s.cube.position.y)")
        }
        landAt(Vec(5.1,1.81));XCTAssertGreaterThan(s.cube.position.y,1.4)
        advance(s,0.2);landAt(Vec(12,0.46));XCTAssertGreaterThan(s.cube.position.x,10.5)
        advance(s,0.2);landAt(Vec(19.5,0.56));XCTAssertGreaterThan(s.cube.position.x,17)
        advance(s,0.2);landAt(Vec(23,0.56));advance(s,0.3)
        XCTAssertTrue(s.won)
    }
}
