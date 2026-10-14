import Foundation
import CPhysics

public struct Vec: Equatable {
    public var x: Float; public var y: Float
    public init(_ x:Float,_ y:Float) { self.x=x;self.y=y }
}
public struct BodyState {
    public var position:Vec;public var velocity:Vec;public var angle:Float;public var mass:Float;public var angularVelocity:Float;public var grounded:Bool
}
public enum Mood { case curious, focused, delighted, startled, displeased, sleepy }
public enum Surface:String { case grass="трава",stone="камень",ice="лёд",wood="дерево",water="вода" }
public enum SimulationFeedback:Equatable {
    case jumped, landed(impact:Float,surface:Surface), enteredWater(strength:Float), collectedCrystal, frozeWater, finished, hurt, died
}
public struct Platform {
    public let x:Float,y:Float,width:Float,height:Float
    public init(_ x:Float,_ y:Float,_ width:Float,_ height:Float) { self.x=x;self.y=y;self.width=width;self.height=height }
}
public struct Mote { public var position:Vec;public var velocity:Vec;public var life:Float;public var kind:Int }

public final class Simulation {
    public static let timestep:Float=1/120
    public let form:ElementForm
    public let fur:FurPhysics
    public let waterField:WaterField
    public let platforms:[Platform]
    public private(set) var cube:BodyState!
    public private(set) var crate:BodyState!
    public private(set) var crateExists=true
    public private(set) var crateFuel:Float=1
    public private(set) var crateFrost:Float=0
    public private(set) var crateBurning:Float=0
    public private(set) var patches:[MaterialPatch]
    public private(set) var frostMarks:[FrostMark]=[]
    public private(set) var time:Float=0,wetness:Float=0,health:Float=100,mana:Float=100
    public private(set) var passiveEquipped=false
    public private(set) var passiveWorking=false
    public var energy:Float { mana }
    public var dead:Bool { health<=0 }
    public var iceCells:[IceCell] { waterField.ice.filter { $0.solid } }
    public private(set) var mood:Mood = .curious
    public private(set) var impact:Float=0,landingAge:Float=10,idleTime:Float=0,shakeTime:Float=0,squash:Float=0
    public private(set) var surface:Surface = .grass
    public private(set) var jumps=0,respawns=0,won=false,deepRelic=false
    public private(set) var collected:Set<Int>=[]
    public private(set) var particles:[Mote]=[]
    public private(set) var wave:[Float]=Array(repeating:0,count:81)
    private var waveSpeed:[Float]=Array(repeating:0,count:81)
    public let shards:[Vec]=[Vec(6.2,1.6),Vec(12,2.1),Vec(19,1.8)]
    private var world:OpaquePointer
    private var cubeID:Int32=0,crateID:Int32=0
    private var platformIDs:[Int32]=[]
    private var iceIDs:[Int:Int32]=[:]
    private var emotionTime:Float=0,shakeCooldown:Float=0,cooldown:Float=0,materialClock:Float=0,particleClock:Float=0
    private var buffer:(Vec,Float)?
    private var randomSeed:UInt64=8251
    private var feedback:[SimulationFeedback]=[]
    private var ticks=0
    private var manaExhausted=false
    public var gravity:Float=18 { didSet { ec_gravity(world,gravity) } }
    public var waterEnabled=true
    public var jumpScale:Float=1,movement:Float=0,wind:Float=1
    public let waterLeft:Float=7,waterRight:Float=17
    public var waterLevel:Float { waterField.surface(at:cube.position.x) }
    public var inWater:Bool { waterEnabled && immersion(cube,size:1.12)>0.02 }
    public var canLaunch:Bool { !dead && (cube.grounded || inWater || (form == .air && passiveWorking && hovering)) && cooldown<=0 }
    public var hovering:Bool {
        guard form == .air else { return false }
        return abs(cube.position.y-supportHeight(at:cube.position.x)-0.76)<0.35 && abs(cube.velocity.y)<1.5
    }
    public var bodyAngle:Float {
        let wiggle=shakeTime>0 ? sin(time*43)*0.11 : 0
        return cube.angle+max(-0.10,min(0.10,-cube.velocity.x*0.012))+wiggle
    }
    public var bodyStretch:SIMD3<Float> {
        if form == .stone { return SIMD3(repeating:1) }
        let breathing=sin(time*2.7)*0.012
        return SIMD3(1+squash*0.5+breathing,1-squash-breathing,1)
    }
    public var windVelocity:Float { wind*(1.2+sin(time*0.9)*0.6+sin(time*2.3)*0.25) }
    public init(form:ElementForm = .ice) {
        self.form=form;fur=FurPhysics(form:form)
        // The bridge has a real 1.7 m passage beneath it, joining both banks.
        platforms=[Platform(2,-2,10,4),Platform(21,-2,8,4),Platform(12,-1,1.7,1.8),Platform(12,-2.1,2.2,0.4),Platform(12,-4.3,10,0.6),Platform(-3.2,1,0.4,7),Platform(25.2,1,0.4,7)]
        waterField=WaterField(platforms:platforms)
        patches=(-6..<50).map { MaterialPatch(x:Float($0)*0.5+0.25) }
        for p in platforms {
            for i in 0...Int(p.width/0.3) {
                let x=p.x-p.width/2+Float(i)*0.3
                frostMarks.append(FrostMark(position:Vec(x,p.y+p.height/2)))
                frostMarks.append(FrostMark(position:Vec(x,p.y-p.height/2)))
            }
            for i in 0...Int(p.height/0.3) {
                let y=p.y-p.height/2+Float(i)*0.3
                frostMarks.append(FrostMark(position:Vec(p.x-p.width/2,y)))
                frostMarks.append(FrostMark(position:Vec(p.x+p.width/2,y)))
            }
        }
        world=ec_create()!
        for (i,p) in platforms.enumerated() {
            let id=ec_box(world,p.x,p.y,p.width,p.height,0,false,true);platformIDs.append(id)
            ec_material(world,id,i<2 ? 0.85 : 0.62,i<2 ? 0.02 : 0.10)
        }
        _=ec_slope(world,7,9.4,false);_=ec_slope(world,14.6,17,true)
        cubeID=ec_box(world,2.7,0.75,1.12,1.12,form.density,true,form == .air)
        crateID=ec_box(world,5.1,0.7,1.25,1.25,0.48,true,false)
        if form == .air { ec_material(world,cubeID,0.015,0.02) }
        if form == .water { ec_material(world,cubeID,0.3,0.06) }
        sync();updateFur()
    }
    deinit { ec_destroy(world) }
    public func equipPassive(_ enabled:Bool) { passiveEquipped=enabled;passiveWorking=enabled && !manaExhausted && mana>0.1 && !dead }
    public func takeFeedback()->[SimulationFeedback] { let events=feedback;feedback.removeAll(keepingCapacity:true);return events }
    private func record(_ event:SimulationFeedback) { if feedback.count>=16 { feedback.removeFirst() };feedback.append(event) }
    private func state(_ id:Int32)->BodyState {
        let s=ec_state(world,id)
        return BodyState(position:Vec(s.x,s.y),velocity:Vec(s.vx,s.vy),angle:s.angle,mass:s.mass,angularVelocity:s.omega,grounded:s.grounded)
    }
    private func sync() { cube=state(cubeID);if crateExists { crate=state(crateID) } }
    public func intersectsSolid(at position:Vec)->Bool { ec_blocked(world,cubeID,position.x,position.y) }
    public func supportHeight(at x:Float)->Float {
        if x<=7 || x>=17 { return 0 }
        var height=waterEnabled && waterField.volume>0.01 ? max(waterField.floor(at:x),waterField.surface(at:x)) : waterField.floor(at:x)
        for p in platforms where abs(p.x-x)<p.width/2 && cube.position.y>p.y+p.height/2 { height=max(height,p.y+p.height/2) }
        return height
    }
    private func immersion(_ s:BodyState,size:Float)->Float {
        guard s.position.x>7-size/3 && s.position.x<17+size/3 else { return 0 }
        let x=max(7.001,min(16.999,s.position.x))
        guard waterField.contains(Vec(x,min(s.position.y,waterField.surface(at:x)-0.01))) else { return 0 }
        return max(0,min(1,(waterField.surface(at:x)-(s.position.y-size/2))/size))
    }
    public func launchVelocity(for request:Vec)->Vec {
        guard request.x.isFinite,request.y.isFinite else { return cube.velocity }
        let length=hypot(request.x,request.y),factor=length>12 ? 12/length : 1
        let impulse=Vec(request.x*factor*jumpScale,max(2.8,request.y*factor)*jumpScale)
        if inWater && !cube.grounded && form != .stone {
            return Vec(cube.velocity.x+impulse.x*0.85,cube.velocity.y+max(8.8,impulse.y)-min(0,cube.velocity.y))
        }
        let weight:Float=form == .stone && inWater ? 0.45 : 1-wetness*0.1
        return Vec(cube.velocity.x+impulse.x,cube.velocity.y+impulse.y*weight)
    }
    @discardableResult public func jump(_ request:Vec,buffered:Bool=true)->Bool {
        guard request.x.isFinite,request.y.isFinite,!dead else { return false }
        guard canLaunch else { if buffered { buffer=(request,0.12) };return false }
        let swimming=inWater && !cube.grounded
        if swimming && form == .stone { return false }
        if swimming && mana<6 { return false }
        let velocity=launchVelocity(for:request)
        ec_impulse(world,cubeID,velocity.x-cube.velocity.x,velocity.y-cube.velocity.y)
        cooldown=swimming ? 0.4 : 0.16
        if swimming { mana-=6;disturb(cube.position.x,amount:1);emit(Vec(cube.position.x,waterLevel),kind:1,count:24) }
        squash = form == .stone ? 0 : -0.28;jumps+=1;buffer=nil;mood = .focused;emotionTime=0.3
        record(.jumped);emit(cube.position,kind:0,count:12);sync();return true
    }
    public func resetCube() { ec_teleport(world,cubeID,2.7,0.75);wetness=0;cooldown=0;buffer=nil;won=false;health=100;mana=100;sync();updateFur() }
    public func placeCube(_ p:Vec) { guard p.x.isFinite,p.y.isFinite else { return };ec_teleport(world,cubeID,p.x,p.y);sync();updateFur() }
    public func damage(_ amount:Float) {
        guard amount.isFinite,amount>0,!dead else { return }
        health=max(0,health-amount)
        if dead { movement=0;passiveWorking=false;mood = .sleepy;record(.died) }
    }
    public func step() {
        let dt=Self.timestep;time+=dt;ticks+=1;cooldown=max(0,cooldown-dt)
        let old=cube!,wasInWater=inWater
        if mana<=0.1 { manaExhausted=true }
        if mana>=20 { manaExhausted=false }
        passiveWorking=passiveEquipped && !manaExhausted && !dead
        mana=min(100,mana+dt*(passiveWorking ? -form.manaCost : 4))
        mana=max(0,mana)
        landingAge+=dt;impact*=exp(-dt*7);emotionTime=max(0,emotionTime-dt)
        shakeTime=max(0,shakeTime-dt);shakeCooldown=max(0,shakeCooldown-dt)
        if !dead {
            if form == .air {
                ec_drive(world,cubeID,movement,0.85,true)
                ec_force(world,cubeID,windVelocity*cube.mass*0.5,0)
                if passiveWorking && cooldown<=0 {
                    let height=max(supportHeight(at:cube.position.x),supportHeight(at:cube.position.x+movement*0.9))
                    let gap=cube.position.y-height-0.76
                    if gap<0.8 && cube.velocity.y<2 {
                        let lift=max(0,min(gravity*3,gravity-gap*75-cube.velocity.y*12))
                        ec_force(world,cubeID,0,cube.mass*lift)
                    }
                }
            } else if cube.grounded {
                ec_drive(world,cubeID,movement,surface == .ice ? 0.12 : (form == .stone && passiveWorking ? 1.6 : 1),false)
            } else if inWater { ec_drive(world,cubeID,movement,form == .stone ? 0.35 : 0.85,true) }
        }
        for (id,s,size) in [(cubeID,cube!,Float(1.12)),(crateID,crate!,Float(1.25))] where id != crateID || crateExists {
            let fraction=waterEnabled ? immersion(s,size:size) : 0
            if fraction>0 {
                let drag:Float=id==cubeID && form == .water && passiveWorking ? 1.4 : 3.2
                ec_force(world,id,-s.velocity.x*s.mass*drag*fraction,gravity*size*size*1.12*fraction-s.velocity.y*s.mass*4*fraction)
                if id==cubeID { wetness=min(1,wetness+dt*2) }
            }
        }
        if form != .air { ec_force(world,cubeID,windVelocity*cube.mass*0.035,0) }
        ec_step(world,dt);sync()
        wetness=inWater ? min(1,wetness+dt*2) : max(0,wetness-dt*0.065)
        if form == .fire { wetness=0 }
        if !wasInWater && inWater {
            disturb(cube.position.x,amount:min(1.5,abs(old.velocity.y)*0.13));emit(Vec(cube.position.x,waterLevel),kind:1,count:28)
            record(.enteredWater(strength:min(1,abs(old.velocity.y)/10)));mood = .displeased;emotionTime=3
        }
        if cube.grounded {
            if iceCells.contains(where:{ abs($0.center.x-cube.position.x)<0.8 && abs($0.center.y-(cube.position.y-0.56))<0.35 }) { surface = .ice }
            else if crateExists && abs(cube.position.x-crate.position.x)<1.15 && cube.position.y>crate.position.y+0.75 { surface = crateFrost>0.5 ? .ice : .wood }
            else {
                let patch=patches.min(by:{ abs($0.x-cube.position.x)<abs($1.x-cube.position.x) })
                let frosted=frostMarks.contains { $0.cold>0.5 && abs($0.position.x-cube.position.x)<0.75 && abs($0.position.y-(cube.position.y-0.56))<0.2 }
                surface=(patch?.frost ?? 0)>0.5 || frosted ? .ice : (cube.position.x<7 || cube.position.x>17 ? .grass : .stone)
            }
        } else if inWater { surface = .water }
        ec_material(world,cubeID,form == .air || surface == .ice ? 0.015 : (form == .water ? 0.3 : 0.48),form == .water ? 0.06 : 0.035)
        if !old.grounded && cube.grounded && old.velocity.y < -1.5 {
            let hardness:Float=surface == .grass ? 0.65 : (surface == .wood ? 0.8 : 1)
            impact=min(1,abs(old.velocity.y)/11)*hardness;landingAge=0
            record(.landed(impact:impact,surface:surface));squash=form == .stone ? 0 : min(0.42,abs(old.velocity.y)*0.035*hardness)
            if abs(old.velocity.y)>12 { damage((abs(old.velocity.y)-12)*hardness*2);record(.hurt) }
            emit(Vec(cube.position.x,cube.position.y-0.56),kind:surface == .ice ? 2 : 0,count:impact>0.65 ? 18 : 7)
            mood=impact>0.7 ? .startled : .delighted;emotionTime=0.8
        }
        if form.hasFur && cube.grounded && wetness>0.4 && abs(movement)<0.1 && abs(cube.velocity.x)<0.4 && shakeCooldown<=0 {
            shakeTime=0.75;shakeCooldown=6;emit(cube.position,kind:1,count:30);wetness=max(0,wetness-0.15)
        }
        if abs(cube.velocity.x)<0.2 && abs(cube.velocity.y)<0.2 && cube.grounded { idleTime+=dt } else { idleTime=0 }
        if emotionTime<=0 { mood=dead ? .sleepy : (health<25 || (inWater && form == .fire) ? .displeased : (idleTime>8 ? .sleepy : (cube.velocity.y < -5 ? .startled : .curious))) }
        squash*=exp(-dt*11)
        if let b=buffer { buffer=b.1>dt ? (b.0,b.1-dt) : nil;if cube.grounded && cooldown<=0 { _=jump(b.0,buffered:false) } }
        updateMaterials(dt:dt)
        for i in 1..<wave.count-1 { waveSpeed[i]+=(wave[i-1]+wave[i+1]-2*wave[i])*dt*100;waveSpeed[i]-=wave[i]*dt*12;waveSpeed[i]*=exp(-dt*1.4) }
        for i in 1..<wave.count-1 { wave[i]+=waveSpeed[i]*dt }
        if !dead {
            for i in shards.indices where !collected.contains(i) {
                let p=shards[i],d=cube.position
                if hypot(p.x-d.x,p.y-d.y)<1 { collected.insert(i);emit(p,kind:3,count:24);mood = .delighted;emotionTime=1.8;record(.collectedCrystal) }
            }
            if form == .stone && hypot(cube.position.x-12,cube.position.y+3.3)<0.7 && !deepRelic { deepRelic=true;emit(Vec(12,-3.3),kind:3,count:40);record(.collectedCrystal) }
            if cube.position.x>22.4 && cube.grounded && !won { won=true;emit(Vec(23,2),kind:3,count:55);record(.finished) }
        }
        if cube.position.y < -5.2 || !cube.position.x.isFinite { respawns+=1;resetCube() }
        for i in particles.indices {
            particles[i].life-=dt;particles[i].position.x+=particles[i].velocity.x*dt;particles[i].position.y+=particles[i].velocity.y*dt
            particles[i].velocity.y+=dt*(particles[i].kind>=4 ? 1.5 : -4)
        }
        particles.removeAll { $0.life<=0 };if particles.count>550 { particles.removeFirst(particles.count-550) }
        if ticks%2==0 { updateFur() }
    }
    private func updateMaterials(dt:Float) {
        let cold=passiveWorking && form == .ice,fire=passiveWorking && form == .fire
        for i in frostMarks.indices {
            let p=frostMarks[i].position,touch=abs(p.x-cube.position.x)<0.9 && abs(p.y-cube.position.y)<0.9
            frostMarks[i].cold=max(0,min(1,frostMarks[i].cold+dt*(touch && cold ? 0.9 : (touch && fire ? -2 : -1/30))))
        }
        if form == .fire && inWater && !dead {
            let fraction=immersion(cube,size:1.12)
            damage(dt*(fire ? 2.4 : 12)*max(0.35,fraction))
        }
        // Heat also reaches a shallow film below the body, so the last centimetres
        // do not remain forever once the rigid body rests on the floor.
        if fire && !dead && waterEnabled && cube.position.x>7 && cube.position.x<17 && (inWater || abs(cube.position.y-waterLevel)<1.25) {
            _=waterField.evaporate(around:cube.position,amount:dt*1.9)
        }
        for i in patches.indices {
            let contact=abs(patches[i].x-cube.position.x)<1 && abs(cube.position.y-0.56)<0.7
            let onBank=patches[i].x<7 || patches[i].x>17
            patches[i].frost=max(0,min(1,patches[i].frost+dt*(cold && contact ? 0.9 : (fire && contact ? -2 : -1/30))))
            if fire && contact && onBank && patches[i].fuel>0 { patches[i].burning=1 }
            if patches[i].burning>0 {
                patches[i].fuel=max(0,patches[i].fuel-dt*0.22)
                if patches[i].fuel<=0 { patches[i].burning=0 }
            }
        }
        if crateExists {
            let contact=hypot(crate.position.x-cube.position.x,crate.position.y-cube.position.y)<1.65
            crateFrost=max(0,min(1,crateFrost+dt*(cold && contact ? 1 : (fire && contact ? -2 : -1/30))))
            ec_material(world,crateID,crateFrost>0.5 ? 0.015 : 0.48,0.035)
            if fire && contact && immersion(crate,size:1.25)<0.1 { crateBurning=1 }
            if immersion(crate,size:1.25)>0.2 { crateBurning=0 }
            if crateBurning>0 { crateFuel=max(0,crateFuel-dt*0.14) }
            if crateFuel<=0 { ec_remove(world,crateID);crateExists=false;crateBurning=0;emit(crate.position,kind:5,count:28) }
        }
        materialClock+=dt;particleClock+=dt
        if materialClock>=0.1 {
            // Retained water adds mass and rotational inertia to furry forms.
            if form.hasFur { ec_density(world,cubeID,form.density*(1+wetness*0.16)) }
            let oldCount=iceIDs.count
            waterField.step(dt:materialClock,coldSource:cold && waterEnabled ? cube.position : nil,heatSource:fire ? cube.position : nil,occupied:crateExists ? [cube.position,crate.position] : [cube.position])
            materialClock=0
            for (i,id) in Array(iceIDs) where !waterEnabled || !waterField.ice[i].solid { ec_remove(world,id);iceIDs.removeValue(forKey:i) }
            for i in waterField.ice.indices where waterEnabled && waterField.ice[i].solid && iceIDs[i]==nil {
                let cell=waterField.ice[i]
                guard ec_space_clear(world,cell.center.x,cell.center.y,cell.size-0.01,cell.size-0.01) else { waterField.deferSolid(at:i);continue }
                let id=ec_box(world,cell.center.x,cell.center.y,cell.size,cell.size,0,false,true)
                if id>=0 { ec_material(world,id,0.015,0.02);iceIDs[i]=id }
            }
            if oldCount==0 && !iceIDs.isEmpty { record(.frozeWater) }
            // A cold contact changes the actual body's friction as well as its appearance.
            for (i,id) in platformIDs.enumerated() {
                let p=platforms[i]
                let frosted=patches.contains { $0.frost>0.5 && abs($0.x-p.x)<p.width/2 && abs(cube.position.x-$0.x)<1 }
                ec_material(world,id,frosted ? 0.015 : (i<2 ? 0.85 : 0.62),i<2 ? 0.02 : 0.1)
            }
        }
        if particleClock>0.1 {
            particleClock=0
            if form == .fire && !dead { emit(cube.position,kind:4,count:fire ? 4 : 1);if inWater { emit(Vec(cube.position.x,waterLevel),kind:5,count:5) } }
            for patch in patches where patch.burning>0 { emit(Vec(patch.x,0.15),kind:4,count:1) }
            if crateBurning>0 { emit(crate.position,kind:4,count:3) }
            if cold && inWater { emit(cube.position,kind:2,count:2) }
        }
    }
    private func updateFur() {
        fur.step(dt:1/60,center:SIMD3(cube.position.x,cube.position.y,0.55),angle:bodyAngle,stretch:bodyStretch,
                 wind:windVelocity,water:{ self.waterEnabled && self.waterField.contains($0) },solid:{ p in
            self.platforms.contains { abs(p.x-$0.x)<$0.width/2 && abs(p.y-$0.y)<$0.height/2 } || (p.x>7 && p.x<17 && p.y<self.waterField.floor(at:p.x))
        })
    }
    public func disturb(_ x:Float,amount:Float) { let i=max(1,min(wave.count-2,Int((x-7)/10*80)));waveSpeed[i]-=amount*6;waveSpeed[i-1]-=amount*3;waveSpeed[i+1]-=amount*3 }
    private func random()->Float { randomSeed=randomSeed &* 6364136223846793005 &+ 1;return Float((randomSeed>>32)&0xffff)/65535 }
    private func emit(_ p:Vec,kind:Int,count:Int) {
        for _ in 0..<count { particles.append(Mote(position:p,velocity:Vec((random()-0.5)*(kind>=4 ? 1.2 : 5),random()*4+0.5),life:0.45+random()*0.65,kind:kind)) }
    }
}
