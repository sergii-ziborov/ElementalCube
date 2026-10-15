import XCTest
import CPhysics
@testable import ElementalCore

final class PhaseAndMasonryTests:XCTestCase {
    private func advance(_ s:Simulation,_ seconds:Float) { for _ in 0..<Int(seconds/Simulation.timestep) { s.step() } }
    func testOrientedOverlapUsesCornersRatherThanCentresOrBoundingCircles() {
        let beam=FluidBody(id:0,center:Vec(0,0),angle:.pi/4,width:4,height:0.12)
        XCTAssertTrue(beam.overlaps(FluidBody(id:1,center:Vec(1.25,1.25),width:0.3,height:0.3)))
        XCTAssertFalse(beam.overlaps(FluidBody(id:1,center:Vec(1,-1),width:0.3,height:0.3)))
        let a=FluidBody(id:0,center:Vec(0,0),width:1,height:1)
        XCTAssertFalse(a.overlaps(FluidBody(id:1,center:Vec(0,1),width:1,height:1)))
        XCTAssertTrue(a.overlaps(FluidBody(id:1,center:Vec(0,0.99),width:1,height:1)))
    }
    func testIceSkinDoesNotFreezeThroughARotatedCrateOrTheEndOfALongBeam() {
        let f=WaterField(platforms:[]),initial=f.representedVolume
        let crate=FluidBody(id:1,center:Vec(10,-1.2),angle:.pi/4,width:1.25,height:1.25)
        let beam=FluidBody(id:2,center:Vec(12.5,-0.8),width:3,height:0.18)
        f.freezeContact(at:10,bottom:-0.71,occupied:[crate,beam])
        f.freezeContact(at:13.7,bottom:-0.71,occupied:[crate,beam])
        XCTAssertTrue(f.ice.filter(\.solid).allSatisfy { c in
            let shape=FluidBody(id:0,center:c.center,width:c.size,height:c.height)
            return !shape.overlaps(crate,clearance:0.012) && !shape.overlaps(beam,clearance:0.012)
        })
        XCTAssertFalse(f.ice.contains { $0.solid && $0.center.x>13 && $0.center.x<14 })
        XCTAssertEqual(f.representedVolume,initial,accuracy:0.0001)
    }
    func testThinPlankAllowsIceAboveItAndStopsOnlyAtActualContact() {
        let f=WaterField(platforms:[]),source=Vec(10,-0.16),initial=f.representedVolume
        let plank=FluidBody(id:1,center:Vec(10,-1.04),width:1.8,height:0.18)
        let cube=FluidBody(id:0,center:source,width:1.12,height:1.12)
        f.freezeContact(at:10,bottom:-0.72,occupied:[cube,plank])
        for _ in 0..<150 { f.step(dt:1/30,coldSource:source,heatSource:nil,occupied:[cube,plank],coldFoot:-0.72) }
        let above=f.ice.filter { $0.solid && abs($0.center.x-10)<0.5 }
        XCTAssertFalse(above.isEmpty)
        XCTAssertGreaterThan(above.map(\.height).max()!,0.20)
        XCTAssertTrue(above.allSatisfy { !FluidBody(id:0,center:$0.center,width:$0.size,height:$0.height).overlaps(plank,clearance:0.012) })
        XCTAssertEqual(f.representedVolume,initial,accuracy:0.0001)
    }
    func testLandingBesideTheBridgeDoesNotFreezeABlockHaloAroundDryBody() {
        let s=Simulation();s.wind=0;s.placeCube(Vec(9.3,0.5));advance(s,1.25)
        XCTAssertTrue(s.cube.grounded);XCTAssertFalse(s.inWater)
        XCTAssertTrue(s.waterField.ice.prefix(s.waterField.rows*s.waterField.columns).allSatisfy { !$0.solid })
        XCTAssertTrue(s.jump(Vec(0,7.2),buffered:false));advance(s,0.4)
        XCTAssertGreaterThan(s.cube.position.y,0.5)
    }
    func testBondGraphKeepsSideSupportsAndDropsDisconnectedLintel() {
        var graph=MasonryBonds(columns:3,rows:3)
        XCTAssertEqual(graph.detach(4),[4]);XCTAssertEqual(graph.attached.count,8)
        XCTAssertEqual(graph.detach(0),[0]);XCTAssertEqual(graph.detach(1),[1])
        XCTAssertEqual(graph.detach(2),[2,3,5,6,7,8]);XCTAssertTrue(graph.attached.isEmpty)
        XCTAssertTrue(graph.detach(2).isEmpty)
    }
    func testStaticMasonryDoesNotCollapseAndDisplacesItsInitialWater() {
        let s=Simulation(form:.stone,map:.grotto);s.wind=0
        let empty=WaterField(platforms:s.platforms)
        XCTAssertLessThan(s.waterField.volume,empty.volume-2)
        advance(s,1)
        XCTAssertEqual(s.attachedMasonryBricks,9);XCTAssertTrue(s.debris.isEmpty)
        XCTAssertEqual(s.obstacles.filter { $0.masonry != nil }.count,9)
        XCTAssertEqual(s.waterField.representedVolume,s.waterField.volume,accuracy:0.0002)
        s.placeCube(Vec(12.1,-2.8),velocity:Vec(1,0));advance(s,0.5)
        XCTAssertEqual(s.attachedMasonryBricks,9);XCTAssertTrue(s.debris.isEmpty)
    }
    func testStoneKnocksRealBricksFromTheSubmergedWallAndTheyPersist() {
        let s=Simulation(form:.stone,map:.grotto);s.wind=0
        s.placeCube(Vec(11.9,-2.8),velocity:Vec(10,0))
        let volume=s.waterField.volume,wallMass=s.obstacles.filter { $0.masonry != nil }.reduce(Float(0)) { $0+$1.restMass }
        advance(s,0.15)
        let chunks=s.debris.filter { $0.origin.hasPrefix("grotto/old-sluice/brick/") }
        print("MASONRY bricks=\(s.attachedMasonryBricks) released=\(chunks.count) cube=\(s.cube.position)")
        XCTAssertFalse(chunks.isEmpty);XCTAssertLessThan(s.attachedMasonryBricks,9)
        XCTAssertEqual(chunks.count+s.attachedMasonryBricks,9)
        XCTAssertTrue(chunks.allSatisfy { $0.state.mass>0 && $0.material == .brick })
        let releasedMass=chunks.reduce(Float(0)) { $0+$1.state.mass }
        let attachedMass=s.obstacles.filter { $0.masonry != nil }.reduce(Float(0)) { $0+$1.restMass }
        XCTAssertEqual(releasedMass+attachedMass,wallMass,accuracy:0.0001)
        XCTAssertEqual(Set(chunks.map(\.origin)).count,chunks.count)
        XCTAssertEqual(Set(s.fluidBodies.map(\.id)).count,s.fluidBodies.count)
        let ids=Set(chunks.map(\.id));s.placeCube(Vec(25,0.8));advance(s,2)
        XCTAssertTrue(ids.isSubset(of:Set(s.debris.map(\.id))))
        XCTAssertEqual(s.waterField.representedVolume,volume,accuracy:0.0002)
        XCTAssertTrue(s.debris.allSatisfy { $0.state.position.x.isFinite && $0.state.position.y.isFinite })
    }
    func testWoodFragmentsFloatAndBrickFragmentsSinkWithOneFluidForce() throws {
        for material in [BreakMaterial.wood,.brick] {
            let world=try XCTUnwrap(ec_create());defer { ec_destroy(world) }
            _=ec_box(world,12,-4.5,10,1,0,false,true)
            let width:Float=0.4167,height:Float=0.625
            let id=ec_box(world,11,-1.8,width,height,material.density,true,false)
            let f=LiquidSolver(platforms:[]),initial=f.particles.reduce(Float(0)) { $0+$1.volume },dt:Float=1/120
            for _ in 0..<720 {
                let q=ec_state(world,id)
                let body=FluidBody(id:Int(id),center:Vec(q.x,q.y),velocity:Vec(q.vx,q.vy),angle:q.angle,omega:q.omega,width:width,height:height,mass:q.mass)
                f.advance(dt:dt,gravity:18,bodies:[body],frozen:[])
                if let load=f.pressureLoads[Int(id)] { ec_force(world,id,q.mass*load.velocity.x/dt,q.mass*load.velocity.y/dt);ec_torque(world,id,body.inertia*load.omega/dt) }
                let drag=f.dragLoad(on:body,mass:q.mass,dt:dt,coefficient:14)
                ec_force(world,id,drag.force.x,drag.force.y);ec_torque(world,id,drag.torque)
                ec_step(world,dt)
            }
            let q=ec_state(world,id)
            print("DEBRIS \(material) y=\(q.y) speed=\(hypot(q.vx,q.vy))")
            if material == .wood { XCTAssertGreaterThan(q.y,-1.2);XCTAssertLessThan(hypot(q.vx,q.vy),0.8) }
            else { XCTAssertLessThan(q.y,-3.3) }
            XCTAssertEqual(f.particles.reduce(Float(0)) { $0+$1.volume },initial,accuracy:0.0001)
        }
    }
    func testThinSluiceRetainsWaterThenOpeningItTransfersTheSameMass() {
        let gate=FluidBody(id:9,center:Vec(12,-1),width:0.04,height:6)
        let f=LiquidSolver(platforms:[],displaced:[gate])
        _=f.extract(in:FluidBody(id:-1,center:Vec(15,-1),width:6,height:8))
        let mass=f.particles.reduce(Float(0)) { $0+$1.volume }
        for _ in 0..<120 { f.advance(dt:1/120,gravity:18,bodies:[gate],frozen:[]) }
        XCTAssertLessThan(f.particles.filter { $0.position.x>12.03 }.reduce(Float(0)) { $0+$1.volume },0.0001)
        for _ in 0..<240 { f.advance(dt:1/120,gravity:18,bodies:[],frozen:[]) }
        XCTAssertGreaterThan(f.particles.filter { $0.position.x>12.1 }.reduce(Float(0)) { $0+$1.volume },1)
        XCTAssertEqual(f.particles.reduce(Float(0)) { $0+$1.volume },mass,accuracy:0.0001)
    }
    func testSweptDropCannotTunnelThroughThinRotatedIce() {
        let wall=FluidBody(id:0,center:Vec(0,0),angle:.pi/4,width:0.02,height:3)
        let hit=wall.sweep(from:Vec(-1,0),to:Vec(1,0),radius:0.025)
        XCTAssertNotNil(hit);XCTAssertLessThan(hit!.fraction,0.5)
        XCTAssertFalse(wall.contains(hit!.point,margin:0.024))
        XCTAssertNil(wall.sweep(from:Vec(-1,3),to:Vec(1,3),radius:0.025))
    }
    func testAnchoredShapeRetainsItsActualBox2DMassWhenReleased() throws {
        let w=try XCTUnwrap(ec_create());defer { ec_destroy(w) }
        let id=ec_box(w,0,0,0.592,0.592,2.1,false,true),mass=ec_shape_mass(w,id)
        XCTAssertGreaterThan(mass,0);XCTAssertEqual(ec_state(w,id).mass,0)
        ec_make_dynamic(w,id);XCTAssertEqual(ec_state(w,id).mass,mass,accuracy:0.000001)
        ec_velocity(w,id,0,0,2);ec_step(w,1/120);XCTAssertGreaterThan(abs(ec_state(w,id).angle),0.001)
    }
    func testFullPhysicsPoolReportsCapacityAndReusesSlots() throws {
        let w=try XCTUnwrap(ec_create());defer { ec_destroy(w) }
        for i in 0..<512 { XCTAssertEqual(ec_box(w,Float(i)*2,0,1,1,1,false,true),Int32(i)) }
        XCTAssertEqual(ec_available_bodies(w),0);XCTAssertEqual(ec_box(w,0,0,1,1,1,true,false),-1)
        ec_remove(w,42);XCTAssertEqual(ec_available_bodies(w),1)
        XCTAssertEqual(ec_box(w,0,0,1,1,1,true,false),42);XCTAssertEqual(ec_available_bodies(w),0)
    }
}
