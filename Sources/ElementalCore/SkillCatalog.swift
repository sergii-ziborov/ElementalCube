import Foundation

public enum SkillSignature { case quickDry,healingWater,softLanding,titanRoll,boilingHeart,coldCrystal,spring,healingMist,windGuard }
public struct SkillEffect:Identifiable {
    public let label:String,before:String,after:String
    public var id:String { label }
}

public enum SkillCatalog {
    public static let movement:[SkillNode.Kind]=[.jump,.momentum,.doubleJump,.control]
    public static let elemental:[SkillNode.Kind]=[.passive,.mastery,.affinity,.resilience]
    static func tree(for m:MonsterRecord)->[SkillNode] {
        func node(_ kind:SkillNode.Kind,_ title:String,_ summary:String,_ text:String,_ cost:Int,_ prerequisite:SkillNode.Kind?)->SkillNode {
            SkillNode(id:m.treeIdentity+"/"+kind.rawValue,kind:kind,title:title,explanation:text,summary:summary,symbol:kind == .jump || kind == .momentum ? "arrow.up.right" : m.form.symbol,cost:m.inheritedPotential.contains(kind) && !m.learned.contains(kind) ? 0 : cost,prerequisite:prerequisite.map { m.treeIdentity+"/"+$0.rawValue })
        }
        let mobility:[ElementForm:String]=[.ice:"Ледяной разбег",.water:"Упругая капля",.air:"Попутный ветер",.stone:"Разгон валуна",.fire:"Искра ввысь"]
        var mastery:(String,String,String),affinity:(String,String,String)
        if m.hybridStyle == .crystal || m.form == .ice {
            mastery=(m.isHybrid ? "Растущий кристалл" : "Глубокий холод","Холод распространяется на 25% быстрее","Усиливает теплопроводность морозного касания. Ледяная корка быстрее растёт в глубину и в стороны; первая опора по-прежнему появляется сразу и не расходует ману.")
            affinity=(m.isHybrid ? "Память снежинки" : "Сердце зимы","Холод +50% · мана приёмов −15%","Доводит суммарное усиление теплопроводности до 50% и снижает стоимость прицельного и двойного прыжков на 15%. Пассивка остаётся бесплатной.")
        } else if m.hybridStyle == .magma || m.form == .fire {
            mastery=(m.isHybrid ? "Сердце вулкана" : "Жаркое ядро","Здоровье на кипение −15%","Горячее ядро медленнее остывает в воде: кипение расходует на 15% меньше здоровья при том же объёме испарения. Действует только при реальном контакте с водой.")
            affinity=(m.isHybrid ? "Живая лава" : "Неугасимый","Здоровье −30% · мана приёмов −15%","Доводит суммарную экономию здоровья при кипении до 30%. Прицельный и двойной прыжки расходуют на 15% меньше маны. Камень и воздух не становятся горючими.")
        } else {
            switch m.form {
            case .water:
                mastery=("Сильная волна","Плавание и водный толчок +15%","Усиливает само движение в воде, а не только недостижимый предел скорости. Кубик быстрее плывёт к касанию карты и получает на 15% более сильный толчок при прыжке из воды.")
                affinity=("Попутное течение","Плавание +30% · мана приёмов −15%","Суммарно усиливает плавание и водный толчок на 30%. Прицельный и двойной прыжки расходуют на 15% меньше маны. Проход в низкую щель остаётся базовым свойством тела.")
            case .air:
                mastery=("Тихое парение","Воздушная подушка +20%","Усиливает подъёмную силу и отзывчивость воздушной подушки на 20%. Легче удерживать высоту и разгоняться в выбранную сторону; высота свободного парения не меняется.")
                affinity=("Долгий полёт","Подушка +40% · мана приёмов −15%","Доводит суммарное усиление подушки до 40%. Прицельный и двойной прыжки расходуют на 15% меньше маны; обычное парение остаётся бесплатным.")
            default:
                mastery=("Крепкая порода","Урон от посадки −20%","Укрепляет тело: жёсткое приземление наносит на 20% меньше урона. Масса, вращение и способность тонуть сохраняются. Защита складывается с талисманом.")
                affinity=("Монолит","Урон −40% · мана приёмов −15%","Доводит снижение урона от жёсткой посадки до 40%. Прицельный и двойной прыжки расходуют на 15% меньше маны. Иммунитет к огню уже есть у каменного тела.")
            }
        }
        if let style=m.hybridStyle {
            let names:[HybridStyle:(String,String)]=[.steam:("Поток пара","Паровая связь"),.magma:("Сердце вулкана","Живая лава"),.geyser:("Напор источника","Глубинное течение"),.crystal:("Растущий кристалл","Память кристалла"),.slush:("Снежная глубина","Сердце снегов"),.mud:("Пластичный поток","Глиняная связь"),.ember:("Жаркая искра","Дыхание углей"),.blizzard:("Сила метели","Северное сияние"),.mist:("Плотное облачко","Туманная связь"),.dust:("Воздушная спираль","Память бури"),.resonance:("Чистая стихия","Полный резонанс")]
            if let names=names[style] { mastery.0=names.0;affinity.0=names.1 }
        }
        let signature=m.signatureDescription
        return [
            node(.passive,m.passiveName,"Автоматически · 0 маны",m.passiveExplanation,0,nil),
            node(.jump,"Направленный прыжок","Выбери угол и силу · 6 маны","Удержи кубика, затем потяни в сторону полёта и отпусти. Пунктир показывает траекторию; стрелки нет. Сила растёт вместе с длиной жеста и ограничена изученными навыками. Базовый свайп вверх уже доступен бесплатно.",1,nil),
            node(.momentum,mobility[m.form]!,"Предел прицела +1,7 м/с","Усиливает изученный направленный прыжок на 1,7 м/с. Короткое движение пальца остаётся мягким толчком; длинный жест позволяет преодолеть более широкий разрыв. Стоимость приёма не растёт.",1,.jump),
            node(.mastery,mastery.0,mastery.1,mastery.2,1,.passive),
            node(.doubleJump,"Двойной прыжок","Ещё один толчок в воздухе","После первого прыжка ещё раз сделай свайп вверх: кубик получит один дополнительный воздушный толчок за 10 маны. Заряд восстанавливается на опоре или в воде. Третьего прыжка этот навык не даёт.",2,.momentum),
            node(.control,"Воздушный манёвр","Рули в полёте · прицел +1,7 м/с","Коснись карты справа или слева во время полёта: кубик сможет менять горизонтальную скорость, продолжая падать под действием тяжести. Ещё +1,7 м/с к пределу прицела. У воздушной формы вместо нового руля усиливается уже доступное управление.",2,.doubleJump),
            node(.affinity,affinity.0,affinity.1,affinity.2,2,.mastery),
            node(.resilience,signature.0,signature.1,signature.2,2,.affinity)
        ]
    }
}

extension MonsterRecord {
    public var signature:SkillSignature {
        switch hybridStyle {
        case .steam,.mud:return .healingWater
        case .geyser:return .spring
        case .magma,.ember:return .boilingHeart
        case .crystal,.blizzard:return .coldCrystal
        case .slush:return .quickDry
        case .mist:return .healingMist
        case .dust:return .windGuard
        default:
            switch form { case .ice:return .quickDry;case .water:return .healingWater;case .air:return .softLanding;case .stone:return .titanRoll;case .fire:return .boilingHeart }
        }
    }
    public var signatureDescription:(String,String,String) {
        let title:String
        switch hybridStyle {
        case .steam:title="Тёплый источник";case .mud:title="Илистый покой";case .geyser:title="Пружинка гейзера"
        case .magma:title="Вулканическое кипение";case .ember:title="Жаркий вихрь";case .crystal:title="Кристальная решётка"
        case .blizzard:title="Вечная метель";case .slush:title="Снежная нежность";case .mist:title="Целебный туман"
        case .dust:title="Глаз бури";default:
            title=[ElementForm.ice:"Пушистый термос",.water:"Живая вода",.air:"Мягкая посадка",.stone:"Поступь титана",.fire:"Кипящее сердце"][form]!
        }
        switch signature {
        case .quickDry:return (title,"Шерсть высыхает на 65% быстрее","После выхода из воды шерсть быстрее отдаёт влагу. В воде она по-прежнему намокает; пассивное улучшение не требует кнопки или маны.")
        case .healingWater:return (title,"В воде: +1,5 здоровья в секунду","Живая вода постепенно восстанавливает здоровье, пока кубик находится в воде и не горит. Лечение не расходует ману, не оживляет погибшего и останавливается при выходе на сушу.")
        case .softLanding:return (title,"Урон от посадки ещё −35%","Воздушное тело смягчает удар об опору: урон от жёсткого приземления уменьшается на 35%. Защита сочетается с талисманом; сам удар и отдача сохраняются.")
        case .titanRoll:return (title,"Тяга качения +25%","На четверть увеличивает усилие двигателя качения на земле и под водой. Камень быстрее разгоняется и увереннее поднимается по склону, сохраняя настоящую массу и вращение.")
        case .boilingHeart:return (title,"Испаряемый объём +25%","При том же расходе здоровья испаряет на 25% больше воды за секунду. Ускоряет именно локальное кипение: вода конечна, здоровье продолжает расходоваться, камень и воздух не горят.")
        case .coldCrystal:return (title,"Теплопроводность ещё ×1,2","Кристаллическая структура дополнительно усиливает холод на 20% поверх предыдущих улучшений. Сохраняются постепенный рост льда, баланс фаз и свободное место вокруг тела.")
        case .spring:return (title,"Маленькие скачки +35%","Гейзер сильнее пружинит при движении по опоре: импульс его маленьких скачков увеличен на 35%. Это собственная анимация и физика движения, а не дополнительный воздушный прыжок.")
        case .healingMist:return (title,"Над водой: +1 здоровья в секунду","Туман восстанавливает здоровье, пока парит над центральным водоёмом и не горит. Пассивное лечение не расходует ману и не работает над сухой землёй.")
        case .windGuard:return (title,"Снос ветром −75%","Снижает внешнюю силу ветра на тело на 75%. Управление касанием и работа воздушной подушки сохраняются; потоки вокруг кубика остаются видимыми.")
        }
    }
    public var swimSpeedMultiplier:Float { form == .water ? 1+Float(masteryRanks)*0.15 : 1 }
    public var dryingMultiplier:Float { learned.contains(.resilience) && signature == .quickDry ? 1.65 : 1 }
    public var regenerationRate:Float { !learned.contains(.resilience) ? 0 : (signature == .healingWater ? 1.5 : (signature == .healingMist ? 1 : 0)) }
    public var rollingMultiplier:Float { learned.contains(.resilience) && signature == .titanRoll ? 1.25 : 1 }
    public var evaporationMultiplier:Float { learned.contains(.resilience) && signature == .boilingHeart ? 1.25 : 1 }
    public var windForceMultiplier:Float { learned.contains(.resilience) && signature == .windGuard ? 0.25 : 1 }
    public var coldSignatureMultiplier:Float { learned.contains(.resilience) && signature == .coldCrystal ? 1.2 : 1 }
    public func effects(of kind:SkillNode.Kind)->[SkillEffect] {
        let known=learned.contains(kind)
        var before=known ? learningPreview(kind,remove:true) : self
        if !known {
            var parent=tree.first { $0.kind==kind }?.prerequisite
            while let id=parent,let node=tree.first(where:{ $0.id==id }) {
                before=before.learningPreview(node.kind);parent=node.prerequisite
            }
        }
        let after=known ? self : before.learningPreview(kind)
        func number(_ f:Float,_ unit:String="")->String { String(format:f.rounded()==f ? "%.0f" : "%.1f",f)+unit }
        func effect(_ title:String,_ a:Float,_ b:Float,_ unit:String)->SkillEffect { SkillEffect(label:title,before:number(a,unit),after:number(b,unit)) }
        switch kind {
        case .passive:return [SkillEffect(label:"Работает",before:"",after:"Автоматически"),SkillEffect(label:"Стоимость",before:"",after:"0 маны"),SkillEffect(label:"Пассивный слот",before:"",after:"1 из 1")]
        case .jump:return [SkillEffect(label:"Прицельный прыжок",before:known ? "Недоступен" : "Ещё не изучен",after:"Доступен"),effect("Предел прицела",0,after.jumpSkill.maximumSpeed," м/с"),effect("Мана за приём",0,6*after.manaMultiplier,"")]
        case .momentum:return [effect("Предел прицела",before.jumpSkill.maximumSpeed,after.jumpSkill.maximumSpeed," м/с"),effect("Мана за приём",6*before.manaMultiplier,6*after.manaMultiplier,"")]
        case .doubleJump:return [effect("Толчков в воздухе",0,1,""),effect("Мана за толчок",0,10*after.manaMultiplier,"")]
        case .control:return [SkillEffect(label:"Руль в полёте",before:form == .air ? "Базовый" : "Нет",after:form == .air ? "Усилен на 40%" : "Касание карты"),effect("Предел прицела",before.jumpSkill.maximumSpeed,after.jumpSkill.maximumSpeed," м/с")]
        case .mastery,.affinity:
            var result:[SkillEffect]
            if form == .ice || hybridStyle == .crystal { result=[effect("Теплопроводность",before.conductivity*100,after.conductivity*100,"%")] }
            else if form == .fire || hybridStyle == .magma { result=[effect("Потеря здоровья при кипении",before.fireDamageMultiplier*100,after.fireDamageMultiplier*100,"%")] }
            else if form == .water { result=[effect("Сила плавания и толчка",before.swimSpeedMultiplier*100,after.swimSpeedMultiplier*100,"%")] }
            else if form == .air { result=[effect("Сила воздушной подушки",before.airControlMultiplier*100,after.airControlMultiplier*100,"%")] }
            else { result=[effect("Получаемый урон от посадки",before.landingDamageMultiplier*100,after.landingDamageMultiplier*100,"%")] }
            if kind == .affinity { result.append(effect("Мана прицельного прыжка",6*before.manaMultiplier,6*after.manaMultiplier,""));result.append(effect("Мана двойного прыжка",10*before.manaMultiplier,10*after.manaMultiplier,"")) };return result
        case .resilience:
            switch signature {
            case .quickDry:return [effect("Скорость высыхания",before.dryingMultiplier*100,after.dryingMultiplier*100,"%")]
            case .healingWater,.healingMist:return [effect("Восстановление здоровья",before.regenerationRate,after.regenerationRate,"/с")]
            case .softLanding:return [effect("Получаемый урон от посадки",before.landingDamageMultiplier*100,after.landingDamageMultiplier*100,"%")]
            case .titanRoll:return [effect("Тяга двигателя качения",before.rollingMultiplier*100,after.rollingMultiplier*100,"%")]
            case .boilingHeart:return [effect("Испарение воды",1.9*before.evaporationMultiplier,1.9*after.evaporationMultiplier," м²/с")]
            case .coldCrystal:return [effect("Теплопроводность",before.conductivity*100,after.conductivity*100,"%")]
            case .spring:return [effect("Импульс маленького скачка",before.hopImpulse,after.hopImpulse," м/с")]
            case .windGuard:return [effect("Внешняя сила ветра",before.windForceMultiplier*100,after.windForceMultiplier*100,"%")]
            }
        }
    }
}
