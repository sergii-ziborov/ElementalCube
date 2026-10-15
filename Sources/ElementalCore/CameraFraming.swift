import Foundation

public enum CameraFraming {
    public static func target(cubeX: Float, velocityX: Float, movement: Float,
                              facing: Float, aimVelocityX: Float?, worldWidth: Float,bounds:WorldBounds=WorldLayout.bounds) -> Float {
        let half = worldWidth/2
        let minimum = bounds.minX+half, maximum = bounds.maxX-half
        guard minimum <= maximum else { return bounds.center.x }
        let intent: Float
        if let aim = aimVelocityX { intent = max(-1,min(1,aim/8)) }
        else if movement != 0 { intent = movement }
        else if abs(velocityX)>0.25 { intent = max(-1,min(1,velocityX/3)) }
        else { intent = facing }
        let distance: Float = worldWidth<12 ? 1.4 : 3
        return max(minimum,min(maximum,cubeX+intent*distance))
    }
    public static func verticalTarget(cubeY:Float,velocityY:Float,aimVelocityY:Float?,worldHeight:Float,bounds:WorldBounds=WorldLayout.bounds)->Float {
        let intent=aimVelocityY ?? velocityY
        let lead:Float=intent < -3 ? -0.04 : 0.13
        // Reserve room for the phone HUD at both extremes. The camera may see
        // sky above the summit and the visual foundation below the cave floor.
        guard worldHeight<bounds.height else { return bounds.center.y }
        let lo=bounds.minY+worldHeight*0.15,hi=bounds.maxY-worldHeight*0.10
        return max(lo,min(hi,cubeY+worldHeight*lead))
    }
}
