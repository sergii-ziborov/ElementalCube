import SwiftUI
import ElementalCore

final class GameSession: ObservableObject {
    private let settingsStore: PlaygroundSettingsStore
    private let feedback = HapticFeedback()
    private let inventoryStore=MonsterInventoryStore()
    @Published var inventory=MonsterInventory()
    private var movementInput = MovementInput()
    private var directControl = DirectControl()
    var viewport = WorldViewport()
    var destination:Float? { directControl.destination }
    var simulation = Simulation()
    @Published var shards = 0
    @Published var energy:Float = 100
    @Published var health:Float = 100
    @Published var form:ElementForm = .ice
    @Published var passiveWorking=false
    @Published var abilityInfo=false
    @Published var forms=false
    @Published var dead=false
    @Published var deepRelic=false
    var suspended:Bool { paused || settings || abilityInfo || forms || dead || aiming }
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
    @Published var hint = "Коснись карты — движение. Потяни кубика к цели — прыжок." { didSet { hintUntil=simulation.time+3 } }
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
        if !visualPreview && !args.contains("--ui-testing") { inventory=inventoryStore.load(selectedForm:form);form=inventory.selected.form }
        else { if args.contains("--ui-testing") { form = .ice };inventory=MonsterInventory(selectedForm:form) }
        simulation=Simulation(form:form);simulation.applySkills(of:inventory.selected)
        let storedWind=UserDefaults.standard.object(forKey:"elementalcube.wind") as? Double ?? 1
        wind=storedWind.isFinite ? max(-3,min(3,storedWind)) : 1;simulation.wind=Float(wind)
        let stored = visualPreview ? PlaygroundSettings() : settingsStore.load()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        debug=stored.debug;haptics=stored.haptics
        simulation.gravity=Float(gravity);simulation.waterEnabled=water
        // Reproducible local QA scenes, never enabled by a normal launch.
        if visualPreview {
            simulation.equipPassive(true)
            if args.contains("--preview-summit") {
                simulation.placeCube(Vec(WorldLayout.summit.x,WorldLayout.summit.y+0.7));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-cave") {
                simulation.placeCube(Vec(41,-12.3));for _ in 0..<120 { simulation.step() }
            } else if args.contains("--preview-gesture") || args.contains("--preview-skills") || args.contains("--preview-equipment") {
                for _ in 0..<120 { simulation.step() }
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
        if args.contains("--preview-fur-live") || args.contains("--preview-physics-live") { visualPreview=false }
        refresh()
    }
    func preparePreview() {
        guard !previewPrepared,ProcessInfo.processInfo.arguments.contains("--preview-gesture") else { return }
        previewPrepared=true
        let point=viewport.project(simulation.cube.position,depth:1.1)
        pointerBegan(CGPoint(x:CGFloat(point.x),y:CGFloat(point.y)))
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
        AimPlanner.directImpulse(dx:Float(aim.width),dy:Float(aim.height),maximumSpeed:simulation.jumpSkill.maximumSpeed,sensitivity:Float(power))
    }
    var launchVelocity:Vec { simulation.launchVelocity(for:aimImpulse) }
    func pointerBegan(_ point:CGPoint) {
        guard !suspended else { return }
        let p=Vec(Float(point.x),Float(point.y)),body=simulation.cube!
        let hit=viewport.hitsCube(p,center:body.position,angle:simulation.bodyAngle,stretch:Vec(simulation.bodyStretch.x,simulation.bodyStretch.y))
        directControl.begin(screen:p,worldX:viewport.unproject(p,depth:1.1).x,onCube:hit,canJump:simulation.canLaunch)
        aiming=directControl.gesture == .aim;aim = .zero
        applyMovement()
        if hit && !aiming { hint="Дождись опоры, чтобы оттолкнуться. Касание карты задаёт движение." }
    }
    func pointerMoved(_ point:CGPoint) {
        let p=Vec(Float(point.x),Float(point.y))
        directControl.update(screen:p,worldX:viewport.unproject(p,depth:1.1).x)
        aim=CGSize(width:CGFloat(directControl.drag.x),height:CGFloat(directControl.drag.y))
        applyMovement()
    }
    func pointerEnded(_ point:CGPoint) {
        pointerMoved(point)
        let impulse=aimImpulse
        let drag=directControl.end()
        aiming=false;aim = .zero
        if drag != nil && hypot(impulse.x,impulse.y)>0.05 {
            let accepted=simulation.jump(impulse,buffered:false)
            if !accepted { hint="Для толчка нужна опора, контакт с водой и запас маны." }
            else { hint="Чем дальше тянешь, тем сильнее прыжок. Предел задаёт навык куба." }
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
    func tapJump() { guard !suspended else { return };_ = simulation.jump(Vec(0,7.2));deliverFeedback() }
    func showAbility() { guard !suspended else { return };cancelAim();abilityInfo=true }
    func selectMonster(_ id:UUID) {
        saveInventory()
        guard inventory.select(id) else { return }
        form=inventory.selected.form;UserDefaults.standard.set(form.rawValue,forKey:"elementalcube.form")
        inventoryStore.save(inventory);reset(preserveFinds:false);forms=false
    }
    func learn(_ node:SkillNode,for id:UUID) {
        guard inventory.learn(node,monsterID:id) else { return }
        if id==inventory.selectedID { simulation.applySkills(of:inventory.selected) }
        inventoryStore.save(inventory)
    }
    func saveInventory() {
        inventory.recordFinds(crystals:simulation.collected,relic:simulation.deepRelic)
        if !visualPreview { inventoryStore.save(inventory) }
    }
    func equip(_ item:MonsterItem?) {
        guard inventory.equip(item) else { return }
        simulation.applySkills(of:inventory.selected);inventoryStore.save(inventory)
    }
    func reset(preserveFinds:Bool=true) {
        if preserveFinds { saveInventory() };simulation=Simulation(form:form);simulation.applySkills(of:inventory.selected);simulation.gravity=Float(gravity);simulation.waterEnabled=water;simulation.wind=Float(wind)
        visualPreview=false;cancelAim();hint="Новая попытка. \(form.ability) действует автоматически.";refresh()
    }
    func tick() {
        guard !suspended && !visualPreview else { return }
        applyMovement();simulation.step();deliverFeedback();publishTime+=Simulation.timestep
        if publishTime > 0.06 { publishTime=0;refresh() }
    }
    func refresh() {
        shards=simulation.collected.count;energy=simulation.energy;wetness=simulation.wetness;grounded=simulation.cube.grounded
        inWater=simulation.inWater;won=simulation.won;jumps=simulation.jumps
        let changed=inventory.selected.crystals.union(simulation.collected) != inventory.selected.crystals || (simulation.deepRelic && !inventory.selected.deepRelic)
        inventory.recordFinds(crystals:simulation.collected,relic:simulation.deepRelic)
        if changed && !visualPreview { inventoryStore.save(inventory) }
        health=simulation.health;dead=simulation.dead;passiveWorking=simulation.passiveWorking;deepRelic=simulation.deepRelic
    }
}
