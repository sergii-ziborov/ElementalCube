import SwiftUI
import ElementalCore

struct MonsterInventoryView:View {
    @ObservedObject var session:GameSession
    @State private var tab=0
    @State private var detail:SkillNode?
    var monster:MonsterRecord { session.inventory.selected }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                HStack {
                    VStack(alignment:.leading,spacing:5) {
                        Text("Мой кубик").font(.system(size:25,design:.serif))
                        Text("МАЛЕНЬКИЙ КУБ. СВОЙ ПУТЬ.").font(.system(size:9,weight:.bold)).tracking(1.8).opacity(0.55)
                    }
                    Spacer()
                    Button { session.forms=false } label:{ Image(systemName:"xmark").frame(width:36,height:36) }.buttonStyle(.plain).accessibilityLabel("Закрыть инвентарь").accessibilityIdentifier("inventory.close")
                }
                HStack(alignment:.top) {
                    MonsterPortrait(form:monster.form,secondary:monster.secondaryForm,seed:monster.appearanceSeed,stage:monster.evolutionStage,wetness:Double(session.wetness),health:Double(session.health),burning:Double(session.burning),celebration:monster.learned.count+(monster.equippedCharm == nil ? 0 : 10),interactive:true).frame(width:58,height:66).accessibilityIdentifier("portrait.inventory")
                    VStack(alignment:.leading,spacing:6) {
                        Text(monster.name).font(.system(size:25,design:.serif))
                        Text(monster.stageName+" · "+monster.typeName+" · "+(monster.form.hasFur ? "мягкая шерсть" : "без шерсти")).font(.system(size:12)).opacity(0.65)
                        Text(String(format:"Предел прицела %.1f м/с",monster.jumpSkill.maximumSpeed)).font(.system(size:12)).monospacedDigit()
                    }
                    Spacer()
                    Button { session.showHome(.collection) } label: { Image(systemName:"square.stack.3d.up").frame(width:40,height:40) }.buttonStyle(.plain).accessibilityLabel("Коллекция кубиков").accessibilityIdentifier("collection.open")
                }
                Picker("Раздел инвентаря",selection:$tab) { Text("Навыки").tag(0);Text("Снаряжение").tag(1);Text("Материалы").tag(2) }.pickerStyle(.segmented)
                if tab==0 { skillTree } else if tab==1 { equipment } else { findings }
            }.padding(20).frame(maxWidth:650).foregroundStyle(ink)
        }.frame(maxWidth:.infinity).frame(idealHeight:900).background(cream)
        .sheet(item:$detail) { node in
            SkillDetailView(session:session,owner:monster.id,kind:node.kind)
                #if os(iOS)
                .presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
                #else
                .frame(width:460,height:480)
                #endif
        }
        .onAppear { session.saveInventory();if ProcessInfo.processInfo.arguments.contains("--preview-equipment") { tab=1 } }
    }
    var skillTree:some View {
        VStack(alignment:.leading,spacing:16) {
            MonsterSkillTree(monster:monster,wetness:Double(session.wetness),health:Double(session.health),burning:Double(session.burning)) { detail=$0 }
            HStack(spacing:10) {
                slot("Свайп вверх","arrow.up","БАЗОВЫЙ ПРЫЖОК")
                slot(monster.passiveName,monster.form.symbol,"ПАССИВНАЯ")
            }
            Text("Находи кристаллы, чтобы открывать новые навыки. Дерево и прогресс принадлежат только этому кубику.")
                .font(.system(size:12)).lineSpacing(4).foregroundStyle(ink.opacity(0.6))
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
            Text("Всего найдено этим кубиком: \(monster.crystals.count).").font(.system(size:13))
            Text(MonsterItem.aetherShard.explanation).font(.system(size:12)).lineSpacing(4).opacity(0.65)
            Text("Материалы и снаряжение хранятся у своего владельца. Повторный сбор того же кристалла не создаёт копии.").font(.system(size:12)).lineSpacing(4).opacity(0.65)
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(ink.opacity(0.05),in:RoundedRectangle(cornerRadius:18))
    }

}
