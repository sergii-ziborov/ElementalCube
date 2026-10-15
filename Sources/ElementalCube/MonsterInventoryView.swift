import SwiftUI
import ElementalCore

struct MonsterInventoryView:View {
    @ObservedObject var session:GameSession
    @State private var tab=0
    @State private var detail:SkillNode?
    var monster:MonsterRecord { session.inventory.selected }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack {
                    VStack(alignment:.leading,spacing:5) {
                        Text("Инвентарь монстра").font(.system(size:26,design:.serif))
                        Text("СНАРЯЖЕНИЕ · МАТЕРИАЛЫ · НАВЫКИ").font(.system(size:9,weight:.bold)).tracking(1.8).opacity(0.55)
                    }
                    Spacer()
                    Button { session.forms=false } label:{ Image(systemName:"xmark").frame(width:36,height:36) }.buttonStyle(.plain).accessibilityLabel("Закрыть инвентарь")
                }
                HStack(alignment:.top) {
                    MonsterPortrait(form:monster.form).frame(width:76,height:86)
                    VStack(alignment:.leading,spacing:6) {
                        Text(monster.name).font(.system(size:30,design:.serif))
                        Text(monster.typeName+" · "+(monster.form.hasFur ? "мягкая шерсть" : "без шерсти")).font(.system(size:12)).opacity(0.65)
                        Text(String(format:"Предел прыжка %.1f м/с",monster.jumpSkill.maximumSpeed)).font(.system(size:12)).monospacedDigit()
                    }
                    Spacer()
                    Menu {
                        ForEach(session.inventory.monsters) { cube in
                            Button(cube.name) { session.selectMonster(cube.id);detail=nil }
                        }
                    } label: { Image(systemName:"arrow.triangle.2.circlepath").frame(width:40,height:40) }.accessibilityLabel("Выбрать тип куба для новой попытки")
                }
                Text("Выбор другого куба начинает новую попытку. Находки и изученные навыки остаются у своего владельца.").font(.system(size:12)).lineSpacing(4).opacity(0.65)
                Picker("Раздел инвентаря",selection:$tab) { Text("Навыки").tag(0);Text("Снаряжение").tag(1);Text("Материалы").tag(2) }.pickerStyle(.segmented)
                if tab==0 { skillTree } else if tab==1 { equipment } else { findings }
            }.padding(24).frame(maxWidth:650).foregroundStyle(ink)
        }.frame(maxWidth:.infinity).background(cream)
        .onAppear { session.saveInventory();if ProcessInfo.processInfo.arguments.contains("--preview-equipment") { tab=1 } }
    }
    var skillTree:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Дерево навыков").font(.system(size:22,design:.serif));Spacer();Text("\(monster.skillPoints) очк.").font(.system(size:12,weight:.bold)).padding(9).background(mint,in:Capsule()) }
            Text("Два назначенных слота").font(.system(size:10,weight:.bold)).tracking(1).opacity(0.6)
            HStack(spacing:10) {
                slot("Прыжок","arrow.up.right","ДВИЖЕНИЕ")
                slot(monster.form.ability,monster.form.symbol,"ПАССИВНАЯ")
            }
            // Rows are paired branches: movement and this material's passive.
            ForEach(0..<3,id:\.self) { row in
                HStack(alignment:.top,spacing:12) {
                    ForEach([row==0 ? 1 : row*2,row==0 ? 0 : row*2+1],id:\.self) { index in
                        let node=monster.tree[index],known=monster.learned.contains(node.kind)
                        Button { detail=node } label: {
                            VStack(alignment:.leading,spacing:9) {
                                HStack { Image(systemName:node.symbol).font(.system(size:19));Spacer();Image(systemName:known ? "checkmark.circle.fill" : (monster.canLearn(node) ? "plus.circle" : "lock")) }
                                Text(node.title).font(.system(size:15,weight:.medium,design:.serif)).multilineTextAlignment(.leading)
                                Text(known ? "Изучено" : "\(node.cost) очк. навыков").font(.system(size:10)).opacity(0.6)
                            }.frame(maxWidth:.infinity,minHeight:93,alignment:.topLeading).padding(14).background(ink.opacity(known ? 0.1 : 0.035),in:RoundedRectangle(cornerRadius:16))
                                .overlay(RoundedRectangle(cornerRadius:16).stroke(ink.opacity(detail?.id==node.id ? 0.6 : 0.08)))
                        }.buttonStyle(.plain).accessibilityIdentifier("skill.\(node.kind.rawValue)")
                    }
                }
                if row<2 { HStack { Spacer();Rectangle().fill(ink.opacity(0.18)).frame(width:1,height:12);Spacer();Rectangle().fill(ink.opacity(0.18)).frame(width:1,height:12);Spacer() }.allowsHitTesting(false) }
            }
            if let selected=detail,let node=monster.tree.first(where:{ $0.id==selected.id }) {
                VStack(alignment:.leading,spacing:12) {
                    Text(node.title).font(.system(size:21,design:.serif))
                    Text(node.explanation).font(.system(size:13)).lineSpacing(5)
                    if monster.learned.contains(node.kind) {
                        Text(node.kind == .passive ? "Назначена в пассивный слот. Срабатывает автоматически при контакте с миром." : "Изучено этим кубом.").font(.system(size:11)).opacity(0.65)
                    } else {
                        Button(monster.canLearn(node) ? "Изучить · \(node.cost) очк." : "Нужен предыдущий навык и \(node.cost) очк.") { session.learn(node,for:monster.id) }.buttonStyle(PillButton()).disabled(!monster.canLearn(node))
                    }
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(mint.opacity(0.45),in:RoundedRectangle(cornerRadius:18))
            }
            Text("Первое очко уже у каждого куба. Каждый новый найденный им кристалл даёт ещё одно. Деревья и прогресс у разных монстров независимы.").font(.system(size:11)).lineSpacing(4).opacity(0.65)
        }
    }
    func slot(_ title:String,_ symbol:String,_ subtitle:String)->some View {
        HStack(spacing:9) { Image(systemName:symbol).font(.system(size:20));VStack(alignment:.leading,spacing:4) { Text(subtitle).font(.system(size:8,weight:.bold)).tracking(0.7).opacity(0.6);Text(title).font(.system(size:12)) } }.frame(maxWidth:.infinity,alignment:.leading).padding(13).background(ink.opacity(0.07),in:RoundedRectangle(cornerRadius:14))
    }
    var equipment:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Слот талисмана").font(.system(size:22,design:.serif))
            Label(monster.equippedCharm?.name ?? "Пока пусто",systemImage:monster.equippedCharm?.symbol ?? "circle.dashed").padding(16).frame(maxWidth:.infinity,alignment:.leading).background(mint.opacity(0.6),in:RoundedRectangle(cornerRadius:16))
            ForEach(MonsterItem.allCases.filter { $0.isEquipment && monster.quantity(of:$0)>0 }) { item in
                VStack(alignment:.leading,spacing:12) {
                    Label(item.name,systemImage:item.symbol).font(.system(size:19,design:.serif))
                    Text(item.explanation).font(.system(size:13)).lineSpacing(5)
                    Button(monster.equippedCharm==item ? "Снять" : "Надеть") { session.equip(monster.equippedCharm==item ? nil : item) }.buttonStyle(PillButton()).accessibilityIdentifier("equip.\(item.rawValue)")
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(ink.opacity(0.05),in:RoundedRectangle(cornerRadius:18))
            }
            if !monster.deepRelic { Text("Другой талисман скрыт в глубине под мостом.").font(.system(size:12)).opacity(0.6) }
        }
    }
    var findings:some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Эфирный кристалл · \(monster.quantity(of:.aetherShard))",systemImage:"diamond.fill").font(.system(size:21,design:.serif))
            Text("Найдено этим кубом: \(monster.crystals.count) из \(WorldLayout.shards.count).").font(.system(size:13))
            Text(MonsterItem.aetherShard.explanation).font(.system(size:12)).lineSpacing(4).opacity(0.65)
            Text("Материалы и снаряжение хранятся у своего владельца. Повторный сбор того же кристалла не создаёт копии.").font(.system(size:12)).lineSpacing(4).opacity(0.65)
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(ink.opacity(0.05),in:RoundedRectangle(cornerRadius:18))
    }

}
struct MonsterPortrait:View {
    var form:ElementForm
    var color:Color {
        switch form { case .ice:return Color(red:0.65,green:0.87,blue:0.96);case .water:return Color(red:0.32,green:0.72,blue:0.86);case .air:return mint;case .stone:return Color(red:0.64,green:0.63,blue:0.53);case .fire:return Color(red:1,green:0.61,blue:0.23) }
    }
    var body:some View {
        GeometryReader { geo in
            let w=geo.size.width
            ZStack {
                Ellipse().fill(ink.opacity(0.13)).frame(width:w*0.85,height:10).offset(y:30)
                RoundedRectangle(cornerRadius:form == .stone ? 12 : 18).fill(LinearGradient(colors:[color.opacity(0.6),color],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:w*0.85,height:w*0.85).rotationEffect(.degrees(-5))
                if form.hasFur {
                    ForEach(0..<28,id:\.self) { i in
                        Capsule().fill(color.opacity(0.75)).frame(width:2,height:7).offset(y:-w*0.42).rotationEffect(.degrees(Double(i)*360/28))
                    }
                }
                HStack(spacing:12) {
                    ForEach(0..<2,id:\.self) { _ in
                        ZStack(alignment:.topLeading) { Ellipse().fill(ink).frame(width:10,height:15);Circle().fill(.white).frame(width:4,height:4).offset(x:2,y:2) }
                    }
                }.offset(y:1)
                Ellipse().fill(ink).frame(width:8,height:6).offset(y:16)
            }.frame(width:geo.size.width,height:geo.size.height)
        }.accessibilityHidden(true)
    }
}
