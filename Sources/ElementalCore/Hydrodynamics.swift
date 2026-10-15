import Foundation

/// The same oriented rectangle is used by Box2D, the fluid boundary and rendering.
public struct FluidBody {
    public var id: Int
    public var center: Vec
    public var velocity: Vec
    public var angle: Float { didSet { cosine=cos(angle);sine=sin(angle) } }
    private var cosine:Float
    private var sine:Float
    public var omega: Float
    public var width: Float
    public var height: Float
    public var mass:Float
    public var rotates:Bool
    public var inertia:Float { max(0.00001,mass*(width*width+height*height)/12) }
    public init(id:Int,center:Vec,velocity:Vec = Vec(0,0),angle:Float=0,omega:Float=0,width:Float,height:Float,mass:Float=0,rotates:Bool=true) {
        self.id=id;self.center=center;self.velocity=velocity;self.angle=angle;self.omega=omega;self.width=width;self.height=height;self.mass=mass;self.rotates=rotates
        cosine=cos(angle);sine=sin(angle)
    }
    public var corners:[Vec] {
        [Vec(-width/2,-height/2),Vec(width/2,-height/2),Vec(width/2,height/2),Vec(-width/2,height/2)].map { world($0) }
    }
    public func local(_ p:Vec)->Vec {
        let x=p.x-center.x,y=p.y-center.y
        return Vec(x*cosine+y*sine,-x*sine+y*cosine)
    }
    public func world(_ p:Vec)->Vec {
        return Vec(center.x+p.x*cosine-p.y*sine,center.y+p.x*sine+p.y*cosine)
    }
    public func contains(_ p:Vec,margin:Float=0)->Bool {
        let q=local(p);return abs(q.x)<width/2+margin && abs(q.y)<height/2+margin
    }
    public func velocity(at p:Vec)->Vec { Vec(velocity.x-omega*(p.y-center.y),velocity.y+omega*(p.x-center.x)) }
    public func displaced(below level:Float,slope:Float=0)->(area:Float,centroid:Vec) {
        let input=corners
        var polygon:[Vec]=[]
        func depth(_ p:Vec)->Float { level+slope*(p.x-center.x)-p.y }
        for i in input.indices {
            let a=input[i],b=input[(i+1)%input.count],da=depth(a),db=depth(b)
            if da>=0 { polygon.append(a) }
            if (da>=0) != (db>=0) {
                let t=da/(da-db);polygon.append(Vec(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t))
            }
        }
        guard polygon.count>=3 else { return (0,center) }
        var twiceArea:Float=0,x:Float=0,y:Float=0
        for i in polygon.indices {
            let a=polygon[i],b=polygon[(i+1)%polygon.count],cross=a.x*b.y-b.x*a.y
            twiceArea+=cross;x+=(a.x+b.x)*cross;y+=(a.y+b.y)*cross
        }
        guard abs(twiceArea)>0.00001 else { return (0,center) }
        return (abs(twiceArea)/2,Vec(x/(3*twiceArea),y/(3*twiceArea)))
    }
}

public struct BridgeSection {
    public var fuel:Float = 1
    public var burning:Float = 0
    public var state:BodyState
    public var width:Float
    public let height:Float=0.18
}
