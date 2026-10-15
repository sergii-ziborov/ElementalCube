import Foundation

public struct LiquidParticle {
    public var position:Vec
    public var velocity:Vec
    public var volume:Float
    public var isSpray=false
    public var sprayAge:Float=0
}
public struct SurfaceFoam {
    public var position:Vec
    public var life:Float
    public var strength:Float
}

/// Incompressible free-surface PIC/FLIP fluid on a staggered MAC grid.
/// Markers carry mass and momentum, a pressure projection removes divergence,
/// and moving oriented Box2D rectangles prescribe boundary velocities.
public final class LiquidSolver {
    public let spacing:Float=0.15625
    public let nx=66,ny=46
    public let origin=Vec(6.84375,-4.15625)
    public private(set) var particles:[LiquidParticle]=[]
    public private(set) var density:[Float]
    public private(set) var surface:[Float]
    public private(set) var pressure:[Float]
    private var u:[Float],v:[Float],oldU:[Float],oldV:[Float],weightU:[Float],weightV:[Float]
    private var kind:[UInt8],solidVelocity:[Vec],counts:[Float],heads:[Int],next:[Int]=[]
    private var particleDensity:[Float]
    private var owner:[Int]
    public private(set) var pressureLoads:[Int:(velocity:Vec,omega:Float)]=[:]
    private let platforms:[Platform]
    private var bodies:[FluidBody]=[]
    public private(set) var foam:[SurfaceFoam]=[]
    private var splashCooldown:[Int:Float]=[:]
    private var foamClock:Float=0
    private var stepNumber=0
    public var markerVolume:Float { spacing*spacing/4 }
    public init(platforms:[Platform]) {
        self.platforms=platforms.filter { $0.x+$0.width/2>6.8 && $0.x-$0.width/2<17.2 && $0.y-$0.height/2<3 && $0.y+$0.height/2 > -4.2 }
        let n=66*46
        u=Array(repeating:0,count:n);v=u;oldU=u;oldV=u;weightU=u;weightV=u;pressure=u;counts=u;density=u
        particleDensity=u;owner=Array(repeating:-1,count:n)
        kind=Array(repeating:1,count:n);solidVelocity=Array(repeating:Vec(0,0),count:n);heads=Array(repeating:-1,count:n)
        surface=Array(repeating:-0.72,count:66)
        let step:Float=0.15625/2
        var x:Float=7+step/2
        while x<17 {
            var y:Float = -4+step/2
            while y < -0.72 {
                let p=Vec(x,y)
                if !staticSolid(p,margin:step*0.35) { particles.append(LiquidParticle(position:p,velocity:Vec(0,0),volume:step*step)) }
                y+=step
            }
            x+=step
        }
        rebuildGrid(frozen:[])
        updateSurface()
    }
    public func floor(at x:Float)->Float {
        if x<9.4 { return max(-4,-(x-7)*1.625) }
        if x>14.6 { return max(-4,-(17-x)*1.625) }
        return -4
    }
    public func staticSolid(_ p:Vec,margin:Float=0)->Bool {
        p.x<7+margin || p.x>17-margin || p.y<floor(at:p.x)+margin || platforms.contains {
            abs(p.x-$0.x)<$0.width/2+margin && abs(p.y-$0.y)<$0.height/2+margin
        }
    }
    private func index(_ p:Vec)->Int {
        let i=max(0,min(nx-1,Int((p.x-origin.x)/spacing))),j=max(0,min(ny-1,Int((p.y-origin.y)/spacing)))
        return i*ny+j
    }
    private func transfer(_ p:Vec,component:Int,value:Float) {
        let dx:Float=component==0 ? 0 : 0.5,dy:Float=component==1 ? 0 : 0.5
        let x=max(0,min(Float(nx-2),(p.x-origin.x)/spacing-dx)),y=max(0,min(Float(ny-2),(p.y-origin.y)/spacing-dy))
        let i=Int(x),j=Int(y),fx=x-Float(i),fy=y-Float(j)
        let ids=[i*ny+j,(i+1)*ny+j,(i+1)*ny+j+1,i*ny+j+1]
        let ws=[(1-fx)*(1-fy),fx*(1-fy),fx*fy,(1-fx)*fy]
        for k in 0..<4 {
            if component==0 { u[ids[k]]+=value*ws[k];weightU[ids[k]]+=ws[k] }
            else if component==1 { v[ids[k]]+=value*ws[k];weightV[ids[k]]+=ws[k] }
            else { particleDensity[ids[k]]+=value*ws[k] }
        }
    }
    private func sample(_ field:[Float],at p:Vec,component:Int)->Float {
        let dx:Float=component==0 ? 0 : 0.5,dy:Float=component==0 ? 0.5 : 0
        let x=max(1,min(Float(nx-2),(p.x-origin.x)/spacing-dx)),y=max(1,min(Float(ny-2),(p.y-origin.y)/spacing-dy))
        let i=Int(x),j=Int(y),fx=x-Float(i),fy=y-Float(j)
        let ids=[i*ny+j,(i+1)*ny+j,(i+1)*ny+j+1,i*ny+j+1]
        let ws=[(1-fx)*(1-fy),fx*(1-fy),fx*fy,(1-fx)*fy]
        var value:Float=0,total:Float=0
        for k in 0..<4 {
            let id=ids[k],neighbor=component==0 ? id-ny : id-1
            if kind[id]==2 || (neighbor>=0 && kind[neighbor]==2) {
                value+=field[id]*ws[k];total+=ws[k]
            }
        }
        return total>0.00001 ? value/total : 0
    }
    public func velocity(at p:Vec)->Vec { Vec(sample(u,at:p,component:0),sample(v,at:p,component:1)) }
    public func contains(_ p:Vec)->Bool {
        guard !staticSolid(p),p.y<3,p.y > -4 else { return false }
        let id=index(p)
        return kind[id]==2 || (p.y<surface[max(0,min(nx-1,id/ny))] && kind[id] != 0 && counts[id]>0.15)
    }
    private func rebuildGrid(frozen:[FluidBody]) {
        for i in u.indices { u[i]=0;v[i]=0;weightU[i]=0;weightV[i]=0;counts[i]=0;pressure[i]=0;particleDensity[i]=0;kind[i]=1;solidVelocity[i]=Vec(0,0);owner[i] = -1 }
        for i in 0..<nx { for j in 0..<ny {
            let id=i*ny+j,p=Vec(origin.x+(Float(i)+0.5)*spacing,origin.y+(Float(j)+0.5)*spacing)
            if i==0 || i==nx-1 || j==0 || staticSolid(p) || frozen.contains(where:{ $0.contains(p) }) { kind[id]=0 }
            else if let k=bodies.firstIndex(where:{ $0.contains(p) }) { kind[id]=0;owner[id]=k;solidVelocity[id]=bodies[k].velocity(at:p) }
        } }
        for p in particles where !p.isSpray {
            let id=index(p.position)
            if kind[id] != 0 { kind[id]=2;counts[id]+=p.volume/markerVolume }
            transfer(p.position,component:0,value:p.velocity.x)
            transfer(p.position,component:1,value:p.velocity.y)
            transfer(p.position,component:2,value:p.volume/markerVolume)
        }
        for i in u.indices {
            if weightU[i]>0 { u[i]/=weightU[i] }
            if weightV[i]>0 { v[i]/=weightV[i] }
        }
        boundaries()
    }
    private func boundaries() {
        for i in 1..<nx { for j in 1..<ny {
            let id=i*ny+j,l=id-ny,b=id-1
            if kind[id]==0 || kind[l]==0 { u[id]=kind[id]==0 ? solidVelocity[id].x : solidVelocity[l].x }
            if kind[id]==0 || kind[b]==0 { v[id]=kind[id]==0 ? solidVelocity[id].y : solidVelocity[b].y }
        } }
    }
    public func advance(dt:Float,gravity:Float,bodies:[FluidBody],frozen:[FluidBody]) {
        guard dt>0,dt<=0.04 else { return }
        let energyBefore=mechanicalEnergy(gravity:gravity,bodies:bodies)
        self.bodies=bodies
        pressureLoads.removeAll(keepingCapacity:true)
        // Predict the same gravity step that Box2D will take, then solve water
        // and body boundary velocities together (including rotational inertia).
        for i in self.bodies.indices where self.bodies[i].mass>0 { self.bodies[i].velocity.y-=gravity*dt }
        let predicted=self.bodies
        // Move markers out of geometry before marking fluid cells, including
        // after a body was teleported or water changed phase.
        for i in particles.indices { collide(&particles[i],frozen:frozen) }
        rebuildGrid(frozen:frozen)
        oldU=u;oldV=v
        for i in 1..<nx-1 { for j in 1..<ny-1 {
            let id=i*ny+j
            if kind[id] != 0 && kind[id-1] != 0 && (kind[id]==2 || kind[id-1]==2) { v[id]-=gravity*dt }
        } }
        let pressureScale=spacing/dt,cellMass=spacing*spacing
        for _ in 0..<50 {
            for i in 1..<nx-1 { for j in 1..<ny-1 {
                let id=i*ny+j
                if kind[id] != 2 { continue }
                let neighbors=[id-ny,id+ny,id-1,id+1]
                let faces=[id,id+ny,id,id+1]
                let signs:[Float]=[-1,1,-1,1]
                var divergence:Float=0,denominator:Float=0
                var coupling:[(Int,Float,Float,Float)]=[]
                for f in 0..<4 {
                    let n=neighbors[f],horizontal=f<2,sign=signs[f]
                    if kind[n] != 0 {
                        divergence+=sign*(horizontal ? u[faces[f]] : v[faces[f]])
                        denominator+=1
                    } else if owner[n]>=0 {
                        let k=owner[n],body=self.bodies[k]
                        let point=Vec(origin.x+(Float(i)+(f==0 ? 0 : (f==1 ? 1 : 0.5)))*spacing,
                                      origin.y+(Float(j)+(f==2 ? 0 : (f==3 ? 1 : 0.5)))*spacing)
                        let velocity=body.velocity(at:point)
                        divergence+=sign*(horizontal ? velocity.x : velocity.y)
                        if body.mass>0 {
                            let gx:Float=horizontal ? sign : 0,gy:Float=horizontal ? 0 : sign
                            let angular=body.rotates ? (point.x-body.center.x)*gy-(point.y-body.center.y)*gx : 0
                            if let k0=coupling.firstIndex(where:{ $0.0==k }) {
                                coupling[k0].1+=gx;coupling[k0].2+=gy;coupling[k0].3+=angular
                            } else { coupling.append((k,gx,gy,angular)) }
                        }
                    }
                }
                for (k,gx,gy,angular) in coupling {
                    let body=self.bodies[k]
                    denominator+=cellMass*((gx*gx+gy*gy)/body.mass+angular*angular/body.inertia)
                }
                guard denominator>0 else { continue }
                let compression=max(0,particleDensity[id]-4)*0.18
                // Free-surface water cannot carry tensile pressure. Without this
                // constraint a departing body would be sucked back into the pond.
                let proposed = -(divergence-compression)/denominator*1.5
                let correction=max(-pressure[id]/pressureScale,proposed)
                for f in 0..<4 where kind[neighbors[f]] != 0 {
                    if f<2 { u[faces[f]]+=signs[f]*correction }
                    else { v[faces[f]]+=signs[f]*correction }
                }
                for (k,gx,gy,angular) in coupling {
                    self.bodies[k].velocity.x+=cellMass*gx*correction/self.bodies[k].mass
                    self.bodies[k].velocity.y+=cellMass*gy*correction/self.bodies[k].mass
                    self.bodies[k].omega+=cellMass*angular*correction/self.bodies[k].inertia
                }
                pressure[id]+=correction*pressureScale
            } }
        }
        for i in self.bodies.indices where self.bodies[i].mass>0 {
            let a=self.bodies[i],b=predicted[i]
            pressureLoads[a.id]=(Vec(a.velocity.x-b.velocity.x,a.velocity.y-b.velocity.y),a.omega-b.omega)
        }
        for i in owner.indices where owner[i]>=0 {
            let k=owner[i],point=Vec(origin.x+(Float(i/ny)+0.5)*spacing,origin.y+(Float(i%ny)+0.5)*spacing)
            solidVelocity[i]=self.bodies[k].velocity(at:point)
        }
        boundaries()
        for i in particles.indices where !particles[i].isSpray {
            let p=particles[i].position
            let pic=velocity(at:p),before=Vec(sample(oldU,at:p,component:0),sample(oldV,at:p,component:1))
            var velocity=Vec((particles[i].velocity.x+pic.x-before.x)*0.92+pic.x*0.08,
                             (particles[i].velocity.y+pic.y-before.y)*0.92+pic.y*0.08)
            let speed=hypot(velocity.x,velocity.y),limit=spacing*0.75/dt
            if speed>limit { velocity.x*=limit/speed;velocity.y*=limit/speed }
            velocity.x*=exp(-dt*0.12);velocity.y*=exp(-dt*0.12)
            particles[i].velocity=velocity
            particles[i].position.x+=velocity.x*dt;particles[i].position.y+=velocity.y*dt
            collide(&particles[i],frozen:frozen)
        }
        stepNumber+=1
        if stepNumber%2==0 { separate(frozen:frozen) }
        updateSurface()
        advanceSecondaryWater(dt:dt,gravity:gravity,impactBodies:bodies,energyBefore:energyBefore,frozen:frozen)
    }
    private func collide(_ particle:inout LiquidParticle,frozen:[FluidBody]) {
        let radius=spacing*0.16
        particle.position.x=max(7+radius,min(17-radius,particle.position.x))
        particle.position.y=min(origin.y+Float(ny-2)*spacing,particle.position.y)
        let floor=floor(at:particle.position.x)+radius
        if particle.position.y<floor {
            particle.position.y=floor
            let slope:Float=particle.position.x<9.4 ? -1.625 : (particle.position.x>14.6 ? 1.625 : 0)
            let inward=(particle.velocity.y-particle.velocity.x*slope)/(1+slope*slope)
            if inward<0 { particle.velocity.x+=inward*slope;particle.velocity.y-=inward }
        }
        for platform in platforms where abs(particle.position.x-platform.x)<platform.width/2+radius && abs(particle.position.y-platform.y)<platform.height/2+radius {
            resolve(&particle,body:FluidBody(id:-1,center:Vec(platform.x,platform.y),width:platform.width,height:platform.height),radius:radius)
        }
        for body in bodies where body.contains(particle.position,margin:radius) { resolve(&particle,body:body,radius:radius) }
        for body in frozen where body.contains(particle.position,margin:radius) { resolve(&particle,body:body,radius:radius) }
    }
    private func resolve(_ particle:inout LiquidParticle,body:FluidBody,radius:Float) {
        var q=body.local(particle.position)
        let dx=body.width/2+radius-abs(q.x),dy=body.height/2+radius-abs(q.y)
        guard dx>0,dy>0 else { return }
        var n=Vec(0,0)
        if dx<dy { n.x=q.x<0 ? -1 : 1;q.x=n.x*(body.width/2+radius) }
        else { n.y=q.y<0 ? -1 : 1;q.y=n.y*(body.height/2+radius) }
        particle.position=body.world(q)
        let c=cos(body.angle),s=sin(body.angle),normal=Vec(n.x*c-n.y*s,n.x*s+n.y*c),wall=body.velocity(at:particle.position)
        let dot=(particle.velocity.x-wall.x)*normal.x+(particle.velocity.y-wall.y)*normal.y
        if dot<0 { particle.velocity.x-=dot*normal.x;particle.velocity.y-=dot*normal.y }
    }
    private func separate(frozen:[FluidBody]) {
        for i in heads.indices { heads[i] = -1 }
        next=Array(repeating:-1,count:particles.count)
        for i in particles.indices where !particles[i].isSpray { let cell=index(particles[i].position);next[i]=heads[cell];heads[cell]=i }
        let minimum=spacing*0.50
        for i in particles.indices where !particles[i].isSpray {
            let cell=index(particles[i].position),x=cell/ny,y=cell%ny
            for xx in max(0,x-1)...min(nx-1,x+1) { for yy in max(0,y-1)...min(ny-1,y+1) {
                var j=heads[xx*ny+yy]
                while j>=0 {
                    if j>i {
                        let dx=particles[j].position.x-particles[i].position.x,dy=particles[j].position.y-particles[i].position.y,d2=dx*dx+dy*dy
                        if d2>0.0000001 && d2<minimum*minimum {
                            let d=sqrt(d2),shift=(minimum-d)*0.45/d
                            particles[i].position.x-=dx*shift;particles[i].position.y-=dy*shift
                            particles[j].position.x+=dx*shift;particles[j].position.y+=dy*shift
                        }
                    }
                    j=next[j]
                }
            } }
        }
        for i in particles.indices { collide(&particles[i],frozen:frozen) }
    }
    private func updateSurface() {
        var top=Array(repeating:Float(-4),count:nx)
        for i in counts.indices { counts[i]=0 }
        for p in particles where !p.isSpray {
            let id=index(p.position);counts[id]+=p.volume/markerVolume
            top[id/ny]=max(top[id/ny],p.position.y+spacing*0.24)
        }
        // Ignore isolated spray when estimating the load-bearing free surface.
        for i in 1..<nx-1 {
            var highest:Float = -4
            for j in 1..<ny-1 {
                let id=i*ny+j
                if counts[id]>0.2 && (counts[id-1]>0.2 || counts[id]+counts[id-ny]+counts[id+ny]>2.5) {
                    highest=max(highest,origin.y+(Float(j)+0.5)*spacing)
                }
            }
            surface[i]=max(floor(at:origin.x+(Float(i)+0.5)*spacing),min(top[i],highest+spacing*0.5))
        }
        for body in bodies {
            let corners=body.corners,minX=corners.map(\.x).min()!,maxX=corners.map(\.x).max()!
            let a=max(1,min(nx-2,Int((minX-origin.x)/spacing)-1)),b=max(1,min(nx-2,Int((maxX-origin.x)/spacing)+1))
            guard b>a else { continue }
            let level=(surface[a]+surface[b])/2
            if body.center.y+body.height>level && body.center.y-body.height<level {
                for i in a...b { surface[i]=max(surface[i],surface[a]+(surface[b]-surface[a])*Float(i-a)/Float(b-a)) }
            }
        }
        for i in density.indices {
            let x=i/ny,y=i%ny
            var sum:Float=0,n:Float=0
            for xx in max(0,x-1)...x { for yy in max(0,y-1)...y { sum+=min(1,counts[xx*ny+yy]/3.5);n+=1 } }
            density[i]=sum/max(1,n)
        }
    }
    public func surfaceHeight(at x:Float)->Float {
        let f=max(1,min(Float(nx-3),(x-origin.x)/spacing-0.5)),i=Int(f),t=f-Float(i)
        return surface[i]*(1-t)+surface[i+1]*t
    }
    public func addImpulse(at p:Vec,impulse:Vec,radius:Float=0.65) {
        var total:Float=0
        for particle in particles { let d=hypot(particle.position.x-p.x,particle.position.y-p.y);if d<radius { total+=(1-d/radius)*particle.volume } }
        guard total>0.0001 else { return }
        for i in particles.indices {
            let d=hypot(particles[i].position.x-p.x,particles[i].position.y-p.y)
            if d<radius { let factor=(1-d/radius)/total;particles[i].velocity.x+=impulse.x*factor;particles[i].velocity.y+=impulse.y*factor }
        }
    }
    public func extract(in body:FluidBody)->[LiquidParticle] {
        var stored:[LiquidParticle]=[]
        particles.removeAll { p in if body.contains(p.position) { stored.append(p);return true };return false }
        return stored
    }
    /// Pairwise dissipative coupling: equal and opposite impulses go to the
    /// rigid body and precisely these markers, without noisy grid-flow feedback.
    public func dragLoad(on body:FluidBody,mass:Float,dt:Float,coefficient:Float)->(force:Vec,torque:Float) {
        let radius=spacing*1.8,inertia=max(0.0001,mass*(body.width*body.width+body.height*body.height)/12)
        var contacts:[(Int,Float,Vec,Vec)]=[],fluidMass:Float=0,fluidMoment:Float=0
        for i in particles.indices {
            let p=particles[i].position,q=body.local(p)
            if abs(q.x)>body.width/2+radius || abs(q.y)>body.height/2+radius { continue }
            let nearest=body.world(Vec(max(-body.width/2,min(body.width/2,q.x)),max(-body.height/2,min(body.height/2,q.y))))
            let distance=hypot(p.x-nearest.x,p.y-nearest.y)
            if distance>=radius { continue }
            let weight=pow(1-distance/radius,2),m=particles[i].volume*weight,wall=body.velocity(at:p)
            let relative=Vec(particles[i].velocity.x-wall.x,particles[i].velocity.y-wall.y)
            let lever=Vec(p.x-body.center.x,p.y-body.center.y)
            contacts.append((i,m,relative,lever));fluidMass+=m;fluidMoment+=m*(lever.x*lever.x+lever.y*lever.y)
        }
        let alpha=min(1-exp(-coefficient*dt),min(0.35*mass/max(0.0001,fluidMass),0.25*inertia/max(0.0001,fluidMoment)))
        var impulse=Vec(0,0),angular:Float=0
        for (i,m,relative,lever) in contacts {
            let j=Vec(relative.x*m*alpha,relative.y*m*alpha)
            particles[i].velocity.x-=j.x/max(0.0000001,particles[i].volume)
            particles[i].velocity.y-=j.y/max(0.0000001,particles[i].volume)
            impulse.x+=j.x;impulse.y+=j.y;angular+=lever.x*j.y-lever.y*j.x
        }
        return (Vec(impulse.x/dt,impulse.y/dt),angular/dt)
    }
    public func restoreAtRest(_ stored:[LiquidParticle]) {
        // An anchored frozen sheet dissipates its captured momentum. It must not
        // replay a stale splash 30 seconds later during melting.
        particles.append(contentsOf:stored.map { LiquidParticle(position:$0.position,velocity:Vec(0,0),volume:$0.volume) })
    }
    public func evaporate(at p:Vec,amount:Float,radius:Float)->Float {
        var remaining=max(0,amount)
        for i in particles.indices where hypot(particles[i].position.x-p.x,particles[i].position.y-p.y)<radius && remaining>0 {
            let removed=min(remaining,particles[i].volume);particles[i].volume-=removed;remaining-=removed
        }
        particles.removeAll { $0.volume<0.0000001 }
        return max(0,amount)-remaining
    }
    public var divergenceRMS:Float {
        var sum:Float=0,n:Float=0
        for i in 1..<nx-1 { for j in 1..<ny-1 where kind[i*ny+j]==2 {
            let id=i*ny+j,d=(u[id+ny]-u[id]+v[id+1]-v[id])/spacing;sum+=d*d;n+=1
        } }
        return sqrt(sum/max(1,n))
    }
}


extension LiquidSolver {
    private func mechanicalEnergy(gravity:Float,bodies:[FluidBody],predictionDT:Float=0)->Double {
        var energy:Double=0
        for p in particles { energy+=Double(p.volume)*(Double(p.velocity.x*p.velocity.x+p.velocity.y*p.velocity.y)*0.5+Double(gravity*(p.position.y+4))) }
        for b in bodies where b.mass>0 {
            let y=b.center.y+b.velocity.y*predictionDT
            energy+=Double(b.mass)*(Double(b.velocity.x*b.velocity.x+b.velocity.y*b.velocity.y)*0.5+Double(gravity*(y+4)))+Double(b.inertia*b.omega*b.omega)*0.5
        }
        return energy
    }
    private func advanceSecondaryWater(dt:Float,gravity:Float,impactBodies:[FluidBody],energyBefore:Double,frozen:[FluidBody]) {
        for id in Array(splashCooldown.keys) { splashCooldown[id]=max(0,(splashCooldown[id] ?? 0)-dt) }
        var reentries:[Vec]=[]
        for i in particles.indices where particles[i].isSpray {
            particles[i].sprayAge+=dt
            particles[i].velocity.y-=gravity*dt
            particles[i].velocity.x*=exp(-dt*0.16)
            particles[i].position.x+=particles[i].velocity.x*dt
            particles[i].position.y+=particles[i].velocity.y*dt
            let before=particles[i].velocity
            collide(&particles[i],frozen:frozen)
            // Drops hitting rigid bodies return their momentum to that body.
            if before != particles[i].velocity {
                for body in self.bodies where body.mass>0 && body.contains(particles[i].position,margin:spacing*0.2) {
                    let impulse=Vec((before.x-particles[i].velocity.x)*particles[i].volume,(before.y-particles[i].velocity.y)*particles[i].volume)
                    let old=pressureLoads[body.id] ?? (Vec(0,0),Float(0))
                    let lever=Vec(particles[i].position.x-body.center.x,particles[i].position.y-body.center.y)
                    pressureLoads[body.id]=(Vec(old.0.x+impulse.x/body.mass,old.0.y+impulse.y/body.mass),old.1+(lever.x*impulse.y-lever.y*impulse.x)/body.inertia)
                    break
                }
            }
            let p=particles[i].position
            if particles[i].velocity.y<=0 && p.y<surfaceHeight(at:p.x)+spacing*0.1 && contains(p) {
                particles[i].isSpray=false;particles[i].sprayAge=0;reentries.append(p)
            }
        }
        // A jet can also detach naturally from an already fast, sparse crest.
        var sprayCount=particles.reduce(0) { $0+($1.isSpray ? 1 : 0) }
        if sprayCount<120 {
            for i in particles.indices where !particles[i].isSpray && particles[i].velocity.y>1.2 {
                let p=particles[i].position
                if p.y>surfaceHeight(at:p.x)+spacing*0.7 && sprayCount<120 { particles[i].isSpray=true;particles[i].sprayAge=0;sprayCount+=1 }
            }
        }
        let energyAfter=mechanicalEnergy(gravity:gravity,bodies:self.bodies,predictionDT:dt)
        var budget=Float(max(0,energyBefore-energyAfter))*0.3
        for body in impactBodies where body.mass>0 && body.velocity.y < -1.2 && body.center.x>7 && body.center.x<17 {
            let level=surfaceHeight(at:body.center.x),half=body.height/2
            guard body.center.y-half<level+0.22 && body.center.y+half>level+0.04 && (splashCooldown[body.id] ?? 0)<=0 else { continue }
            let spent=detachSplash(at:Vec(body.center.x,level),halfWidth:body.width/2,speed:min(8,abs(body.velocity.y)),budget:budget)
            if spent>0 { budget=max(0,budget-spent);splashCooldown[body.id]=0.35 }
            addFoam(at:Vec(body.center.x-body.width/2-0.1,level),strength:0.7)
            addFoam(at:Vec(body.center.x+body.width/2+0.1,level),strength:0.7)
        }
        for p in reentries { addFoam(at:p,strength:0.35) }
        foamClock+=dt
        if foamClock>0.13 {
            foamClock=0
            for b in impactBodies where hypot(b.velocity.x,b.velocity.y)>0.65 && b.center.x>7 && b.center.x<17 {
                let y=surfaceHeight(at:b.center.x)
                if abs(b.center.y-y)<b.height/2+0.15 {
                    addFoam(at:Vec(b.center.x-b.width/2-0.06,y),strength:0.25)
                    addFoam(at:Vec(b.center.x+b.width/2+0.06,y),strength:0.25)
                }
            }
        }
        for i in foam.indices {
            let flow=velocity(at:foam[i].position)
            foam[i].position.x=max(7.04,min(16.96,foam[i].position.x+flow.x*dt))
            let target=surfaceHeight(at:foam[i].position.x)+0.015
            foam[i].position.y+=(target-foam[i].position.y)*min(1,dt*14)
            foam[i].life-=dt
            if frozen.contains(where:{ $0.contains(foam[i].position,margin:0.025) }) { foam[i].life-=dt*6 }
        }
        foam.removeAll { $0.life<=0 };if foam.count>260 { foam.removeFirst(foam.count-260) }
        updateSurface()
    }
    /// Redirect a few real surface markers into spray. Equal/opposite momentum
    /// goes into nearby bulk water. The quadratic energy limit spends only a
    /// fraction of energy lost by this step's coupled dissipative solve.
    @discardableResult private func detachSplash(at p:Vec,halfWidth:Float,speed:Float,budget:Float)->Float {
        guard budget>0.00001,particles.filter({ $0.isSpray }).count<100 else { return 0 }
        var candidates:[Int]=[],bulk:[Int]=[]
        for i in particles.indices where !particles[i].isSpray {
            let q=particles[i].position,dx=abs(q.x-p.x),depth=p.y-q.y
            if dx<halfWidth+0.55 && dx>halfWidth+0.025 && depth > -0.08 && depth<0.19 && !bodies.contains(where:{ $0.contains(q,margin:0.025) }) { candidates.append(i) }
            else if dx<1.4 && depth>0.2 && depth<1.1 { bulk.append(i) }
        }
        // Both exposed lips of the impact eject water; do not fill the quota
        // from one side simply because markers were seeded in x order.
        candidates.sort { particles[$0].position.y>particles[$1].position.y }
        let jets=Array(candidates.filter { particles[$0].position.x<p.x }.prefix(3))+Array(candidates.filter { particles[$0].position.x>=p.x }.prefix(3))
        let mass=bulk.reduce(Float(0)) { $0+particles[$1].volume }
        guard jets.count>1,mass>0.05 else { return 0 }
        var changes:[(Int,Vec)]=[],momentum=Vec(0,0)
        for i in jets {
            let q=particles[i],sign:Float=q.position.x<p.x ? -1 : 1
            let desired=Vec(sign*(0.9+speed*0.45),1.6+speed*0.88)
            let change=Vec(desired.x-q.velocity.x,desired.y-q.velocity.y)
            changes.append((i,change));momentum.x+=change.x*q.volume;momentum.y+=change.y*q.volume
        }
        let recoil=Vec(-momentum.x/mass,-momentum.y/mass)
        for i in bulk { changes.append((i,recoil)) }
        var a:Float=0,b:Float=0
        for (i,d) in changes { let q=particles[i];a+=0.5*q.volume*(d.x*d.x+d.y*d.y);b+=q.volume*(q.velocity.x*d.x+q.velocity.y*d.y) }
        guard a>0.0000001 else { return 0 }
        let factor=min(1,max(0,(-b+sqrt(max(0,b*b+4*a*budget)))/(2*a)))
        guard factor>0.08 else { return 0 }
        for (i,d) in changes { particles[i].velocity.x+=d.x*factor;particles[i].velocity.y+=d.y*factor }
        for i in jets { particles[i].isSpray=true;particles[i].sprayAge=0 }
        return max(0,a*factor*factor+b*factor)
    }
    public func addFoam(at p:Vec,strength:Float) {
        guard p.x>7,p.x<17 else { return }
        let amount=max(0,min(1,strength))
        for i in 0..<3 {
            foam.append(SurfaceFoam(position:Vec(p.x+Float(i-1)*0.045,p.y),life:0.9+Float((stepNumber+i*13)%17)*0.06,strength:amount))
        }
    }
}
