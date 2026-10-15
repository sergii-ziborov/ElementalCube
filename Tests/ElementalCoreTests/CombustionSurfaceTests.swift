import XCTest
@testable import ElementalCore

final class CombustionSurfaceTests:XCTestCase {
    private func advance(_ s:Simulation,_ t:Float) { for _ in 0..<Int(t/Simulation.timestep) { s.step() } }
    func testFireCharsContactGrassWithoutPaintingItsFlightPath() {
        let s=Simulation(form:.fire);s.wind=0;s.waterEnabled=false;s.movement = -1
        advance(s,1)
        XCTAssertTrue(s.patches.contains { $0.fuel<1 });XCTAssertFalse(s.trails.contains { $0.form == .fire })
        let flight=Simulation(form:.fire);flight.wind=0;flight.waterEnabled=false;flight.placeCube(Vec(2.7,1.6))
        advance(flight,0.15)
        XCTAssertTrue(flight.patches.allSatisfy { $0.fuel==1 },"Floating above grass does not paint or ignite it")
        let rock=Simulation(form:.fire,map:.glacier);rock.wind=0;rock.placeCube(Vec(42,7.9));advance(rock,1)
        XCTAssertTrue(rock.patches.isEmpty);XCTAssertFalse(rock.trails.contains { $0.form == .fire })
    }
    func testWoodenBridgeCharsAtTheActualMovingSection() {
        let s=Simulation(form:.fire);s.wind=0;s.waterEnabled=false;advance(s,0.2)
        let section=s.bridge[0];s.placeCube(Vec(section.state.position.x,section.state.position.y+0.7));advance(s,2)
        XCTAssertTrue(s.bridge.contains { $0.fuel<0.99 })
        XCTAssertFalse(s.trails.contains { $0.form == .fire })
    }
    func testHeatCirculationConservesWaterAndNetMomentum() {
        let liquid=LiquidSolver(platforms:[]),volume=liquid.particles.reduce(Float(0)) { $0+$1.volume }
        let before=liquid.particles.reduce(Float(0)) { $0+$1.velocity.y*$1.volume }
        liquid.heatCirculation(at:Vec(10,-2),dt:0.1,strength:1)
        let after=liquid.particles.reduce(Float(0)) { $0+$1.velocity.y*$1.volume }
        XCTAssertEqual(after,before,accuracy:0.00001)
        XCTAssertEqual(liquid.particles.reduce(Float(0)) { $0+$1.volume },volume,accuracy:0.00001)
        XCTAssertTrue(liquid.particles.contains { $0.velocity.y>0.01 });XCTAssertTrue(liquid.particles.contains { $0.velocity.y < -0.005 })
        XCTAssertTrue(liquid.particles.filter { abs($0.position.x-10)>1.4 }.allSatisfy { $0.velocity==Vec(0,0) })
    }
    func testBoilingUsesFiniteWaterAndHealthWithoutBurnMarksInWater() {
        let s=Simulation(form:.fire);s.wind=0;s.placeCube(Vec(10,-2));let initial=s.waterField.volume
        advance(s,0.8)
        XCTAssertGreaterThan(s.boilingStrength,0);XCTAssertLessThan(s.health,100)
        XCTAssertLessThan(s.waterField.volume,initial)
        XCTAssertEqual(s.waterField.volume+s.waterField.evaporated,initial,accuracy:0.001)
        XCTAssertTrue(s.particles.contains { $0.kind==7 || $0.kind==5 })
        XCTAssertFalse(s.trails.contains { $0.form == .fire })
    }
    func testFireAboveThePondCannotBoilOrEvaporateWithoutWaterContact() {
        let s=Simulation(form:.fire);s.wind=0;s.placeCube(Vec(10,0.2));let volume=s.waterField.volume
        advance(s,0.05)
        XCTAssertFalse(s.inWater);XCTAssertEqual(s.boilingStrength,0)
        XCTAssertEqual(s.waterField.volume,volume,accuracy:0.00001)
        XCTAssertTrue(s.particles.allSatisfy { $0.kind != 7 })
    }

}
