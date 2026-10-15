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
        quad(V3(a.x,a.y,a.z),V3(b.x,a.y,a.z),V3(b.x,a.y,b.z),V3(a.x,a.y,b.z),color,V3(0,-1,0))
        quad(V3(b.x,a.y,a.z),V3(a.x,a.y,a.z),V3(a.x,b.y,a.z),V3(b.x,b.y,a.z),color,V3(0,0,-1))
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
        var m=Mesh();m.vertices.reserveCapacity(physics.strands.count*60)
        for (i,s) in physics.strands.enumerated() {
            let dry=form == .air ? tint(0xf1fff3) : (form == .water ? tint(0xa6e7f9) : tint(0xf2fbff))
            let color=mix(dry,tint(form == .air ? 0x7cafaa : 0x568fb8),s.wetness*0.52)
            func curve(_ t:Float)->V3 {
                let q:Float=1-t
                return s.points[0]*(q*q*q)+s.points[1]*(3*q*q*t)+s.points[2]*(3*q*t*t)+s.points[3]*(t*t*t)
            }
            let axis=simd_normalize(s.points[3]-s.points[0]+V3(0.0001,0,0))
            var side=simd_cross(axis,V3(-0.28,-0.3,1))
            if simd_length(side)<0.001 { side=V3(1,0,0) }
            side=simd_normalize(side)
            let normal=simd_normalize(simd_cross(side,axis))
            for ribbon:Float in [-0.5,0.5] {
                func vertex(_ t:Float,_ across:Float)->Vertex {
                    let width=(0.018+Float(i%5)*0.003)*(1-s.wetness*0.58)*pow(max(0,1-t),0.65)
                    let spread=ribbon*0.018*(1-s.wetness*0.85)*(1-t)
                    let p=curve(t)+side*(spread+across*width)
                    // position.w and normal.w carry tuft UVs; world positions stay 3D.
                    return Vertex(position:SIMD4(p,across),normal:SIMD4(normal,1+t),color:color)
                }
                for j in 0..<5 {
                    let a=Float(j)/5,b=Float(j+1)/5
                    for (t,x):(Float,Float) in [(a,-1),(b,-1),(b,1),(a,-1),(b,1),(a,1)] {
                        m.vertices.append(vertex(t,x))
                    }
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
            m.ellipse(center:V3(x*1.65,-0.102,0.556),rx:0.054,ry:0.022,color:tint(0xf2bbd3,0.72))
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
    static func terrain(patches:[MaterialPatch] = [],visible:WorldBounds=WorldBounds(-6,-8,29,11))->Mesh {
        var m=Mesh()
        // Only decorate the visible bricks; the full physics map retains its scale.
        for (platformIndex,platform) in WorldLayout.terrain.enumerated() where visible.overlaps(platform,margin:2) {
            let start=platform.x-platform.width/2,end=platform.x+platform.width/2,top=platform.y+platform.height/2,bottom=platform.y-platform.height/2-(platform.width==WorldLayout.bounds.width ? 24 : 0)
            m.box(center:V3((start+end)/2,(top+bottom)/2,0),size:V3(end-start,top-bottom,2.5),color:tint(0x6d8070))
            let firstRow=max(0,Int(floor((top-visible.maxY-2)/0.75)))
            let lastRow=max(firstRow,Int(ceil((top-max(bottom,visible.minY-2))/0.75)))
            let firstCol=max(0,Int(floor((visible.minX-2-start)/1.1)))
            let lastCol=max(firstCol,Int(ceil((min(end,visible.maxX+2)-start)/1.1))+1)
            for row in firstRow..<lastRow {
                let y=top-0.05-Float(row)*0.75
                for col in firstCol..<lastCol {
                    var tile=RNG(seed:UInt64(platformIndex+1)*8719 ^ UInt64(row+1)*131 ^ UInt64(col+2)*317)
                    let rawX=start+Float(col)*1.1-(row%2==0 ? 0 : 0.5)
                    let x=max(start,rawX),w=min(end,rawX+1.1)-x,height=min(0.69,y-bottom)
                    guard w>0.04,height>0.04 else { continue }
                    m.box(center:V3(x+w/2,y-height/2,1.20),size:V3(w-0.035,height-0.04,0.12+tile.next()*0.05),color:mix(tint(0x728579),tint(0xa6b398),tile.next()))
                }
            }
            if platform.surface == .grass {
                // Close the turf overhang in depth, so the rear coat cannot show
                // through the gap between the grass lip and recessed stonework.
                m.box(center:V3((start+end)/2,top-0.16,0.0),size:V3(end-start,0.24,2.56),color:tint(0x64784d))
                m.box(center:V3((start+end)/2,top+0.01,0.0),size:V3(end-start,0.16,2.56),color:tint(0x82a45d))
                let grassStart=max(0,Int((max(start,visible.minX-2)-start)*22))
                let grassEnd=max(grassStart,Int((min(end,visible.maxX+2)-start)*22))
                for index in grassStart..<grassEnd {
                    var r=RNG(seed:UInt64(platformIndex+1)*9319 ^ UInt64(index+1)*731)
                    let x=start+(Float(index)+r.next())/22,h=0.05+r.next()*0.16,z=0.5+r.next()*0.35
                    let patch=patches.filter { abs($0.y-top)<0.1 }.min(by:{ abs($0.x-x)<abs($1.x-x) })
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
            m.quad(V3(start,-4,1.28),V3(end,-4,1.28),V3(end,y2,1.28),V3(start,y1,1.28),tint(0x849b8c),V3(0,0,1))
            m.quad(V3(start,y1,1.28),V3(end,y2,1.28),V3(end,y2,-1.1),V3(start,y1,-1.1),tint(0xa2b4a0),V3(right ? -0.6 : 0.6,0.8,0))
            for i in 0..<8 {
                let t=Float(i)/8,x=start+(end-start)*t,y=y1+(y2-y1)*t
                m.line(V3(x,y-0.03,1.29),V3(x+0.16,y-0.38,1.29),width:0.017,color:tint(0x59796e))
            }
        }
        // A recessed rock face supports the cliff shelves without blocking the path.
        if visible.maxX>25 {
            m.box(center:V3(46,-13,-2.7),size:V3(42,22,1.2),color:tint(0x536e67))
            for i in 0..<16 {
                let x:Float=25+Float(i)*2.7
                m.box(center:V3(x,-13,-1.9),size:V3(0.12,21,0.18),color:tint(0x69877b))
            }
        }
        // The former finish is now a waypoint on the longer journey.
        for x:Float in [22.25,23.8] { m.box(center:V3(x,1.05,-0.8),size:V3(0.34,2.1,0.4),color:tint(0xb4bb9b)) }
        m.box(center:V3(23.03,2.2,-0.8),size:V3(1.9,0.35,0.4),color:tint(0xc9cbb0))
        for marker in [WorldLayout.goal] {
            let x=marker.x,y=marker.y
            m.line(V3(x,y,0.9),V3(x,y+2.35,0.9),width:0.055,color:tint(0x525c51))
            m.quad(V3(x,y+2.2,0.95),V3(x+0.85,y+2.1,0.95),V3(x+0.67,y+1.65,0.95),V3(x,y+1.73,0.95),tint(0xead490),V3(0,0,1))
            m.diamond(V3(x+0.36,y+1.94,1),size:0.12,color:tint(0xfff4cb))
        }
        return m
    }
    static func bridgeSection(width:Float)->Mesh {
        var m=Mesh()
        m.box(center:V3(0,0,0),size:V3(width,0.18,1.25),color:tint(0xa67b51))
        for z:Float in [-0.48,-0.24,0,0.24,0.48] {
            m.box(center:V3(0,0.09,z),size:V3(width-0.02,0.018,0.218),color:tint(0xc59b68))
        }
        for x:Float in [-width*0.34,width*0.34] {
            m.ellipse(center:V3(x,0,0.635),rx:0.023,ry:0.023,color:tint(0x3a4d4b),segments:8)
        }
        return m
    }
    static func bridgeFixtures()->Mesh {
        var m=Mesh()
        for x:Float in [6.7,17.3] {
            m.box(center:V3(x,-0.03,0.55),size:V3(0.28,0.04,1.32),color:tint(0x77867c))
            m.box(center:V3(x,-0.005,0.55),size:V3(0.36,0.02,1.4),color:tint(0xa6b398))
            m.ellipse(center:V3(x,-0.005,1.225),rx:0.045,ry:0.035,color:tint(0x324f51),segments:12)
        }
        return m
    }
    static func frozenWater(_ field:WaterField)->Mesh {
        var mesh=Mesh()
        let skinStart=field.rows*field.columns
        for (index,c) in field.ice.enumerated() where c.solid {
            let x=c.center.x,y=c.center.y,h=c.size/2,hh=c.height/2
            if index<skinStart {
                mesh.box(center:V3(x,y,1.08),size:V3(c.size,c.height,0.4),color:tint(0x9ad8ec,0.9))
                continue
            }
            let col=index-skinStart,top=y+hh
            func bottom(_ neighbour:Int)->Float {
                let i=skinStart+neighbour
                if neighbour>=0 && neighbour<field.columns && field.ice[i].solid { return (y-hh+field.ice[i].center.y-field.ice[i].height/2)/2 }
                return y-hh+min(0.06,c.height*0.2)
            }
            let leftBottom=bottom(col-1),rightBottom=bottom(col+1),z:Float=1.33
            let points=[V3(x-h,top,z),V3(x-h,leftBottom,z),V3(x+h,rightBottom,z),V3(x+h,top,z)]
            let pale=tint(0xb9edfa,0.94),deep=tint(0x5babcf,0.88)
            for i in [0,1,2,0,2,3] { mesh.vertices.append(Vertex(position:SIMD4(points[i],1),normal:SIMD4(0,0,1,0),color:i==0 || i==3 ? pale : deep)) }
            mesh.quad(V3(x-h,top,z),V3(x+h,top,z),V3(x+h,top,1.0),V3(x-h,top,1.0),tint(0xd8f8ff,0.94),V3(0,1,0))
            mesh.line(V3(x-h,top,z+0.01),V3(x+h,top,z+0.01),width:0.024,color:tint(0xf0feff))
            mesh.line(V3(x-h,leftBottom,z+0.01),V3(x+h,rightBottom,z+0.01),width:0.009,color:tint(0x9fe7f5,0.7))
            // Stable branching inclusions, not a border around every solver cell.
            if col%3==0 && c.height>0.2 {
                let start=V3(x-0.12,top-0.04,z+0.015),end=V3(x+0.09,top-c.height*0.72,z+0.015)
                mesh.line(start,end,width:0.009,color:tint(0xecfdff,0.6))
                mesh.line(start+(end-start)*0.5,start+(end-start)*0.5+V3(0.11,0.045,0),width:0.007,color:tint(0xecfdff,0.45))
            }
        }
        return mesh
    }
    static func liquid(_ field:WaterField,bodies:[FluidBody])->Mesh {
        var mesh=Mesh();let fluid=field.liquid,h=fluid.spacing,z:Float=1.29
        mesh.vertices.reserveCapacity(24000)
        var nodeValues=fluid.density
        for i in 0..<fluid.nx {
            let x=fluid.origin.x+Float(i)*h,level=field.surface(at:x)
            for j in 0..<fluid.ny {
                let p=Vec(x,fluid.origin.y+Float(j)*h),id=i*fluid.ny+j
                if p.y<level && (fluid.staticSolid(p) || bodies.contains(where:{ $0.contains(p) })) { nodeValues[id]=max(nodeValues[id],0.85) }
            }
        }
        func value(_ i:Int,_ j:Int)->Float { nodeValues[i*fluid.ny+j]-0.26 }
        func clip(_ polygon:[V3],_ depth:(V3)->Float)->[V3] {
            guard !polygon.isEmpty else { return [] }
            var out:[V3]=[]
            for i in polygon.indices {
                let a=polygon[i],b=polygon[(i+1)%polygon.count],da=depth(a),db=depth(b)
                if da>=0 { out.append(a) }
                if (da>=0) != (db>=0) { out.append(a+(b-a)*(da/(da-db))) }
            }
            return out
        }
        for i in 1..<fluid.nx-1 { for j in 1..<fluid.ny-1 {
            let x=fluid.origin.x+Float(i)*h,y=fluid.origin.y+Float(j)*h
            let positions=[V3(x,y,z),V3(x+h,y,z),V3(x+h,y+h,z),V3(x,y+h,z)]
            let values=[value(i,j),value(i+1,j),value(i+1,j+1),value(i,j+1)]
            if values.allSatisfy({ $0<0 }) { continue }
            for indices in [[0,1,2],[0,2,3]] {
                var polygon:[V3]=[],edge:[V3]=[]
                for k in 0..<3 {
                    let a=indices[k],b=indices[(k+1)%3],pa=positions[a],pb=positions[b],da=values[a],db=values[b]
                    if da>=0 { polygon.append(pa) }
                    if (da>=0) != (db>=0) { let p=pa+(pb-pa)*(da/(da-db));polygon.append(p);edge.append(p) }
                }
                polygon=clip(polygon) { $0.x-7 };polygon=clip(polygon) { 17-$0.x }
                polygon=clip(polygon) { $0.y-field.floor(at:$0.x) }
                if polygon.count>=3 {
                    for k in 1..<polygon.count-1 {
                        for p in [polygon[0],polygon[k],polygon[k+1]] {
                            let depth=max(0,min(1,(-p.y-0.5)/3.5)),color=mix(tint(0x61cbd3,0.43),tint(0x176c91,0.69),depth)
                            mesh.vertices.append(Vertex(position:SIMD4(p,1),normal:SIMD4(0,0,1,0),color:color))
                        }
                    }
                }
                if edge.count==2 && edge.allSatisfy({ $0.x>=7 && $0.x<=17 && $0.y>field.floor(at:$0.x)+0.012 }) {
                    let a=edge[0],b=edge[1]
                    mesh.quad(a,b,V3(b.x,b.y,-0.75),V3(a.x,a.y,-0.75),tint(0x9ce8e5,0.28),V3(0,1,0))
                    mesh.line(a+V3(0,0,0.01),b+V3(0,0,0.01),width:0.014,color:tint(0xdcfff4,0.8))
                }
            }
        } }
        for (i,p) in fluid.particles.enumerated() where i%29==0 && hypot(p.velocity.x,p.velocity.y)>0.7 {
            mesh.line(V3(p.position.x,p.position.y,z+0.015),V3(p.position.x+p.velocity.x*0.025,p.position.y+p.velocity.y*0.025,z+0.015),width:0.009,color:tint(0xc7f5f1,0.22))
        }
        return mesh
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
