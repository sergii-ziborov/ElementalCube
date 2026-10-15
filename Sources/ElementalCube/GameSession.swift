import SwiftUI
import ElementalCore

enum HomeTab:String,CaseIterable { case journey="Путь",collection="Кубики",laboratory="Эволюция" }

final class GameSession: ObservableObject {
    private let settingsStore: PlaygroundSettingsStore
    private let feedback = HapticFeedback()
    private let inventoryStore=MonsterInventoryStore()
    private let adventureStore=AdventureStore()
    @Published var adventure=AdventureState()
    var inventory:MonsterInventory { get { adventure.inventory } set { adventure.inventory=newValue } }
    @Published var home=true
    @Published var homeTab:HomeTab = .journey
    @Published var starter=MonsterRecord(form:.ice)
    @Published var recruitCandidates=ElementForm.allCases.map { MonsterRecord(form:$0) }
    @Published var homeMessage=""
    @Published var affection=0
    var monsterName:String { inventory.selected.name }
    private var lastPet:TimeInterval = -100
    private var movementInput = MovementInput()
    private var directControl = DirectControl()
    var viewport = WorldViewport()
    var destination:Float? { directControl.destination }
    var simulation = Simulation()
    @Published var shards = 0
    @Published var coinFinds=0
    @Published var completion:FinishReceipt?=nil
    @Published var elapsed:Double=0
    @Published var energy:Float = 100
    @Published var health:Float = 100
    @Published var form:ElementForm = .ice
    @Published var passiveWorking=false
    @Published var abilityInfo=false
    @Published var forms=false
    @Published var dead=false
    @Published var deepRelic=false
    var suspended:Bool { home || paused || settings || abilityInfo || forms || dead || won }
    @Published var burning:Float = 0
    @Published var wetness:Float = 0
    @Published var grounded = true
    @Published var inWater = false
    @Published var won = false
    @Published var jumps = 0
    @Published var aim: CGSize = .zero
    @Published var aiming = false
    @Published var settings = false
    @Published var debug = false { didSet { persistSettings() } }
    @Published var paused = false
    @Published var hint = "Свайп вверх — прыжок. Карта — движение. Погладь кубика — он обрадуется." { didSet { hintUntil=simulation.time+3 } }
    var hintUntil:Float = 0
    @Published var gravity:Double = 18 { didSet { simulation.gravity=Float(gravity);persistSettings() } }
    @Published var power:Double = 1 { didSet { persistSettings() } }
    @Published var water = true { didSet { simulation.waterEnabled=water;persistSettings() } }
    @Published var zoom:Double = 1 { didSet { persistSettings() } }

    @Published var haptics = true { didSet { persistSettings() } }
    @Published var wind:Double = 1 { didSet { simulation.wind=Float(wind);UserDefaults.standard.set(wind,forKey:"elementalcube.wind") } }
    @Published var direction:Float = 1
    @Published var moving:Float = 0
    var dragging = false
    private var publishTime:Float = 0
    private var visualPreview = false
    private var previewPrepared=false
    init() {
        settingsStore = PlaygroundSettingsStore()
        let args=ProcessInfo.processInfo.arguments
        visualPreview=args.contains { $0.hasPrefix("--preview-") }
        let furPreview=args.contains { $0.hasPrefix("--preview-fur-") }
        let physicsPreview=args.contains { $0.hasPrefix("--preview-physics-") }
        let previewForm=physicsPreview ? (args.contains("--preview-physics-crate") ? ElementForm.water : (args.contains("--preview-physics-bridge") ? .stone : .ice)) : (furPreview ? ElementForm.ice : ElementForm.allCases.first { args.contains("--preview-"+$0.rawValue) })
        form=previewForm ?? ElementForm(rawValue:UserDefaults.standard.string(forKey:"elementalcube.form") ?? "ice") ?? .ice
        if args.contains("--preview-metamorphosis") { form = .ice }
        if !visualPreview && !args.contains("--ui-testing") {
            adventure=adventureStore.load(fallback:inventoryStore.load(selectedForm:form));form=inventory.selected.form
        } else {
            if args.contains("--ui-testing") && previewForm == nil { form = .ice }
            adventure=AdventureState(inventory:MonsterInventory(selectedForm:form))
        }
        starter=inventory.selected
        let previewHome=args.contains("--preview-journey") || args.contains("--preview-home") || args.contains("--preview-lab") || args.contains("--preview-metamorphosis")
        home = previewHome || args.contains("--preview-start") || (!visualPreview && (!args.contains("--ui-testing") || args.contains("--onboarding")))
        if (!home || previewHome) && !adventure.started { _=adventure.begin(with:inventory.selected) }
        if args.contains("--ui-testing-rich") || args.contains("--preview-lab") || args.contains("--preview-metamorphosis") {
            for map in WorldMap.allCases { adventure.map=map;adventure.recordFinds(Set(0..<12),relic:true);adventure.finishMap() }
            adventure.map = .shore
        }
        if args.contains("--preview-lab") { homeTab = .laboratory;_ = adventure.evolve() }
        if args.contains("--preview-metamorphosis") {
            let receiver=inventory.selectedID,donor=inventory.monsters.first { $0.form == .fire }!.id
            for kind in [SkillNode.Kind.jump,.momentum,.doubleJump,.control,.mastery,.affinity,.resilience] { _=inventory.learn(inventory.selected.tree.first { $0.kind==kind }!,monsterID:receiver) }
            _=adventure.evolve();_=inventory.setInheritanceSelection([.mastery,.affinity,.resilience,.jump])
            _=adventure.select(donor);adventure.recordFinds(Set(0..<12),relic:false)
            for kind in [SkillNode.Kind.jump,.momentum,.doubleJump,.control,.mastery,.affinity,.resilience] { _=inventory.learn(inventory.selected.tree.first { $0.kind==kind }!,monsterID:donor) }
            _=inventory.setInheritanceSelection([.jump,.mastery,.momentum,.affinity]);_=adventure.select(receiver);homeTab = .laboratory
        }
        if args.contains("--preview-journey") {
            adventure.map = .shore;adventure.finishMap();adventure.map = .glacier;adventure.finishMap();adventure.map = .meadow
        }
        if args.contains("--preview-glacier") { adventure.map = .glacier }
        if args.contains("--preview-forge") { adventure.map = .forge }
        if args.contains("--preview-gesture"),let node=inventory.selected.tree.first(where:{ $0.kind == .jump }) { _=inventory.learn(node,monsterID:inventory.selectedID) }
        simulation=Simulation(form:form,map:adventure.map);simulation.applySkills(of:inventory.selected)
        simulation.restoreFinds(crystals:adventure.foundCrystals(on:adventure.map),coins:adventure.foundCoins(on:adventure.map),relic:inventory.selected.deepRelic)
        let storedWind=UserDefaults.standard.object(forKey:"elementalcube.wind") as? Double ?? 1
        wind=storedWind.isFinite ? max(-3,min(3,storedWind)) : 1;simulation.wind=Float(wind)
        // Isolate the vertical gesture regression from saved wind settings.
        if args.contains("--ui-testing") && args.contains("--test-calm") { simulation.wind=0 }
        let stored = visualPreview ? PlaygroundSettings() : settingsStore.load()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        debug=stored.debug;haptics=stored.haptics
        simulation.gravity=Float(gravity);simulation.waterEnabled=water
        // Reproducible local QA scenes, never enabled by a normal launch.
        if visualPreview && !home {
            simulation.equipPassive(true)
            if args.contains("--preview-shatter") {
                simulation.wind=0;zoom=1.45
                for _ in 0..<30 { simulation.step() }
                simulation.placeCube(Vec(3.65,0.7),velocity:Vec(7,0))
                for _ in 0..<60 { simulation.step() }
            } else if args.contains("--preview-finish") {
                let goal=simulation.definition.goal;simulation.placeCube(Vec(goal.x,goal.y+0.75));simulation.movement=0.1
                for _ in 0..<120 { simulation.step();if simulation.won { break } }
            } else if args.contains("--preview-glacier") {
                simulation.placeCube(Vec(42,7.9));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-forge") {
                simulation.placeCube(Vec(46.2,-11.9));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-summit") {
                simulation.placeCube(Vec(WorldLayout.summit.x,WorldLayout.summit.y+0.7));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-cave") {
                simulation.placeCube(Vec(41,-12.3));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-gesture") || args.contains("--preview-skills") || args.contains("--preview-equipment") {
                for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-bank") {
                simulation.wind=0;zoom=1.15
                simulation.placeCrate(Vec(2,1));simulation.placeCube(Vec(14.5,-0.5));simulation.movement=1
                for _ in 0..<100 { simulation.step() };simulation.movement=0
            } else if args.contains("--preview-splash") {
                simulation.wind=0;zoom=0.9
                simulation.placeCube(Vec(9.1,0.1))
                simulation.placeCrate(Vec(10,1.2),angle:0.1,velocity:Vec(0,-5))
                // Stop a real coupled impact at its first visible spray crest.
                for _ in 0..<200 {
                    simulation.step()
                    if simulation.waterField.liquid.particles.contains(where:{ $0.isSpray && $0.position.y>simulation.waterField.liquid.surfaceHeight(at:$0.position.x)+0.36 }) { break }
                }
            } else if physicsPreview {
                simulation.wind=0;zoom=1.1
                if args.contains("--preview-physics-crate") {
                    simulation.placeCube(Vec(11.1,-0.2));simulation.placeCrate(Vec(9.8,0.8),angle:0.35,velocity:Vec(1.8,-1))
                    for _ in 0..<130 { simulation.step() }
                } else if args.contains("--preview-physics-bridge") {
                    simulation.placeCube(Vec(12,1.2));for _ in 0..<240 { simulation.step() }
                } else {
                    simulation.placeCube(Vec(9.3,0.5));for _ in 0..<100 { simulation.step() }
                }
            } else if furPreview {
                zoom=1.8
                simulation.wind=args.contains("--preview-fur-wind") || args.contains("--preview-fur-live") ? 3 : 0.5
                if args.contains("--preview-fur-wet") {
                    simulation.placeCube(Vec(10,-1));for _ in 0..<240 { simulation.step() }
                }
                simulation.placeCube(Vec(3.5,0.7))
                for _ in 0..<24 { simulation.step() }
            } else if args.contains("--preview-stone") {
                simulation.placeCube(Vec(10,-3.3));simulation.movement=1
                for _ in 0..<150 { simulation.step() };simulation.movement=0
            } else if args.contains("--preview-fire") {
                simulation.placeCube(Vec(9.9,-1))
                for _ in 0..<300 { simulation.step() }
            } else if args.contains("--preview-air") {
                simulation.placeCube(Vec(10,0.1));for _ in 0..<160 { simulation.step() }
            } else {
                simulation.placeCube(Vec(10,-1));for _ in 0..<360 { simulation.step() }
                if args.contains("--preview-wet") { simulation.placeCube(Vec(6,0.7));for _ in 0..<30 { simulation.step() } }
                else if args.contains("--preview-ice") { simulation.placeCube(Vec(10.7,-0.2));for _ in 0..<150 { simulation.step() } }
            }
        }
        abilityInfo=args.contains("--preview-ability");forms=args.contains("--preview-forms") || args.contains("--preview-skills") || args.contains("--preview-equipment")
        if args.contains("--preview-fur-live") || args.contains("--preview-physics-live") || args.contains("--preview-live") { visualPreview=false }
        refresh()
    }
    func preparePreview() {
        guard !previewPrepared,ProcessInfo.processInfo.arguments.contains("--preview-gesture") else { return }
        previewPrepared=true
        let point=viewport.project(simulation.cube.position,depth:1.1)
        pointerBegan(CGPoint(x:CGFloat(point.x),y:CGFloat(point.y)),time:ProcessInfo.processInfo.systemUptime-0.4)
        pointerMoved(CGPoint(x:CGFloat(point.x)+75,y:CGFloat(point.y)-110))
    }
    private func persistSettings() {
        var stored = PlaygroundSettings()
        stored.gravity=gravity;stored.power=power;stored.zoom=zoom;stored.water=water
        stored.inverted=false;stored.debug=debug;stored.haptics=haptics
        settingsStore.save(stored)
    }
    func restoreDefaults() {
        let stored = PlaygroundSettings()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        debug=stored.debug;haptics=stored.haptics;wind=1
    }
    private func deliverFeedback() { feedback.play(simulation.takeFeedback(),enabled:haptics && !visualPreview) }
    var aimImpulse:Vec {
        guard simulation.directionalJumpUnlocked else { return Vec(0,0) }
        return AimPlanner.directImpulse(dx:Float(aim.width),dy:Float(aim.height),maximumSpeed:simulation.jumpSkill.maximumSpeed,sensitivity:Float(power))
    }
    var launchVelocity:Vec { simulation.launchVelocity(for:aimImpulse) }
    func pointerBegan(_ point:CGPoint,time:TimeInterval=ProcessInfo.processInfo.systemUptime) {
        guard !suspended else { return }
        let p=Vec(Float(point.x),Float(point.y)),body=simulation.cube!
        let hit=viewport.hitsCube(p,center:body.position,angle:simulation.bodyAngle,stretch:Vec(simulation.bodyStretch.x,simulation.bodyStretch.y))
        directControl.begin(screen:p,worldX:viewport.unproject(p,depth:1.1).x,onCube:hit,canJump:simulation.canLaunch,canAim:simulation.directionalJumpUnlocked,time:time)
        aiming=directControl.gesture == .aim;aim = .zero
        applyMovement()
        if hit { hint=simulation.directionalJumpUnlocked ? "Погладь кубика. Для прицела удержи и потяни." : "Кубик любит поглаживания. Прыжок — свайп вверх по экрану." }
    }
    func pointerMoved(_ point:CGPoint) {
        let p=Vec(Float(point.x),Float(point.y))
        directControl.update(screen:p,worldX:viewport.unproject(p,depth:1.1).x)
        aiming=directControl.gesture == .aim
        aim=CGSize(width:CGFloat(directControl.drag.x),height:CGFloat(directControl.drag.y))
        if directControl.gesture == .cube && hypot(directControl.drag.x,directControl.drag.y)>8 { petCube() }
        applyMovement()
    }
    func pointerEnded(_ point:CGPoint) {
        pointerMoved(point)
        let aimedImpulse=aimImpulse
        let release=directControl.end()
        aiming=false;aim = .zero
        let impulse:Vec
        switch release {
        case .pet:petCube();impulse=Vec(0,0)
        case .swipeJump(let v):impulse=v
        case .aim:impulse=aimedImpulse
        case .none:impulse=Vec(0,0)
        }
        if hypot(impulse.x,impulse.y)>0.05 {
            let directed:Bool
            if case .aim=release { directed=true } else { directed=false }
            let accepted=simulation.performJump(impulse,directed:directed)
            if !accepted { hint=simulation.nextJumpIsAirJump ? "Для второго толчка изучи двойной прыжок. Он стоит 10 маны." : "Дождись опоры. Прицельному прыжку нужны 6 маны." }
            else { hint=directed ? "Сила прицельного прыжка растёт вместе с навыками." : "Прыг! Небольшой наклон свайпа задаёт направление." }
            deliverFeedback();refresh()
        }
        applyMovement()
    }
    func setMovement(source:String,direction:Float,pressed:Bool) {
        if pressed {
            guard !suspended else { return }
            directControl.cancel();movementInput.press(source:source,direction:direction)
        } else { movementInput.release(source:source) }
        applyMovement()
    }
    private func applyMovement() {
        let body=simulation.cube!
        let mapMovement=directControl.movement(position:body.position.x,velocity:body.velocity.x)
        moving=movementInput.value != 0 ? movementInput.value : mapMovement
        simulation.movement=moving
        if moving != 0 { direction=moving<0 ? -1 : 1 }
    }
    func cancelAim() { aiming=false;aim = .zero;directControl.cancel();movementInput.clear();applyMovement() }
    func tapJump() { guard !suspended else { return };_ = simulation.performJump();deliverFeedback() }
    func showAbility() { guard !suspended else { return };cancelAim();abilityInfo=true }
    private func persistAdventure() {
        guard !visualPreview,!ProcessInfo.processInfo.arguments.contains(where:{ $0 == "--ui-testing" || $0.hasPrefix("--preview-") }) else { return }
        adventureStore.save(adventure)
    }
    func petCube() {
        let now=ProcessInfo.processInfo.systemUptime
        guard now-lastPet>0.24 else { return }
        lastPet=now;simulation.pet();affection+=1;refresh()
    }
    func showHome(_ tab:HomeTab = .journey) {
        saveInventory();cancelAim();forms=false;settings=false;abilityInfo=false
        homeTab=tab;home=true;homeMessage=""
    }
    func randomizeStarter() { starter=MonsterRecord.randomStarter() }
    func beginJourney() {
        guard adventure.begin(with:starter) else { return }
        form=inventory.selected.form;persistAdventure();reset(preserveFinds:false);home=false;paused=false
    }
    func play(_ map:WorldMap) {
        guard adventure.started,adventure.canVisit(map) else { return }
        saveInventory()
        let changing=adventure.map != map
        adventure.map=map;persistAdventure()
        if changing || simulation.won || simulation.dead { reset(preserveFinds:false) }
        home=false;paused=false;forms=false;cancelAim()
    }
    @discardableResult func selectMonster(_ id:UUID)->Bool {
        saveInventory()
        guard adventure.select(id) else { homeMessage="Для смены кубика нужно больше эфира. Находи кристаллы в мирах.";return false }
        form=inventory.selected.form;persistAdventure();reset(preserveFinds:false);forms=false
        homeMessage="\(monsterName) готов к приключению.";return true
    }
    @discardableResult func recruit(_ candidate:MonsterRecord)->Bool {
        saveInventory()
        guard adventure.recruitRandom(candidate) else { homeMessage="Новый друг стоит 4 эфира.";return false }
        form=inventory.selected.form
        if let i=recruitCandidates.firstIndex(where:{ $0.id==candidate.id }) { recruitCandidates[i]=MonsterRecord(form:candidate.form) }
        persistAdventure();reset(preserveFinds:false);homeMessage="Знакомьтесь: \(monsterName)!";return true
    }
    func evolve() {
        saveInventory()
        guard adventure.evolve() else { return }
        simulation.applySkills(of:inventory.selected);simulation.pet();affection+=1
        persistAdventure();homeMessage="Новая ступень: \(monsterName) · \(inventory.selected.stageName.lowercased())."
    }
    @discardableResult func merge(with second:UUID)->MonsterRecord? {
        saveInventory()
        guard let plan=adventure.prepareMerge(inventory.selectedID,second) else { return nil }
        return commitMerge(plan)
    }
    @discardableResult func commitMerge(_ plan:MergePlan,pins:Set<GenePin>=[])->MonsterRecord? {
        guard let child=adventure.commitMerge(plan,pins:pins) else { return nil }
        persistAdventure()
        if inventory.selectedID==child.id { form=child.form;reset(preserveFinds:false) }
        homeMessage="Новое поколение: \(child.name). Донор остался с тобой.";return child
    }
    @discardableResult func setInheritanceSelection(_ kinds:[SkillNode.Kind],owner:UUID)->Bool {
        guard owner==inventory.selectedID,inventory.setInheritanceSelection(kinds) else { return false }
        persistAdventure();return true
    }
    @discardableResult func learn(_ node:SkillNode,for id:UUID)->Bool {
        guard inventory.learn(node,monsterID:id) else { return false }
        if id==inventory.selectedID { simulation.applySkills(of:inventory.selected) }
        if id==inventory.selectedID { simulation.pet();affection+=1 }
        persistAdventure();return true
    }
    @discardableResult func buyStudyPoint()->Bool {
        guard adventure.buyStudyPoint(for:inventory.selectedID) else { return false }
        persistAdventure();homeMessage="Новое очко навыка у \(monsterName). Выбери улучшение в дереве.";return true
    }
    func saveInventory() {
        adventure.recordFinds(simulation.collected,relic:simulation.deepRelic)
        adventure.recordCoins(simulation.collectedCoins)
        if let result=simulation.outcome { completion=adventure.finishRun(result) }
        persistAdventure()
    }
    func equip(_ item:MonsterItem?) {
        guard inventory.equip(item) else { return }
        simulation.applySkills(of:inventory.selected);persistAdventure()
    }
    func reset(preserveFinds:Bool=true) {
        if preserveFinds { saveInventory() }
        completion=nil
        simulation=Simulation(form:form,map:adventure.map);simulation.applySkills(of:inventory.selected)
        simulation.restoreFinds(crystals:adventure.foundCrystals(on:adventure.map),coins:adventure.foundCoins(on:adventure.map),relic:inventory.selected.deepRelic)
        simulation.gravity=Float(gravity);simulation.waterEnabled=water;simulation.wind=Float(wind)
        visualPreview=false;cancelAim();hint="\(monsterName) здесь. Свайп вверх — прыжок.";refresh()
    }
    func tick() {
        guard !suspended && !visualPreview else { return }
        applyMovement();simulation.step();deliverFeedback();publishTime+=Simulation.timestep
        if publishTime > 0.06 { publishTime=0;refresh() }
    }
    func refresh() {
        shards=simulation.collected.count;coinFinds=simulation.collectedCoins.count;elapsed=simulation.elapsed ?? 0;energy=simulation.energy;burning=simulation.burning;wetness=simulation.wetness;grounded=simulation.cube.grounded
        inWater=simulation.inWater;won=simulation.won;jumps=simulation.jumps
        let before=adventure
        adventure.recordFinds(simulation.collected,relic:simulation.deepRelic)
        adventure.recordCoins(simulation.collectedCoins)
        if let result=simulation.outcome { completion=adventure.finishRun(result) }
        if adventure != before { persistAdventure() }
        health=simulation.health;dead=simulation.dead;passiveWorking=simulation.passiveWorking;deepRelic=simulation.deepRelic
    }
}
