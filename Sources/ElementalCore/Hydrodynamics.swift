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
    /// Separating-axis test for the actual oriented rectangles. A positive
    /// clearance permits a small contact gap without treating it as penetration.
    public func overlaps(_ other:FluidBody,clearance:Float=0)->Bool {
        let delta=Vec(other.center.x-center.x,other.center.y-center.y)
        let axes=[Vec(cosine,sine),Vec(-sine,cosine),Vec(other.cosine,other.sine),Vec(-other.sine,other.cosine)]
        for axis in axes {
            let a=width/2*abs(axis.x*cosine+axis.y*sine)+height/2*abs(-axis.x*sine+axis.y*cosine)
            let b=other.width/2*abs(axis.x*other.cosine+axis.y*other.sine)+other.height/2*abs(-axis.x*other.sine+axis.y*other.cosine)
            if abs(delta.x*axis.x+delta.y*axis.y)>=a+b-clearance { return false }
        }
        return true
    }
    /// Continuous segment/rectangle collision. Checking the endpoint alone lets
    /// fast water cross a thin plank or ice edge between two solver steps.
    public func sweep(from start:Vec,to end:Vec,radius:Float)->(point:Vec,normal:Vec,fraction:Float)? {
        let bound=(width+height)/2+radius
        if max(start.x,end.x)<center.x-bound || min(start.x,end.x)>center.x+bound || max(start.y,end.y)<center.y-bound || min(start.y,end.y)>center.y+bound { return nil }
        let a=local(start),b=local(end),d=Vec(b.x-a.x,b.y-a.y)
        let half=Vec(width/2+radius,height/2+radius)
        var enter:Float=0,exit:Float=1,normal=Vec(0,0)
        for axis in 0..<2 {
            let p=axis==0 ? a.x : a.y,v=axis==0 ? d.x : d.y,h=axis==0 ? half.x : half.y
            if abs(v)<0.000001 { if abs(p)>h { return nil };continue }
            let t1=(-h-p)/v,t2=(h-p)/v,near=min(t1,t2),far=max(t1,t2)
            if near>=enter { enter=near;normal=axis==0 ? Vec(v>0 ? -1 : 1,0) : Vec(0,v>0 ? -1 : 1) }
            exit=min(exit,far)
            if enter>exit { return nil }
        }
        guard enter>=0,enter<=1,exit>=0,normal != Vec(0,0) else { return nil }
        let n=Vec(normal.x*cosine-normal.y*sine,normal.x*sine+normal.y*cosine)
        let p=world(Vec(a.x+d.x*enter,a.y+d.y*enter))
        return (Vec(p.x+n.x*0.0001,p.y+n.y*0.0001),n,enter)
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
