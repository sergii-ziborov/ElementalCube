import Foundation

public struct WorldBounds:Equatable {
    public var minX:Float,minY:Float,maxX:Float,maxY:Float
    public init(_ minX:Float,_ minY:Float,_ maxX:Float,_ maxY:Float) { self.minX=minX;self.minY=minY;self.maxX=maxX;self.maxY=maxY }
    public var width:Float { maxX-minX }
    public var height:Float { maxY-minY }
    public var center:Vec { Vec((minX+maxX)/2,(minY+maxY)/2) }
    public func scaled(_ factor:Float)->Self { Self(center.x-width*factor/2,center.y-height*factor/2,center.x+width*factor/2,center.y+height*factor/2) }
    public func overlaps(_ p:Platform,margin:Float=0)->Bool { p.x+p.width/2>minX-margin && p.x-p.width/2<maxX+margin && p.y+p.height/2>minY-margin && p.y-p.height/2<maxY+margin }
}

public enum WorldLayout {
    /// The original 28 m shore and its 13 m vertical play envelope, expanded
    /// around the same centre. Objects and jump distances retain their scale.
    public static let originalBounds=WorldBounds(-3,-4.6,25,8.4)
    public static let bounds=originalBounds.scaled(4)
    public static let goal=Vec(64,-22.9)
    public static let campfires=[Vec(23,0.3)]
    public static let summit=Vec(-40,22)
    public static let floorHeight:Float = -22.9
    public static let platforms:[Platform] = {
        let b=bounds
        // First seven indices are shared with the pond's bridge anchors.
        var result=[Platform(2,-2,10,4,surface:.grass),Platform(21,-2,8,4,surface:.grass),Platform(12,-4.3,10,0.6),
                    Platform(b.minX-0.2,b.center.y,0.4,b.height+8,boundary:true),Platform(b.maxX+0.2,b.center.y,0.4,b.height+8,boundary:true),
                    Platform(6.7,-0.03,0.28,0.04),Platform(17.3,-0.03,0.28,0.04)]
        // Western hillside: eleven supported, climbable two-metre terraces.
        for i in 0..<11 {
            let right:Float = -3-Float(i)*2,top=Float(i+1)*2
            result.append(Platform(right-1,(top+b.minY)/2,2,top-b.minY,surface:.grass))
        }
        result.append(Platform((b.minX-25)/2,(22+b.minY)/2,-25-b.minX,22-b.minY,surface:.grass))
        // Eastern cliff ledges leave the cavern beneath the original shore open.
        // They protrude from the rock face behind the XY play plane.
        for i in 0..<11 {
            result.append(Platform(26.2+Float(i)*2.4,-Float(i+1)*2-0.55,2.4,1.1))
        }
        for i in 0..<6 { result.append(Platform(Float(i)*5,-19.5+Float(i)*2.5-0.5,4.2,1)) }
        for fire in campfires { result.append(Platform(fire.x,0.055,0.9,0.11)) }
        result.append(Platform(b.center.x,(floorHeight+b.minY)/2,b.width,floorHeight-b.minY))
        return result
    }()
    public static var terrain:[Platform] { platforms.enumerated().compactMap { i,p in !p.boundary && i != 5 && i != 6 ? p : nil } }
    public static let shards:[Vec]=[Vec(6.2,1.6),Vec(12,2.1),Vec(19,1.8),Vec(-8,7.2),Vec(-16,15.2),Vec(-24,23.1),Vec(-40,23.1),Vec(28.5,-2.8),Vec(40.5,-12.8),Vec(61,-21.7),Vec(0,-18.3),Vec(20,-8.3)]
}
