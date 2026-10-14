import Foundation
import CPhysics

public struct Vec: Equatable {
    public var x: Float; public var y: Float
    public init(_ x: Float, _ y: Float) { self.x=x; self.y=y }
}
public struct BodyState {
    public var position: Vec; public var velocity: Vec; public var angle: Float; public var mass: Float; public var angularVelocity: Float; public var grounded: Bool
}
public enum Mood { case curious, focused, delighted, startled, displeased, sleepy }
public enum Surface: String { case grass = "трава", stone = "камень", ice = "лёд", wood = "дерево", water = "вода" }
public struct Platform {
    public let x: Float, y: Float, width: Float, height: Float
    public init(_ x:Float,_ y:Float,_ width:Float,_ height:Float) { self.x=x;self.y=y;self.width=width;self.height=height }
}
public struct Mote {
    public var position: Vec; public var velocity: Vec; public var life: Float; public var kind: Int
}
public final class Simulation {
    public static let timestep: Float = 1/120
    public static let iceDuration: Float = 25
    public let platforms: [Platform] = [Platform(2,-2,10,4),Platform(21,-2,8,4),Platform(12,-1.85,1.7,3.5),Platform(12,-4.3,10,0.6),Platform(-3.2,1,0.4,7),Platform(25.2,1,0.4,7)]
    public private(set) var cube: BodyState!
    public private(set) var crate: BodyState!
    public private(set) var time: Float = 0
    public private(set) var wetness: Float = 0
    public private(set) var energy: Float = 100
    public private(set) var iceTime: Float = 0
    public private(set) var iceSegments: [Vec] = []
    public private(set) var mood: Mood = .curious
    public private(set) var impact: Float = 0
    public private(set) var landingAge: Float = 10
    public private(set) var idleTime: Float = 0
    public private(set) var shakeTime: Float = 0
    public private(set) var surface: Surface = .grass
    public private(set) var squash: Float = 0
    public private(set) var jumps = 0
    public private(set) var respawns = 0
    public private(set) var won = false
    public private(set) var collected: Set<Int> = []
    public private(set) var particles: [Mote] = []
    public private(set) var wave: [Float] = Array(repeating: 0, count: 81)
    private var waveSpeed: [Float] = Array(repeating: 0, count: 81)
    public let shards: [Vec] = [Vec(6.2,1.6),Vec(12,2.1),Vec(19,1.8)]
    private var world: OpaquePointer
    private var cubeID: Int32 = 0
    private var crateID: Int32 = 0
    private var iceIDs: [Int32] = []
    private var emotionTime: Float = 0
    private var shakeCooldown: Float = 0
    private var cooldown: Float = 0
    private var buffer: (Vec,Float)?
    private var randomSeed: UInt64 = 8251
    public var gravity: Float = 18 { didSet { ec_gravity(world,gravity) } }
    public var waterEnabled = true
    public var jumpScale: Float = 1
    public var movement: Float = 0
    public let waterLeft: Float = 7, waterRight: Float = 17, waterLevel: Float = -0.72
    public var inWater: Bool {
        waterEnabled && cube.position.x > waterLeft && cube.position.x < waterRight &&
        cube.position.y-0.56 < waterLevel && cube.position.y+0.56 > -4
    }
    public var canLaunch: Bool { (cube.grounded || inWater) && cooldown <= 0 }
    public init() {
        world=ec_create()!
        for (i,p) in platforms.enumerated() {
            let id=ec_box(world,p.x,p.y,p.width,p.height,0,false,true)
            ec_material(world,id,i<2 ? 0.85 : 0.62,i<2 ? 0.02 : 0.10)
        }
        _=ec_slope(world,7,9.4,false);_=ec_slope(world,14.6,17,true)
        cubeID=ec_box(world,2.7,0.75,1.12,1.12,0.75,true,false)
        crateID=ec_box(world,5.1,0.7,1.25,1.25,0.48,true,false)
        sync()
    }
    deinit { ec_destroy(world) }
    private func state(_ id:Int32)->BodyState {
        let s=ec_state(world,id)
        return BodyState(position:Vec(s.x,s.y),velocity:Vec(s.vx,s.vy),angle:s.angle,mass:s.mass,angularVelocity:s.omega,grounded:s.grounded)
    }
    private func sync() { cube=state(cubeID);crate=state(crateID) }
    public func intersectsSolid(at position:Vec)->Bool { ec_blocked(world,cubeID,position.x,position.y) }
    public func launchVelocity(for request:Vec)->Vec {
        let length=sqrt(request.x*request.x+request.y*request.y)
        let factor=length > 12 ? 12/length : 1
        let impulse=Vec(request.x*factor*jumpScale,max(2.8,request.y*factor)*jumpScale)
        if inWater && !cube.grounded {
            return Vec(cube.velocity.x+impulse.x*0.85,cube.velocity.y+max(8.8,impulse.y)-min(0,cube.velocity.y))
        }
        return Vec(cube.velocity.x+impulse.x,cube.velocity.y+impulse.y*(1-wetness*0.10))
    }
    @discardableResult public func jump(_ request: Vec, buffered: Bool = true)->Bool {
        guard canLaunch else {
            if buffered { buffer=(request,0.12) }
            return false
        }
        let predicted=launchVelocity(for:request)
        let delta=Vec(predicted.x-cube.velocity.x,predicted.y-cube.velocity.y)
        if inWater && !cube.grounded {
            // A stroke against actual water is distinct from an air jump.
            guard energy >= 6 else { return false }
            energy-=6
            ec_impulse(world,cubeID,delta.x,delta.y)
            disturb(cube.position.x,amount:1)
            emit(Vec(cube.position.x,waterLevel),kind:1,count:24)
            cooldown=0.4
        } else {
            ec_impulse(world,cubeID,delta.x,delta.y)
            cooldown=0.16
        }
        squash = -0.28; jumps += 1; buffer=nil;mood = .focused;emotionTime=0.3
        emit(cube.position,kind:0,count:12)
        sync()
        return true
    }
    @discardableResult public func frost()->Bool {
        guard energy >= 30, iceTime <= 0 else { return false }
        guard cube.position.x > 4.8 && cube.position.x < 18.6 && cube.position.y < 3 else { return false }
        energy-=30; iceTime=Self.iceDuration
        // Leave room for a rising jump when cast while immersed, rather than sealing the cube underneath.
        if inWater {
            iceSegments=[Vec(7,max(7,cube.position.x-2.1)),Vec(min(17,cube.position.x+2.1),17)]
        } else { iceSegments=[Vec(7,17)] }
        for segment in iceSegments where segment.y-segment.x > 0.18 {
            let id=ec_box(world,(segment.x+segment.y)/2,waterLevel+0.225,segment.y-segment.x,0.45,0,false,true)
            ec_material(world,id,0.015,0.04);iceIDs.append(id)
        }
        for i in 0..<28 { emit(Vec(7+Float(i)*0.37,waterLevel+0.22),kind:2,count:2) }
        return true
    }
    public func resetCube() { ec_teleport(world,cubeID,2.7,0.75);wetness=0;cooldown=0;buffer=nil;won=false;sync() }
    // A reproducible entry point for physics tests and the optional debug tools.
    public func placeCube(_ p: Vec) { ec_teleport(world,cubeID,p.x,p.y);sync() }
    public func step() {
        let dt=Self.timestep;time+=dt;cooldown=max(0,cooldown-dt)
        energy=min(100,energy+dt*3)
        let old=cube!
        landingAge+=dt;impact*=exp(-dt*7);emotionTime=max(0,emotionTime-dt)
        shakeTime=max(0,shakeTime-dt);shakeCooldown=max(0,shakeCooldown-dt)
        if cube.grounded { ec_drive(world,cubeID,movement,surface == .ice ? 0.12 : 1,false) }
        else if inWater { ec_drive(world,cubeID,movement,0.75,true) }
        for (id,s,size) in [(cubeID,cube!,Float(1.12)),(crateID,crate!,Float(1.25))] {
            let fraction=max(0,min(1,(waterLevel-(s.position.y-size/2))/size))
            if waterEnabled && s.position.x > waterLeft-size/2 && s.position.x < waterRight+size/2 && fraction > 0 {
                let buoyancy=gravity*size*size*1.12*fraction
                ec_force(world,id,-s.velocity.x*s.mass*3.2*fraction,buoyancy-s.velocity.y*s.mass*4*fraction)
                if id == cubeID { wetness=min(1,wetness+dt*2) }
            }
        }
        ec_step(world,dt);sync()
        if cube.position.y-0.56 > waterLevel { wetness=max(0,wetness-dt*0.065) }
        if old.position.y-0.56 > waterLevel && cube.position.y-0.56 <= waterLevel && cube.position.x > 7 && cube.position.x < 17 && waterEnabled {
            disturb(cube.position.x,amount:min(1.5,abs(old.velocity.y)*0.13));emit(Vec(cube.position.x,waterLevel),kind:1,count:28)
            mood = .displeased;emotionTime=3
        }
        if cube.grounded {
            if iceTime>0 && cube.position.x>7 && cube.position.x<17 && cube.position.y>0 { surface = .ice }
            else if abs(cube.position.x-crate.position.x)<1.15 && cube.position.y>crate.position.y+0.75 { surface = .wood }
            else { surface = cube.position.x<7 || cube.position.x>17 ? .grass : .stone }
        } else if inWater { surface = .water }
        if !old.grounded && cube.grounded && old.velocity.y < -1.5 {
            let hardness:Float=surface == .grass ? 0.65 : (surface == .wood ? 0.8 : 1)
            impact=min(1,abs(old.velocity.y)/11)*hardness;landingAge=0
            squash=min(0.42,abs(old.velocity.y)*0.035*hardness)
            emit(Vec(cube.position.x,cube.position.y-0.56),kind:surface == .ice ? 2 : 0,count:impact>0.65 ? 18 : 7)
            mood = impact>0.7 ? .startled : .delighted;emotionTime=impact>0.7 ? 0.8 : 0.45
        }
        if cube.grounded && wetness>0.4 && abs(movement)<0.1 && abs(cube.velocity.x)<0.4 && shakeCooldown<=0 {
            shakeTime=0.75;shakeCooldown=6;emit(cube.position,kind:1,count:30);wetness=max(0,wetness-0.15)
        }
        if abs(cube.velocity.x)<0.2 && abs(cube.velocity.y)<0.2 && cube.grounded { idleTime+=dt } else { idleTime=0 }
        if emotionTime<=0 {
            mood=idleTime>8 ? .sleepy : (inWater ? .displeased : (cube.velocity.y < -5 ? .startled : .curious))
        }
        squash*=exp(-dt*11)
        if let b=buffer { buffer=b.1>dt ? (b.0,b.1-dt) : nil; if cube.grounded && cooldown <= 0 { _=jump(b.0,buffered:false) } }
        if !iceIDs.isEmpty {
            iceTime-=dt
            if iceTime <= 0 {
                for id in iceIDs { ec_remove(world,id) };iceIDs=[];iceSegments=[];iceTime=0
                disturb(cube.position.x,amount:0.4)
                for i in 0..<20 { emit(Vec(7+Float(i)*0.5,waterLevel),kind:2,count:2) }
            }
        }
        for i in 1..<wave.count-1 { waveSpeed[i]+=(wave[i-1]+wave[i+1]-2*wave[i])*dt*100; waveSpeed[i]-=wave[i]*dt*12; waveSpeed[i]*=exp(-dt*1.4) }
        for i in 1..<wave.count-1 { wave[i]+=waveSpeed[i]*dt }
        for i in shards.indices where !collected.contains(i) {
            let p=shards[i];let d=cube.position
            if hypot(p.x-d.x,p.y-d.y)<1.0 { collected.insert(i);emit(p,kind:3,count:24);mood = .delighted;emotionTime=1.8 }
        }
        if cube.position.x > 22.4 && cube.grounded && !won { won=true;emit(Vec(23,2),kind:3,count:55) }
        if cube.position.y < -5.2 || !cube.position.x.isFinite { respawns+=1;resetCube() }
        for i in particles.indices { particles[i].life-=dt;particles[i].position.x+=particles[i].velocity.x*dt;particles[i].position.y+=particles[i].velocity.y*dt;particles[i].velocity.y-=dt*4 }
        particles.removeAll { $0.life <= 0 }
        if particles.count>550 { particles.removeFirst(particles.count-550) }
    }
    public func disturb(_ x:Float,amount:Float) { let i=max(1,min(wave.count-2,Int((x-7)/10*80)));waveSpeed[i]-=amount*6;waveSpeed[i-1]-=amount*3;waveSpeed[i+1]-=amount*3 }
    private func random()->Float { randomSeed=randomSeed &* 6364136223846793005 &+ 1;return Float((randomSeed>>32)&0xffff)/65535 }
    private func emit(_ p:Vec,kind:Int,count:Int) {
        for _ in 0..<count { particles.append(Mote(position:p,velocity:Vec((random()-0.5)*5,random()*4+0.5),life:0.45+random()*0.65,kind:kind)) }
    }
}
