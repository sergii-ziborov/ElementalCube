import Foundation

/// Physical gait, independent of the portrait animation and the input gesture.
public struct MotionProfile {
    public let jump:Float,speed:Float,grip:Float,gravityFraction:Float,hoverHeight:Float
}
extension ElementForm {
    public var motion:MotionProfile {
        switch self {
        case .ice:return MotionProfile(jump:7.2,speed:3.25,grip:0.8,gravityFraction:1,hoverHeight:0)
        case .water:return MotionProfile(jump:7.0,speed:2.5,grip:0.95,gravityFraction:1,hoverHeight:0)
        case .air:return MotionProfile(jump:8.0,speed:3.6,grip:0.8,gravityFraction:0.72,hoverHeight:1.28)
        case .stone:return MotionProfile(jump:7.1,speed:3.4,grip:1.6,gravityFraction:1,hoverHeight:0)
        case .fire:return MotionProfile(jump:7.0,speed:1.85,grip:0.7,gravityFraction:1,hoverHeight:0)
        }
    }
}
extension MonsterRecord {
    public var groundSpeed:Float { form.motion.speed*(learned.contains(.momentum) ? (form == .ice ? 1.2 : (form == .fire ? 1.15 : 1)) : 1) }
    public var hoverHeight:Float { form.motion.hoverHeight+(form == .air && learned.contains(.momentum) ? 0.25 : 0) }
    public var impactMultiplier:Float { form == .stone && learned.contains(.momentum) ? 1.25 : 1 }
}
