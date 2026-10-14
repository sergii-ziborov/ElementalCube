import Foundation

public typealias FurVector = SIMD3<Float>
private func length(_ v:FurVector)->Float { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
private func unit(_ v:FurVector)->FurVector { v/max(0.00001,length(v)) }
public struct FurStrand {
    public let root: FurVector
    public let normal: FurVector
    public let length: Float
    public let face: Int
    public var points: [FurVector]
    public var previous: [FurVector]
    public var wetness: Float = 0
}

/// Rooted, inextensible three-segment guides, integrated with Verlet and solved
/// by position constraints. All six faces participate, including the face front.
public final class FurPhysics {
    public private(set) var strands: [FurStrand] = []
    private var lastCenter=FurVector(repeating:0)
    private var initialized=false
    public init(form:ElementForm) {
        guard form.hasFur else { return }
        var seed:UInt64=92841
        func random()->Float { seed=seed &* 6364136223846793005 &+ 1;return Float((seed>>32)&0xffff)/65535 }
        let frames:[(FurVector,FurVector,FurVector)]=[
            (.init(0,0,1),.init(1,0,0),.init(0,1,0)),(.init(1,0,0),.init(0,0,-1),.init(0,1,0)),
            (.init(-1,0,0),.init(0,0,1),.init(0,1,0)),(.init(0,1,0),.init(1,0,0),.init(0,0,-1)),
            (.init(0,-1,0),.init(1,0,0),.init(0,0,1)),(.init(0,0,-1),.init(-1,0,0),.init(0,1,0))]
        for (face,frame) in frames.enumerated() {
            let (n,u,v)=frame
            for _ in 0..<120 {
                let x=(random()*2-1)*0.48,y=(random()*2-1)*0.48
                if face==0 && ((abs(abs(x)-0.21)<0.14 && abs(y-0.09)<0.19) || (abs(x)<0.10 && abs(y+0.17)<0.13)) { continue }
                let p=n*0.48+u*x+v*y
                let q=FurVector(max(-0.36,min(0.36,p.x)),max(-0.36,min(0.36,p.y)),max(-0.36,min(0.36,p.z)))
                let normal=unit(p-q),root=q+normal*0.12
                let l:Float=face==0 ? 0.06+random()*0.055 : 0.13+random()*0.13
                let points=(0...3).map { root+normal*(l*Float($0)/3) }
                strands.append(FurStrand(root:root,normal:normal,length:l,face:face,points:points,previous:points))
            }
        }
    }
    public func step(dt:Float, center:FurVector, angle:Float, stretch:FurVector,
                     wind:Float, water:(Vec)->Bool, solid:(Vec)->Bool) {
        let ca=cos(angle),sa=sin(angle),cy=cos(Float(0.12)),sy=sin(Float(0.12))
        func rotate(_ p:FurVector)->FurVector {
            let v=FurVector(p.x*cy+p.z*sy,p.y,-p.x*sy+p.z*cy)
            return FurVector(v.x*ca-v.y*sa,v.x*sa+v.y*ca,v.z)
        }
        let teleported = !initialized || length(center-lastCenter)>2
        for i in strands.indices {
            var s=strands[i]
            let root=center+rotate(s.root*stretch),normal=unit(rotate(s.normal))
            if teleported {
                for j in 0...3 { s.points[j]=root+normal*s.length*Float(j)/3;s.previous[j]=s.points[j] }
            }
            let submerged=water(Vec(root.x,root.y)) || s.points.contains { water(Vec($0.x,$0.y)) }
            s.wetness=submerged ? min(1,s.wetness+dt*4) : max(0,s.wetness-dt*0.065)
            s.points[0]=root;s.previous[0]=root
            for j in 1...3 {
                let old=s.points[j],velocity=(old-s.previous[j])/dt
                let wet=s.wetness,drag:Float=submerged ? 13 : 3+wet*5
                let acceleration=FurVector((wind-velocity.x)*drag,-3.8-wet*9-velocity.y*drag,-velocity.z*drag)
                let t=Float(j)/3
                // Rest curvature and wet clumping are forces, not vertex animation.
                let cluster=FurVector((round(s.root.x*8)/8-s.root.x)*wet*t,
                                      -wet*0.07*t*t,(round(s.root.z*8)/8-s.root.z)*wet*t)
                let target=root+normal*(s.length*t*(1-wet*0.12))+rotate(cluster)
                s.points[j]=old+(old-s.previous[j])*exp(-dt*1.4)+(acceleration+(target-old)*(wet>0.5 ? 75 : 110))*dt*dt
                s.previous[j]=old
            }
            for _ in 0..<4 {
                s.points[0]=root
                for j in 1...3 {
                    let delta=s.points[j]-s.points[j-1],distance=length(delta)
                    let correction=delta*((distance-s.length/3)/max(distance,0.00001))
                    if j==1 { s.points[j]-=correction } else { s.points[j]-=correction*0.5;s.points[j-1]+=correction*0.5 }
                    let offset=s.points[j]-root
                    let dot=offset.x*normal.x+offset.y*normal.y+offset.z*normal.z
                    if dot<0.001 { s.points[j]+=normal*(0.001-dot) }
                    if solid(Vec(s.points[j].x,s.points[j].y)) {
                        // Sweep from the free parent to the tip; shorten/compress at contact.
                        var free=s.points[j-1],blocked=s.points[j]
                        for _ in 0..<6 {
                            let mid=(free+blocked)/2
                            if solid(Vec(mid.x,mid.y)) { blocked=mid } else { free=mid }
                        }
                        s.points[j]=free
                        s.previous[j]=s.points[j]
                    }
                }
            }
            strands[i]=s
        }
        initialized=true;lastCenter=center
    }
}
