import XCTest
@testable import ElementalCore

final class LiquidPhysicsTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testSubmergedPolygonAreaAndOffCenterBuoyancy() {
        var body=FluidBody(id:0,center:Vec(0,0),width:2,height:2)
        let half=body.displaced(below:0)
        XCTAssertEqual(half.area,2,accuracy:0.0001);XCTAssertEqual(half.centroid.y,-0.5,accuracy:0.0001)
        body.angle = .pi/4
        let tilted=body.displaced(below:0)
        XCTAssertEqual(tilted.area,2,accuracy:0.0001);XCTAssertEqual(tilted.centroid.y,-sqrt(2)/3,accuracy:0.0001)
        let asymmetric=body.displaced(below:0.2,slope:0.3)
        XCTAssertGreaterThan(asymmetric.area,2);XCTAssertGreaterThan(abs(asymmetric.centroid.x),0.01)
    }
    func testLiquidConservesMarkersAndDoesNotPenetrateBanks() {
        let f=LiquidSolver(platforms:[]),volume=f.particles.reduce(Float(0)) { $0+$1.volume }
        for _ in 0..<120 { f.advance(dt:1/120,gravity:18,bodies:[],frozen:[]) }
        XCTAssertEqual(f.particles.reduce(Float(0)) { $0+$1.volume },volume,accuracy:0.0001)
        XCTAssertTrue(f.particles.allSatisfy { !f.staticSolid($0.position) && $0.position.x.isFinite && $0.position.y.isFinite })
        XCTAssertLessThan(f.divergenceRMS,2)
        XCTAssertEqual(f.surfaceHeight(at:10),-0.72,accuracy:0.18)
    }
    func testCrateHasGravityRotationBuoyancyAndMakesWaves() {
        let s=Simulation(form:.water);s.wind=0
        s.placeCrate(Vec(9.9,0.8),angle:0.35,velocity:Vec(0.5,-1))
        advance(s,0.25);XCTAssertLessThan(s.crate.position.y,0.5)
        advance(s,2)
        XCTAssertGreaterThan(s.crate.position.y,-1.8);XCTAssertLessThan(s.crate.position.y,0.3)
        XCTAssertGreaterThan(abs(s.crate.angle-0.35),0.02)
        XCTAssertTrue(s.waterField.liquid.particles.contains { hypot($0.velocity.x,$0.velocity.y)>0.2 })
    }
    func testPlayerCanPushCrateOffTheBankIntoWater() {
        let s=Simulation(form:.water);s.wind=0;s.movement=1
        advance(s,5)
        XCTAssertGreaterThan(s.crate.position.x,7.8)
        XCTAssertGreaterThan(abs(s.crate.angle),0.05)
        XCTAssertGreaterThan(s.cube.position.x,6)
    }
    func testFloatingBodiesSettleWithoutSelfExcitation() {
        let s=Simulation(form:.water);s.wind=0;s.placeCrate(Vec(9.5,-0.5),angle:0.2)
        advance(s,8)
        XCTAssertLessThan(hypot(s.crate.velocity.x,s.crate.velocity.y),1.5)
        XCTAssertTrue(s.bridge.allSatisfy { abs($0.state.velocity.y)<2 })
        XCTAssertLessThan(s.bridge.map { $0.state.position.y }.max()!,0.2)
        XCTAssertGreaterThan(s.crate.position.y,-1.5)
    }
    func testBridgeSagsUnderLoadAndStaysAttached() {
        let unloaded=Simulation(form:.stone),loaded=Simulation(form:.stone)
        unloaded.wind=0;loaded.wind=0
        advance(unloaded,1.5);advance(loaded,1.5)
        loaded.placeCube(Vec(12,1.2));advance(loaded,1.5);advance(unloaded,1.5)
        let a=unloaded.bridge[2].state.position.y,b=loaded.bridge[2].state.position.y
        XCTAssertLessThan(b,a-0.025)
        XCTAssertTrue(loaded.bridge.allSatisfy { $0.state.position.y > -2 && $0.state.position.x.isFinite })
        for i in 1..<loaded.bridge.count {
            let a=loaded.bridge[i-1],b=loaded.bridge[i]
            XCTAssertLessThan(hypot(a.state.position.x-b.state.position.x,a.state.position.y-b.state.position.y),0.85)
        }
    }
    func testIceContactCreatesSupportBeforeSinking() {
        for x:Float in [8.5,9.3,9.9,12,14.7,15.5] {
            let s=Simulation();s.wind=0;s.placeCube(Vec(x,0.5))
            let initial=s.waterField.volume
            var deepest:Float=0
            for _ in 0..<120 {
                s.step()
                let foot=s.fluidBodies[0].corners.map(\.y).min()!
                deepest=max(deepest,s.waterField.liquid.surfaceHeight(at:s.cube.position.x)-foot)
            }
            // Surface reconstruction is accurate to roughly one MAC cell.
            XCTAssertLessThan(deepest,0.20,"x=\(x)")
            XCTAssertFalse(s.inWater,"x=\(x)")
            XCTAssertTrue(s.cube.grounded,"x=\(x)")
            XCTAssertLessThan(s.wetness,0.15,"x=\(x)")
            XCTAssertEqual(s.waterField.volume,initial,accuracy:0.0001)
            XCTAssertEqual(s.waterField.representedVolume,initial,accuracy:0.0001)
        }
    }
    func testDragExchangesMomentumWithoutAddingEnergy() {
        let fluid=LiquidSolver(platforms:[]),mass:Float=0.7,dt:Float=1/120
        let body=FluidBody(id:0,center:Vec(10,-1.5),velocity:Vec(3,0),width:1,height:1)
        let load=fluid.dragLoad(on:body,mass:mass,dt:dt,coefficient:14)
        let vx=3+load.force.x*dt/mass,vy=load.force.y*dt/mass,inertia=mass/6,omega=load.torque*dt/inertia
        let fluidMomentum=fluid.particles.reduce(Vec(0,0)) { Vec($0.x+$1.volume*$1.velocity.x,$0.y+$1.volume*$1.velocity.y) }
        let energy=fluid.particles.reduce(Float(0)) { $0+0.5*$1.volume*($1.velocity.x*$1.velocity.x+$1.velocity.y*$1.velocity.y) }+0.5*mass*(vx*vx+vy*vy)+0.5*inertia*omega*omega
        XCTAssertEqual(mass*vx+fluidMomentum.x,3*mass,accuracy:0.0001)
        XCTAssertEqual(mass*vy+fluidMomentum.y,0,accuracy:0.0001)
        XCTAssertLessThan(energy,0.5*mass*9)
    }
    func testStandingBuildsThickerIceDownwardWithoutLiftingTheCube() {
        let s=Simulation();s.wind=0;s.placeCube(Vec(9.3,0.5));advance(s,1)
        let initial=s.iceCells.map(\.height).max()!,top=s.iceCells.map { $0.center.y+$0.height/2 }.max()!,mass=s.waterField.representedVolume
        let resting=s.cube.position.y
        advance(s,6)
        XCTAssertGreaterThan(s.iceCells.map(\.height).max()!,initial+0.2)
        XCTAssertEqual(s.iceCells.map { $0.center.y+$0.height/2 }.max()!,top,accuracy:0.07)
        XCTAssertEqual(s.cube.position.y,resting,accuracy:0.1)
        XCTAssertEqual(s.waterField.representedVolume,mass,accuracy:0.0001)
        XCTAssertFalse(s.inWater)
    }
    func testJumpingOffIceDoesNotRecreateMassOrLaunchWater() {
        let s=Simulation();s.wind=0;s.placeCube(Vec(9.3,0.5));advance(s,3)
        let mass=s.waterField.representedVolume,frozen=s.waterField.frozenVolume
        XCTAssertTrue(s.jump(Vec(-4,9),buffered:false));advance(s,0.4)
        XCTAssertGreaterThan(s.cube.position.y,1)
        XCTAssertEqual(s.waterField.representedVolume,mass,accuracy:0.0001)
        XCTAssertLessThan(s.waterField.frozenVolume,frozen+0.1)
        XCTAssertTrue(s.waterField.liquid.particles.allSatisfy { $0.position.y<0.5 && hypot($0.velocity.x,$0.velocity.y)<6 })
        XCTAssertLessThan(s.waterField.liquid.surfaceHeight(at:9.3),-0.35)
    }

    func testThawReturnsPhaseMassWithoutReplayingCapturedMomentum() {
        let field=WaterField(platforms:[]),initial=field.representedVolume
        field.liquid.addImpulse(at:Vec(9.3,-0.85),impulse:Vec(0.2,0.1),radius:0.7)
        field.freezeContact(at:9.3,bottom:-0.71)
        XCTAssertGreaterThan(field.frozenVolume,0)
        for _ in 0..<310 { field.step(dt:0.1,coldSource:nil,heatSource:nil,occupied:[]) }
        XCTAssertTrue(field.ice.allSatisfy { !$0.solid })
        XCTAssertEqual(field.representedVolume,initial,accuracy:0.0001)
        XCTAssertTrue(field.liquid.particles.filter { abs($0.position.x-9.3)<0.8 && $0.position.y > -0.88 }.allSatisfy { hypot($0.velocity.x,$0.velocity.y)<0.001 })
    }

}
