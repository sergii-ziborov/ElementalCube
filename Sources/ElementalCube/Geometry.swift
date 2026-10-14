import Foundation
import simd
import ElementalCore

typealias V3 = SIMD3<Float>
typealias C4 = SIMD4<Float>
struct Vertex { var position: SIMD4<Float>; var normal: SIMD4<Float>; var color: C4 }
struct Mesh {
    var vertices: [Vertex] = []
    mutating func triangle(_ a:V3,_ b:V3,_ c:V3,_ color:C4,_ normal:V3?=nil, hair:Float=0) {
        let n=normal ?? simd_normalize(simd_cross(b-a,c-a))
        for p in [a,b,c] { vertices.append(Vertex(position:SIMD4(p,1),normal:SIMD4(n,hair),color:color)) }
    }
    mutating func quad(_ a:V3,_ b:V3,_ c:V3,_ d:V3,_ color:C4,_ normal:V3?=nil) { triangle(a,b,c,color,normal);triangle(a,c,d,color,normal) }
    mutating func box(center:V3,size:V3,color:C4) {
        let a=center-size/2,b=center+size/2
        quad(V3(a.x,a.y,b.z),V3(b.x,a.y,b.z),V3(b.x,b.y,b.z),V3(a.x,b.y,b.z),color,V3(0,0,1))
        quad(V3(a.x,b.y,b.z),V3(b.x,b.y,b.z),V3(b.x,b.y,a.z),V3(a.x,b.y,a.z),color,V3(0,1,0))
        quad(V3(b.x,a.y,b.z),V3(b.x,a.y,a.z),V3(b.x,b.y,a.z),V3(b.x,b.y,b.z),color,V3(1,0,0))
        quad(V3(a.x,a.y,a.z),V3(a.x,a.y,b.z),V3(a.x,b.y,b.z),V3(a.x,b.y,a.z),color,V3(-1,0,0))
    }
    mutating func ellipse(center:V3,rx:Float,ry:Float,color:C4,segments:Int=28) {
        for i in 0..<segments {
            let a=Float(i)*2*Float.pi/Float(segments),b=Float(i+1)*2*Float.pi/Float(segments)
            triangle(center,center+V3(cos(a)*rx,sin(a)*ry,0),center+V3(cos(b)*rx,sin(b)*ry,0),color,V3(0,0,1))
        }
    }
    mutating func line(_ a:V3,_ b:V3,width:Float,color:C4) {
        let d=simd_normalize(V3(-(b.y-a.y),b.x-a.x,0))*width/2
        quad(a-d,b-d,b+d,a+d,color,V3(0,0,1))
    }
    mutating func diamond(_ p:V3,size:Float,color:C4) {
        let top=p+V3(0,size,0),bottom=p-V3(0,size,0),left=p-V3(size*0.48,0,0),right=p+V3(size*0.48,0,0),front=p+V3(0,0,size*0.36)
        triangle(top,left,front,color,V3(-0.4,0.4,1));triangle(top,front,right,color*SIMD4(0.7,1,1,1),V3(0.4,0.4,1))
        triangle(bottom,front,left,color*SIMD4(0.55,0.8,1,1),V3(-0.4,-0.5,1));triangle(bottom,right,front,color,V3(0.4,-0.5,1))
    }
}
struct RNG { var seed:UInt64=9349823; mutating func next()->Float { seed=seed &* 6364136223846793005 &+ 1;return Float((seed>>32)&0xffff)/65535 } }
func tint(_ hex:UInt32,_ alpha:Float=1)->C4 { C4(Float(hex>>16&255)/255,Float(hex>>8&255)/255,Float(hex&255)/255,alpha) }

enum Geometry {
    static func cube(form:ElementForm = .ice)->Mesh {
        var mesh=Mesh(),r=RNG()
        // Rounded solid cube: six subdivided faces, with physical depth.
        let h:Float=0.48,round:Float=form == .stone ? 0.08 : 0.12,n=form == .stone ? 5 : 12
        let colors:[ElementForm:UInt32]=[.ice:0xd9f6ff,.water:0x65bedd,.air:0xc1efe2,.stone:0x9d9788,.fire:0xffc263]
        let frames:[(V3,V3,V3)]=[(V3(0,0,1),V3(1,0,0),V3(0,1,0)),(V3(1,0,0),V3(0,0,-1),V3(0,1,0)),(V3(-1,0,0),V3(0,0,1),V3(0,1,0)),(V3(0,1,0),V3(1,0,0),V3(0,0,-1)),(V3(0,-1,0),V3(1,0,0),V3(0,0,1)),(V3(0,0,-1),V3(-1,0,0),V3(0,1,0))]
        func rounded(_ p:V3)->(V3,V3) { let q=simd_clamp(p,V3(repeating:-h+round),V3(repeating:h-round));let normal=simd_normalize(p-q);return(q+normal*round,normal) }
        for (normal,u,v) in frames {
            for i in 0..<n { for j in 0..<n {
                let x=Float(i)/Float(n)*h*2-h,y=Float(j)/Float(n)*h*2-h,step=h*2/Float(n)
                let ps=[normal*h+u*x+v*y,normal*h+u*(x+step)+v*y,normal*h+u*(x+step)+v*(y+step),normal*h+u*x+v*(y+step)]
                let pts=ps.map(rounded)
                let shade:Float=form == .stone ? 0.82+r.next()*0.28 : 1
                for k in [0,1,2,0,2,3] { mesh.vertices.append(Vertex(position:SIMD4(pts[k].0,1),normal:SIMD4(pts[k].1,0),color:tint(colors[form]!)*SIMD4(shade,shade,shade,1))) }
            } }

        }
        return mesh
    }
    static func fur(_ physics:FurPhysics,form:ElementForm)->Mesh {
        var m=Mesh();m.vertices.reserveCapacity(physics.strands.count*54)
        for (i,s) in physics.strands.enumerated() {
            let dry=form == .air ? tint(0xf1fff3) : (form == .water ? tint(0xa6e7f9) : tint(0xf2fbff))
            let color=mix(dry,tint(0x428ba5),s.wetness*0.72)
            for offset:Float in [-1,0,1] {
                let spread:Float=(1-s.wetness*0.8)*offset*0.012
                for j in 0..<3 {
                    let a=s.points[j]+V3(spread,0,0),b=s.points[j+1]+V3(spread*0.7,0,0)
                    let width:Float=(0.008+Float(i%3)*0.002)*(1-Float(j)/3)
                    var side=simd_cross(b-a,V3(0,0,1))
                    if simd_length(side)<0.001 { side=V3(1,0,0) }
                    side=simd_normalize(side)*width
                    m.quad(a-side,b-side*0.25,b+side*0.25,a+side,color,V3(0,0.5,1))
                }
            }
        }
        return m
    }
    static func flames(time:Float,active:Bool)->Mesh {
        var m=Mesh()
        for i in 0..<17 {
            let x=Float(i)/16*1.04-0.52,h=(0.24+sin(time*8+Float(i)*1.7)*0.12)*(active ? 1 : 0.4)
            m.triangle(V3(x-0.07,0.35,0.42),V3(x+0.07,0.35,0.42),V3(x+sin(time*5+Float(i))*0.07,0.55+h,0.44),tint(i%2==0 ? 0xffb743 : 0xff6b39),V3(0,0.3,1))
        }
        return m
    }
    static func face(blink:Float,mood:Mood,look:Float,wet:Float)->Mesh {
        var m=Mesh()
        let eyeHeight=blink*(mood == .sleepy ? 0.45 : (mood == .focused ? 0.78 : 1))
        let gaze=max(-0.025,min(0.025,look))
        for x:Float in [-0.21,0.21] {
            m.ellipse(center:V3(x,0.095,0.497),rx:0.126,ry:0.167*eyeHeight,color:tint(0xf8fdff))
            m.ellipse(center:V3(x+gaze,0.084,0.515),rx:0.091,ry:0.134*eyeHeight,color:tint(0x152a4d))
            m.ellipse(center:V3(x+gaze,0.053,0.519),rx:0.068,ry:0.077*eyeHeight,color:tint(0x338de1))
            m.ellipse(center:V3(x+gaze,0.093,0.523),rx:0.059,ry:0.106*eyeHeight,color:tint(0x07192f))
            m.ellipse(center:V3(x+gaze-0.031,0.148*eyeHeight,0.53),rx:0.03,ry:0.04*eyeHeight,color:tint(0xffffff))
            m.ellipse(center:V3(x+gaze+0.032,0.06,0.532),rx:0.012,ry:0.017*eyeHeight,color:tint(0xb1ecff))
            m.ellipse(center:V3(x*1.65,-0.102,0.503),rx:0.054,ry:0.022,color:tint(0xf2bbd3,0.72))
            if mood == .displeased {
                let side:Float=x<0 ? -1 : 1
                m.line(V3(x-side*0.075,0.31,0.61),V3(x+side*0.075,0.265,0.61),width:0.019,color:tint(0x43769a))
            } else if mood == .focused {
                let side:Float=x<0 ? -1 : 1
                m.line(V3(x-side*0.075,0.235,0.61),V3(x+side*0.08,0.29,0.61),width:0.019,color:tint(0x43769a))
            } else if mood == .startled {
                m.line(V3(x-0.07,0.32,0.61),V3(x+0.07,0.34,0.61),width:0.016,color:tint(0x43769a))
            }
        }
        if mood == .displeased {
            for i in 0..<8 {
                let x=Float(i)/8*0.14-0.07,x2=Float(i+1)/8*0.14-0.07
                m.line(V3(x,-0.15-x*x*7,0.55),V3(x2,-0.15-x2*x2*7,0.55),width:0.023,color:tint(0x253959))
            }
        } else if mood == .startled || mood == .sleepy {
            m.ellipse(center:V3(0,-0.17,0.55),rx:0.051,ry:0.060,color:tint(0x1c2544))
        } else if mood == .focused {
            m.line(V3(-0.055,-0.16,0.55),V3(0.055,-0.15,0.55),width:0.023,color:tint(0x1c2544))
        } else {
            m.ellipse(center:V3(0,-0.165,0.55),rx:0.075,ry:mood == .delighted ? 0.095 : 0.064,color:tint(0x1c2544))
            m.ellipse(center:V3(0.009,-0.208,0.555),rx:0.045,ry:0.027,color:tint(0xf080a6))
        }
        if wet>0.2 { m.ellipse(center:V3(-0.36,0.3,0.61),rx:0.018,ry:0.038,color:tint(0xa0e9ff,0.9)) }
        return m
    }
    static func terrain(patches:[MaterialPatch] = [])->Mesh {
        var m=Mesh(),r=RNG(seed:871)
        for (start,end,top,bottom):(Float,Float,Float,Float) in [(-3,7,0,-4),(17,25,0,-4),(11.15,12.85,-0.1,-1.9),(10.9,13.1,-1.9,-2.3),(7,17,-4,-4.6)] {
            m.box(center:V3((start+end)/2,(top+bottom)/2,-0.5),size:V3(end-start,top-bottom,1.8),color:tint(0x6d8070))
            var y=top-0.05
            while y>bottom {
                var x=start
                while x<end {
                    let w=min(0.8+r.next()*0.75,end-x),height=min(0.55+r.next()*0.3,y-bottom)
                    m.box(center:V3(x+w/2,y-height/2,0.43),size:V3(max(0.02,w-0.035),max(0.02,height-0.04),0.22+r.next()*0.07),color:mix(tint(0x728579),tint(0xa6b398),r.next()))
                    x+=w
                }
                y-=0.75
            }
            if top > -1 {
                m.box(center:V3((start+end)/2,top+0.01,0.0),size:V3(end-start,0.16,1.82),color:tint(0x82a45d))
                for _ in 0..<Int((end-start)*22) {
                    let x=start+r.next()*(end-start),h=0.05+r.next()*0.16,z=0.5+r.next()*0.35
                    let patch=patches.min(by:{ abs($0.x-x)<abs($1.x-x) })
                    let fuel=patch?.fuel ?? 1,frost=patch?.frost ?? 0
                    let color=mix(mix(tint(0x332f2b),mix(tint(0x587e45),tint(0xb9cf79),r.next()),fuel),tint(0xdbf7ff),frost)
                    m.triangle(V3(x-0.035,top+0.08,z),V3(x+0.04,top+0.08,z),V3(x+0.02,top+h*max(0.1,fuel),z),color,V3(0,0.5,1))
                }
            }
        }
        for x:Float in [1.1,1.3,1.55,4,6.8,17.3,20.5,24] where (patches.min(by:{ abs($0.x-x)<abs($1.x-x) })?.fuel ?? 1)>0.5 {
            for i in 0..<3 { let h=0.3+Float(i)*0.09
                m.line(V3(x,0,0.65),V3(x+0.08*Float(i-1),h,0.65),width:0.018,color:tint(0x6a985f))
                m.ellipse(center:V3(x+0.08*Float(i-1),h,0.66),rx:0.033,ry:0.043,color:i==1 ? tint(0xf7dc9b) : tint(0xe8efbf),segments:8)
            }
        }
        // Visible shallow banks correspond to the actual sloped collision surfaces.
        for (start,end,right):(Float,Float,Bool) in [(7,9.4,false),(14.6,17,true)] {
            let y1:Float=right ? -3.9 : 0,y2:Float=right ? 0 : -3.9
            m.quad(V3(start,-4,0.63),V3(end,-4,0.63),V3(end,y2,0.63),V3(start,y1,0.63),tint(0x849b8c),V3(0,0,1))
            m.quad(V3(start,y1,0.8),V3(end,y2,0.8),V3(end,y2,-0.8),V3(start,y1,-0.8),tint(0xa2b4a0),V3(right ? -0.6 : 0.6,0.8,0))
            for i in 0..<8 {
                let t=Float(i)/8,x=start+(end-start)*t,y=y1+(y2-y1)*t
                m.line(V3(x,y-0.03,0.65),V3(x+0.16,y-0.38,0.65),width:0.017,color:tint(0x59796e))
            }
        }
        // Small weathered arch at the destination. Decoration has no hidden path.
        for x:Float in [22.25,23.8] { m.box(center:V3(x,1.05,-0.8),size:V3(0.34,2.1,0.4),color:tint(0xb4bb9b)) }
        m.box(center:V3(23.03,2.2,-0.8),size:V3(1.9,0.35,0.4),color:tint(0xc9cbb0))
        m.line(V3(23,0,0.9),V3(23,2.35,0.9),width:0.055,color:tint(0x525c51))
        m.quad(V3(23,2.2,0.95),V3(23.85,2.1,0.95),V3(23.67,1.65,0.95),V3(23,1.73,0.95),tint(0xead490),V3(0,0,1))
        m.diamond(V3(23.36,1.94,1),size:0.12,color:tint(0xfff4cb))
        return m
    }
    static func crate()->Mesh {
        var m=Mesh();m.box(center:V3(0,0,0),size:V3(1.25,1.25,1),color:tint(0xad8860))
        for x:Float in [-0.38,-0.13,0.13,0.38] { m.line(V3(x,-0.56,0.507),V3(x,0.56,0.507),width:0.018,color:tint(0x7c644c)) }
        for y:Float in [-0.52,0.52] { m.box(center:V3(0,y,0.53),size:V3(1.25,0.15,0.11),color:tint(0xd1b086)) }
        m.line(V3(-0.53,-0.48,0.61),V3(0.53,0.48,0.61),width:0.14,color:tint(0xccaa7b))
        for x:Float in [-0.5,0.5] { for y:Float in [-0.5,0.5] { m.ellipse(center:V3(x,y,0.66),rx:0.025,ry:0.025,color:tint(0x4a4b43),segments:8) } }
        for z:Float in [-0.35,-0.1,0.15,0.4] {
            m.box(center:V3(0,0.64,z),size:V3(1.25,0.025,0.20),color:tint(0xcfaa7d))
        }
        for y:Float in [-0.46,-0.15,0.16,0.47] {
            m.box(center:V3(0.635,y,0),size:V3(0.025,0.025,0.95),color:tint(0x715941))
        }
        m.box(center:V3(0.665,0,0.4),size:V3(0.09,1.25,0.15),color:tint(0xb59368))
        m.box(center:V3(-0.665,0,0.4),size:V3(0.09,1.25,0.15),color:tint(0xb59368))
        return m
    }
}
func mix(_ a:C4,_ b:C4,_ t:Float)->C4 { a+(b-a)*t }
