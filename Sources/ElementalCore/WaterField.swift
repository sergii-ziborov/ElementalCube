import Foundation

/// Free-surface liquid and a conservative water/ice phase change.
public final class WaterField {
    public let left: Float = 7, right: Float = 17, bottom: Float = -4
    public let cell: Float = 0.4
    public let columns = 25, rows = 9
    public private(set) var heights: [Float]
    public private(set) var ice: [IceCell] = []
    public var evaporated:Float { Float(evaporatedVolume) }
    public let liquid:LiquidSolver
    private let platforms: [Platform]
    private var totalVolume:Double=0
    private var evaporatedVolume:Double=0
    private var frozenMarkers:[Int:[LiquidParticle]]=[:]
    private var bodies:[FluidBody]=[]
    public init(platforms: [Platform]) {
        self.platforms=platforms
        liquid=LiquidSolver(platforms:platforms)
        heights=Array(repeating:-0.72,count:columns)
        totalVolume=liquid.particles.reduce(Double(0)) { $0+Double($1.volume) }
        for row in 0..<rows { for col in 0..<columns {
            let p=Vec(left+(Float(col)+0.5)*cell,bottom+(Float(row)+0.5)*cell)
            ice.append(IceCell(center:p,size:cell,cold:0,solid:false))
        } }
        for col in 0..<columns {
            ice.append(IceCell(center:Vec(left+(Float(col)+0.5)*cell,-0.82),size:cell,height:0.2,cold:0,solid:false))
        }
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
    private func refreshSurface() {
        for i in 0..<columns { heights[i]=liquid.surfaceHeight(at:left+(Float(i)+0.5)*cell) }
    }
    public func surface(at x: Float)->Float {
        var height=liquid.surfaceHeight(at:x)
        for c in ice where c.solid && abs(c.center.x-x)<c.size/2 { height=max(height,c.center.y+c.height/2) }
        return height
    }
    public func contains(_ p: Vec)->Bool {
        guard p.x>left && p.x<right && !solid(at:p),p.y<surface(at:p.x) else { return false }
        if ice.contains(where:{ $0.solid && abs(p.x-$0.center.x)<$0.size/2 && abs(p.y-$0.center.y)<$0.height/2 }) { return false }
        return liquid.contains(p) || (p.y<surface(at:p.x) && bodies.contains { $0.contains(p) })
    }
    public var volume:Float { Float(totalVolume) }
    /// Independently sum the mass carried by both phases for conservation checks.
    public var representedVolume:Float {
        let water=liquid.particles.reduce(Double(0)) { $0+Double($1.volume) }
        return Float(frozenMarkers.values.reduce(water) { sum,markers in sum+markers.reduce(Double(0)) { $0+Double($1.volume) } })
    }
    public func deferSolid(at index:Int) {
        ice[index].solid=false
        if let markers=frozenMarkers.removeValue(forKey:index) { liquid.restore(markers) }
    }
    public var frozenBodies:[FluidBody] {
        ice.enumerated().compactMap { i,c in c.solid ? FluidBody(id:1000+i,center:c.center,width:c.size,height:c.height) : nil }
    }
    public func advanceFluid(dt:Float,gravity:Float,bodies:[FluidBody]) {
        self.bodies=bodies
        liquid.advance(dt:dt,gravity:gravity,bodies:bodies,frozen:frozenBodies);refreshSurface()
    }
    /// Form the first load-bearing skin before the rigid-body step crosses the surface.
    public func freezeContact(at x:Float,bottom foot:Float) {
        let top=min(surface(at:x),foot-0.003)
        for col in 0..<columns where abs(left+(Float(col)+0.5)*cell-x)<0.9 {
            let i=rows*columns+col
            if ice[i].solid { ice[i].cold=1;continue }
            let minX=max(left+Float(col)*cell,left+max(0,-top+0.22)/1.625+0.025)
            let maxX=min(left+Float(col+1)*cell,right-max(0,-top+0.22)/1.625-0.025)
            guard maxX-minX>0.08 else { continue }
            ice[i].center=Vec((minX+maxX)/2,top-0.1);ice[i].size=maxX-minX;ice[i].height=0.2
            guard !solid(at:ice[i].center) else { continue }
            let body=FluidBody(id:i,center:ice[i].center,width:ice[i].size,height:ice[i].height)
            let markers=liquid.extract(in:body)
            guard !markers.isEmpty else { continue }
            frozenMarkers[i]=markers;ice[i].cold=1;ice[i].solid=true
        }
    }
    @discardableResult public func evaporate(around p:Vec, amount: Float, radius:Float=1.45)->Float {
        let removed=liquid.evaporate(at:p,amount:min(Float(totalVolume),max(0,amount)),radius:radius)
        totalVolume=max(0,totalVolume-Double(removed));evaporatedVolume+=Double(removed)
        refreshSurface()
        return removed
    }
    public func step(dt:Float, coldSource:Vec?, heatSource:Vec?, occupied:[Vec]) {
        refreshSurface()
        let previous=ice.map(\.solid)
        for i in ice.indices {
            let p=ice[i].center,col=i%columns
            if i>=rows*columns {
                let contact=coldSource.map { abs($0.x-p.x)<1.2 && abs($0.y-p.y)<1.2 } ?? false
                ice[i].cold=max(0,ice[i].cold-dt*(contact ? 0 : 1/30))
                if let heat=heatSource,hypot(heat.x-p.x,heat.y-p.y)<1.5 { ice[i].cold=max(0,ice[i].cold-dt*2) }
                if ice[i].cold<0.02 { deferSolid(at:i) }
                continue
            }
            guard !solid(at:p,margin:0.08),(p.y-cell*0.4<heights[col] || previous[i]),totalVolume>0.001 else {
                ice[i].cold=0;deferSolid(at:i);continue
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
            let now=previous[i] ? ice[i].cold>0.02 : ice[i].cold>=0.82 && !overlaps
            if now && !previous[i] {
                let markers=liquid.extract(in:FluidBody(id:i,center:p,width:cell,height:cell))
                if !markers.isEmpty { frozenMarkers[i]=markers;ice[i].solid=true }
            } else if !now { deferSolid(at:i) }
        }
    }
}
