import SwiftUI
import ElementalCore

extension WorldMap {
    var mapColor:Color {
        switch self {
        case .shore:return Color(red:0.27,green:0.53,blue:0.48)
        case .glacier:return Color(red:0.29,green:0.57,blue:0.72)
        case .forge:return Color(red:0.73,green:0.38,blue:0.23)
        case .meadow:return Color(red:0.32,green:0.55,blue:0.32)
        case .grotto:return Color(red:0.42,green:0.43,blue:0.57)
        case .windridge:return Color(red:0.34,green:0.60,blue:0.61)
        case .sanctuary:return Color(red:0.64,green:0.49,blue:0.25)
        }
    }
}

struct JourneyMapView:View {
    let adventure:AdventureState
    @Binding var selection:WorldMap
    var body:some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx,size in
                    func point(_ map:WorldMap)->CGPoint { let p=map.routePosition;return CGPoint(x:CGFloat(p.x)*size.width,y:CGFloat(p.y)*size.height) }
                    // Quiet contours and mountain/forest silhouettes support
                    // the connected route, rather than stand in for buttons.
                    for i in 0..<8 {
                        let y=CGFloat(i)*83+21
                        var p=Path();p.move(to:CGPoint(x:-30,y:y))
                        p.addCurve(to:CGPoint(x:size.width+30,y:y+30),control1:CGPoint(x:size.width*0.3,y:y-65),control2:CGPoint(x:size.width*0.65,y:y+90))
                        ctx.stroke(p,with:.color(ink.opacity(0.045)),lineWidth:1)
                    }
                    for map in WorldMap.allCases {
                        for next in CampaignRoute.next(map) {
                            let a=point(map),b=point(next),mid=(a.y+b.y)/2
                            var p=Path();p.move(to:a);p.addCurve(to:b,control1:CGPoint(x:a.x,y:mid),control2:CGPoint(x:b.x,y:mid))
                            ctx.stroke(p,with:.color(.white.opacity(0.7)),lineWidth:12)
                            let done=adventure.completedMaps.contains(map)
                            ctx.stroke(p,with:.color(done ? Color(red:0.71,green:0.57,blue:0.28) : ink.opacity(0.18)),style:StrokeStyle(lineWidth:done ? 3.5 : 2,dash:done ? [] : [3,7]))
                        }
                    }
                    // River through the middle of the two route branches.
                    var river=Path();river.move(to:CGPoint(x:size.width*0.50,y:165));river.addCurve(to:CGPoint(x:size.width*0.48,y:395),control1:CGPoint(x:size.width*0.37,y:250),control2:CGPoint(x:size.width*0.66,y:320))
                    ctx.stroke(river,with:.color(Color.cyan.opacity(0.09)),style:StrokeStyle(lineWidth:18,lineCap:.round))
                }.accessibilityHidden(true)
                ForEach(WorldMap.allCases) { map in
                    node(map).position(x:geo.size.width*CGFloat(map.routePosition.x),y:geo.size.height*CGFloat(map.routePosition.y))
                }
            }.background(LinearGradient(colors:[.white.opacity(0.35),Color(red:0.84,green:0.91,blue:0.79).opacity(0.5)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:28))
                .overlay(RoundedRectangle(cornerRadius:28).stroke(.white.opacity(0.6)))
        }.frame(height:630).accessibilityElement(children:.contain).accessibilityIdentifier("journey.map")
    }
    private func node(_ map:WorldMap)->some View {
        let done=adventure.completedMaps.contains(map),available=adventure.canVisit(map),chosen=selection==map
        return Button { withAnimation(.easeOut(duration:0.2)) { selection=map } } label: {
            VStack(spacing:7) {
                ZStack(alignment:.bottomTrailing) {
                    Circle().fill(chosen ? map.mapColor.opacity(0.16) : .white.opacity(0.85)).frame(width:62,height:62)
                        .overlay(Circle().stroke(chosen ? map.mapColor : ink.opacity(0.12),lineWidth:chosen ? 3 : 1))
                    Image(systemName:available ? map.symbol : "lock.fill").font(.system(size:24,weight:.light)).foregroundStyle(available ? map.mapColor : ink.opacity(0.3)).frame(width:62,height:62)
                    if done { Image(systemName:"checkmark.circle.fill").font(.system(size:19)).foregroundStyle(cream,map.mapColor).offset(x:2,y:2) }
                }
                Text(map.name).font(.system(size:11,weight:chosen ? .bold : .medium)).multilineTextAlignment(.center).lineLimit(2).frame(width:125,height:29)
                if let record=adventure.record(for:map),record.medal != .none {
                    HStack(spacing:3) { Image(systemName:"medal.fill");Text(record.bestTime.map(formatDuration) ?? "") }.font(.system(size:8,weight:.semibold)).foregroundStyle(map.mapColor)
                }
            }.foregroundStyle(ink.opacity(available ? 1 : 0.5)).frame(width:130,height:111).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("map."+map.rawValue)
            .accessibilityLabel(map.name).accessibilityValue(done ? "Пройдено" : (available ? "Доступно" : "Закрыто"))
    }
}

func formatDuration(_ seconds:Double)->String {
    let value=max(0,seconds)
    return String(format:"%02d:%04.1f",Int(value)/60,value.truncatingRemainder(dividingBy:60))
}

struct RouteFinishView:View {
    @ObservedObject var session:GameSession
    let receipt:FinishReceipt
    var body:some View {
        VStack(spacing:0) {
            ScrollView {
                VStack(spacing:18) {
                    Text(receipt.map == .sanctuary ? "МАЯК СНОВА ГОРИТ" : "ЕЩЁ ШАГ ПО ПУТИ").font(.system(size:9,weight:.bold)).tracking(2).opacity(0.55)
                    MonsterPortrait(form:session.form,secondary:session.inventory.selected.secondaryForm,seed:session.inventory.selected.appearanceSeed,stage:session.inventory.selected.evolutionStage,celebration:3,interactive:true).frame(width:95,height:106)
                    Text(receipt.map.name+"\nпройден!").font(.system(size:30,weight:.medium,design:.serif)).multilineTextAlignment(.center).accessibilityIdentifier("finish.title")
                    if let seconds=receipt.seconds {
                        HStack(spacing:9) { Image(systemName:"stopwatch");Text(formatDuration(seconds)).monospacedDigit();if receipt.newBest { Text("НОВЫЙ РЕКОРД").font(.system(size:8,weight:.bold)).tracking(1) } }.font(.system(size:21,weight:.medium,design:.serif))
                    }
                    if receipt.medal != .none {
                        Label(receipt.medal.name,systemImage:"medal.fill").font(.system(size:13,weight:.semibold)).foregroundStyle(receipt.map.mapColor)
                    } else {
                        Text(receipt.standardPhysics ? "Золото до "+formatDuration(receipt.map.times.gold)+" · серебро до "+formatDuration(receipt.map.times.silver) : "Свободная физика: находки и финиш сохранены, рекорд скорости не засчитывается.").font(.system(size:11)).lineSpacing(4).multilineTextAlignment(.center).opacity(0.65)
                    }
                    HStack(spacing:25) {
                        Label("\(receipt.crystals) / \(receipt.crystalTotal)",systemImage:"diamond.fill").foregroundStyle(Color(red:0.2,green:0.55,blue:0.65))
                        Label("\(receipt.coins) / \(receipt.coinTotal)",systemImage:"circle.inset.filled").foregroundStyle(Color(red:0.64,green:0.47,blue:0.2))
                    }.font(.system(size:15,weight:.semibold)).accessibilityIdentifier("finish.finds")
                    VStack(spacing:9) {
                        reward("Эфир за первый финиш",receipt.aetherAward,"diamond.fill")
                        reward("Монеты за этап",receipt.clearGold,"circle.inset.filled")
                        reward("Улучшение медали скорости",receipt.speedGold,"medal.fill",zero:receipt.medal == .none ? "Без бонуса" : "Уже получено")
                    }.padding(16).background(ink.opacity(0.045),in:RoundedRectangle(cornerRadius:18)).accessibilityIdentifier("finish.rewards")
                    Text("Награды сохранены. Монеты скорости выдаются только за улучшение медали; повтор того же результата ничего не дублирует.").font(.system(size:11)).lineSpacing(4).opacity(0.6)
                    if !CampaignRoute.next(receipt.map).isEmpty {
                        Text("Путь продолжается").font(.system(size:23,design:.serif))
                        ForEach(CampaignRoute.next(receipt.map)) { map in
                            Button { session.play(map) } label: { HStack { Image(systemName:map.symbol);Text(map.name);Spacer();Image(systemName:"arrow.right") }.frame(maxWidth:.infinity) }.buttonStyle(PillButton()).accessibilityIdentifier("finish.next."+map.rawValue)
                        }
                    } else { Text("Ты прошёл путь до маяка. На карте ещё можно исследовать другую ветку и улучшить медали.").font(.system(size:13)).lineSpacing(5).multilineTextAlignment(.center) }
                }.padding(25).frame(maxWidth:520).frame(maxWidth:.infinity)
            }
            HStack(spacing:12) {
                Button("Карта пути") { session.showHome() }.buttonStyle(PillButton()).accessibilityIdentifier("finish.route")
                Button("Ещё раз") { session.reset() }.buttonStyle(PillButton(filled:false)).accessibilityIdentifier("finish.retry")
            }.padding(18).frame(maxWidth:.infinity).background(cream)
        }.foregroundStyle(ink).background(cream).accessibilityIdentifier("finish.panel")
    }
    private func reward(_ title:String,_ amount:Int,_ icon:String,zero:String="Уже получено")->some View {
        HStack { Label(title,systemImage:icon);Spacer();Text(amount>0 ? "+\(amount)" : zero).fontWeight(.semibold).monospacedDigit() }.font(.system(size:12))
    }
}
