import SwiftUI
import ElementalCore

struct MonsterSkillTree:View {
    var monster:MonsterRecord
    var wetness:Double=0
    var health:Double=100
    var burning:Double=0
    var select:(SkillNode)->Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var palette:SkillPalette { SkillPalette(monster.form) }
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:14) {
                MonsterPortrait(form:monster.form,secondary:monster.secondaryForm,seed:monster.appearanceSeed,stage:monster.evolutionStage,wetness:wetness,health:health,burning:burning,celebration:monster.learned.count,interactive:true)
                    .frame(width:66,height:76).accessibilityIdentifier("portrait.tree")
                VStack(alignment:.leading,spacing:7) {
                    Text(monster.isHybrid ? "Путь гибрида" : "Дерево навыков").font(.system(size:23,weight:.medium,design:.serif))
                    Text("\(monster.learned.count) из \(monster.tree.count) изучено").font(.system(size:12)).foregroundStyle(palette.paper.opacity(0.6))
                    HStack(spacing:4) { ForEach(0..<monster.tree.count,id:\.self) { i in Capsule().fill(i<monster.learned.count ? palette.accent : palette.paper.opacity(0.12)).frame(width:12,height:3) } }
                }
                Spacer(minLength:0)
                VStack(spacing:3) { Text("\(monster.skillPoints)").font(.system(size:26,weight:.medium,design:.serif)).monospacedDigit();Text("ОЧК.").font(.system(size:8,weight:.bold)).tracking(1.2) }
                    .foregroundStyle(palette.accent).frame(width:53,height:62).background(palette.accent.opacity(0.09),in:RoundedRectangle(cornerRadius:16))
                    .overlay(RoundedRectangle(cornerRadius:16).stroke(palette.accent.opacity(0.25)))
                    .accessibilityElement(children:.ignore).accessibilityLabel("Очков навыков: \(monster.skillPoints)")
            }
            Text("Свайп вверх уже прыгает бесплатно. Новые приёмы изучаются здесь, улучшения действуют автоматически.")
                .font(.system(size:12)).lineSpacing(4).foregroundStyle(palette.paper.opacity(0.65)).fixedSize(horizontal:false,vertical:true)
            if typeSize.isAccessibilitySize {
                branch(SkillCatalog.movement,title:"Движение",subtitle:"От первого прицела до руля в полёте")
                branch(SkillCatalog.elemental,title:monster.isHybrid ? "Природа гибрида" : "Сила стихии",subtitle:monster.passiveName)
            } else {
                HStack(alignment:.top,spacing:14) {
                    branch(SkillCatalog.movement,title:"Движение",subtitle:"Новые приёмы")
                    branch(SkillCatalog.elemental,title:monster.isHybrid ? "Гибрид" : "Стихия",subtitle:"Растущая сила")
                }
            }
            HStack(alignment:.top,spacing:9) {
                Image(systemName:"diamond.fill").font(.system(size:12)).foregroundStyle(palette.accent)
                Text("Первая находка каждого кристалла даёт этому кубику 1 очко. Изученные навыки сохраняются вместе с ним.")
                    .font(.system(size:11)).lineSpacing(4).foregroundStyle(palette.paper.opacity(0.58))
            }
        }.padding(20).foregroundStyle(palette.paper)
            .background {
                RoundedRectangle(cornerRadius:26).fill(LinearGradient(colors:[Color(red:0.11,green:0.25,blue:0.27),palette.background],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .overlay(alignment:.topTrailing) { Circle().fill(palette.accent.opacity(0.06)).frame(width:190,height:190).blur(radius:40).offset(x:70,y:-60) }
                    .overlay(RoundedRectangle(cornerRadius:26).stroke(palette.accent.opacity(0.18)))
            }.clipShape(RoundedRectangle(cornerRadius:26))
    }
    private func branch(_ kinds:[SkillNode.Kind],title:String,subtitle:String)->some View {
        VStack(spacing:0) {
            VStack(spacing:5) { Text(title.uppercased()).font(.system(size:10,weight:.bold)).tracking(1.3);Text(subtitle).font(.system(size:10)).foregroundStyle(palette.paper.opacity(0.45)) }.frame(height:39)
            ForEach(Array(kinds.enumerated()),id:\.element) { index,kind in
                if let node=monster.tree.first(where:{ $0.kind==kind }) {
                    if index>0 {
                        let unlocked=monster.learned.contains(kind) || monster.canLearn(node)
                        VStack(spacing:3) { Capsule().fill(palette.accent.opacity(unlocked ? 0.65 : 0.18)).frame(width:1.5,height:11);Circle().fill(palette.accent.opacity(unlocked ? 0.7 : 0.2)).frame(width:3,height:3) }.frame(height:23).accessibilityHidden(true)
                    }
                    skill(node)
                }
            }
        }.frame(maxWidth:.infinity)
    }
    private func skill(_ node:SkillNode)->some View {
        let known=monster.learned.contains(node.kind),available=monster.canLearn(node)
        let inherited=monster.inheritedPotential.contains(node.kind)
        let prerequisite=node.prerequisite.flatMap { id in monster.tree.first { $0.id==id } }
        let locked=prerequisite.map { !monster.learned.contains($0.kind) } ?? false
        return Button { select(node) } label: {
            VStack(spacing:9) {
                HStack {
                    Text(node.kind == .passive ? "ПАССИВНАЯ" : (node.kind == .jump || node.kind == .doubleJump ? "ПРИЁМ" : "УЛУЧШЕНИЕ"))
                        .font(.system(size:7,weight:.bold)).tracking(0.8).foregroundStyle(palette.paper.opacity(0.45))
                    Spacer(minLength:0)
                    if known { Label("ИЗУЧЕН",systemImage:"checkmark.seal.fill").font(.system(size:8,weight:.heavy)).foregroundStyle(palette.background).padding(.horizontal,7).padding(.vertical,5).background(palette.accent,in:Capsule()) }
                    else { Image(systemName:locked ? "lock.fill" : "plus").font(.system(size:10,weight:.semibold)).foregroundStyle(available ? palette.accent : palette.paper.opacity(0.35)) }
                }
                SkillArtwork(monster:monster,kind:node.kind,size:80).saturation(locked ? 0.25 : 1).opacity(locked ? 0.5 : 1)
                    .overlay(alignment:.bottomTrailing) { if known { Image(systemName:"checkmark.circle.fill").font(.system(size:23,weight:.bold)).foregroundStyle(palette.background,palette.accent).offset(x:8,y:4) } }
                Text(node.title).font(.system(size:13,weight:.semibold)).multilineTextAlignment(.center).lineLimit(2).frame(maxWidth:.infinity,minHeight:34)
                    .foregroundStyle(palette.paper.opacity(locked ? 0.78 : 1))
                Text(node.summary).font(.system(size:10)).lineSpacing(2).multilineTextAlignment(.center).lineLimit(3).frame(maxWidth:.infinity,minHeight:35)
                    .foregroundStyle(palette.paper.opacity(0.55))
                Text(known ? (inherited ? "Унаследован" : "Изучено") : (locked ? (inherited ? "Ждёт основы" : "После предыдущего") : (available ? "Изучить · \(node.cost) очк." : "Нужно \(node.cost) очк.")))
                    .font(.system(size:10,weight:known || available ? .semibold : .regular)).foregroundStyle(known || available ? palette.accent : palette.paper.opacity(0.4))
                    .padding(.horizontal,9).frame(height:25).background(palette.accent.opacity(known ? 0.12 : (available ? 0.08 : 0.025)),in:Capsule())
            }.padding(12).frame(maxWidth:.infinity,minHeight:230,alignment:.top)
                .background(RoundedRectangle(cornerRadius:20).fill(palette.paper.opacity(known ? 0.14 : 0.023)))
                .overlay(RoundedRectangle(cornerRadius:20).stroke(palette.accent.opacity(known ? 0.95 : (available ? 0.3 : 0.10)),lineWidth:known ? 2.3 : 1))
                .contentShape(RoundedRectangle(cornerRadius:20))
        }.buttonStyle(SkillPressStyle()).accessibilityIdentifier("skill.\(node.kind.rawValue)")
            .accessibilityLabel(node.title+". "+node.summary)
            .accessibilityValue(known ? "Изучено" : (locked ? "Сначала "+(prerequisite?.title ?? "предыдущий навык") : (available ? "Доступно, \(node.cost) очков" : "Нужно \(node.cost) очков")))
    }
}

private struct SkillPressStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View { configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).animation(.easeOut(duration:0.16),value:configuration.isPressed) }
}

struct SkillDetailView:View {
    @ObservedObject var session:GameSession
    var owner:UUID
    var kind:SkillNode.Kind
    var didLearn:((String)->Void)?=nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduced
    private var monster:MonsterRecord { session.inventory.monsters.first { $0.id==owner } ?? session.inventory.selected }
    private var node:SkillNode { monster.tree.first { $0.kind==kind }! }
    private var palette:SkillPalette { SkillPalette(monster.form) }
    private var known:Bool { monster.learned.contains(kind) }
    private var prerequisite:SkillNode? { node.prerequisite.flatMap { id in monster.tree.first { $0.id==id } } }
    private var needsParent:Bool { prerequisite.map { !monster.learned.contains($0.kind) } ?? false }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack {
                    Text(kind == .passive ? "ПАССИВНАЯ СПОСОБНОСТЬ" : (kind == .jump || kind == .doubleJump ? "ИЗУЧАЕМЫЙ ПРИЁМ" : "УЛУЧШЕНИЕ НАВЫКОВ"))
                        .font(.system(size:9,weight:.semibold)).tracking(1.2).foregroundStyle(palette.paper.opacity(0.5))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName:"xmark").font(.system(size:16)).frame(width:42,height:42).background(palette.paper.opacity(0.07),in:Circle()) }
                        .buttonStyle(.plain).accessibilityLabel("Закрыть описание").accessibilityIdentifier("skill.detail.close")
                }
                TimelineView(.animation(minimumInterval:1/24,paused:reduced)) { time in
                    let phase=reduced ? 0 : sin(time.date.timeIntervalSinceReferenceDate*1.7)
                    SkillArtwork(monster:monster,kind:kind,size:146).scaleEffect(1+phase*0.025).rotationEffect(.degrees(phase*1.4)).frame(maxWidth:.infinity).frame(height:158)
                }
                if known { Label("ИЗУЧЕНО ЭТИМ КУБИКОМ",systemImage:"checkmark.seal.fill").font(.system(size:11,weight:.bold)).tracking(0.7).foregroundStyle(palette.background).padding(12).frame(maxWidth:.infinity).background(palette.accent,in:RoundedRectangle(cornerRadius:14)).accessibilityIdentifier("skill.known.status") }
                VStack(alignment:.leading,spacing:8) {
                    Text(monster.name+" · "+monster.typeName).font(.system(size:11)).foregroundStyle(palette.accent.opacity(0.8))
                    Text(node.title).font(.system(size:30,weight:.medium,design:.serif)).fixedSize(horizontal:false,vertical:true)
                    Text(node.summary).font(.system(size:14)).foregroundStyle(palette.accent).lineSpacing(3)
                }
                VStack(spacing:0) {
                    HStack { Text(needsParent ? "ПОСЛЕ ПРЕДЫДУЩИХ УЗЛОВ" : "ЭФФЕКТ");Spacer();Text(kind == .passive ? "УЖЕ РАБОТАЕТ" : (known ? "БЫЛО     СЕЙЧАС" : (needsParent ? "ДО     ПОСЛЕ" : "СЕЙЧАС     ПОСЛЕ"))) }.font(.system(size:8,weight:.bold)).tracking(0.7).foregroundStyle(palette.paper.opacity(0.4)).padding(.bottom,12)
                    ForEach(monster.effects(of:kind)) { effect in
                        HStack(alignment:.firstTextBaseline,spacing:8) {
                            Text(effect.label).font(.system(size:12)).foregroundStyle(palette.paper.opacity(0.7)).frame(maxWidth:.infinity,alignment:.leading)
                            if !effect.before.isEmpty { Text(effect.before).foregroundStyle(palette.paper.opacity(0.4));Image(systemName:"chevron.right").font(.system(size:8)).foregroundStyle(palette.paper.opacity(0.25)) }
                            Text(effect.after).foregroundStyle(palette.accent).fontWeight(.semibold)
                        }.font(.system(size:12)).monospacedDigit().padding(.vertical,11)
                        if effect.id != monster.effects(of:kind).last?.id { Rectangle().fill(palette.paper.opacity(0.06)).frame(height:1) }
                    }
                }.padding(16).background(palette.paper.opacity(0.04),in:RoundedRectangle(cornerRadius:18)).accessibilityIdentifier("skill.effects")
                Text(node.explanation).font(.system(size:14)).lineSpacing(6).foregroundStyle(palette.paper.opacity(0.75)).fixedSize(horizontal:false,vertical:true)
                if monster.inheritedPotential.contains(kind) {
                    Text(known ? "Приём сохранён в наследии этого поколения." : "Потенциал сохранён в наследии. После изучения нужных основ он раскроется без дополнительных очков.").font(.system(size:12)).lineSpacing(4).foregroundStyle(palette.accent)
                }
                if kind != .jump && kind != .doubleJump { Label("Действует автоматически · не расходует ману",systemImage:"checkmark.seal").font(.system(size:11)).foregroundStyle(palette.accent.opacity(0.8)) }
                if !known {
                    VStack(alignment:.leading,spacing:9) {
                        Text("ДЛЯ ИЗУЧЕНИЯ").font(.system(size:8,weight:.bold)).tracking(1.2).foregroundStyle(palette.paper.opacity(0.4))
                        if let parent=prerequisite { Label(parent.title,systemImage:needsParent ? "lock" : "checkmark.circle.fill").foregroundStyle(needsParent ? palette.paper.opacity(0.6) : palette.accent) }
                        Label("\(node.cost) очк. навыков · у кубика \(monster.skillPoints)",systemImage:"sparkle").foregroundStyle(monster.skillPoints>=node.cost ? palette.accent : palette.paper.opacity(0.6))
                        if monster.skillPoints<node.cost { Text("Первая находка кристалла даёт 1 очко этому кубику.").font(.system(size:11)).foregroundStyle(palette.paper.opacity(0.45)) }
                    }.font(.system(size:12))
                }
            }.padding(24).frame(maxWidth:560,alignment:.leading).frame(maxWidth:.infinity)
        }.safeAreaInset(edge:.bottom,spacing:0) {
            VStack(spacing:10) {
                if known {
                    Label(kind == .passive ? "Занимает пассивный слот · 0 маны" : "Изучено этим кубиком",systemImage:"checkmark.circle.fill").font(.system(size:12)).foregroundStyle(palette.accent).padding(.vertical,9)
                } else {
                    Button {
                        if session.learn(node,for:owner) { didLearn?(node.title);dismiss() }
                    } label: {
                        HStack { Text(needsParent ? "Сначала изучи предыдущий навык" : "Изучить навык");Spacer(minLength:8);if !needsParent { Text("\(node.cost) очк.").monospacedDigit() } }
                            .font(.system(size:14,weight:.semibold)).padding(.horizontal,20).frame(maxWidth:.infinity,minHeight:52)
                            .foregroundStyle(palette.background).background(palette.accent,in:RoundedRectangle(cornerRadius:17))
                    }.buttonStyle(SkillPressStyle()).disabled(!monster.canLearn(node)).opacity(monster.canLearn(node) ? 1 : 0.4).accessibilityIdentifier("skill.learn")
                }
            }.frame(maxWidth:512).padding(.horizontal,24).padding(.vertical,16).frame(maxWidth:.infinity).background(palette.background.opacity(0.98))
        }.foregroundStyle(palette.paper).background(LinearGradient(colors:[Color(red:0.11,green:0.24,blue:0.26),palette.background],startPoint:.topLeading,endPoint:.bottomTrailing))
    }
}
