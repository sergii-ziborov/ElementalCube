import SwiftUI
import ElementalCore

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
    var controlHint:String { "Тап по кубику — прыжок · Карта — движение" }
    var buildLabel:String { "АЛЬФА · " + (Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "DEV") }
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
                                Image(systemName:"diamond.fill")
                                Text("\(session.shards) / \(WorldLayout.shards.count) кристаллов").font(.system(size:11)).opacity(0.7)
                                if session.deepRelic { Image(systemName:"seal.fill").foregroundStyle(.orange).accessibilityLabel("Глубинная реликвия найдена") }
                            }
                            if compact {
                                HStack(spacing:5) {
                                    Circle().fill(session.passiveWorking ? Color.green.opacity(0.65) : ink.opacity(0.25)).frame(width:5,height:5)
                                    Text(session.form.name + (session.form.hasFur && session.wetness>0.2 ? " · шерсть \(Int(session.wetness*100))%" : " · пассивная")).font(.system(size:10)).opacity(0.7)
                                }
                            }
                        }.padding(short ? 10 : 18).background(cream.opacity(0.75),in:RoundedRectangle(cornerRadius:short ? 12 : 18))
                        Spacer()
                        if !compact {
                            HStack(spacing:7) { Circle().fill(Color(red:0.32,green:0.56,blue:0.4)).frame(width:5,height:5);Text("ТЕСТОВЫЙ МИР • 01").font(.system(size:10,weight:.medium)).tracking(1.4) }.padding(.top,14).opacity(0.7)
                        }
                    }.padding(.top,short ? 8 : 25).allowsHitTesting(false)
                    Spacer()
                    controls(compact:compact,short:short)
                }.padding(.horizontal,compact ? 16 : 38).padding(.bottom,short ? 7 : (compact ? 20 : 25)).foregroundStyle(ink)
                if session.paused && !session.settings {
                    VStack(spacing:16) {
                        Text("Небольшая пауза").font(.system(size:28,design:.serif))
                        Button("Продолжить") { session.paused=false }.buttonStyle(PillButton())
                    }.padding(40).background(cream,in:RoundedRectangle(cornerRadius:24)).foregroundStyle(ink)
                }
                if session.dead {
                    VStack(spacing:16) {
                        Image(systemName:session.form.symbol).font(.system(size:36))
                        Text("Нужна новая попытка").font(.system(size:24,design:.serif))
                        Text("Здоровье закончилось. Огонь теряет его в воде; жёсткие падения тоже оставляют след.").font(.system(size:13)).multilineTextAlignment(.center).frame(maxWidth:280)
                        Button("Вернуться на берег") { session.reset() }.buttonStyle(PillButton())
                    }.padding(30).background(cream,in:RoundedRectangle(cornerRadius:24)).foregroundStyle(ink)
                }
                if session.won && !dismissVictory {
                    ZStack {
                        ink.opacity(0.12).ignoresSafeArea()
                        VStack(spacing:17) {
                            Image(systemName:"flag.checkered").font(.system(size:34)).foregroundStyle(Color(red:0.64,green:0.54,blue:0.27))
                            Text("Маленький куб.\nПервое приключение.").font(.system(size:30,weight:.medium,design:.serif)).multilineTextAlignment(.center)
                            Text("Берег пройден за \(session.jumps) прыжков.\nСобрано кристаллов: \(session.shards) из \(WorldLayout.shards.count).").font(.system(size:14)).lineSpacing(5).opacity(0.7).multilineTextAlignment(.center)
                            HStack(spacing:10) {
                                Button("Ещё раз") { dismissVictory=false;session.reset() }.buttonStyle(PillButton())
                                Button("Исследовать") { dismissVictory=true }.buttonStyle(PillButton(filled:false))
                            }.padding(.top,7)
                        }.padding(36).background(cream,in:RoundedRectangle(cornerRadius:26)).shadow(color:ink.opacity(0.15),radius:35,y:10)
                    }
                }
            }
            .sheet(isPresented:$session.settings) { settingsPanel }
            .sheet(isPresented:$session.abilityInfo) { abilityPanel }
            .sheet(isPresented:$session.forms) { MonsterInventoryView(session:session) }
            .onChange(of:session.abilityInfo) { _ in session.cancelAim() }
            .onChange(of:session.forms) { _ in session.cancelAim() }
            .onChange(of:session.settings) { _ in session.cancelAim() }
            .onChange(of:session.won) { won in if !won { dismissVictory=false } }
            .onReceive(NotificationCenter.default.publisher(for:appInactiveNotification)) { _ in session.cancelAim();session.saveInventory();session.paused=true }
        }
    }
    var appInactiveNotification:Notification.Name {
        #if os(macOS)
        NSApplication.didResignActiveNotification
        #else
        UIApplication.willResignActiveNotification
        #endif
    }
    func resource(_ label:String,_ symbol:String,value:Float,color:Color)->some View {
        VStack(spacing:4) {
            HStack(spacing:5) { Image(systemName:symbol);Text(label);Spacer(minLength:0);Text("\(Int(ceil(value))) / 100").monospacedDigit() }.font(.system(size:9,weight:.semibold))
            GeometryReader { g in
                ZStack(alignment:.leading) { Capsule().fill(ink.opacity(0.12));Capsule().fill(color).frame(width:g.size.width*CGFloat(max(0,min(1,value/100)))) }
            }.frame(height:5)
        }.accessibilityElement(children:.ignore).accessibilityLabel("\(label): \(Int(value)) из 100")
    }
    func header(compact:Bool)->some View {
        VStack(spacing:9) {
            HStack(spacing:compact ? 8 : 14) {
                VStack(alignment:.leading,spacing:3) {
                    Text("ElementalCube").font(.system(size:compact ? 20 : 28,weight:.medium,design:.serif)).padding(6).background(cream.opacity(0.72),in:RoundedRectangle(cornerRadius:10))
                    Text(buildLabel).font(.system(size:7,weight:.semibold)).tracking(1.4).padding(.leading,6).opacity(0.55).accessibilityIdentifier("app.build")
                    if !compact { Text("МАЛЕНЬКИЙ КУБ. БОЛЬШОЙ МИР.").font(.system(size:8,weight:.medium)).tracking(1.55).opacity(0.65) }
                }
                Spacer(minLength:4)
                Button { session.forms=true } label: {
                    HStack(spacing:5) { Image(systemName:session.form.symbol);if !compact { Text(session.form.name) };Image(systemName:"chevron.down").font(.system(size:8)) }.font(.system(size:13,weight:.medium)).padding(10).background(cream.opacity(0.65),in:Capsule())
                }.buttonStyle(.plain).accessibilityLabel("Инвентарь монстра: \(session.form.name)").accessibilityIdentifier("inventory.open")
                if !compact {
                    VStack(spacing:8) {
                        resource("ЗДОРОВЬЕ","heart.fill",value:session.health,color:Color(red:0.76,green:0.33,blue:0.31))
                        resource("МАНА","drop.fill",value:session.energy,color:Color(red:0.2,green:0.56,blue:0.67))
                    }.frame(width:170).padding(.horizontal,12)
                }
                Button { session.reset() } label: { Image(systemName:"arrow.counterclockwise").frame(width:35,height:35) }.buttonStyle(GlassButton()).help("Начать заново · R")
                Button { session.settings=true } label: { Image(systemName:"slider.horizontal.3").frame(width:35,height:35) }.buttonStyle(GlassButton()).help("Настройки прототипа")
            }
            if compact {
                HStack(spacing:18) {
                    resource("ЗДОРОВЬЕ","heart.fill",value:session.health,color:Color(red:0.76,green:0.33,blue:0.31))
                    resource("МАНА","drop.fill",value:session.energy,color:Color(red:0.2,green:0.56,blue:0.67))
                }.padding(.horizontal,10).padding(.vertical,8).background(cream.opacity(0.6),in:RoundedRectangle(cornerRadius:12))
            }
        }
    }
    func controls(compact:Bool,short:Bool)->some View {
        HStack(alignment:.bottom,spacing:18) {
            Button { session.showAbility() } label: {
                VStack(alignment:.leading,spacing:5) {
                    Label("ПАССИВНАЯ",systemImage:session.form.symbol).font(.system(size:9,weight:.medium)).tracking(1).opacity(0.65)
                    Text(session.form.ability).font(.system(size:compact ? 15 : 19,design:.serif))
                }.foregroundStyle(cream).padding(.vertical,12).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(session.form.ability+", описание пассивной способности")
            Spacer(minLength:0)
            VStack(alignment:.trailing,spacing:6) {
                Text(session.aiming ? "ОТПУСТИ, ЧТОБЫ ПРЫГНУТЬ" : (session.grounded ? "НА ОПОРЕ" : (session.inWater ? "В ВОДЕ" : "В ПОЛЁТЕ")))
                    .font(.system(size:9,weight:.medium)).tracking(1).opacity(0.7)
                if !short { Text(controlHint).font(.system(size:compact ? 10 : 12)) }
            }.foregroundStyle(cream).padding(.vertical,12).allowsHitTesting(false)
        }.padding(.top,8).background {
            LinearGradient(colors:[ink.opacity(0),ink.opacity(0.75)],startPoint:.top,endPoint:.bottom).padding(.horizontal,-50).padding(.bottom,-35).padding(.top,-30).allowsHitTesting(false)
        }.overlay(alignment:.top) {
            if session.simulation.time<session.hintUntil {
                Text(session.hint).font(.system(size:11)).foregroundStyle(cream).multilineTextAlignment(.center).padding(12).background(ink.opacity(0.7),in:RoundedRectangle(cornerRadius:16)).offset(y:-55).allowsHitTesting(false)
            }
        }
    }
    var abilityPanel:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack { Label(session.form.ability,systemImage:session.form.symbol).font(.system(size:25,design:.serif));Spacer();Button { session.abilityInfo=false } label:{ Image(systemName:"xmark") }.buttonStyle(.plain) }
                Text("ПАССИВНАЯ СПОСОБНОСТЬ").font(.system(size:10,weight:.bold)).tracking(1.3).opacity(0.6)
                Text(session.form.explanation).font(.system(size:15)).lineSpacing(6)
                Text(String(format:"Расход: %.1f маны/с. При истощении мана восстанавливается до 20, затем способность возобновляется. Здоровье восстанавливается при новой попытке.",session.form.manaCost)).font(.system(size:12)).lineSpacing(4).opacity(0.7)
                Text(session.form == .ice ? "Первая ледяная опора возникает даже при восстановлении маны. Мана нужна для дальнейшего распространения холода." : "Действует автоматически при движении и контакте с миром.").font(.system(size:12)).lineSpacing(4).opacity(0.7)
                Button("В игру") { session.abilityInfo=false }.buttonStyle(PillButton())
            }.padding(28).frame(maxWidth:540).foregroundStyle(ink)
        }.frame(maxWidth:.infinity).background(cream)
    }
    var settingsPanel:some View {
        ScrollView { settingsContents }.background(cream)
    }
    var settingsContents:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Text("Почувствуй физику").font(.system(size:26,design:.serif));Spacer();Button { session.settings=false } label:{ Image(systemName:"xmark") }.buttonStyle(.plain) }
            Text("Настройки тестовой площадки. Мир приостановлен, пока открыта эта панель.").font(.system(size:13)).foregroundStyle(ink.opacity(0.65))
            VStack(alignment:.leading,spacing:8) { HStack { Text("Гравитация");Spacer();Text(String(format:"%0.0f м/с²",session.gravity)).monospacedDigit() };Slider(value:$session.gravity,in:10...26,step:1) }
            VStack(alignment:.leading,spacing:8) { HStack { Text("Чувствительность жеста");Spacer();Text(String(format:"× %0.2f",session.power)).monospacedDigit() };Slider(value:$session.power,in:0.7...1.3,step:0.05) }
            VStack(alignment:.leading,spacing:8) { HStack { Text("Масштаб камеры");Spacer();Text(String(format:"× %.2f",session.zoom)).monospacedDigit() };Slider(value:$session.zoom,in:0.85...1.6,step:0.05) }
            VStack(alignment:.leading,spacing:8) { HStack { Text("Ветер");Spacer();Text(String(format:"%+.1f",session.wind)).monospacedDigit() };Slider(value:$session.wind,in:-3...3,step:0.25) }
            Toggle("Вода и плавучесть",isOn:$session.water)
            Toggle("Показать столкновения и скорость",isOn:$session.debug)
            #if os(iOS)
            Toggle("Отклик вибрацией",isOn:$session.haptics)
            #endif
            HStack { Button("По умолчанию") { session.restoreDefaults() }.buttonStyle(PillButton(filled:false));Spacer();Button("Продолжить") { session.settings=false }.buttonStyle(PillButton()) }
            Text("Metal • Box2D 3.1.1 • физика 120 Гц").font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.45))
            Text("ElementalCube \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") · \(buildLabel)").font(.system(size:11)).foregroundStyle(ink.opacity(0.6))
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
