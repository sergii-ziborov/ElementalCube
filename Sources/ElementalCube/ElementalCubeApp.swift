import SwiftUI

@main struct ElementalCubeApp:App {
    @StateObject var session=GameSession()
    var body:some Scene {
        WindowGroup {
            GameView(session:session)
                #if os(macOS)
                .frame(minWidth:480,minHeight:420)
                #else
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                #endif
                .preferredColorScheme(.light)
        }
        #if os(macOS)
        .defaultSize(width:1280,height:800)
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing:.newItem) {} }
        #endif
    }
}
let ink=Color(red:0.12,green:0.24,blue:0.23)
let cream=Color(red:0.97,green:0.98,blue:0.88)
let mint=Color(red:0.68,green:0.92,blue:0.84)

struct GameView:View {
    @ObservedObject var session:GameSession
    @State private var dismissVictory=false
    var abilityCaption:String {
        if session.iceTime>0 { return "\(Int(ceil(session.iceTime))) с" }
        #if os(macOS)
        return "F · 30"
        #else
        return "30 ⚡"
        #endif
    }
    var body:some View {
        GeometryReader { geo in
            let short=geo.size.height<550
            let compact=geo.size.width<980 || short
            ZStack {
                MetalView(session:session).ignoresSafeArea()
                VStack(spacing:0) {
                    header(compact:compact).padding(.top,short ? 4 : (compact ? 14 : 26))
                    HStack(alignment:.top) {
                        VStack(alignment:.leading,spacing:8) {
                            if !short { Label("ПЕРВАЯ ПРОГУЛКА",systemImage:"sparkle").font(.system(size:10,weight:.bold)).tracking(2).opacity(0.6) }
                            Text(session.won ? "Берег пройден!" : "Доберись до флага").font(.system(size:short ? 14 : (compact ? 18 : 22),weight:.medium,design:.serif))
                            HStack(spacing:7) {
                                ForEach(0..<3) { i in Image(systemName:"diamond.fill").foregroundStyle(i<session.shards ? ink : ink.opacity(0.18)) }
                                Text("\(session.shards) / 3 кристалла").font(.system(size:11)).opacity(0.7)
                            }
                        }.padding(short ? 10 : 18).background(cream.opacity(0.75),in:RoundedRectangle(cornerRadius:short ? 12 : 18))
                        Spacer()
                        if !compact {
                            HStack(spacing:7) { Circle().fill(Color(red:0.32,green:0.56,blue:0.4)).frame(width:5,height:5);Text("ТЕСТОВЫЙ МИР • 01").font(.system(size:10,weight:.medium)).tracking(1.4) }.padding(.top,14).opacity(0.7)
                        }
                    }.padding(.top,short ? 8 : 25)
                    Spacer()
                    controls(compact:compact,short:short)
                }.padding(.horizontal,compact ? 16 : 38).padding(.bottom,short ? 7 : (compact ? 20 : 25)).foregroundStyle(ink)
                if session.paused && !session.settings {
                    VStack(spacing:16) {
                        Text("Небольшая пауза").font(.system(size:28,design:.serif))
                        Button("Продолжить") { session.paused=false }.buttonStyle(PillButton())
                    }.padding(40).background(cream,in:RoundedRectangle(cornerRadius:24)).foregroundStyle(ink)
                }
                if session.won && !dismissVictory {
                    ZStack {
                        ink.opacity(0.12).ignoresSafeArea()
                        VStack(spacing:17) {
                            Image(systemName:"flag.checkered").font(.system(size:34)).foregroundStyle(Color(red:0.64,green:0.54,blue:0.27))
                            Text("Маленький куб.\nПервое приключение.").font(.system(size:30,weight:.medium,design:.serif)).multilineTextAlignment(.center)
                            Text("Берег пройден за \(session.jumps) прыжков.\nСобрано кристаллов: \(session.shards) из 3.").font(.system(size:14)).lineSpacing(5).opacity(0.7).multilineTextAlignment(.center)
                            HStack(spacing:10) {
                                Button("Ещё раз") { dismissVictory=false;session.reset() }.buttonStyle(PillButton())
                                Button("Исследовать") { dismissVictory=true }.buttonStyle(PillButton(filled:false))
                            }.padding(.top,7)
                        }.padding(36).background(cream,in:RoundedRectangle(cornerRadius:26)).shadow(color:ink.opacity(0.15),radius:35,y:10)
                    }
                }
            }
            .sheet(isPresented:$session.settings) { settingsPanel }
            .onChange(of:session.settings) { _ in session.cancelAim() }
            .onChange(of:session.won) { won in if !won { dismissVictory=false } }
            .onReceive(NotificationCenter.default.publisher(for:appInactiveNotification)) { _ in session.cancelAim();session.paused=true }
        }
    }
    var appInactiveNotification:Notification.Name {
        #if os(macOS)
        NSApplication.didResignActiveNotification
        #else
        UIApplication.willResignActiveNotification
        #endif
    }
    func header(compact:Bool)->some View {
        HStack(alignment:.center,spacing:14) {
            HStack(spacing:10) {
                ZStack { RoundedRectangle(cornerRadius:13).fill(cream.opacity(0.8)).frame(width:44,height:44);Image(systemName:"cube.transparent.fill").font(.system(size:27,weight:.light)).foregroundStyle(ink) }
                VStack(alignment:.leading,spacing:3) {
                    Text("ElementalCube").font(.system(size:compact ? 20 : 28,weight:.medium,design:.serif))
                    Text(compact ? "ЛЬДИНКА • ЭНЕРГИЯ \(Int(session.energy))" : "МАЛЕНЬКИЙ КУБ. БОЛЬШОЙ МИР.").font(.system(size:8,weight:.medium)).tracking(compact ? 1 : 1.55).opacity(0.65)
                }
            }
            Spacer()
            if !compact {
                HStack(spacing:8) { Image(systemName:"leaf");Text("Тихий берег").font(.system(size:13,weight:.medium)) }.padding(.horizontal,18).padding(.vertical,12).background(cream.opacity(0.46),in:Capsule())
                Spacer()
                VStack(alignment:.leading,spacing:5) {
                    HStack { Image(systemName:"bolt.fill").font(.system(size:10));Text("ЭНЕРГИЯ").font(.system(size:9,weight:.semibold)).tracking(1.2);Spacer();Text("\(Int(session.energy))").font(.system(size:11,weight:.medium,design:.monospaced)) }
                    GeometryReader { g in ZStack(alignment:.leading) { Capsule().fill(ink.opacity(0.13));Capsule().fill(ink.opacity(0.7)).frame(width:g.size.width*CGFloat(session.energy/100)) } }.frame(height:4)
                }.frame(width:137).padding(.horizontal,6)
            }
            Button { session.reset() } label: { Image(systemName:"arrow.counterclockwise").frame(width:39,height:39) }.buttonStyle(GlassButton()).help("Начать заново · R")
            Button { session.settings=true } label: { Image(systemName:"slider.horizontal.3").frame(width:39,height:39) }.buttonStyle(GlassButton()).help("Настройки прототипа")
        }
    }
    func controls(compact:Bool,short:Bool)->some View {
        VStack(spacing:short ? 8 : 18) {
            HStack(alignment:.bottom,spacing:compact ? 10 : 20) {
                VStack(alignment:.leading,spacing:8) {
                    Text(session.inWater ? "ПЛЫВИ К БЕРЕГУ" : "КАТИСЬ").font(.system(size:9,weight:.semibold)).tracking(1.5).foregroundStyle(cream.opacity(0.65))
                    HStack(spacing:7) { movementButton(-1,compact:compact);movementButton(1,compact:compact) }
                }
                VStack(alignment:.leading,spacing:9) {
                    if !compact { Text("УМЕНИЕ ЛЬДИНКИ").font(.system(size:9,weight:.semibold)).tracking(1.7).foregroundStyle(cream.opacity(0.65)) }
                    HStack(spacing:13) {
                        Button { session.frost() } label: {
                            VStack(spacing:5) {
                                Image(systemName:"snowflake").font(.system(size:compact ? 26 : 34,weight:.ultraLight))
                                Text(abilityCaption).font(.system(size:10,weight:.semibold,design:.monospaced))
                            }.foregroundStyle(cream).frame(width:compact ? 62 : 82,height:compact ? 64 : 82)
                                .background(ink.opacity(0.65),in:RoundedRectangle(cornerRadius:19))
                                .overlay(RoundedRectangle(cornerRadius:19).stroke(mint.opacity(0.6),lineWidth:1))
                        }.buttonStyle(.plain).accessibilityLabel("Морозное дыхание")
                        if !compact {
                            VStack(alignment:.leading,spacing:6) {
                                Text("Морозное дыхание").font(.system(size:16,weight:.medium,design:.serif)).foregroundStyle(cream)
                                Text("Заморозь поверхность воды.\nЛёд держится 25 секунд.").font(.system(size:11)).foregroundStyle(cream.opacity(0.7)).lineSpacing(3)
                            }
                        }
                    }
                }
                Spacer(minLength:0)
                if !compact {
                    VStack(spacing:8) {
                        HStack(spacing:7) { Circle().fill(session.grounded || session.inWater ? mint : Color.orange.opacity(0.8)).frame(width:5,height:5);Text(session.grounded ? "НА ОПОРЕ" : (session.inWater ? "В ВОДЕ · МОЖНО ОТТОЛКНУТЬСЯ" : "В ПОЛЁТЕ")).tracking(1.3) }
                            .font(.system(size:9,weight:.medium)).foregroundStyle(cream.opacity(0.7))
                        Text(session.wetness>0.2 ? "Мокрая шерсть · \(Int(session.wetness*100))%" : "Льдинка • готова исследовать").font(.system(size:13,design:.serif)).foregroundStyle(cream)
                    }.padding(.bottom,14)
                    Spacer(minLength:0)
                }
                VStack(alignment:.trailing,spacing:10) {
                    Text(session.aiming ? "ОТПУСТИ" : (session.inWater ? "ТОЛЧОК ИЗ ВОДЫ" : "ПРЫЖОК")).font(.system(size:9,weight:.semibold)).tracking(1.6).foregroundStyle(cream.opacity(0.75))
                    ZStack {
                        Circle().fill(cream.opacity(session.aiming ? 0.22 : 0.12))
                        Circle().stroke(cream.opacity(0.5),lineWidth:1)
                        Circle().stroke(cream.opacity(0.13),lineWidth:1).padding(7)
                        Image(systemName:"arrow.up").font(.system(size:35,weight:.ultraLight)).foregroundStyle(cream)
                            .rotationEffect(.radians(Double(atan2(session.launchVelocity.x,session.launchVelocity.y))))
                    }.frame(width:short ? 76 : (compact ? 88 : 111),height:short ? 76 : (compact ? 88 : 111))
                        .contentShape(Circle())
                        .gesture(DragGesture(minimumDistance:0).onChanged { value in session.beginAim();session.updateAim(value.translation) }.onEnded { _ in session.releaseAim() })
                        .accessibilityLabel("Прыжок: потяни и отпусти")
                }
            }
            HStack {
                Text(compact ? (session.inverted ? "Удерживай ← →. Для прыжка потяни назад и отпусти." : "Удерживай ← →. Для прыжка потяни к цели и отпусти.") : "← → — катиться / плыть    ПРОБЕЛ — прыжок    F — дыхание    R — заново").font(.system(size:compact ? 9 : 10)).foregroundStyle(cream.opacity(0.65))
                Spacer()
                if !compact { Text("ПРИРОДА ПОМНИТ. КУБ МЕНЯЕТ МИР.").font(.system(size:8,weight:.medium)).tracking(1.8).foregroundStyle(cream.opacity(0.5)) }
            }.padding(.top,6).overlay(alignment:.top) { Rectangle().fill(cream.opacity(0.16)).frame(height:1) }
        }.padding(.top,short ? 12 : 35).background {
            LinearGradient(colors:[ink.opacity(0),ink.opacity(0.78)],startPoint:.top,endPoint:.bottom).padding(.horizontal,-50).padding(.bottom,-35).padding(.top,-45).allowsHitTesting(false)
        }
        .overlay(alignment:.top) {
            if session.simulation.time<session.hintUntil {
                Text(session.hint).font(.system(size:11)).foregroundStyle(cream.opacity(0.9)).padding(.horizontal,16).padding(.vertical,9).background(ink.opacity(0.55),in:Capsule()).offset(y:-22).allowsHitTesting(false)
            }
        }
    }
    func movementButton(_ direction:Float,compact:Bool)->some View {
        Image(systemName:direction<0 ? "arrow.left" : "arrow.right")
            .font(.system(size:compact ? 22 : 25,weight:.light)).foregroundStyle(cream)
            .frame(width:compact ? 47 : 58,height:compact ? 56 : 66)
            .background(cream.opacity(session.moving==direction ? 0.26 : 0.11),in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(cream.opacity(0.4),lineWidth:1))
            .contentShape(RoundedRectangle(cornerRadius:16))
            .gesture(DragGesture(minimumDistance:0).onChanged { _ in if !session.paused && !session.settings { session.move(direction) } }.onEnded { _ in session.move(0) })
            .accessibilityLabel(direction<0 ? "Катиться или плыть влево" : "Катиться или плыть вправо")
    }
    var settingsPanel:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Text("Почувствуй физику").font(.system(size:26,design:.serif));Spacer();Button { session.settings=false } label:{ Image(systemName:"xmark") }.buttonStyle(.plain) }
            Text("Настройки тестовой площадки. Мир приостановлен, пока открыта эта панель.").font(.system(size:13)).foregroundStyle(ink.opacity(0.65))
            VStack(alignment:.leading,spacing:8) { HStack { Text("Гравитация");Spacer();Text(String(format:"%0.0f м/с²",session.gravity)).monospacedDigit() };Slider(value:$session.gravity,in:10...26,step:1) }
            VStack(alignment:.leading,spacing:8) { HStack { Text("Сила прыжка");Spacer();Text(String(format:"× %0.2f",session.power)).monospacedDigit() };Slider(value:$session.power,in:0.7...1.3,step:0.05) }
            VStack(alignment:.leading,spacing:8) { HStack { Text("Масштаб камеры");Spacer();Text(String(format:"× %.2f",session.zoom)).monospacedDigit() };Slider(value:$session.zoom,in:0.85...1.6,step:0.05) }
            Toggle("Вода и плавучесть",isOn:$session.water)
            Toggle("Прыжок как рогатка: тяни в обратную сторону",isOn:$session.inverted)
            Toggle("Показать столкновения и скорость",isOn:$session.debug)
            HStack { Button("По умолчанию") { session.gravity=18;session.power=1;session.zoom=1;session.water=true;session.debug=false }.buttonStyle(PillButton(filled:false));Spacer();Button("Продолжить") { session.settings=false }.buttonStyle(PillButton()) }
            Text("Metal • Box2D 3.1.1 • физика 120 Гц").font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.45))
        }.font(.system(size:13)).padding(30).frame(maxWidth:440).foregroundStyle(ink).background(cream)
    }
}
struct GlassButton:ButtonStyle {
    func makeBody(configuration:Configuration)->some View { configuration.label.background(cream.opacity(configuration.isPressed ? 0.95 : 0.6),in:Circle()).foregroundStyle(ink) }
}
struct PillButton:ButtonStyle {
    var filled=true
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:13,weight:.medium)).padding(.horizontal,20).padding(.vertical,12)
            .background(filled ? ink : ink.opacity(0.07),in:Capsule()).foregroundStyle(filled ? cream : ink).opacity(configuration.isPressed ? 0.7 : 1)
    }
}
