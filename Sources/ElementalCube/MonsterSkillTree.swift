import SwiftUI
import ElementalCore

private struct SkillPalette {
    let accent:Color
    let background=Color(red:0.07,green:0.18,blue:0.20)
    let paper=Color(red:0.91,green:0.96,blue:0.90)
    init(_ form:ElementForm) {
        switch form {
        case .ice:accent=Color(red:0.49,green:0.86,blue:1)
        case .water:accent=Color(red:0.37,green:0.73,blue:1)
        case .air:accent=Color(red:0.47,green:0.94,blue:0.78)
        case .stone:accent=Color(red:0.87,green:0.77,blue:0.51)
        case .fire:accent=Color(red:1,green:0.63,blue:0.34)
        }
    }
}

/// Two actual prerequisite chains. The paths sit behind native, labelled buttons,
/// so the diagram remains usable with VoiceOver and without motion effects.
struct MonsterSkillTree:View {
    var monster:MonsterRecord
    var wetness:Double=0
    var health:Double=100
    var burning:Double=0
    var select:(SkillNode)->Void
    private var palette:SkillPalette { SkillPalette(monster.form) }
    private let rows:[[SkillNode.Kind?]] = [[.jump,.passive],[.momentum,.mastery],[.doubleJump,.affinity],[.control,nil]]
    var body:some View {
        VStack(spacing:0) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:5) {
                    Text("Дерево навыков").font(.system(size:23,weight:.medium,design:.serif))
                    Text("\(monster.learned.count) ИЗ \(monster.tree.count) ОТКРЫТО").font(.system(size:9,weight:.semibold)).tracking(1.6).opacity(0.5)
                }
                Spacer(minLength:4)
                Label("\(monster.skillPoints)",systemImage:"sparkle").font(.system(size:15,weight:.semibold)).monospacedDigit()
                    .foregroundStyle(palette.accent).padding(.horizontal,13).padding(.vertical,9)
                    .background(palette.accent.opacity(0.1),in:Capsule())
                    .overlay(Capsule().stroke(palette.accent.opacity(0.25)))
                    .accessibilityLabel("Очков навыков: \(monster.skillPoints)")
            }.padding(.horizontal,20).padding(.top,22)
            GeometryReader { geo in
                let w=geo.size.width
                ZStack(alignment:.topLeading) {
                    ornament(width:w)
                    ForEach(0..<2,id:\.self) { branch in
                        let x=w*(branch==0 ? 0.25 : 0.75)
                        connection(from:CGPoint(x:w/2,y:78),to:CGPoint(x:x,y:108),active:true)
                        ForEach(0..<rows.count-1,id:\.self) { row in
                            if let kind=rows[row+1][branch],let node=monster.tree.first(where:{ $0.kind==kind }) {
                            // Bow outwards around the labels, then back into the next node.
                            branchConnection(x:x,y:CGFloat(138+row*126),side:branch==0 ? -1 : 1,
                                             active:monster.learned.contains(node.kind),available:monster.canLearn(node))
                            }
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                    ZStack {
                        Circle().stroke(palette.accent.opacity(0.16),lineWidth:1).frame(width:88,height:88)
                        Circle().stroke(palette.accent.opacity(0.35),lineWidth:1).frame(width:73,height:73)
                        Circle().fill(palette.accent.opacity(0.12)).frame(width:64,height:64)
                        MonsterPortrait(form:monster.form,wetness:wetness,health:health,burning:burning,celebration:monster.learned.count,interactive:true).frame(width:52,height:58).accessibilityIdentifier("portrait.tree")
                    }.position(x:w/2,y:47)
                    ForEach(0..<rows.count,id:\.self) { row in
                        ForEach(0..<2,id:\.self) { branch in
                            if let kind=rows[row][branch],let node=monster.tree.first(where:{ $0.kind==kind }) {
                            skill(node,width:w*0.44)
                                .position(x:w*(branch==0 ? 0.25 : 0.75),y:CGFloat(138+row*126)+28)
                            }
                        }
                    }
                    Text("ДВИЖЕНИЕ").position(x:w*0.22,y:77)
                    Text("СТИХИЯ").position(x:w*0.78,y:77)
                }.font(.system(size:8,weight:.semibold)).tracking(0.8)
            }.frame(height:626)
            HStack(spacing:16) {
                legend("Изучено",symbol:"checkmark.circle.fill",color:palette.accent)
                legend("Доступно",symbol:"plus.circle",color:palette.paper)
                legend("Закрыто",symbol:"lock",color:palette.paper.opacity(0.38))
            }.padding(.bottom,22)
        }
        .foregroundStyle(palette.paper)
        .background {
            RoundedRectangle(cornerRadius:26).fill(LinearGradient(colors:[Color(red:0.12,green:0.27,blue:0.28),palette.background],startPoint:.topLeading,endPoint:.bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius:26).stroke(palette.accent.opacity(0.22)))
        }
        .clipShape(RoundedRectangle(cornerRadius:26))
    }
    private func skill(_ node:SkillNode,width:CGFloat)->some View {
        let known=monster.learned.contains(node.kind),available=monster.canLearn(node)
        let color=known || available ? palette.accent : palette.paper.opacity(0.32)
        return Button { select(node) } label: {
            VStack(spacing:6) {
                ZStack {
                    Circle().fill(palette.background).frame(width:62,height:62)
                    Circle().fill(LinearGradient(colors:[color.opacity(known ? 0.4 : 0.13),color.opacity(0.02)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:58,height:58)
                    Circle().stroke(color.opacity(known ? 0.95 : (available ? 0.7 : 0.3)),lineWidth:known ? 2 : 1).frame(width:58,height:58)
                    Circle().stroke(color.opacity(0.12),lineWidth:1).frame(width:68,height:68)
                    Image(systemName:node.symbol).font(.system(size:25,weight:.light)).foregroundStyle(color)
                    Image(systemName:known ? "checkmark" : (available ? "plus" : "lock.fill"))
                        .font(.system(size:8,weight:.bold)).foregroundStyle(known ? palette.background : color)
                        .frame(width:17,height:17).background(known ? palette.accent : palette.background,in:Circle())
                        .overlay(Circle().stroke(color.opacity(0.55))).offset(x:23,y:23)
                }.frame(height:68).shadow(color:color.opacity(known ? 0.17 : 0),radius:12)
                Text(node.title).font(.system(size:12,weight:.medium)).tracking(0)
                    .multilineTextAlignment(.center).lineLimit(2).frame(height:32).foregroundStyle(palette.paper.opacity(known || available ? 1 : 0.55))
                Text(known ? (node.kind == .passive ? "ПАССИВНАЯ" : "ИЗУЧЕНО") : "\(node.cost) ОЧК.")
                    .font(.system(size:8,weight:.semibold)).tracking(1).foregroundStyle(color)
            }.frame(width:width,height:118).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("skill.\(node.kind.rawValue)")
            .accessibilityLabel(node.title).accessibilityValue(known ? "Изучено" : (available ? "Доступно, \(node.cost) очков" : "Закрыто, \(node.cost) очков"))
    }
    private func connection(from:CGPoint,to:CGPoint,active:Bool)->some View {
        Path { p in p.move(to:from);p.addCurve(to:to,control1:CGPoint(x:from.x,y:to.y-7),control2:CGPoint(x:to.x,y:from.y+8)) }
            .stroke(palette.accent.opacity(active ? 0.5 : 0.1),lineWidth:1)
    }
    private func branchConnection(x:CGFloat,y:CGFloat,side:CGFloat,active:Bool,available:Bool)->some View {
        Path { p in
            p.move(to:CGPoint(x:x+side*30,y:y+5))
            p.addCurve(to:CGPoint(x:x,y:y+96),control1:CGPoint(x:x+side*65,y:y+38),control2:CGPoint(x:x+side*54,y:y+73))
        }.stroke(palette.accent.opacity(active ? 0.8 : (available ? 0.35 : 0.14)),style:StrokeStyle(lineWidth:active ? 1.7 : 1,dash:active || available ? [] : [3,5]))
    }
    private func legend(_ title:String,symbol:String,color:Color)->some View {
        Label(title,systemImage:symbol).font(.system(size:9)).foregroundStyle(color)
    }
    private func ornament(width:CGFloat)->some View {
        ZStack {
            Circle().stroke(palette.accent.opacity(0.045),lineWidth:1).frame(width:width*0.9,height:width*0.9).position(x:width/2,y:240)
            Path { p in p.move(to:CGPoint(x:width/2,y:99));p.addLine(to:CGPoint(x:width/2,y:413)) }.stroke(palette.paper.opacity(0.05),style:StrokeStyle(lineWidth:1,dash:[2,7]))
            ForEach(0..<14,id:\.self) { i in
                Circle().fill(palette.accent.opacity(i%3==0 ? 0.35 : 0.12)).frame(width:i%3==0 ? 2 : 1,height:i%3==0 ? 2 : 1)
                    .position(x:CGFloat((i*71+19)%100)/100*width,y:CGFloat((i*83+33)%440))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SkillDetailView:View {
    @ObservedObject var session:GameSession
    var owner:UUID
    var kind:SkillNode.Kind
    @Environment(\.dismiss) private var dismiss
    private var monster:MonsterRecord { session.inventory.monsters.first { $0.id==owner } ?? session.inventory.selected }
    private var node:SkillNode { monster.tree.first { $0.kind==kind }! }
    private var palette:SkillPalette { SkillPalette(monster.form) }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                HStack {
                    Image(systemName:node.symbol).font(.system(size:29,weight:.light)).foregroundStyle(ink).frame(width:62,height:62)
                        .background(palette.accent.opacity(0.25),in:Circle())
                    Spacer()
                    Button { dismiss() } label:{ Image(systemName:"xmark").frame(width:40,height:40).background(ink.opacity(0.06),in:Circle()) }
                        .buttonStyle(.plain).accessibilityLabel("Закрыть описание").accessibilityIdentifier("skill.detail.close")
                }
                VStack(alignment:.leading,spacing:7) {
                    Text(monster.name.uppercased()+" · "+(kind == .passive ? "ПАССИВНАЯ" : "НАВЫК")).font(.system(size:9,weight:.bold)).tracking(1.4).opacity(0.55)
                    Text(node.title).font(.system(size:28,weight:.medium,design:.serif))
                }
                Text(node.explanation).font(.system(size:15)).lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                if monster.learned.contains(kind) {
                    Label(kind == .passive ? "В пассивном слоте · действует автоматически" : "Изучено этим кубиком",systemImage:"checkmark.circle.fill").font(.system(size:12)).opacity(0.65)
                } else {
                    if let prerequisite=node.prerequisite,let parent=monster.tree.first(where:{ $0.id==prerequisite }),!monster.learned.contains(parent.kind) {
                        Label("Сначала изучи «\(parent.title)»",systemImage:"lock").font(.system(size:12)).opacity(0.6)
                    } else if monster.skillPoints<node.cost {
                        Text("Найди ещё \(node.cost-monster.skillPoints) очк. навыков в кристаллах мира.").font(.system(size:12)).opacity(0.6)
                    }
                    Button { session.learn(node,for:owner);dismiss() } label: {
                        HStack { Text("Изучить");Spacer();Label("\(node.cost) очк.",systemImage:"sparkle") }.padding(.horizontal,6).frame(maxWidth:.infinity)
                    }.buttonStyle(PillButton()).disabled(!monster.canLearn(node)).opacity(monster.canLearn(node) ? 1 : 0.4).accessibilityIdentifier("skill.learn")
                }
            }.padding(26).frame(maxWidth:520,alignment:.leading).foregroundStyle(ink)
        }.frame(maxWidth:.infinity).background(cream)
    }
}
