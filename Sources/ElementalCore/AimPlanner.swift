import Foundation

public enum AimPlanner {
    public static func impulse(dx:Float,dy:Float,direction:Float=1,inverted:Bool=true)->Vec {
        let radius=hypot(dx,dy)
        if radius < 8 { return Vec(0,7.2) }
        let x=inverted ? -dx : dx
        let y=inverted ? dy : -dy
        // One radial power curve preserves the vector's angle across orientations.
        let chosenAngle=max(Float.pi/12,min(Float.pi*11/12,atan2(max(0,y),x)))
        let blend=max(0,min(1,(radius-8)/20))
        let angle=Float.pi/2+(chosenAngle-Float.pi/2)*blend
        let chosenPower=min(12,max(3.8,radius*0.11))
        let power=7.2+(chosenPower-7.2)*blend
        return Vec(cos(angle)*power,max(2.8,sin(angle)*power))
    }
}
