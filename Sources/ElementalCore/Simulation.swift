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
    public let surface:Surface,boundary:Bool
    public init(_ x:Float,_ y:Float,_ width:Float,_ height:Float,surface:Surface = .stone,boundary:Bool=false) { self.x=x;self.y=y;self.width=width;self.height=height;self.surface=surface;self.boundary=boundary }
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
    public private(set) var bridge:[BridgeSection]=[]
    public let bridgeAnchors=[Vec(6.7,-0.005),Vec(17.3,-0.005)]
    public var fireSources:[FireSource]=WorldLayout.campfires.map { FireSource($0,radius:0.95) }
    public private(set) var burning:Float=0
    private var ignitionHeat:Float=0,burnTime:Float=0,burnFeedbackClock:Float=0
    public private(set) var crateExists=true
    public private(set) var crateFuel:Float=1
    public private(set) var crateFrost:Float=0
    public private(set) var crateBurning:Float=0
    public private(set) var patches:[MaterialPatch]
    public private(set) var frostMarks:[FrostMark]=[]
    public private(set) var time:Float=0,wetness:Float=0,health:Float=100,mana:Float=100
    public private(set) var passiveEquipped=true
    public private(set) var passiveWorking=true
    public var energy:Float { mana }
    public var dead:Bool { health<=0 }
    public var iceCells:[IceCell] { waterField.ice.filter { $0.solid } }
    public private(set) var mood:Mood = .curious
    public private(set) var impact:Float=0,landingAge:Float=10,idleTime:Float=0,shakeTime:Float=0,squash:Float=0
    public private(set) var surface:Surface = .grass
    public private(set) var jumps=0,respawns=0,won=false,deepRelic=false
    public private(set) var collected:Set<Int>=[]
    public private(set) var particles:[Mote]=[]
    public let shards=WorldLayout.shards
    public var jumpSkill:JumpSkill
    private var world:OpaquePointer
    private var cubeID:Int32=0,crateID:Int32=0
    private var platformIDs:[Int32]=[]
    private var bridgeIDs:[Int32]=[]
    private var bridgeWidths:[Float]=[]
    private var iceIDs:[Int:Int32]=[:]
    private var iceShapes:[Int:IceCell]=[:]
    private var emotionTime:Float=0,shakeCooldown:Float=0,cooldown:Float=0,materialClock:Float=0,particleClock:Float=0
    private var buffer:(Vec,Float)?
    private var randomSeed:UInt64=8251
    private var feedback:[SimulationFeedback]=[]
    private var ticks=0
    public private(set) var directionalJumpUnlocked=false,doubleJumpUnlocked=false
    private var airJumpUsed=false
    public private(set) var airControlMultiplier:Float=1
    private var lastSupportTime:Float = -10
    public var gravity:Float=18 { didSet { ec_gravity(world,gravity) } }
    public var waterEnabled=true
    public var manaCostMultiplier:Float=1,landingDamageMultiplier:Float=1,fireDamageMultiplier:Float=1
    public func applySkills(of monster:MonsterRecord) {
        guard monster.form==form else { return }
        directionalJumpUnlocked=monster.learned.contains(.jump);doubleJumpUnlocked=monster.learned.contains(.doubleJump);airControlMultiplier=monster.airControlMultiplier
        jumpSkill=monster.jumpSkill;waterField.conductivity=monster.conductivity
        manaCostMultiplier=monster.manaMultiplier;landingDamageMultiplier=monster.landingDamageMultiplier;fireDamageMultiplier=monster.fireDamageMultiplier
    }
    public var jumpScale:Float=1,movement:Float=0,wind:Float=1
    public let waterLeft:Float=7,waterRight:Float=17
    public var waterLevel:Float { waterField.surface(at:cube.position.x) }
    public var inWater:Bool { waterEnabled && immersion(cube,size:1.12)>0.02 }
    private var hasJumpSupport:Bool { cube.grounded || time-lastSupportTime<0.1 || inWater || (form == .air && passiveWorking && hovering) }
    public var canLaunch:Bool { !dead && cooldown<=0 && (hasJumpSupport || (doubleJumpUnlocked && !airJumpUsed)) }
    public var nextJumpIsAirJump:Bool { !hasJumpSupport }
    public var nextJumpManaCost:Float { (nextJumpIsAirJump ? 10 : 6)*manaCostMultiplier }
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
        self.form=form;jumpSkill=JumpSkill.initial(for:form);fur=FurPhysics(form:form)
        platforms=WorldLayout.platforms
        waterField=WaterField(platforms:platforms)
        patches=(-6..<50).map { MaterialPatch(x:Float($0)*0.5+0.25) }
        for p in WorldLayout.terrain where p.surface == .grass && p.x+p.width/2<=(-3) {
            let count=Int(p.width/0.5)
            for i in 0..<count { patches.append(MaterialPatch(x:p.x-p.width/2+(Float(i)+0.5)*0.5,y:p.y+p.height/2)) }
        }
        for p in platforms where !p.boundary {
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
        let points=(0...6).map { i -> Vec in
            let t=Float(i)/6;return Vec(10.1+3.8*t,-0.2-sin(t*Float.pi)*0.12)
        }
        for i in 0..<6 {
            let a=points[i],b=points[i+1],width=hypot(b.x-a.x,b.y-a.y)
            let id=ec_box(world,(a.x+b.x)/2,(a.y+b.y)/2,width,0.18,0.62,true,false)
            ec_rotate(world,id,atan2(b.y-a.y,b.x-a.x));ec_material(world,id,0.72,0.03)
            bridgeIDs.append(id);bridgeWidths.append(width)
            if i>0 { ec_hinge(world,bridgeIDs[i-1],id,a.x,a.y) }
        }
        ec_rope(world,platformIDs[5],bridgeIDs[0],bridgeAnchors[0].x,bridgeAnchors[0].y,points[0].x,points[0].y)
        ec_rope(world,platformIDs[6],bridgeIDs[5],bridgeAnchors[1].x,bridgeAnchors[1].y,points[6].x,points[6].y)
        if form == .air { ec_material(world,cubeID,0.015,0.02) }
        if form == .water { ec_material(world,cubeID,0.3,0.06) }
        sync();updateFur()
    }
    deinit { ec_destroy(world) }
    /// Skill-loadout assignment. There is deliberately no gameplay-screen toggle.
    public func equipPassive(_ enabled:Bool) { passiveEquipped=enabled;passiveWorking=enabled && !dead }
    public func takeFeedback()->[SimulationFeedback] { let events=feedback;feedback.removeAll(keepingCapacity:true);return events }
    private func record(_ event:SimulationFeedback) { if feedback.count>=16 { feedback.removeFirst() };feedback.append(event) }
    private func state(_ id:Int32)->BodyState {
        let s=ec_state(world,id)
        return BodyState(position:Vec(s.x,s.y),velocity:Vec(s.vx,s.vy),angle:s.angle,mass:s.mass,angularVelocity:s.omega,grounded:s.grounded)
    }
    private func sync() {
        cube=state(cubeID);if crateExists { crate=state(crateID) }
        bridge=bridgeIDs.enumerated().map { BridgeSection(state:state($0.element),width:bridgeWidths[$0.offset]) }
    }
    public var fluidBodies:[FluidBody] {
        func body(_ id:Int32,_ s:BodyState,_ w:Float,_ h:Float)->FluidBody {
            FluidBody(id:Int(id),center:s.position,velocity:s.velocity,angle:s.angle,omega:s.angularVelocity,width:w,height:h,mass:s.mass,rotates:id != cubeID || form != .air)
        }
        var result=[body(cubeID,cube,1.12,1.12)]
        if crateExists { result.append(body(crateID,crate,1.25,1.25)) }
        for (i,section) in bridge.enumerated() { result.append(body(bridgeIDs[i],section.state,section.width,section.height)) }
        return result
    }
    public func intersectsSolid(at position:Vec)->Bool { ec_blocked(world,cubeID,position.x,position.y) }
    public func supportHeight(at x:Float)->Float {
        var height=WorldLayout.floorHeight
        if x>7 && x<17 { height=waterEnabled && waterField.volume>0.01 ? max(waterField.floor(at:x),waterField.surface(at:x)) : waterField.floor(at:x) }
        for p in platforms where !p.boundary && abs(p.x-x)<p.width/2 && cube.position.y>p.y+p.height/2-0.1 { height=max(height,p.y+p.height/2) }
        for section in bridge where abs(section.state.position.x-x)<section.width/2+0.08 && cube.position.y>section.state.position.y { height=max(height,section.state.position.y+section.height/2) }
        return height
    }
    private func immersion(_ s:BodyState,size:Float)->Float {
        guard s.position.x>7-size/3 && s.position.x<17+size/3 else { return 0 }
        guard waterField.volume>0.0001 else { return 0 }
        let body=FluidBody(id:0,center:s.position,angle:s.angle,width:size,height:size)
        var wet:Float=0
        for i in 0..<5 { for j in 0..<5 {
            let p=body.world(Vec((Float(i)+0.5)/5*size-size/2,(Float(j)+0.5)/5*size-size/2))
            if waterField.contains(p) { wet+=1/25 }
        } }
        return wet
    }
    public func launchVelocity(for request:Vec)->Vec {
        guard request.x.isFinite,request.y.isFinite else { return cube.velocity }
        let length=hypot(request.x,request.y),scaled=length*max(0,jumpScale)
        let factor=length>0 ? min(jumpSkill.maximumSpeed,scaled)/length : 0
        let impulse=Vec(request.x*factor,request.y*factor)
        if inWater && !cube.grounded && form != .stone {
            let speed=hypot(impulse.x,impulse.y)*1.2
            let gain=speed>0 ? min(jumpSkill.strokeMaximumSpeed,speed)/max(0.0001,length*factor) : 0
            return Vec(cube.velocity.x+impulse.x*gain,cube.velocity.y+impulse.y*gain-min(0,cube.velocity.y))
        }
        let weight:Float=form == .stone && inWater ? 0.45 : 1-wetness*0.1
        return Vec(cube.velocity.x+impulse.x,cube.velocity.y+impulse.y*weight)
    }
    /// Player-facing action gate. A basic jump is free; learned techniques use mana.
    @discardableResult public func performJump(_ request:Vec=Vec(0,7.2),directed:Bool=false)->Bool {
        guard !directed || directionalJumpUnlocked else { return false }
        let cost:Float=nextJumpIsAirJump ? 10*manaCostMultiplier : (directed ? 6*manaCostMultiplier : 0)
        guard canLaunch,mana+0.0001>=cost else { return false }
        guard jump(directed ? request : Vec(0,7.2),buffered:false) else { return false }
        mana=max(0,mana-cost);return true
    }
    /// Physical launch primitive; gesture input must use performJump for skill/cost checks.
    @discardableResult public func jump(_ request:Vec,buffered:Bool=true)->Bool {
        guard request.x.isFinite,request.y.isFinite,!dead else { return false }
        guard canLaunch else { if buffered { buffer=(request,0.12) };return false }
        let swimming=inWater && !cube.grounded
        if swimming && form == .stone { return false }
        if !hasJumpSupport { airJumpUsed=true }
        let velocity=launchVelocity(for:request)
        ec_impulse(world,cubeID,velocity.x-cube.velocity.x,velocity.y-cube.velocity.y)
        lastSupportTime = -10;cooldown=swimming ? 0.4 : 0.16
        if swimming { waterField.liquid.addFoam(at:Vec(cube.position.x,waterLevel),strength:0.8) }
        squash = form == .stone ? 0 : -0.28;jumps+=1;buffer=nil;mood = .focused;emotionTime=0.3
        record(.jumped);emit(cube.position,kind:0,count:12);sync();return true
    }
    public func resetCube() { ec_teleport(world,cubeID,2.7,0.75);wetness=0;cooldown=0;buffer=nil;airJumpUsed=false;burning=0;burnTime=0;ignitionHeat=0;won=false;health=100;mana=100;sync();updateFur() }
    public func placeCube(_ p:Vec) { guard p.x.isFinite,p.y.isFinite else { return };ec_teleport(world,cubeID,p.x,p.y);lastSupportTime = -10;sync();updateFur() }
    public func placeCrate(_ p:Vec,angle:Float=0,velocity:Vec=Vec(0,0),omega:Float=0) {
        guard crateExists,p.x.isFinite,p.y.isFinite,angle.isFinite else { return }
        ec_teleport(world,crateID,p.x,p.y);ec_rotate(world,crateID,angle);ec_velocity(world,crateID,velocity.x,velocity.y,omega);sync()
    }
    public func damage(_ amount:Float) {
        guard amount.isFinite,amount>0,!dead else { return }
        health=max(0,health-amount)
        if dead { movement=0;passiveWorking=false;mood = .sleepy;record(.died) }
    }
    public func step() {
        let dt=Self.timestep;time+=dt;ticks+=1;cooldown=max(0,cooldown-dt)
        let old=cube!,wasInWater=inWater
        passiveWorking=passiveEquipped && !dead
        mana=min(100,mana+dt*4)
        if waterEnabled {
            waterField.advanceFluid(dt:dt,gravity:gravity,bodies:fluidBodies)
            if passiveEquipped && !dead && form == .ice {
                let foot=fluidBodies[0].corners.map(\.y).min()!,level=waterLevel
                if cube.position.x>7 && cube.position.x<17 && foot>level-0.12 && foot+min(0,cube.velocity.y)*dt<level+0.035 && level>waterField.floor(at:cube.position.x)+0.05 {
                    waterField.freezeContact(at:cube.position.x,bottom:foot);syncIceColliders()
                }
            }
        }
        landingAge+=dt;impact*=exp(-dt*7);emotionTime=max(0,emotionTime-dt)
        shakeTime=max(0,shakeTime-dt);shakeCooldown=max(0,shakeCooldown-dt)
        if !dead {
            if form == .air {
                ec_drive(world,cubeID,movement,0.85*airControlMultiplier,true)
                ec_force(world,cubeID,windVelocity*cube.mass*0.5,0)
                if passiveWorking && cooldown<=0 {
                    let height=max(supportHeight(at:cube.position.x),supportHeight(at:cube.position.x+movement*0.9))
                    let gap=cube.position.y-height-0.76
                    if gap<0.8 && cube.velocity.y<2 {
                        let lift=max(0,min(gravity*3*airControlMultiplier,gravity-gap*75*airControlMultiplier-cube.velocity.y*12))
                        ec_force(world,cubeID,0,cube.mass*lift)
                    }
                }
            } else if cube.grounded {
                ec_drive(world,cubeID,movement,surface == .ice ? 0.55 : (form == .stone && passiveWorking ? 1.6 : 1),false)
            } else if inWater {
                // Stone keeps its rolling motor in water: loss of a floor contact
                // for one step must not turn a heavy walker into a weak swimmer.
                ec_drive(world,cubeID,movement,form == .stone ? (passiveWorking ? 1.6 : 1) : 0.85,form != .stone)
            }
        }
        if waterEnabled { applyLiquidForces(dt:dt) }
        if form != .air { ec_force(world,cubeID,windVelocity*cube.mass*0.035,0) }
        ec_step(world,dt);sync();if cube.grounded { lastSupportTime=time;if cooldown<=0 && cube.velocity.y<0.3 { airJumpUsed=false } };if inWater { airJumpUsed=false }
        wetness=inWater ? min(1,wetness+dt*2) : max(0,wetness-dt*0.065)
        if form == .fire { wetness=0 }
        if !wasInWater && inWater {
            waterField.liquid.addFoam(at:Vec(cube.position.x,waterLevel),strength:min(1,abs(old.velocity.y)*0.1))
            record(.enteredWater(strength:min(1,abs(old.velocity.y)/10)));mood = .displeased;emotionTime=3
        }
        if cube.grounded {
            if iceCells.contains(where:{ abs($0.center.x-cube.position.x)<0.8 && abs($0.center.y-(cube.position.y-0.56))<0.35 }) { surface = .ice }
            else if crateExists && abs(cube.position.x-crate.position.x)<1.15 && cube.position.y>crate.position.y+0.75 { surface = crateFrost>0.5 ? .ice : .wood }
            else if bridge.contains(where:{ abs($0.state.position.x-cube.position.x)<$0.width/2+0.3 && abs(cube.position.y-$0.state.position.y-0.65)<0.35 }) { surface = .wood }
            else {
                let patch=patches.min(by:{ hypot($0.x-cube.position.x,$0.y-cube.position.y+0.56)<hypot($1.x-cube.position.x,$1.y-cube.position.y+0.56) })
                let frosted=frostMarks.contains { $0.cold>0.5 && abs($0.position.x-cube.position.x)<0.75 && abs($0.position.y-(cube.position.y-0.56))<0.2 }
                let support=platforms.filter { !$0.boundary && abs($0.x-cube.position.x)<$0.width/2+0.5 && abs($0.y+$0.height/2-(cube.position.y-0.56))<0.55 }.min { abs($0.y+$0.height/2-(cube.position.y-0.56))<abs($1.y+$1.height/2-(cube.position.y-0.56)) }
                surface=(patch?.frost ?? 0)>0.5 || frosted ? .ice : (support?.surface ?? .stone)
            }
        } else if inWater { surface = .water }
        ec_material(world,cubeID,form == .air || surface == .ice ? 0.015 : (form == .water ? 0.3 : 0.48),form == .water ? 0.06 : 0.035)
        if !old.grounded && cube.grounded && old.velocity.y < -1.5 {
            let hardness:Float=surface == .grass ? 0.65 : (surface == .wood ? 0.8 : 1)
            impact=min(1,abs(old.velocity.y)/11)*hardness;landingAge=0
            record(.landed(impact:impact,surface:surface));squash=form == .stone ? 0 : min(0.42,abs(old.velocity.y)*0.035*hardness)
            if abs(old.velocity.y)>12 { damage((abs(old.velocity.y)-12)*hardness*2*landingDamageMultiplier);record(.hurt) }
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
        updateBurning(dt:dt)
        updateMaterials(dt:dt)
        if !dead {
            for i in shards.indices where !collected.contains(i) {
                let p=shards[i],d=cube.position
                if hypot(p.x-d.x,p.y-d.y)<1 { collected.insert(i);emit(p,kind:3,count:24);mood = .delighted;emotionTime=1.8;record(.collectedCrystal) }
            }
            if form == .stone && hypot(cube.position.x-12,cube.position.y+3.3)<0.7 && !deepRelic { deepRelic=true;emit(Vec(12,-3.3),kind:3,count:40);record(.collectedCrystal) }
            if hypot(cube.position.x-WorldLayout.goal.x,cube.position.y-WorldLayout.goal.y-0.56)<1.1 && cube.grounded && !won { won=true;emit(Vec(WorldLayout.goal.x,WorldLayout.goal.y+2),kind:3,count:55);record(.finished) }
        }
        if cube.position.y < WorldLayout.bounds.minY-2 || !cube.position.x.isFinite { respawns+=1;resetCube() }
        for i in particles.indices {
            particles[i].life-=dt;particles[i].position.x+=particles[i].velocity.x*dt;particles[i].position.y+=particles[i].velocity.y*dt
            particles[i].velocity.y+=dt*(particles[i].kind>=4 ? 1.5 : (particles[i].kind==1 ? -gravity : -4))
            if particles[i].kind==1 {
                let p=particles[i].position
                if p.x>7 && p.x<17 && p.y<=waterField.surface(at:p.x) && particles[i].velocity.y<0 {
                    waterField.liquid.addFoam(at:p,strength:0.2);particles[i].life=0
                } else if waterField.solid(at:p) || platforms.contains(where:{ !$0.boundary && abs(p.x-$0.x)<$0.width/2 && abs(p.y-$0.y)<$0.height/2 }) { particles[i].life=0 }
            }
        }
        particles.removeAll { $0.life<=0 };if particles.count>550 { particles.removeFirst(particles.count-550) }
        if ticks%2==0 { updateFur() }
    }
    private func updateBurning(dt:Float) {
        guard !form.fireImmune else { burning=0;burnTime=0;ignitionHeat=0;return }
        let fraction=inWater ? immersion(cube,size:1.12) : 0
        if fraction>0.12 {
            ignitionHeat=0;burnTime=max(0,burnTime-dt*24*fraction)
            burning=max(0,burning-dt*7*fraction)
            if fraction>0.5 { burning=0;burnTime=0 }
            return
        }
        var exposure:Float=0
        for source in fireSources {
            exposure=max(exposure,source.intensity*max(0,1-hypot(cube.position.x-source.position.x,cube.position.y-source.position.y)/max(0.1,source.radius)))
        }
        for patch in patches where patch.burning>0 {
            exposure=max(exposure,max(0,1-hypot(cube.position.x-patch.x,cube.position.y-patch.y-0.2)/0.95))
        }
        if crateExists && crateBurning>0 { exposure=max(exposure,max(0,1-hypot(cube.position.x-crate.position.x,cube.position.y-crate.position.y)/1.5)) }
        ignitionHeat=max(0,ignitionHeat+dt*(exposure*(1-wetness*0.9)-0.12))
        if ignitionHeat>0.35 { burnTime=5;burning=min(1,burning+dt*2) }
        else if burning>0 { burnTime=max(0,burnTime-dt);burning=max(0,burning-dt*(burnTime>0 ? 0.06 : 1.5)) }
        if exposure<0.05 { ignitionHeat=max(0,ignitionHeat-dt*0.7) }
        if burning>0 && !dead {
            damage(dt*5*burning);wetness=max(0,wetness-dt*0.18*burning)
            mood = .displeased;emotionTime=0.5;burnFeedbackClock-=dt
            if burnFeedbackClock<=0 { record(.hurt);burnFeedbackClock=1 }
        }
    }
    private func updateMaterials(dt:Float) {
        let cold=passiveWorking && form == .ice,fire=(passiveWorking && form == .fire) || burning>0.35
        for i in frostMarks.indices {
            let p=frostMarks[i].position,touch=abs(p.x-cube.position.x)<0.9 && abs(p.y-cube.position.y)<0.9
            frostMarks[i].cold=max(0,min(1,frostMarks[i].cold+dt*(touch && cold ? 0.9 : (touch && fire ? -2 : -1/30))))
        }
        if form == .fire && inWater && !dead {
            let fraction=immersion(cube,size:1.12)
            damage(dt*(fire ? 2.4*fireDamageMultiplier : 12)*max(0.35,fraction))
        }
        // Heat also reaches a shallow film below the body, so the last centimetres
        // do not remain forever once the rigid body rests on the floor.
        if fire && !dead && waterEnabled && cube.position.x>7 && cube.position.x<17 && (inWater || abs(cube.position.y-waterLevel)<1.25) {
            _=waterField.evaporate(around:cube.position,amount:dt*1.9)
        }
        for i in patches.indices {
            let contact=abs(patches[i].x-cube.position.x)<1 && abs(cube.position.y-0.56-patches[i].y)<0.7
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
            if (fire && contact || fireSources.contains(where:{ hypot($0.position.x-crate.position.x,$0.position.y-crate.position.y)<$0.radius+0.4 })) && immersion(crate,size:1.25)<0.1 { crateBurning=1 }
            if immersion(crate,size:1.25)>0.2 { crateBurning=0 }
            if crateBurning>0 { crateFuel=max(0,crateFuel-dt*0.14) }
            if crateFuel<=0 { ec_remove(world,crateID);crateExists=false;crateBurning=0;emit(crate.position,kind:5,count:28) }
        }
        materialClock+=dt;particleClock+=dt
        if materialClock>=1/30 {
            // Retained water adds mass and rotational inertia to furry forms.
            if form.hasFur { ec_density(world,cubeID,form.density*(1+wetness*0.16)) }
            waterField.step(dt:materialClock,coldSource:cold && waterEnabled ? cube.position : nil,heatSource:fire ? cube.position : nil,occupied:crateExists ? [cube.position,crate.position] : [cube.position],coldFoot:fluidBodies[0].corners.map(\.y).min())
            materialClock=0
            syncIceColliders()
            // A cold contact changes the actual body's friction as well as its appearance.
            for (i,id) in platformIDs.enumerated() {
                let p=platforms[i]
                let frosted=patches.contains { $0.frost>0.5 && abs($0.x-p.x)<p.width/2 && abs(cube.position.x-$0.x)<1 }
                ec_material(world,id,frosted ? 0.015 : (i<2 ? 0.85 : 0.62),i<2 ? 0.02 : 0.1)
            }
        }
        if particleClock>0.1 {
            particleClock=0
            if (form == .fire || burning>0) && !dead { emit(cube.position,kind:4,count:fire ? 4 : 1);if inWater { emit(Vec(cube.position.x,waterLevel),kind:5,count:5) } }
            for patch in patches where patch.burning>0 { emit(Vec(patch.x,patch.y+0.15),kind:4,count:1) }
            if crateBurning>0 { emit(crate.position,kind:4,count:3) }
            if cold && inWater { emit(cube.position,kind:2,count:2) }
        }
    }
    private func syncIceColliders() {
        let oldCount=iceIDs.count
        for (i,id) in Array(iceIDs) where !waterEnabled || !waterField.ice[i].solid { ec_remove(world,id);iceIDs.removeValue(forKey:i);iceShapes.removeValue(forKey:i) }
        for i in waterField.ice.indices where waterEnabled && waterField.ice[i].solid && iceIDs[i]==nil {
            let cell=waterField.ice[i]
            guard ec_space_clear(world,cell.center.x,cell.center.y,cell.size-0.012,max(0.002,cell.height-0.012)) else { waterField.deferSolid(at:i);continue }
            let id=ec_box(world,cell.center.x,cell.center.y,cell.size,cell.height,0,false,true)
            if id>=0 { ec_material(world,id,0.015,0.02);iceIDs[i]=id;iceShapes[i]=cell }
        }
        for (i,id) in iceIDs where iceShapes[i]?.center != waterField.ice[i].center || iceShapes[i]?.height != waterField.ice[i].height || iceShapes[i]?.size != waterField.ice[i].size {
            let c=waterField.ice[i]
            if ec_space_clear_ignoring(world,id,c.center.x,c.center.y,max(0.002,c.size-0.012),max(0.002,c.height-0.012)) {
                ec_resize_static(world,id,c.center.x,c.center.y,c.size,c.height);iceShapes[i]=c
            } else if let old=iceShapes[i] { waterField.restoreShape(at:i,to:old) }
        }
        if oldCount==0 && !iceIDs.isEmpty { record(.frozeWater) }
    }
    private func applyLiquidForces(dt:Float) {
        guard waterField.volume>0.0001 else { return }
        for body in fluidBodies {
            guard body.center.x+body.width>7,body.center.x-body.width<17 else { continue }
            let mass=body.mass
            if let load=waterField.liquid.pressureLoads[body.id] {
                ec_force(world,Int32(body.id),mass*load.velocity.x/dt,mass*load.velocity.y/dt)
                ec_torque(world,Int32(body.id),body.inertia*load.omega/dt)
            }
            let coefficient:Float=body.id==Int(cubeID) && form == .water && passiveWorking ? 5 : 14
            let drag=waterField.liquid.dragLoad(on:body,mass:mass,dt:dt,coefficient:coefficient)
            ec_force(world,Int32(body.id),drag.force.x,drag.force.y);ec_torque(world,Int32(body.id),drag.torque)
        }
    }
    private func updateFur() {
        let obstacles=Array(fluidBodies.dropFirst())+waterField.frozenBodies
        let nearby=platforms.filter { abs($0.x-cube.position.x)<$0.width/2+2 && abs($0.y-cube.position.y)<$0.height/2+2 }
        fur.step(dt:1/60,center:SIMD3(cube.position.x,cube.position.y,0.55),angle:bodyAngle,stretch:bodyStretch,
                 wind:windVelocity,water:{ self.waterEnabled && self.waterField.contains($0) },solid:{ p in
            nearby.contains { abs(p.x-$0.x)<$0.width/2 && abs(p.y-$0.y)<$0.height/2 } || (p.x>7 && p.x<17 && p.y<self.waterField.floor(at:p.x)) || obstacles.contains { $0.contains(p) }
        })
    }
    public func disturb(_ x:Float,amount:Float) { waterField.liquid.addImpulse(at:Vec(x,waterField.surface(at:x)-0.15),impulse:Vec(0,-amount*0.1),radius:0.8) }
    private func random()->Float { randomSeed=randomSeed &* 6364136223846793005 &+ 1;return Float((randomSeed>>32)&0xffff)/65535 }
    private func emit(_ p:Vec,kind:Int,count:Int) {
        for _ in 0..<count { particles.append(Mote(position:p,velocity:Vec((random()-0.5)*(kind>=4 ? 1.2 : 5),random()*4+0.5),life:0.45+random()*0.65,kind:kind)) }
    }
}
