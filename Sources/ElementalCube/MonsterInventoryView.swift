import SwiftUI
import ElementalCore

struct MonsterInventoryView:View {
    @ObservedObject var session:GameSession
    @State private var tab=0
    @State private var detail:SkillNode?
    @State private var learnedMessage=""
    @State private var passport=false
    var monster:MonsterRecord { session.inventory.selected }
    var body:some View {
        VStack(spacing:0) {
            header.padding(.horizontal,20).padding(.top,18).padding(.bottom,12)
            if !learnedMessage.isEmpty {
                Label(learnedMessage,systemImage:"checkmark.circle.fill").font(.system(size:13,weight:.medium)).foregroundStyle(ink).padding(13).frame(maxWidth:610,alignment:.leading).background(mint,in:RoundedRectangle(cornerRadius:14)).padding(.horizontal,20).padding(.bottom,10).accessibilityIdentifier("skill.learned.feedback")
            }
            ScrollView {
            VStack(alignment:.leading,spacing:16) {
                HStack(alignment:.top) {
                    MonsterPortrait(form:monster.form,secondary:monster.secondaryForm,seed:monster.appearanceSeed,stage:monster.evolutionStage,wetness:Double(session.wetness),health:Double(session.health),burning:Double(session.burning),celebration:monster.learned.count+(monster.equippedCharm == nil ? 0 : 10),interactive:true).frame(width:72,height:82).accessibilityIdentifier("portrait.inventory")
                    VStack(alignment:.leading,spacing:6) {
                        Text(monster.name).font(.system(size:25,design:.serif)).lineLimit(2)
                        Text(monster.stageName+" · "+monster.typeName+" · "+(monster.form.hasFur ? "мягкая шерсть" : "без шерсти")).font(.system(size:12)).opacity(0.65)
                        Text(monster.learned.contains(.jump) ? String(format:"Прицельный прыжок · %.1f м/с",monster.jumpSkill.maximumSpeed) : "Свайп вверх — базовый прыжок").font(.system(size:12)).monospacedDigit()
                    }
                    Spacer()
                    Button { session.showHome(.collection) } label: { Image(systemName:"square.stack.3d.up").frame(width:40,height:40) }.buttonStyle(.plain).accessibilityLabel("Коллекция кубиков").accessibilityIdentifier("collection.open")
                }
                Picker("Раздел инвентаря",selection:$tab) { Text("Навыки").tag(0);Text("Снаряжение").tag(1);Text("Материалы").tag(2) }.pickerStyle(.segmented).labelsHidden()
                if tab==0 { skillTree } else if tab==1 { equipment } else { findings }
            }.padding(.horizontal,20).padding(.bottom,20).frame(maxWidth:650).foregroundStyle(ink)
            }
        }.frame(maxWidth:.infinity).frame(idealHeight:900).background(cream)
        .sheet(item:$detail) { node in
            SkillDetailView(session:session,owner:monster.id,kind:node.kind) { title in withAnimation(.easeOut(duration:0.3)) { learnedMessage="Изучено: "+title } }
                #if os(iOS)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
                #else
                .frame(width:560,height:740)
                #endif
        }
        .task(id:learnedMessage) {
            guard !learnedMessage.isEmpty else { return };try? await Task.sleep(nanoseconds:3_000_000_000)
            if !Task.isCancelled { withAnimation { learnedMessage="" } }
        }
        .sheet(isPresented:$passport) {
            InheritancePassportEditor(session:session)
                #if os(iOS)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
                #else
                .frame(width:600,height:740)
                #endif
        }
        .onAppear { session.saveInventory();if ProcessInfo.processInfo.arguments.contains("--preview-equipment") { tab=1 } }
    }
    private var header:some View {
        HStack {
            VStack(alignment:.leading,spacing:5) {
                Text("Мой кубик").font(.system(size:25,design:.serif))
                Text("МАЛЕНЬКИЙ КУБ. СВОЙ ПУТЬ.").font(.system(size:9,weight:.bold)).tracking(1.8).opacity(0.55)
            }
            Spacer()
            Button { session.forms=false } label:{ Image(systemName:"xmark").frame(width:36,height:36) }.buttonStyle(.plain).accessibilityLabel("Закрыть инвентарь").accessibilityIdentifier("inventory.close")
        }
    }
    var skillTree:some View {
        VStack(alignment:.leading,spacing:16) {
            MonsterSkillTree(monster:monster,wetness:Double(session.wetness),health:Double(session.health),burning:Double(session.burning)) { detail=$0 }
            Button { passport=true } label: {
                HStack { Label("Отпечатки наследия",systemImage:"square.stack.3d.up");Spacer();Text("\(monster.inheritanceSelection.count) / 4").monospacedDigit();Image(systemName:"chevron.right") }.font(.system(size:13)).frame(minHeight:44)
            }.buttonStyle(PillButton(filled:false)).accessibilityIdentifier("passport.open")
            Text("Находи кристаллы, чтобы открывать новые навыки. Дерево и прогресс принадлежат только этому кубику.")
                .font(.system(size:12)).lineSpacing(4).foregroundStyle(ink.opacity(0.6))
        }
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
