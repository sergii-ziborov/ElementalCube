import SwiftUI
import ElementalCore

/// A local drawing clock keeps portraits alive while gameplay is suspended.
/// Canvas redraws only the portrait; it never steps physics or publishes session state.
struct MonsterPortrait:View {
    var form:ElementForm
    var wetness:Double=0
    var health:Double=100
    var burning:Double=0
    var celebration:Int=0
    var interactive=false
    var animate=true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible=false
    @State private var born=Date.timeIntervalSinceReferenceDate
    @State private var touched:TimeInterval = -100
    @State private var touches=0

    var body:some View {
        Group {
            if interactive {
                Button(action:react) { drawing }.buttonStyle(.plain)
                    .accessibilityLabel("Погладить: "+form.name)
                    .accessibilityHint("Кубик радуется прикосновению")
                    .accessibilityValue(ProcessInfo.processInfo.arguments.contains("--ui-testing") ? "reactions=\(touches)" : "")
            } else { drawing.accessibilityHidden(true) }
        }
        .onAppear { visible=true }
        .onDisappear { visible=false }
        .onChange(of:form) { _ in born=Date.timeIntervalSinceReferenceDate;touched = -100 }
        .onChange(of:celebration) { _ in react() }
    }
    private func react() { touched=Date.timeIntervalSinceReferenceDate;touches+=1 }
    private var drawing:some View {
        TimelineView(.animation(minimumInterval:reduceMotion ? 1/8 : 1/30,paused:!visible || !animate || scenePhase != .active)) { timeline in
            let now=timeline.date.timeIntervalSinceReferenceDate
            Canvas { context,size in
                PortraitPainter(form:form,time:now-born,reactionAge:now-touched,wetness:wetness,health:health,burning:burning,reduced:reduceMotion)
                    .draw(in:&context,size:size)
            }.accessibilityHidden(true)
        }.contentShape(Rectangle())
    }
}

private struct PortraitPainter {
    var form:ElementForm,time:Double,reactionAge:Double,wetness:Double,health:Double,burning:Double,reduced:Bool
    var reacting:Bool { reactionAge>=0 && reactionAge<1.2 }
    var motion:Double { reduced ? 0 : time }
    var wet:Double { min(1,max(0,wetness)) }
    var color:Color {
        switch form {
        case .ice:return Color(red:0.57-wet*0.1,green:0.81-wet*0.12,blue:0.96-wet*0.07)
        case .water:return Color(red:0.27-wet*0.05,green:0.66-wet*0.08,blue:0.85-wet*0.04)
        case .air:return Color(red:0.59,green:0.89,blue:0.79)
        case .stone:return Color(red:0.57,green:0.59,blue:0.51)
        case .fire:return Color(red:1,green:0.58,blue:0.18)
        }
    }
    func draw(in context:inout GraphicsContext,size:CGSize) {
        let scale=min(size.width/100,size.height/112)
        context.translateBy(x:(size.width-100*scale)/2,y:(size.height-112*scale)/2)
        context.scaleBy(x:scale,y:scale)
        let breath=sin(motion*2.4),hop=reacting && !reduced ? sin(min(1,reactionAge/0.65)*Double.pi)*4 : 0
        let hover=form == .air ? 3+sin(motion*2.1)*2.4 : 0
        let shadow=CGRect(x:18+hover*0.8,y:96,width:66-hover*1.6,height:7)
        context.fill(Path(ellipseIn:shadow),with:.color(ink.opacity(form == .air ? 0.10 : 0.16)))
        if form == .air { wind(in:&context) }
        context.translateBy(x:50,y:88-hover-hop*(form == .stone ? 0.2 : 1))
        context.rotate(by:.degrees(form == .stone ? sin(motion)*0.3 : sin(motion*1.1)*1.8))
        let amount=form == .stone ? 0.004 : (form == .water ? 0.025 : 0.014)
        context.scaleBy(x:1-breath*amount,y:1+breath*amount)
        context.translateBy(x:-50,y:-88)
        if form == .fire || burning>0 { flames(in:&context) }
        body(in:&context)
        if form.hasFur { fur(in:&context) }
        face(in:&context)
        if form.hasFur && wet>0.2 { droplets(in:&context) }
        if reacting { affection(in:&context) }
    }
    private func body(in c:inout GraphicsContext) {
        var side=Path();side.move(to:CGPoint(x:72,y:20));side.addQuadCurve(to:CGPoint(x:88,y:29),control:CGPoint(x:87,y:16))
        side.addLine(to:CGPoint(x:88,y:72));side.addQuadCurve(to:CGPoint(x:76,y:87),control:CGPoint(x:89,y:83));side.closeSubpath()
        c.fill(side,with:.linearGradient(Gradient(colors:[color,color.opacity(0.7)]),startPoint:CGPoint(x:79,y:22),endPoint:CGPoint(x:90,y:88)))
        var top=Path();top.move(to:CGPoint(x:22,y:25));top.addLine(to:CGPoint(x:31,y:18));top.addQuadCurve(to:CGPoint(x:77,y:18),control:CGPoint(x:50,y:15));top.addQuadCurve(to:CGPoint(x:87,y:28),control:CGPoint(x:86,y:18));top.closeSubpath()
        c.fill(top,with:.color(color.opacity(0.65)))
        let rect=CGRect(x:14,y:23,width:66,height:65)
        let shape=RoundedRectangle(cornerRadius:form == .stone ? 11 : 15).path(in:rect)
        let light:Color=form == .fire ? Color(red:1,green:0.9,blue:0.42) : (form == .stone ? Color(red:0.78,green:0.78,blue:0.66) : Color(red:0.89-wet*0.18,green:0.97-wet*0.15,blue:1-wet*0.1))
        c.fill(shape,with:.linearGradient(Gradient(colors:[light,color]),startPoint:CGPoint(x:20,y:27),endPoint:CGPoint(x:74,y:87)))
        if form == .stone {
            for points in [[CGPoint(x:16,y:34),CGPoint(x:32,y:25),CGPoint(x:36,y:44),CGPoint(x:20,y:49)],
                           [CGPoint(x:56,y:25),CGPoint(x:76,y:30),CGPoint(x:73,y:47),CGPoint(x:63,y:40)],
                           [CGPoint(x:20,y:70),CGPoint(x:34,y:77),CGPoint(x:39,y:88),CGPoint(x:22,y:85)]] {
                var p=Path();p.addLines(points);p.closeSubpath();c.fill(p,with:.color(ink.opacity(0.1)))
            }
        } else {
            var gleam=Path();gleam.move(to:CGPoint(x:24,y:37));gleam.addQuadCurve(to:CGPoint(x:43,y:29),control:CGPoint(x:28,y:28))
            c.stroke(gleam,with:.color(.white.opacity(form == .water ? 0.65 : 0.3)),style:StrokeStyle(lineWidth:2.5,lineCap:.round))
        }
    }
    private func fur(in c:inout GraphicsContext) {
        // Short, curved tufts follow a rounded cube, including a fine front coat.
        // Wet tufts lie closer to the skin and move together in small clumps.
        func boundary(_ a:Double,_ radius:Double=1)->CGPoint {
            let x=cos(a),y=sin(a)
            return CGPoint(x:47+33*radius*(x<0 ? -1 : 1)*pow(abs(x),0.47),y:55+32*radius*(y<0 ? -1 : 1)*pow(abs(y),0.47))
        }
        for i in 0..<92 {
            let a=Double(i)*2*Double.pi/92
            let wave=sin(motion*2.8+Double(wet>0.3 ? i/4 : i)*0.65)
            let length=(3.3+1.1*sin(Double(i)*9.2))*(1-wet*0.6)
            let b=boundary(a-0.026),e=boundary(a+0.026),m=boundary(a)
            let tip=CGPoint(x:m.x+cos(a)*length+wave*(form == .air ? 1.6 : 0.6),y:m.y+sin(a)*length)
            var p=Path();p.move(to:b);p.addQuadCurve(to:tip,control:CGPoint(x:m.x,y:m.y-1));p.addQuadCurve(to:e,control:CGPoint(x:tip.x+0.5,y:tip.y+1));p.closeSubpath()
            c.fill(p,with:.color(i%3==0 ? .white.opacity(0.85-wet*0.35) : color.opacity(0.75)))
        }
        for i in 0..<58 {
            let x=20+Double((i*31)%54),y=29+Double((i*17)%53)
            if y>38 && y<77 && x>24 && x<70 { continue }
            var p=Path();p.move(to:CGPoint(x:x,y:y));p.addQuadCurve(to:CGPoint(x:x+sin(motion*2+Double(i))*0.7,y:y-2.5+wet),control:CGPoint(x:x+0.8,y:y-1))
            c.stroke(p,with:.color(.white.opacity(0.3-wet*0.12)),style:StrokeStyle(lineWidth:0.65,lineCap:.round))
        }
    }
    private func face(in c:inout GraphicsContext) {
        let phase=time.truncatingRemainder(dividingBy:4.8)
        let blink=phase<4.54 ? 1 : max(0.08,abs(phase-4.67)/0.13)
        let look=reacting ? 0 : sin(time*0.73)*1.3+sin(time*0.31)*0.5
        for x:Double in [32,61] {
            if reacting && reactionAge>0.15 && reactionAge<0.65 {
                var arc=Path();arc.move(to:CGPoint(x:x-6,y:53));arc.addQuadCurve(to:CGPoint(x:x+6,y:53),control:CGPoint(x:x,y:44))
                c.stroke(arc,with:.color(ink),style:StrokeStyle(lineWidth:2.8,lineCap:.round))
            } else {
                let eye=CGRect(x:x-7,y:52-11*blink,width:14,height:22*blink)
                c.fill(Path(ellipseIn:eye),with:.color(.white.opacity(0.9)))
                c.fill(Path(ellipseIn:CGRect(x:x-5+look,y:52-9*blink,width:10,height:18*blink)),with:.color(ink))
                if blink>0.4 { c.fill(Path(ellipseIn:CGRect(x:x-3+look,y:45,width:3.8,height:4.5*blink)),with:.color(.white)) }
            }
        }
        for x:Double in [25,69] { c.fill(Path(ellipseIn:CGRect(x:x-3,y:65,width:6,height:2.8)),with:.color(Color.pink.opacity(reacting ? 0.42 : 0.17))) }
        var mouth=Path();mouth.move(to:CGPoint(x:41,y:70))
        if reacting {
            mouth.addQuadCurve(to:CGPoint(x:53,y:70),control:CGPoint(x:47,y:74));mouth.addQuadCurve(to:CGPoint(x:41,y:70),control:CGPoint(x:47,y:88));mouth.closeSubpath()
            c.fill(mouth,with:.color(ink));c.fill(Path(ellipseIn:CGRect(x:44,y:76,width:6,height:3)),with:.color(.pink.opacity(0.8)))
        } else {
            mouth.addQuadCurve(to:CGPoint(x:53,y:70),control:CGPoint(x:47,y:health<30 || burning>0 ? 64 : 76))
            c.stroke(mouth,with:.color(ink),style:StrokeStyle(lineWidth:1.9,lineCap:.round))
        }
    }
    private func flames(in c:inout GraphicsContext) {
        for i in 0..<10 {
            let x=18+Double(i)*7,wave=sin(motion*5.3+Double(i)*1.7)
            let height=11+8*(wave+1)/2+(reacting ? 4 : 0)
            var p=Path();p.move(to:CGPoint(x:x-6,y:33));p.addCurve(to:CGPoint(x:x+wave*3,y:23-height),control1:CGPoint(x:x-11,y:21),control2:CGPoint(x:x+7,y:20));p.addCurve(to:CGPoint(x:x+6,y:34),control1:CGPoint(x:x-2,y:21),control2:CGPoint(x:x+12,y:26));p.closeSubpath()
            c.fill(p,with:.linearGradient(Gradient(colors:[Color(red:1,green:0.82,blue:0.27),.orange,.red.opacity(0.55)]),startPoint:CGPoint(x:x,y:35),endPoint:CGPoint(x:x,y:5)))
        }
    }
    private func wind(in c:inout GraphicsContext) {
        for i in 0..<3 {
            let y=38+Double(i)*18,sway=sin(motion*1.8+Double(i))*3
            var p=Path();p.move(to:CGPoint(x:5,y:y));p.addCurve(to:CGPoint(x:95,y:y-10),control1:CGPoint(x:22,y:y+12+sway),control2:CGPoint(x:79,y:y+9))
            c.stroke(p,with:.color(color.opacity(0.22)),style:StrokeStyle(lineWidth:1.4,lineCap:.round))
        }
    }
    private func droplets(in c:inout GraphicsContext) {
        for i in 0..<3 {
            let phase=(motion*0.65+Double(i)/3).truncatingRemainder(dividingBy:1)
            c.fill(Path(ellipseIn:CGRect(x:20+Double(i)*25,y:83+phase*12,width:2.3,height:3.8)),with:.color(color.opacity((1-phase)*wet*0.7)))
        }
    }
    private func affection(in c:inout GraphicsContext) {
        let opacity=min(1,(1.2-reactionAge)*2),rise=reduced ? 0 : reactionAge*9
        for i in 0..<2 {
            let x=Double(15+i*67),y=25-rise+Double(i)*8
            var star=Path();star.move(to:CGPoint(x:x,y:y-3));star.addLine(to:CGPoint(x:x+1,y:y-1));star.addLine(to:CGPoint(x:x+3,y:y));star.addLine(to:CGPoint(x:x+1,y:y+1));star.addLine(to:CGPoint(x:x,y:y+3));star.addLine(to:CGPoint(x:x-1,y:y+1));star.addLine(to:CGPoint(x:x-3,y:y));star.addLine(to:CGPoint(x:x-1,y:y-1));star.closeSubpath()
            c.fill(star,with:.color(Color(red:0.94,green:0.72,blue:0.32).opacity(opacity)))
        }
    }
}
