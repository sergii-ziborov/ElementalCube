import Foundation

public enum BreakMaterial:String { case wood,brick
    public var density:Float { self == .wood ? 0.48 : 2.1 }
    public var energy:Float { self == .wood ? 20 : 55 }
}
public struct BreakableDefinition {
    public let position:Vec,width:Float,height:Float,material:BreakMaterial
    public init(_ position:Vec,_ width:Float,_ height:Float,_ material:BreakMaterial) { self.position=position;self.width=width;self.height=height;self.material=material }
}
public struct BreakableObject:Identifiable {
    public let id:Int32,width:Float,height:Float,material:BreakMaterial
    public var state:BodyState,fuel:Float=1
}
public struct DebrisPiece:Identifiable {
    public let id:Int32,origin:String,width:Float,height:Float,material:BreakMaterial
    public var state:BodyState,fuel:Float=1
}
