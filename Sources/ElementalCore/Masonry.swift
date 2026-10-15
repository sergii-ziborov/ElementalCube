import Foundation

/// A bounded, bonded masonry panel. Intact bricks are anchored through their
/// neighbours; released bricks keep their physics identity and become dynamic.
public struct MasonryDefinition {
    public let id:String
    public let base:Vec
    public let columns:Int,rows:Int
    public let brickWidth:Float,brickHeight:Float
    public init(id:String,base:Vec,columns:Int=3,rows:Int=3,brickWidth:Float=0.6,brickHeight:Float=0.6) {
        self.id=id;self.base=base;self.columns=columns;self.rows=rows;self.brickWidth=brickWidth;self.brickHeight=brickHeight
    }
    public var bricks:[FluidBody] {
        (0..<columns*rows).map { i in
            FluidBody(id:i,center:Vec(base.x+(Float(i%columns)+0.5-Float(columns)/2)*brickWidth,base.y+(Float(i/columns)+0.5)*brickHeight),width:brickWidth-0.008,height:brickHeight-0.008)
        }
    }
}

/// Explicit adjacency and foundation anchors, rather than deleting a painted
/// rectangle. Cutting a brick also releases every component without an anchor.
public struct MasonryBonds {
    public let columns:Int,rows:Int
    public private(set) var attached:Set<Int>
    public init(columns:Int,rows:Int) { self.columns=columns;self.rows=rows;attached=Set(0..<columns*rows) }
    public func neighbours(of i:Int)->[Int] {
        guard i>=0,i<columns*rows else { return [] }
        return [i%columns>0 ? i-1 : -1,i%columns+1<columns ? i+1 : -1,i>=columns ? i-columns : -1,i+columns<columns*rows ? i+columns : -1].filter { $0>=0 }
    }
    public func fractureCost(at i:Int)->Float {
        guard attached.contains(i) else { return .infinity }
        return Float(neighbours(of:i).filter { attached.contains($0) }.count+(i<columns ? 1 : 0))*5
    }
    @discardableResult public mutating func detach(_ hit:Int)->Set<Int> {
        guard attached.remove(hit) != nil else { return [] }
        var supported=Set(attached.filter { $0<columns }),queue=supported.sorted(),head=0
        while head<queue.count {
            let i=queue[head];head+=1
            for j in neighbours(of:i) where attached.contains(j) && supported.insert(j).inserted { queue.append(j) }
        }
        let released=attached.subtracting(supported).union([hit]);attached=supported
        return released
    }
}

struct MasonryState {
    let definition:MasonryDefinition
    let bodies:[Int32]
    var bonds:MasonryBonds
}
