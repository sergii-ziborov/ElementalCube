import Foundation

public enum CameraFraming {
    public static func target(cubeX: Float, velocityX: Float, movement: Float,
                              facing: Float, aimVelocityX: Float?, worldWidth: Float) -> Float {
        let half = worldWidth/2
        let minimum = -2.7+half, maximum = 25-half
        guard minimum <= maximum else { return (-2.7+25)/2 }
        let intent: Float
        if let aim = aimVelocityX { intent = max(-1,min(1,aim/8)) }
        else if movement != 0 { intent = movement }
        else if abs(velocityX)>0.25 { intent = max(-1,min(1,velocityX/3)) }
        else { intent = facing }
        let distance: Float = worldWidth<12 ? 1.4 : 3
        return max(minimum,min(maximum,cubeX+intent*distance))
    }
}
