import Foundation

/// Finite communicating columns share a hydrostatic head through the underwater passage;
/// evaporation removes it. Frozen cells retain their water until they thaw.
public final class WaterField {
    public let left: Float = 7, right: Float = 17, bottom: Float = -4
    public let cell: Float = 0.4
    public let columns = 25, rows = 9
    public private(set) var heights: [Float]
    public private(set) var ice: [IceCell] = []
    public private(set) var evaporated: Float = 0
    private let platforms: [Platform]
    private var totalVolume: Float = 0
    public init(platforms: [Platform]) {
        self.platforms=platforms
        heights=Array(repeating:-0.72,count:columns)
        for i in 0..<columns { totalVolume+=capacity(at:i,level:-0.72) }
        for row in 0..<rows { for col in 0..<columns {
            let p=Vec(left+(Float(col)+0.5)*cell,bottom+(Float(row)+0.5)*cell)
            ice.append(IceCell(center:p,size:cell,cold:0,solid:false))
        } }
    }
    public func floor(at x: Float)->Float {
        if x<9.4 { return -(x-7)*1.625 }
        if x>14.6 { return -(17-x)*1.625 }
        return bottom
    }
    public func solid(at p: Vec, margin: Float = 0)->Bool {
        if p.x<left || p.x>right || p.y<floor(at:p.x)+margin { return true }
        return platforms.contains { abs(p.x-$0.x)<$0.width/2+margin && abs(p.y-$0.y)<$0.height/2+margin }
    }
    private func capacity(at index: Int, level: Float)->Float {
        let x=left+(Float(index)+0.5)*cell,lo=floor(at:x)
        var height=max(0,level-lo)
        for p in platforms where abs(x-p.x)<p.width/2 {
            height-=max(0,min(level,p.y+p.height/2)-max(lo,p.y-p.height/2))
        }
        return max(0,height)*cell
    }
    private func refreshSurface() {
        var lo=bottom,hi:Float=0
        for _ in 0..<22 {
            let mid=(lo+hi)/2,capacity=(0..<columns).reduce(Float(0)) { $0+self.capacity(at:$1,level:mid) }
            if capacity<totalVolume { lo=mid } else { hi=mid }
        }
        let head=(lo+hi)/2
        for i in 0..<columns { heights[i]=max(floor(at:left+(Float(i)+0.5)*cell),head) }
    }
    public func surface(at x: Float)->Float {
        let i=max(0,min(columns-1,Int((x-left)/cell)))
        return heights[i]
    }
    public func contains(_ p: Vec)->Bool {
        guard p.x>left && p.x<right && !solid(at:p),p.y<surface(at:p.x) else { return false }
        let col=Int((p.x-left)/cell),row=Int(floorf((p.y-bottom)/cell)),i=row*columns+col
        if row>=0 && row<rows && i<ice.count && ice[i].solid { return false }
        return true
    }
    public var volume: Float { totalVolume }
    public func deferSolid(at index:Int) { ice[index].solid=false }
    @discardableResult public func evaporate(around p:Vec, amount: Float, radius:Float=1.45)->Float {
        let indices=(0..<columns).filter { abs(left+(Float($0)+0.5)*cell-p.x)<radius }
        let available=indices.reduce(Float(0)) { $0+capacity(at:$1,level:heights[$1]) }
        let removed=min(totalVolume,min(available,max(0,amount)))
        totalVolume-=removed;evaporated+=removed
        refreshSurface()
        return removed
    }
    public func step(dt:Float, coldSource:Vec?, heatSource:Vec?, occupied:[Vec]) {
        refreshSurface()
        let previous=ice.map(\.solid)
        for i in ice.indices {
            let p=ice[i].center,col=i%columns
            guard !solid(at:p,margin:0.08),p.y-cell*0.4<heights[col],totalVolume>0.001 else {
                ice[i].cold=0;ice[i].solid=false;continue
            }
            var chilling=false
            if let source=coldSource {
                let distance=hypot(p.x-source.x,p.y-source.y)
                let touched=abs(p.x-source.x)<0.99 && abs(p.y-source.y)<0.99
                let connected=[i-1,i+1,i-columns,i+columns].contains { j in
                    j>=0 && j<ice.count && abs(ice[j].center.x-p.x)<=cell*1.1 && previous[j]
                }
                chilling=distance<1.45 && (touched || connected)
                if chilling { ice[i].cold=min(1,ice[i].cold+dt*(1.6-distance*0.55)) }
            }
            if !chilling { ice[i].cold=max(0,ice[i].cold-dt/30) }
            if let source=heatSource,hypot(source.x-p.x,source.y-p.y)<1.5 { ice[i].cold=max(0,ice[i].cold-dt*2) }
            let overlaps=occupied.contains { abs($0.x-p.x)<0.78 && abs($0.y-p.y)<0.78 }
            // No static collider is born intersecting a moving rigid body.
            ice[i].solid=(previous[i] ? ice[i].cold>0.02 : ice[i].cold>=0.82 && !overlaps)
        }
    }
}
