import AppKit

// Procedural artwork: a rounded ice cube, the same eyes and palette as the game.
let size = 1024
let bitmap = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,
    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext:bitmap,flipped:false)
NSGradient(starting:NSColor(calibratedRed:0.14,green:0.35,blue:0.36,alpha:1),
           ending:NSColor(calibratedRed:0.48,green:0.78,blue:0.69,alpha:1))!
    .draw(in:NSRect(x:0,y:0,width:size,height:size),angle:70)
func ellipse(_ rect:NSRect,_ color:NSColor) { color.setFill(); NSBezierPath(ovalIn:rect).fill() }
ellipse(NSRect(x:182,y:144,width:664,height:110),NSColor.black.withAlphaComponent(0.18))
let body = NSBezierPath(roundedRect:NSRect(x:238,y:222,width:570,height:570),xRadius:112,yRadius:112)
NSGradient(starting:NSColor(calibratedRed:0.29,green:0.65,blue:0.89,alpha:1),ending:NSColor(calibratedRed:0.93,green:0.99,blue:1,alpha:1))!.draw(in:body,angle:45)
// Seeded strands preserve the silhouette and keep regeneration reproducible.
var seed:UInt64 = 73
func random()->CGFloat { seed=seed &* 6364136223846793005 &+ 1;return CGFloat(seed >> 40)/CGFloat(1 << 24) }
for i in 0..<720 {
    let a=CGFloat(i)/720 * .pi*2, r:CGFloat=280
    let cx:CGFloat=520,cy:CGFloat=510
    let x=cx+cos(a)*r/(pow(pow(abs(cos(a)),8)+pow(abs(sin(a)),8),1/8))
    let y=cy+sin(a)*r/(pow(pow(abs(cos(a)),8)+pow(abs(sin(a)),8),1/8))
    let length:CGFloat=14+random()*38
    let path=NSBezierPath();path.move(to:NSPoint(x:x,y:y))
    path.curve(to:NSPoint(x:x+cos(a)*length+14,y:y+sin(a)*length+9),
        controlPoint1:NSPoint(x:x+cos(a)*length*0.3,y:y+sin(a)*length*0.7),
        controlPoint2:NSPoint(x:x+cos(a)*length*0.8+15,y:y+sin(a)*length*0.7+12))
    NSColor(calibratedRed:0.70+random()*0.25,green:0.89+random()*0.10,blue:1,alpha:0.9).setStroke()
    path.lineWidth=3+random()*4;path.stroke()
}
for x:CGFloat in [418,644] {
    ellipse(NSRect(x:x-59,y:424,width:118,height:163),NSColor(calibratedRed:0.07,green:0.22,blue:0.30,alpha:1))
    ellipse(NSRect(x:x-39,y:436,width:78,height:83),NSColor(calibratedRed:0.14,green:0.53,blue:0.73,alpha:1))
    ellipse(NSRect(x:x-23,y:487,width:59,height:80),NSColor(calibratedRed:0.02,green:0.10,blue:0.16,alpha:1))
    ellipse(NSRect(x:x-26,y:538,width:31,height:34),.white)
    ellipse(NSRect(x:x+18,y:460,width:13,height:15),.white)
}
ellipse(NSRect(x:317,y:396,width:74,height:24),NSColor(calibratedRed:0.96,green:0.57,blue:0.65,alpha:0.48))
ellipse(NSRect(x:674,y:396,width:74,height:24),NSColor(calibratedRed:0.96,green:0.57,blue:0.65,alpha:0.48))
let mouth=NSBezierPath();mouth.move(to:NSPoint(x:484,y:408));mouth.curve(to:NSPoint(x:580,y:408),controlPoint1:NSPoint(x:516,y:389),controlPoint2:NSPoint(x:548,y:389));mouth.curve(to:NSPoint(x:484,y:408),controlPoint1:NSPoint(x:560,y:320),controlPoint2:NSPoint(x:501,y:323));mouth.close()
NSColor(calibratedRed:0.06,green:0.19,blue:0.24,alpha:1).setFill();mouth.fill()
ellipse(NSRect(x:513,y:345,width:45,height:27),NSColor(calibratedRed:1,green:0.55,blue:0.65,alpha:1))
NSGraphicsContext.restoreGraphicsState()
let output=URL(fileURLWithPath:"Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let rep = NSBitmapImageRep(cgImage:bitmap.makeImage()!)
try rep.representation(using:.png,properties:[:])!.write(to:output)
print("Generated \(output.path)")
