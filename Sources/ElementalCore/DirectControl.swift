import Foundation

/// Limits supplied by the currently assigned jump skill, rather than gesture length.
public struct JumpSkill:Equatable {
    public var maximumSpeed:Float
    public var strokeMaximumSpeed:Float
    public init(maximumSpeed:Float,strokeMaximumSpeed:Float=15) {
        self.maximumSpeed=max(1,min(20,maximumSpeed));self.strokeMaximumSpeed=max(1,min(20,strokeMaximumSpeed))
    }
    public static func initial(for form:ElementForm)->Self {
        Self(maximumSpeed:form == .stone ? 10 : (form == .air ? 12.5 : 12))
    }
}

/// Projection shared by Metal rendering and native touch hit-testing. Screen
/// coordinates are view points, independent of Retina scale and orientation.
public struct WorldViewport {
    public var center:Vec,size:Vec,screen:Vec
    public init(center:Vec=Vec(7.3,1.6),size:Vec=Vec(22,13.5),screen:Vec=Vec(1280,800)) { self.center=center;self.size=size;self.screen=screen }
    public func project(_ p:Vec,depth:Float=0)->Vec { Vec((p.x+depth*0.30-center.x)/size.x*screen.x+screen.x/2,screen.y/2-(p.y+depth*0.34-center.y)/size.y*screen.y) }
    public func unproject(_ p:Vec,depth:Float=0)->Vec { Vec((p.x-screen.x/2)/max(1,screen.x)*size.x+center.x-depth*0.30,(screen.y/2-p.y)/max(1,screen.y)*size.y+center.y-depth*0.34) }
    public func hitsCube(_ point:Vec,center:Vec,angle:Float,stretch:Vec=Vec(1,1))->Bool {
        let p=unproject(point,depth:1.1),dx=p.x-center.x,dy=p.y-center.y
        // At least a 44-point hit target, including the soft coat, but no full-screen aim gesture.
        let padding=max(0.1,22*size.x/max(1,screen.x)-0.56)
        return abs(dx*cos(angle)+dy*sin(angle))<0.56*stretch.x+padding && abs(-dx*sin(angle)+dy*cos(angle))<0.56*stretch.y+padding
    }
}

public struct DirectControl {
    public enum Gesture:Equatable { case cube,move,jump,aim }
    public enum Release:Equatable { case none,pet,swipeJump(Vec),aim(Vec) }
    public private(set) var gesture:Gesture?
    public private(set) var drag=Vec(0,0)
    public private(set) var destination:Float?
    private var origin=Vec(0,0)
    private var pendingDestination:Float?
    private var startedAt:TimeInterval=0
    private var furthestDrag:Float=0
    private var onCube=false,aimAllowed=false,aimArmed=false,heldCube=false
    public init() {}
    public mutating func begin(screen:Vec,worldX:Float,onCube:Bool,canJump:Bool,canAim:Bool=false,time:TimeInterval=ProcessInfo.processInfo.systemUptime) {
        guard gesture==nil else { return }
        origin=screen;drag=Vec(0,0);startedAt=time;furthestDrag=0
        self.onCube=onCube;aimAllowed=canAim && canJump;aimArmed=false;heldCube=false
        gesture=onCube ? .cube : .move
        // Map taps and screen jumps share the same touch. Wait for release or
        // horizontal intent; driving at touch-down gives a vertical jump drift.
        pendingDestination=onCube ? nil : worldX;destination=nil
    }
    public mutating func update(screen:Vec,worldX:Float,time:TimeInterval=ProcessInfo.processInfo.systemUptime) {
        guard gesture != nil else { return }
        // Aim requires a stationary hold before dragging. A quick upward swipe
        // stays a basic jump even when it starts on the monster.
        if onCube && time-startedAt>=0.28 && furthestDrag<8 { heldCube=true;aimArmed=aimAllowed }
        drag=Vec(screen.x-origin.x,screen.y-origin.y);furthestDrag=max(furthestDrag,hypot(drag.x,drag.y))
        if gesture == .aim || (aimArmed && furthestDrag>=8) { gesture = .aim;destination=nil }
        else if -drag.y>14 && -drag.y>abs(drag.x)*0.7 { gesture = .jump;destination=nil }
        else if onCube { gesture = .cube;destination=nil }
        else {
            gesture = .move;pendingDestination=worldX
            let horizontal=abs(drag.x)>=8 && abs(drag.x)>=abs(drag.y)*0.7
            destination=horizontal || drag.y>=14 ? worldX : nil
        }
    }
    public mutating func end(time:TimeInterval=ProcessInfo.processInfo.systemUptime)->Release {
        guard gesture != nil else { return .none }
        var release=Release.none
        if gesture == .aim {
            if hypot(drag.x,drag.y)>=12 { release = .aim(drag) }
            destination=nil
        } else if -drag.y>=28 && -drag.y>=abs(drag.x)*0.7 && !(onCube && heldCube) {
            release = .swipeJump(Vec(max(-3.2,min(3.2,drag.x*0.055)),7.2));destination=nil
        } else if onCube { release = .pet;destination=nil }
        else if gesture == .move { destination=pendingDestination }
        gesture=nil;drag=Vec(0,0);pendingDestination=nil;return release
    }
    public mutating func cancel() { gesture=nil;destination=nil;drag=Vec(0,0);aimArmed=false }
    public mutating func movement(position:Float,velocity:Float,maxSpeed:Float=3.4)->Float {
        guard gesture == nil || gesture == .move,let target=destination else { return 0 }
        let delta=target-position
        if abs(delta)<0.14 && abs(velocity)<0.25 { destination=nil;return 0 }
        return max(-1,min(1,delta*3/maxSpeed))
    }
}
