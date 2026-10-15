import XCTest
@testable import ElementalCore

final class WaterStabilityTests:XCTestCase {
    private func report(_ label:String,_ f:LiquidSolver) {
        let mass=f.particles.reduce(Float(0)) { $0+$1.volume }
        let kinetic=f.particles.reduce(Float(0)) { $0+$1.volume*($1.velocity.x*$1.velocity.x+$1.velocity.y*$1.velocity.y)/2 }
        let levels=(0..<40).map { f.surfaceHeight(at:8.5+Float($0)*0.18) }
        print("WATER \(label) mass=\(mass) rmsSpeed=\(sqrt(2*kinetic/mass)) surface=[\(levels.min()!),\(levels.max()!)] top=\(f.particles.map { $0.position.y }.max()!)")
    }
    func testUnforcedPondSettlesWithoutPersistentNumericalCurrents() {
        let f=LiquidSolver(platforms:[])
        for _ in 0..<720 { f.advance(dt:1/120,gravity:18,bodies:[],frozen:[]) }
        report("rest",f)
        let mass=f.particles.reduce(Float(0)) { $0+$1.volume }
        let speed2=f.particles.reduce(Float(0)) { $0+$1.volume*($1.velocity.x*$1.velocity.x+$1.velocity.y*$1.velocity.y) }/mass
        XCTAssertLessThan(sqrt(speed2),0.05)
    }
    func testReconstructedSurfaceIntegratesToTheActualWaterVolume() {
        let f=LiquidSolver(platforms:[])
        let markers=f.particles.reduce(Float(0)) { $0+$1.volume }
        let field=f.density.reduce(Float(0),+)*f.spacing*f.spacing
        XCTAssertEqual(field,markers,accuracy:0.0002)
    }
    func testLocalEvaporationIsSymmetricInsteadOfFollowingParticleArrayOrder() {
        let f=LiquidSolver(platforms:[])
        func side(_ left:Bool)->Float { f.particles.filter { ($0.position.x<12)==left }.reduce(Float(0)) { $0+$1.volume } }
        let left=side(true),right=side(false),mass=left+right
        let evaporated=f.evaporate(at:Vec(12,-1.2),amount:0.2,radius:0.8)
        XCTAssertEqual(left-side(true),right-side(false),accuracy:0.0001)
        XCTAssertEqual(evaporated,0.2,accuracy:0.0001)
        XCTAssertEqual(side(true)+side(false)+evaporated,mass,accuracy:0.0002)
        XCTAssertLessThanOrEqual(f.particles.filter { $0.volume<f.markerVolume*0.99 }.count,2,"A sink removes markers; it must not leave a dilute cloud supporting full-cell pressure")
    }
    func testWaterRefillsAnEvaporatedPocketAndConservesTheRemainingMass() {
        let f=LiquidSolver(platforms:[]),initial=f.particles.reduce(Float(0)) { $0+$1.volume }
        var removed:Float=0
        for tick in 0..<480 {
            if tick<120 { removed+=f.evaporate(at:Vec(12,-1),amount:1/120,radius:0.6) }
            f.advance(dt:1/120,gravity:18,bodies:[],frozen:[])
        }
        XCTAssertEqual(f.particles.reduce(Float(0)) { $0+$1.volume }+removed,initial,accuracy:0.0002)
        let outside=(f.surfaceHeight(at:10)+f.surfaceHeight(at:14))/2
        XCTAssertEqual(f.surfaceHeight(at:12),outside,accuracy:0.18)
        XCTAssertLessThan(outside,-0.75)
    }
    func testWaterDoesNotRemainAttachedToAWithdrawnBody() {
        let f=LiquidSolver(platforms:[]),mass=f.particles.reduce(Float(0)) { $0+$1.volume }
        for tick in 0..<720 {
            let t=Float(tick)/120
            let body=FluidBody(id:1,center:Vec(14.5+t*1.2,-1+t*1.8),velocity:Vec(1.2,1.8),width:1.12,height:1.12)
            f.advance(dt:1/120,gravity:18,bodies:t<2 ? [body] : [],frozen:[])
        }
        report("withdrawal",f)
        XCTAssertEqual(f.particles.reduce(Float(0)) { $0+$1.volume },mass,accuracy:0.0001)
        XCTAssertLessThan(f.particles.map { $0.position.y }.max()!,-0.3)
    }
    func testSwimmingOntoTheBankDoesNotDragUpAPersistentWaterSheet() {
        let s=Simulation(form:.water);s.wind=0;s.placeCrate(Vec(2,1));s.placeCube(Vec(14,-0.5));s.movement=1
        for _ in 0..<600 { s.step() }
        print("WATER bank cube=\(s.cube.position)");report("bank",s.waterField.liquid)
        XCTAssertGreaterThan(s.cube.position.x,17)
        XCTAssertLessThan(s.waterField.liquid.particles.filter { !$0.isSpray }.map { $0.position.y }.max()!,0.1)
    }
}
