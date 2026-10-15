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
    private var contactTime:[Float]=Array(repeating:0,count:25)
    /// Thermal conductivity multiplier supplied by this monster's learned skill.
    public var conductivity:Float=1
    public var frozenVolume:Float { Float(frozenMarkers.values.reduce(Double(0)) { $0+$1.reduce(Double(0)) { $0+Double($1.volume) } }) }
    public init(platforms: [Platform]) {
        self.platforms=platforms.filter { $0.x+$0.width/2>6.8 && $0.x-$0.width/2<17.2 && $0.y-$0.height/2<3 && $0.y+$0.height/2 > -4.2 }
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
        if let markers=frozenMarkers.removeValue(forKey:index) { liquid.restoreAtRest(markers) }
    }
    public var frozenBodies:[FluidBody] {
        ice.enumerated().compactMap { i,c in c.solid ? FluidBody(id:1000+i,center:c.center,width:c.size,height:c.height) : nil }
    }
    public func advanceFluid(dt:Float,gravity:Float,bodies:[FluidBody]) {
        self.bodies=bodies
        liquid.advance(dt:dt,gravity:gravity,bodies:bodies,frozen:frozenBodies);refreshSurface()
    }
    /// Capture a thin skin at the current free surface. Its top stays fixed:
    /// continuing cold grows the interface into liquid, never lifts the player.
    public func freezeContact(at x:Float,bottom foot:Float) {
        let top=min(surface(at:x),foot-0.003)
        for col in 0..<columns where abs(left+(Float(col)+0.5)*cell-x)<0.9 {
            let i=rows*columns+col
            if ice[i].solid { ice[i].cold=max(0.8,ice[i].cold);continue }
            let minX=max(left+Float(col)*cell,left+max(0,-top+0.18)/1.625+0.025)
            let maxX=min(left+Float(col+1)*cell,right-max(0,-top+0.18)/1.625-0.025)
            guard maxX-minX>0.08 else { continue }
            let candidate=IceCell(center:Vec((minX+maxX)/2,top-0.08),size:maxX-minX,height:0.16,cold:1,solid:true)
            guard !solid(at:candidate.center) else { continue }
            let markers=liquid.extract(in:FluidBody(id:i,center:candidate.center,width:candidate.size,height:candidate.height))
            guard !markers.isEmpty else { continue }
            frozenMarkers[i]=markers;ice[i]=candidate;contactTime[col]=0
        }
    }
    /// Resize a phase boundary by taking only the newly frozen markers. Thawing
    /// returns only released mass, at the current local flow rather than its old
    /// pre-freeze velocity. This avoids a delayed impulse when the cube leaves.
    private func reshapeSkin(_ index:Int,height:Float) {
        let old=ice[index],top=old.center.y+old.height/2
        let next=FluidBody(id:index,center:Vec(old.center.x,top-height/2),width:old.size,height:height)
        var stored=frozenMarkers[index] ?? []
        let released=stored.filter { !next.contains($0.position) }
        stored.removeAll { !next.contains($0.position) }
        if !released.isEmpty { liquid.restoreAtRest(released) }
        stored.append(contentsOf:liquid.extract(in:next))
        frozenMarkers[index]=stored
        ice[index].center=next.center;ice[index].height=height
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
                let dx=coldSource.map { abs($0.x-p.x) } ?? Float.greatestFiniteMagnitude
                let near=coldSource.map { abs($0.y-(p.y+ice[i].height/2)-0.56)<0.65 } ?? false
                let contact=near && dx<0.8
                let leftIndex=i-1,rightIndex=i+1
                let connected=(col>0 && previous[leftIndex]) || (col+1<columns && previous[rightIndex])
                // Conduct heat out through a connected sheet. The freezing front
                // takes time to travel sideways; it cannot seed remote ice.
                let conducted=near && dx<1.8 && connected
                if contact || conducted {
                    let strength=contact ? 1 : max(0.05,(1.8-dx)*0.3)
                    ice[i].cold=min(1,ice[i].cold+dt*strength*conductivity)
                    if ice[i].solid { contactTime[col]+=dt*strength*conductivity }
                } else { ice[i].cold=max(0,ice[i].cold-dt/30) }
                if let heat=heatSource,hypot(heat.x-p.x,heat.y-p.y)<1.5 { ice[i].cold=max(0,ice[i].cold-dt*2) }
                if !ice[i].solid && ice[i].cold>=0.6 && connected && near {
                    // Match the neighbouring top instead of freezing a square at
                    // an arbitrary grid height above the water.
                    let neighbour=col>0 && previous[leftIndex] ? ice[leftIndex] : ice[rightIndex]
                    let top=min(neighbour.center.y+neighbour.height/2,liquid.surfaceHeight(at:p.x)+0.04)
                    let candidate=FluidBody(id:i,center:Vec(p.x,top-0.08),width:cell,height:0.16)
                    if !solid(at:candidate.center,margin:0.05) && !occupied.contains(where:{ abs($0.x-p.x)<0.75 && abs($0.y-candidate.center.y)<0.67 }) {
                        let markers=liquid.extract(in:candidate)
                        if !markers.isEmpty { ice[i].center=candidate.center;ice[i].height=0.16;ice[i].solid=true;frozenMarkers[i]=markers;contactTime[col]=0 }
                    }
                }
                if ice[i].solid {
                    if ice[i].cold<0.02 { deferSolid(at:i);contactTime[col]=0 }
                    else {
                        let top=ice[i].center.y+ice[i].height/2
                        let maxDepth=min(1.4,max(0.16,top-floor(at:p.x)-0.04))
                        // Stefan-type front: growth slows as the insulating layer
                        // thickens (depth proportional to the square root of time).
                        let target=min(maxDepth,0.16+0.24*sqrt(contactTime[col]))
                        var height=ice[i].height
                        if contact || conducted { height=min(target,height+dt*0.2) }
                        else { height=max(0.035,height-dt*0.006) }
                        let newBottom=top-height
                        let blocked=occupied.contains { abs($0.x-p.x)<ice[i].size/2+0.62 && $0.y+0.65>newBottom && $0.y-0.65<top-ice[i].height }
                        if !blocked || height<ice[i].height { reshapeSkin(i,height:height) }
                    }
                }
                continue
            }
            guard !solid(at:p,margin:0.08),(p.y-cell*0.4<heights[col] || previous[i]),totalVolume>0.001 else {
                ice[i].cold=0;deferSolid(at:i);continue
            }
            var chilling=false
            if let source=coldSource,source.y<liquid.surfaceHeight(at:source.x)-0.15 {
                let distance=hypot(p.x-source.x,p.y-source.y)
                let touched=abs(p.x-source.x)<0.99 && abs(p.y-source.y)<0.99
                let connected=[i-1,i+1,i-columns,i+columns].contains { j in
                    j>=0 && j<ice.count && abs(ice[j].center.x-p.x)<=cell*1.1 && previous[j]
                }
                chilling=distance<1.45 && (touched || connected)
                if chilling { ice[i].cold=min(1,ice[i].cold+dt*(1.6-distance*0.55)*conductivity) }
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
