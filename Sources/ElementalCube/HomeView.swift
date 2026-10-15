import SwiftUI
import ElementalCore

struct HomeView:View {
    @ObservedObject var session:GameSession
    @State private var picked:MonsterRecord?
    @State private var recruiting=false
    @State private var secondID:UUID?
    @State private var mergePreparation:MergePlan?
    @State private var pendingBirth:MonsterRecord?
    @State private var newborn:MonsterRecord?
    private var monster:MonsterRecord { session.adventure.started ? session.inventory.selected : session.starter }
    private var partner:MonsterRecord? { session.adventure.collection.first { $0.id==secondID && $0.id != monster.id } ?? session.adventure.collection.first { $0.id != monster.id } }
    var body:some View {
        GeometryReader { geo in
            VStack(spacing:0) {
                VStack(spacing:16) {
                    HStack(alignment:.top) {
                        VStack(alignment:.leading,spacing:5) {
                            Text("ElementalCube").font(.system(size:geo.size.width<500 ? 30 : 40,weight:.medium,design:.serif))
                            Text("МАЛЕНЬКИЙ КУБ. БОЛЬШОЙ МИР.").font(.system(size:8,weight:.bold)).tracking(1.8).opacity(0.5)
                        }
                        Spacer(minLength:6)
                        if session.adventure.started { wallet }
                    }
                    if session.adventure.started {
                        Picker("Главный экран",selection:$session.homeTab) {
                            ForEach(HomeTab.allCases,id:\.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("home.tabs")
                    }
                }.padding(.horizontal,24).padding(.vertical,16).frame(maxWidth:850).frame(maxWidth:.infinity)
                ScrollViewReader { proxy in
                ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    Color.clear.frame(height:1).id("home.top")
                    if !session.adventure.started { starter }
                    else {
                        if !session.homeMessage.isEmpty {
                            Label(session.homeMessage,systemImage:"sparkles").font(.system(size:13)).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(mint.opacity(0.45),in:RoundedRectangle(cornerRadius:16))
                        }
                        switch session.homeTab {
                        case .journey:journey
                        case .collection:collection
                        case .laboratory:laboratory
                        }
                    }
                    HStack {
                        Text("СОЗДАНО ДЛЯ МАЛЕНЬКИХ ОТКРЫТИЙ").font(.system(size:8,weight:.medium)).tracking(1.4)
                        Spacer()
                        Text("АЛЬФА · "+(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "DEV")).font(.system(size:8)).monospacedDigit()
                    }.opacity(0.38).padding(.top,12)
                }.padding(24).frame(maxWidth:850)
                    .frame(maxWidth:.infinity)
                }.onChange(of:session.homeTab) { _ in proxy.scrollTo("home.top",anchor:.top) }
                }
            }.foregroundStyle(ink).background {
                LinearGradient(colors:[cream,Color(red:0.85,green:0.94,blue:0.86)],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
            }
        }
        .sheet(isPresented:$session.forms) { MonsterInventoryView(session:session) }
        .sheet(item:$picked) { candidate in pickDetail(candidate) }
        .sheet(item:$newborn) { child in birth(child) }
        .sheet(item:$mergePreparation,onDismiss:{
            if let child=pendingBirth { pendingBirth=nil;newborn=child }
        }) { plan in
            MergePreparationView(session:session,plan:plan) { child in pendingBirth=child;mergePreparation=nil }
                #if os(iOS)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
                #else
                .frame(width:620,height:760)
                #endif
        }
    }
    private var wallet:some View {
        Label("\(session.adventure.coins)",systemImage:"diamond.fill").font(.system(size:17,weight:.semibold)).monospacedDigit()
            .padding(.horizontal,15).padding(.vertical,12).background(.white.opacity(0.55),in:Capsule())
            .accessibilityLabel("Эфир: \(session.adventure.coins)").accessibilityIdentifier("home.wallet")
    }
    private var starter:some View {
        VStack(alignment:.leading,spacing:20) {
            VStack(alignment:.leading,spacing:9) {
                Text("С кого начнётся\nтвоя история?").font(.system(size:32,weight:.medium,design:.serif))
                Text("Выбери первого друга или доверься маленькому чуду.").font(.system(size:14)).lineSpacing(4).opacity(0.65)
            }.padding(.top,8)
            hero(session.starter,compact:true)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:5),spacing:6) {
                ForEach(session.inventory.monsters.prefix(5)) { cube in
                    Button { session.starter=cube } label: {
                        VStack(spacing:6) {
                            MonsterPortrait(form:cube.form,secondary:cube.secondaryForm,seed:cube.appearanceSeed,stage:cube.evolutionStage).frame(width:33,height:38)
                            Text(cube.form.name).font(.system(size:10,weight:.medium)).lineLimit(1).minimumScaleFactor(0.75)
                        }.padding(.vertical,10).frame(maxWidth:.infinity).background(.white.opacity(cube.id==session.starter.id ? 0.9 : 0.4),in:RoundedRectangle(cornerRadius:15))
                            .overlay(RoundedRectangle(cornerRadius:15).stroke(ink.opacity(cube.id==session.starter.id ? 0.5 : 0.08)))
                            .contentShape(RoundedRectangle(cornerRadius:15))
                    }.buttonStyle(.plain).accessibilityIdentifier("starter."+cube.form.rawValue)
                }
            }
            Button { session.randomizeStarter() } label: { Label("Случайный пушистик",systemImage:"dice").frame(maxWidth:.infinity) }
                .buttonStyle(PillButton(filled:false)).accessibilityIdentifier("starter.random")
            Button { session.beginJourney() } label: { HStack { Text("Начать путь");Spacer();Image(systemName:"arrow.right") }.frame(maxWidth:.infinity) }
                .buttonStyle(PillButton()).accessibilityIdentifier("starter.begin")
            Text("Первый выбор бесплатный. Потом смена друга стоит 2 эфира, новый кубик — 4. Эфир находишь в кристаллах мира.").font(.system(size:12)).lineSpacing(4).opacity(0.55)
        }
    }
    private func hero(_ cube:MonsterRecord,compact:Bool=false)->some View {
        VStack(spacing:8) {
            MonsterPortrait(form:cube.form,secondary:cube.secondaryForm,seed:cube.appearanceSeed,stage:cube.evolutionStage,celebration:cube.evolutionStage,interactive:true).frame(width:compact ? 110 : 155,height:compact ? 124 : 174).accessibilityIdentifier("home.portrait")
            Text(cube.name).font(.system(size:compact ? 26 : 32,weight:.medium,design:.serif))
            Text(cube.typeName+(cube.generation>0 ? " · поколение \(cube.generation)" : "")).font(.system(size:11,weight:.semibold)).tracking(1.5).opacity(0.5)
            HStack(spacing:6) {
                ForEach(0..<3,id:\.self) { i in Image(systemName:i<cube.evolutionStage ? "star.fill" : "star").foregroundStyle(ink.opacity(i<cube.evolutionStage ? 0.8 : 0.18)) }
                Text(cube.stageName).padding(.leading,5)
            }.font(.system(size:11)).padding(.top,6)
        }.frame(maxWidth:.infinity).padding(.vertical,compact ? 14 : 24)
            .background(.white.opacity(0.38),in:RoundedRectangle(cornerRadius:30))
            .overlay(RoundedRectangle(cornerRadius:30).stroke(.white.opacity(0.6)))
    }
    private var journey:some View {
        VStack(alignment:.leading,spacing:20) {
            hero(monster)
            HStack(spacing:10) {
                Button { session.play(session.adventure.map) } label: { Label("Продолжить",systemImage:"play.fill").frame(maxWidth:.infinity) }.buttonStyle(PillButton()).accessibilityIdentifier("home.play")
                Button { session.forms=true } label: { Image(systemName:"square.grid.2x2").frame(width:25) }.buttonStyle(PillButton(filled:false)).accessibilityLabel("Инвентарь и навыки").accessibilityIdentifier("home.inventory")
            }
            Text("Куда отправимся?").font(.system(size:26,weight:.medium,design:.serif))
            ForEach(WorldMap.allCases) { map in
                Button { session.play(map) } label: {
                    VStack(alignment:.leading,spacing:12) {
                        HStack {
                            Label(map.name,systemImage:map.symbol).font(.system(size:20,weight:.medium,design:.serif))
                            Spacer()
                            Image(systemName:session.adventure.completedMaps.contains(map) ? "checkmark.seal.fill" : "arrow.up.right")
                        }
                        Text(map.subtitle).font(.system(size:12)).opacity(0.65)
                        MapPreview(map:map).frame(height:90).clipShape(RoundedRectangle(cornerRadius:12))
                        Text("12 кристаллов · +6 эфира за первое прохождение").font(.system(size:10)).opacity(0.5)
                    }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.47),in:RoundedRectangle(cornerRadius:22)).contentShape(RoundedRectangle(cornerRadius:22))
                }.buttonStyle(.plain).accessibilityIdentifier("map."+map.rawValue)
            }
        }
    }
    private var collection:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Твои маленькие миры").font(.system(size:29,weight:.medium,design:.serif))
            Text("Каждый хранит собственные навыки, находки и снаряжение.").font(.system(size:13)).opacity(0.6)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145))],spacing:12) {
                ForEach(session.adventure.collection) { cube in
                    monsterCard(cube,caption:cube.id==monster.id ? "С тобой" : "Сменить · 2 эфира") { recruiting=false;picked=cube }
                }
            }
            Text("Познакомиться").font(.system(size:25,design:.serif)).padding(.top,10)
            Text("Новый друг · 4 эфира. Можно выбрать стихию или сначала посмотреть случайного кубика.").font(.system(size:12)).lineSpacing(3).opacity(0.6)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145))],spacing:12) {
                ForEach(session.recruitCandidates) { cube in monsterCard(cube,caption:"Новый друг · 4") { recruiting=true;picked=cube } }
            }
            Button { recruiting=true;picked=MonsterRecord.randomStarter() } label: { Label("Случайный друг",systemImage:"dice").frame(maxWidth:.infinity) }.buttonStyle(PillButton(filled:false)).accessibilityIdentifier("collection.random")
        }
    }
    private func monsterCard(_ cube:MonsterRecord,caption:String,action:@escaping()->Void)->some View {
        Button(action:action) {
            VStack(spacing:7) {
                MonsterPortrait(form:cube.form,secondary:cube.secondaryForm,seed:cube.appearanceSeed,stage:cube.evolutionStage,celebration:cube.evolutionStage).frame(width:82,height:92)
                Text(cube.name).font(.system(size:18,design:.serif)).lineLimit(1)
                Text(caption).font(.system(size:10)).opacity(0.6)
            }.frame(maxWidth:.infinity).padding(15).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:22)).contentShape(RoundedRectangle(cornerRadius:22))
        }.buttonStyle(.plain).accessibilityIdentifier("collection."+cube.id.uuidString)
    }
    private func pickDetail(_ cube:MonsterRecord)->some View {
        let price=recruiting ? AdventureState.recruitPrice : session.adventure.price(toSelect:cube.id)
        return ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack { Text(recruiting ? "Новый друг" : "Маленькая история").font(.system(size:25,design:.serif));Spacer();Button { picked=nil } label: { Image(systemName:"xmark").frame(width:40,height:40) }.buttonStyle(.plain) }
                hero(cube)
                Text(cube.hybridStyle?.explanation ?? cube.form.explanation).font(.system(size:14)).lineSpacing(4)
                Text("В кошельке: \(session.adventure.coins) эфира").font(.system(size:12)).opacity(0.6)
                Button {
                    let accepted=recruiting ? session.recruit(cube) : session.selectMonster(cube.id)
                    if accepted { picked=nil }
                } label: { Text(price==0 ? "Уже с тобой" : "\(recruiting ? "Познакомиться" : "Сменить кубика") · \(price) эфира").frame(maxWidth:.infinity) }
                    .buttonStyle(PillButton()).disabled(price==0 || session.adventure.coins<price).opacity(price==0 || session.adventure.coins<price ? 0.4 : 1).accessibilityIdentifier("collection.confirm")
            }.padding(24).frame(maxWidth:600)
        }.frame(maxWidth:.infinity).background(cream).foregroundStyle(ink)
    }
    private var laboratory:some View {
        VStack(alignment:.leading,spacing:20) {
            hero(monster)
            Text("Расти в своём ритме").font(.system(size:29,design:.serif))
            if monster.inheritance != nil {
                Button { newborn=monster } label: { Label("Наследие этого поколения",systemImage:"leaf").frame(maxWidth:.infinity) }
                    .buttonStyle(PillButton(filled:false)).accessibilityIdentifier("lineage.report")
            }
            Text("Эволюция сохраняет личность и дерево. Каждая ступень добавляет 0,8 м/с к силе прицельного прыжка и новый блеск облику.").font(.system(size:13)).lineSpacing(4).opacity(0.65)
            if monster.evolutionStage<3 {
                Label("Кристаллы: \(monster.crystals.count) / \(monster.evolutionRequirement)",systemImage:"diamond").font(.system(size:14))
                Button { session.evolve() } label: { Label("Эволюция · \(monster.evolutionCost) эфира",systemImage:"sparkles").frame(maxWidth:.infinity) }.buttonStyle(PillButton()).disabled(!session.adventure.canEvolve).opacity(session.adventure.canEvolve ? 1 : 0.4).accessibilityIdentifier("evolution.confirm")
            } else { Label("Хранитель: все три ступени раскрыты",systemImage:"star.fill").font(.system(size:14)) }
            Divider().padding(.vertical,12)
            Text("Два характера. Новое чудо.").font(.system(size:27,design:.serif))
            if let other=partner {
                let future=FormCatalog.result(monster.currentForm,other.currentForm)
                HStack {
                    VStack { MonsterPortrait(form:monster.form,secondary:monster.secondaryForm,seed:monster.appearanceSeed,stage:monster.evolutionStage).frame(width:92,height:105);Text(monster.name).font(.system(size:12)).lineLimit(1) }
                    Spacer();Image(systemName:"sparkles").font(.system(size:24));Spacer()
                    Menu {
                        ForEach(session.adventure.collection.filter { $0.id != monster.id }) { cube in Button(cube.name) { secondID=cube.id } }
                    } label: { VStack { MonsterPortrait(form:other.form,secondary:other.secondaryForm,seed:other.appearanceSeed,stage:other.evolutionStage).frame(width:92,height:105);Label(other.name,systemImage:"chevron.down").font(.system(size:12)).lineLimit(1) } }
                }.padding(18).background(.white.opacity(0.45),in:RoundedRectangle(cornerRadius:24))
                Text(future.map { "Новая форма: "+$0.name } ?? "Это сочетание пока не поддерживается").font(.system(size:22,design:.serif)).accessibilityIdentifier("merge.preview.form")
                if let future=future { Text(future.properties.joined(separator:" · ")).font(.system(size:13)).lineSpacing(4).opacity(0.65) }
                Text("Твоя линия получит новое поколение. Донор останется в коллекции. В каждом блоке наследия выбираются ровно по две карточки из четырёх у каждого; несовместимые приёмы теряются.").font(.system(size:12)).lineSpacing(4).opacity(0.6)
                Button {
                    session.saveInventory();mergePreparation=session.adventure.prepareMerge(monster.id,other.id)
                } label: { Label("Подготовить слияние",systemImage:"arrow.triangle.merge").frame(maxWidth:.infinity) }
                    .buttonStyle(PillButton()).disabled(session.adventure.coins<4 || future==nil).opacity(session.adventure.coins<4 || future==nil ? 0.4 : 1).accessibilityIdentifier("merge.begin")
                Text("Стоимость — 4 эфира. Фиксаторов наследия: \(monster.inheritanceLocks).").font(.system(size:11)).opacity(0.6)
            } else {
                Text("Для мерджа нужны два друга из твоей коллекции.").font(.system(size:14)).opacity(0.6)
                Button("Познакомиться с кубиком") { session.homeTab = .collection }.buttonStyle(PillButton(filled:false))
            }
            let history=session.adventure.archivedGenerations.filter { $0.lineageID==monster.lineageID }
            if !history.isEmpty {
                DisclosureGroup("Родословная · \(history.count) прежних поколений") {
                    VStack(alignment:.leading,spacing:12) {
                        ForEach(history.reversed()) { old in
                            HStack(spacing:12) {
                                MonsterPortrait(form:old.form,secondary:old.secondaryForm,seed:old.appearanceSeed,stage:old.evolutionStage).frame(width:45,height:52)
                                VStack(alignment:.leading,spacing:5) { Text(old.name).font(.system(size:16,design:.serif));Text(old.typeName+" · поколение \(old.generation)").font(.system(size:11)).opacity(0.6) }
                            }
                        }
                        Text("Архив хранит историю линии. Прежние поколения нельзя выбрать для игры или слияния.").font(.system(size:11)).lineSpacing(3).opacity(0.6)
                    }.padding(.top,12)
                }.font(.system(size:14)).accessibilityIdentifier("lineage.archive")
            }
        }
    }
    private func birth(_ child:MonsterRecord)->some View {
        MergeResultView(child:child) { newborn=nil;session.homeTab = .journey }
            #if os(iOS)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
            #else
            .frame(width:620,height:760)
            #endif
    }

}

private struct MapPreview:View {
    let map:WorldMap
    var body:some View {
        Canvas { context,size in
            let world=map.definition,b=world.bounds
            let color:Color=map == .glacier ? Color(red:0.39,green:0.62,blue:0.73) : (map == .forge ? Color(red:0.65,green:0.43,blue:0.33) : ink.opacity(0.65))
            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(color.opacity(0.08)))
            func point(_ v:Vec)->CGPoint { CGPoint(x:CGFloat((v.x-b.minX)/b.width)*size.width,y:CGFloat(1-(v.y-b.minY)/b.height)*size.height) }
            for p in world.terrain {
                let top=point(Vec(p.x-p.width/2,p.y+p.height/2))
                let rect=CGRect(x:top.x,y:top.y,width:CGFloat(p.width/b.width)*size.width,height:max(1,CGFloat(p.height/b.height)*size.height))
                context.fill(Path(roundedRect:rect,cornerRadius:1),with:.color(color.opacity(0.65)))
            }
            for shard in world.shards { let p=point(shard);context.fill(Path(ellipseIn:CGRect(x:p.x-1.5,y:p.y-1.5,width:3,height:3)),with:.color(Color.cyan)) }
            let goal=point(world.goal)
            context.fill(Path(ellipseIn:CGRect(x:goal.x-3,y:goal.y-3,width:6,height:6)),with:.color(Color(red:0.89,green:0.66,blue:0.26)))
        }.accessibilityHidden(true)
    }
}
