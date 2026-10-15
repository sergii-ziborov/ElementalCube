import SwiftUI
import ElementalCore

struct MergePreparationView:View {
    @ObservedObject var session:GameSession
    let plan:MergePlan
    var complete:(MonsterRecord)->Void
    @State private var pins:Set<GenePin>=[]
    @State private var committing=false
    @State private var error=""
    @Environment(\.dismiss) private var dismiss
    private var accent:Color { SkillPalette(plan.result.body).accent }
    var body:some View {
        VStack(spacing:0) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text("Слияние линии").font(.system(size:26,design:.serif))
                    Text("ФОРМА ИЗВЕСТНА. НАСЛЕДИЕ — СЮРПРИЗ.").font(.system(size:8,weight:.bold)).tracking(1.1).opacity(0.55)
                }
                Spacer(minLength:8)
                Button { dismiss() } label: { Image(systemName:"xmark").frame(width:44,height:44) }.buttonStyle(.plain).accessibilityLabel("Оставить как есть").accessibilityIdentifier("merge.cancel")
            }.padding(22)
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    future
                    if !plan.lostProperties.isEmpty {
                        VStack(alignment:.leading,spacing:10) {
                            Text("Что уйдёт вместе с прежним телом").font(.system(size:20,design:.serif))
                            ForEach(plan.lostProperties,id:\.self) { Text("− "+$0).font(.system(size:13)).foregroundStyle(Color(red:0.7,green:0.3,blue:0.23)) }
                        }.accessibilityIdentifier("merge.losses")
                    }
                    VStack(alignment:.leading,spacing:9) {
                        Text("Ровно половина от каждого").font(.system(size:24,design:.serif))
                        Text("Из каждой четвёрки выбираются две карточки. Зачаток тоже может попасть в отбор. Повторы не заменяются другим навыком, ранги не складываются.").font(.system(size:13)).lineSpacing(4).opacity(0.7)
                        Text("Фиксаторы: \(pins.count) / \(plan.lockBudget)").font(.system(size:12,weight:.semibold)).accessibilityIdentifier("merge.pin.count")
                        if plan.lockBudget==0 { Text("Один фиксатор откроется на ступени «Росток», второй — у «Хранителя».").font(.system(size:11)).opacity(0.6) }
                    }
                    passport(.receiver,monster:plan.receiver,title:"Твоя линия")
                    passport(.donor,monster:plan.donor,title:"Донор · остаётся с тобой")
                    VStack(alignment:.leading,spacing:9) {
                        Text("Зачатки развития").font(.system(size:20,design:.serif))
                        Text("В отдельном блоке тоже отбирается по 2 карточки из 4 у каждого. Сейчас это нераскрытые зачатки; дополнительных приёмов они не дают.").font(.system(size:12)).lineSpacing(4).opacity(0.65)
                    }
                    Label("Вещи, материалы и свободные очки твоей линии перейдут новому поколению. Вещи и очки донора останутся у него.",systemImage:"shippingbox").font(.system(size:12)).lineSpacing(4).opacity(0.7)
                    Text("\(plan.receiver.name) прежнего поколения останется в родословной. Вернуть его в активную коллекцию после слияния нельзя.").font(.system(size:12,weight:.medium)).lineSpacing(4)
                    if !error.isEmpty { Text(error).font(.system(size:13)).foregroundStyle(.red) }
                }.padding(.horizontal,22).padding(.bottom,24).frame(maxWidth:650,alignment:.leading).frame(maxWidth:.infinity)
            }
            HStack(spacing:12) {
                Button("Оставить как есть") { dismiss() }.buttonStyle(PillButton(filled:false)).accessibilityIdentifier("merge.keep")
                Button {
                    committing=true
                    if let child=session.commitMerge(plan,pins:pins) { complete(child) }
                    else { error="Подготовка изменилась или не хватает эфира. Закрой окно и подготовь слияние заново.";committing=false }
                } label: { Text("Слиться · 4 эфира").frame(maxWidth:.infinity) }
                    .buttonStyle(PillButton()).disabled(committing || !session.adventure.canCommit(plan,pins:pins)).opacity(session.adventure.canCommit(plan,pins:pins) ? 1 : 0.4).accessibilityIdentifier("merge.confirm")
            }.font(.system(size:12)).padding(18).background(cream)
        }.foregroundStyle(ink).background(cream)
    }
    private var future:some View {
        VStack(spacing:13) {
            HStack(spacing:20) {
                MonsterPortrait(form:plan.receiver.form,secondary:plan.receiver.secondaryForm,seed:plan.receiver.appearanceSeed,stage:plan.receiver.evolutionStage).frame(width:75,height:86)
                Image(systemName:"arrow.right").font(.system(size:20,weight:.light))
                MonsterPortrait(form:plan.result.body,secondary:plan.result.secondaryVisual,stage:plan.receiver.evolutionStage,interactive:true).frame(width:105,height:118)
                    .accessibilityLabel("Погладить: "+plan.result.name)
            }
            Text(plan.result.name).font(.system(size:32,design:.serif)).accessibilityIdentifier("merge.result.form")
            Text("Поколение \(plan.receiver.generation+1) · результат формы гарантирован").font(.system(size:11)).opacity(0.65)
            Text(plan.result.properties.joined(separator:" · ")).font(.system(size:12)).multilineTextAlignment(.center).lineSpacing(4).opacity(0.7)
        }.frame(maxWidth:.infinity).padding(20).background(.white.opacity(0.55),in:RoundedRectangle(cornerRadius:26))
    }
    private func passport(_ parent:GeneParent,monster:MonsterRecord,title:String)->some View {
        VStack(alignment:.leading,spacing:13) {
            HStack { Text(title).font(.system(size:20,design:.serif));Spacer();Text(monster.name).font(.system(size:11)).opacity(0.55) }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(plan.passport(parent).skills) { card in gene(card,parent:parent,monster:monster) }
            }
            let selected=Set(monster.inheritanceSelection)
            let outside=monster.tree.filter { $0.kind != .passive && monster.learned.contains($0.kind) && !selected.contains($0.kind) }
            if !outside.isEmpty { Text("Вне паспорта: "+outside.map(\.title).joined(separator:", ")+". Эти навыки не участвуют в отборе.").font(.system(size:11)).lineSpacing(3).fixedSize(horizontal:false,vertical:true).opacity(0.65) }
        }
    }
    private func gene(_ card:GeneCard,parent:GeneParent,monster:MonsterRecord)->some View {
        let pin=GenePin(parent,card.slot),selected=pins.contains(pin)
        let expression=InheritanceEngine.expression(card,as:plan.result),chance=Int((plan.probability(pin,pins:pins)*100).rounded())
        let canPin=expression.usable && (selected || pins.count<plan.lockBudget)
        return Button {
            if selected { pins.remove(pin) } else if canPin { pins.insert(pin) }
        } label: {
            VStack(alignment:.leading,spacing:9) {
                HStack {
                    Text("ОТПЕЧАТОК \(card.slot+1)").font(.system(size:7,weight:.bold)).tracking(0.8).opacity(0.5)
                    Spacer()
                    Image(systemName:selected ? "pin.fill" : "pin").font(.system(size:12)).foregroundStyle(selected ? ink : ink.opacity(0.3))
                }
                if case .skill(let kind)=card.content { SkillArtwork(monster:monster,kind:kind,size:58).frame(maxWidth:.infinity) }
                else { Image(systemName:"circle.dotted").font(.system(size:35,weight:.ultraLight)).opacity(0.2).frame(maxWidth:.infinity).frame(height:58) }
                Text(card.title).font(.system(size:12,weight:.semibold)).lineLimit(2).frame(minHeight:31,alignment:.top)
                Text(card.rank>0 ? "Ранг \(card.rank)" : "Ещё не раскрыт").font(.system(size:10)).opacity(0.55)
                Text("В геном: \(chance)%").font(.system(size:11,weight:.medium))
                Text("Потенциал в форме: \(expression.usable ? chance : 0)%").font(.system(size:10)).foregroundStyle(expression.usable ? ink.opacity(0.6) : Color(red:0.7,green:0.3,blue:0.23))
                if !expression.usable && card.rank>0 { Text("Ветвь будет потеряна").font(.system(size:10)).foregroundStyle(Color(red:0.7,green:0.3,blue:0.23)) }
            }.padding(13).frame(maxWidth:.infinity,alignment:.leading).background(selected ? mint.opacity(0.65) : .white.opacity(0.45),in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(ink.opacity(selected ? 0.45 : 0.07))).contentShape(RoundedRectangle(cornerRadius:18))
        }.buttonStyle(GeneCardButtonStyle()).disabled(!canPin).accessibilityIdentifier("merge.pin.\(parent.rawValue).\(card.slot)")
            .accessibilityLabel(card.title+". В геном \(chance) процентов. В новой форме \(expression.usable ? chance : 0) процентов")
            .accessibilityValue(selected ? "Закреплён" : (canPin ? "Можно закрепить" : "Без фиксатора"))
    }
}

/// Incompatible imprints remain legible because they explain the real loss.
/// Only interaction is disabled; the system's disabled opacity hides that text.
private struct GeneCardButtonStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct InheritancePassportEditor:View {
    @ObservedObject var session:GameSession
    private let owner:UUID
    @State private var selected:[SkillNode.Kind]
    @State private var error=""
    @Environment(\.dismiss) private var dismiss
    init(session:GameSession) {
        self.session=session;owner=session.inventory.selectedID
        _selected=State(initialValue:session.inventory.selected.inheritanceSelection)
    }
    private var monster:MonsterRecord { session.inventory.selected }
    var body:some View {
        VStack(spacing:0) {
            HStack { Text("Отпечатки наследия").font(.system(size:25,design:.serif));Spacer();Button { dismiss() } label: { Image(systemName:"xmark").frame(width:44,height:44) }.buttonStyle(.plain) }.padding(22)
            ScrollView {
                VStack(alignment:.leading,spacing:17) {
                    Text("Подготовь до четырёх приёмов. При слиянии случайно пройдут два. Врождённая пассивка задаётся новым телом и не занимает карточку.").font(.system(size:13)).lineSpacing(4).opacity(0.7)
                    HStack(spacing:8) {
                        ForEach(0..<4,id:\.self) { i in
                            Group { if i<selected.count { SkillArtwork(monster:monster,kind:selected[i],size:48) } else { Image(systemName:"circle.dotted").font(.system(size:25)).opacity(0.25).frame(width:48,height:48) } }
                                .frame(maxWidth:.infinity).padding(.vertical,10).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:15))
                        }
                    }
                    Text("\(selected.count) / 4 карточки").font(.system(size:12,weight:.semibold)).accessibilityIdentifier("passport.count")
                    if monster.availableImprints.isEmpty { Text("Пока известна только пассивка. Изучи приёмы в своём дереве; свободные места остаются зачатками и тоже могут попасть в отбор.").font(.system(size:14)).lineSpacing(5) }
                    ForEach(monster.tree.filter { monster.availableImprints.contains($0.kind) }) { node in
                        Button {
                            if selected.contains(node.kind) { selected.removeAll { $0==node.kind } }
                            else if selected.count<4 { selected.append(node.kind);error="" }
                            else { error="Сначала освободи одну из четырёх карточек." }
                        } label: {
                            HStack(spacing:12) {
                                SkillArtwork(monster:monster,kind:node.kind,size:52)
                                VStack(alignment:.leading,spacing:5) { Text(node.title).font(.system(size:14,weight:.medium));Text(monster.learned.contains(node.kind) ? "Изучен" : "Унаследованный потенциал · нужны основы").font(.system(size:11)).opacity(0.6) }
                                Spacer();Image(systemName:selected.contains(node.kind) ? "checkmark.circle.fill" : "circle").font(.system(size:22)).opacity(selected.contains(node.kind) ? 1 : 0.2)
                            }.padding(12).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:17)).contentShape(RoundedRectangle(cornerRadius:17))
                        }.buttonStyle(.plain).accessibilityIdentifier("passport.\(node.kind.rawValue)").accessibilityValue(selected.contains(node.kind) ? "В паспорте" : "Вне паспорта")
                    }
                    Text("Паспорт не меняет доступные кнопки. Оставшиеся изученные навыки продолжают работать у этого кубика, но не участвуют в данном наследовании.").font(.system(size:12)).lineSpacing(4).opacity(0.6)
                    if !error.isEmpty { Text(error).font(.system(size:12)).foregroundStyle(.red) }
                }.padding(.horizontal,22).padding(.bottom,22)
            }
            Button { if session.setInheritanceSelection(selected,owner:owner) { dismiss() } else { error="Выбранный кубик изменился. Открой его паспорт заново." } } label: { Text("Сохранить четвёрку").frame(maxWidth:.infinity) }.buttonStyle(PillButton()).accessibilityIdentifier("passport.save").padding(20)
        }.foregroundStyle(ink).background(cream)
    }
}

struct MergeResultView:View {
    let child:MonsterRecord
    var close:()->Void
    var body:some View {
        VStack(spacing:0) {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text("Новое поколение").font(.system(size:31,design:.serif))
                    VStack(spacing:8) {
                        MonsterPortrait(form:child.form,secondary:child.secondaryForm,seed:child.appearanceSeed,stage:child.evolutionStage,celebration:3,interactive:true).frame(width:145,height:164)
                            .accessibilityLabel("Погладить: "+child.name)
                        Text(child.name).font(.system(size:32,design:.serif))
                        Text("\(child.currentForm.name) · поколение \(child.generation)").font(.system(size:12)).opacity(0.6)
                    }.frame(maxWidth:.infinity).padding(18).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:26))
                    Text("Результат сохранён. Донор остался в коллекции, прежнее поколение линии — в родословной.").font(.system(size:13)).lineSpacing(4).opacity(0.7)
                    if let genome=child.inheritance {
                        Text("Четыре отпечатка умений").font(.system(size:23,design:.serif))
                        ForEach(genome.skills) { expression in report(expression) }
                        DisclosureGroup("Развитие · ещё четыре отпечатка") { ForEach(genome.development) { report($0) } }.font(.system(size:13))
                    }
                    Text("Сохранённый приём может ждать основы в новом дереве. Пропущенные навыки не выдаются бесплатно; унаследованный потенциал раскроется, когда изучишь их.").font(.system(size:12)).lineSpacing(4).opacity(0.65)
                }.padding(24).frame(maxWidth:620,alignment:.leading).frame(maxWidth:.infinity)
            }
            Button("Познакомиться поближе",action:close).buttonStyle(PillButton()).accessibilityIdentifier("merge.result.close").padding(20)
        }.foregroundStyle(ink).background(cream)
    }
    private func report(_ expression:GeneExpression)->some View {
        let color:Color=expression.usable ? ink : (expression.disposition == .lost ? Color(red:0.7,green:0.3,blue:0.23) : ink.opacity(0.5))
        let source=child.parents.first { $0.id==expression.source.ownerID }?.name ?? expression.source.form.name
        return VStack(alignment:.leading,spacing:7) {
            HStack(alignment:.firstTextBaseline) { Text(expression.source.title).font(.system(size:14,weight:.semibold));Spacer();Text(expression.label).font(.system(size:10,weight:.semibold)).foregroundStyle(color) }
            Text(source+" · карточка \(expression.source.slot+1)").font(.system(size:10)).opacity(0.5)
            Text(expression.reason).font(.system(size:12)).lineSpacing(3).opacity(0.7)
            if expression.usable,case .skill(let kind)?=expression.result,let node=child.tree.first(where:{ $0.kind==kind }) {
                Text(node.title+(child.learned.contains(kind) ? " · доступен" : " · ждёт основы")).font(.system(size:11,weight:.medium))
            }
        }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:17))
    }
}
