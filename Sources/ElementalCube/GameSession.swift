import SwiftUI
import ElementalCore

final class GameSession: ObservableObject {
    private let settingsStore: PlaygroundSettingsStore
    private let feedback = HapticFeedback()
    private var movementInput = MovementInput()
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
    var suspended:Bool { paused || settings || abilityInfo || forms || dead }
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
    @Published var hint = "Потяни кнопку назад и отпусти — куб прыгнет по дуге." { didSet { hintUntil=simulation.time+3 } }
    var hintUntil:Float = 0
    @Published var gravity:Double = 18 { didSet { simulation.gravity=Float(gravity);persistSettings() } }
    @Published var power:Double = 1 { didSet { simulation.jumpScale=Float(power);persistSettings() } }
    @Published var water = true { didSet { simulation.waterEnabled=water;persistSettings() } }
    @Published var zoom:Double = 1 { didSet { persistSettings() } }
    @Published var inverted = true { didSet { persistSettings() } }
    @Published var haptics = true { didSet { persistSettings() } }
    @Published var wind:Double = 1 { didSet { simulation.wind=Float(wind);UserDefaults.standard.set(wind,forKey:"elementalcube.wind") } }
    @Published var direction:Float = 1
    @Published var moving:Float = 0
    var dragging = false
    private var publishTime:Float = 0
    private var visualPreview = false
    init() {
        settingsStore = PlaygroundSettingsStore()
        let args=ProcessInfo.processInfo.arguments
        visualPreview=args.contains { $0.hasPrefix("--preview-") }
        let furPreview=args.contains { $0.hasPrefix("--preview-fur-") }
        let physicsPreview=args.contains { $0.hasPrefix("--preview-physics-") }
        let previewForm=physicsPreview ? (args.contains("--preview-physics-crate") ? ElementForm.water : (args.contains("--preview-physics-bridge") ? .stone : .ice)) : (furPreview ? ElementForm.ice : ElementForm.allCases.first { args.contains("--preview-"+$0.rawValue) })
        form=previewForm ?? ElementForm(rawValue:UserDefaults.standard.string(forKey:"elementalcube.form") ?? "ice") ?? .ice
        simulation=Simulation(form:form)
        let storedWind=UserDefaults.standard.object(forKey:"elementalcube.wind") as? Double ?? 1
        wind=storedWind.isFinite ? max(-3,min(3,storedWind)) : 1;simulation.wind=Float(wind)
        let stored = visualPreview ? PlaygroundSettings() : settingsStore.load()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        inverted=stored.inverted;debug=stored.debug;haptics=stored.haptics
        simulation.gravity=Float(gravity);simulation.jumpScale=Float(power);simulation.waterEnabled=water
        // Reproducible local QA scenes, never enabled by a normal launch.
        if visualPreview {
            simulation.equipPassive(true)
            if physicsPreview {
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
        abilityInfo=args.contains("--preview-ability");forms=args.contains("--preview-forms")
        if args.contains("--preview-fur-live") || args.contains("--preview-physics-live") { visualPreview=false }
        refresh()
    }
    private func persistSettings() {
        var stored = PlaygroundSettings()
        stored.gravity=gravity;stored.power=power;stored.zoom=zoom;stored.water=water
        stored.inverted=inverted;stored.debug=debug;stored.haptics=haptics
        settingsStore.save(stored)
    }
    func restoreDefaults() {
        let stored = PlaygroundSettings()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        inverted=stored.inverted;debug=stored.debug;haptics=stored.haptics;wind=1
    }
    private func deliverFeedback() { feedback.play(simulation.takeFeedback(),enabled:haptics && !visualPreview) }
    var aimImpulse:Vec {
        AimPlanner.impulse(dx:Float(aim.width),dy:Float(aim.height),direction:direction,inverted:inverted)
    }
    var launchVelocity:Vec { simulation.launchVelocity(for:aimImpulse) }
    func updateAim(_ translation:CGSize) {
        let r=max(1,hypot(translation.width,translation.height)),scale=min(1,115/r)
        aim=CGSize(width:translation.width*scale,height:translation.height*scale)
    }
    func setMovement(source:String,direction:Float,pressed:Bool) {
        if pressed {
            guard !suspended else { return }
            movementInput.press(source:source,direction:direction)
        } else { movementInput.release(source:source) }
        applyMovement()
    }
    private func applyMovement() {
        moving=movementInput.value;simulation.movement=moving
        if moving != 0 { direction=moving }
    }
    func beginAim() { guard !suspended else { return }; aiming=true }
    func releaseAim() {
        guard aiming else { return }; let v=aimImpulse
        let accepted=simulation.jump(v)
        if !accepted && simulation.inWater && simulation.energy<6 { hint="Для толчка нужно 6 маны. Дождись восстановления запаса." }
        else if !accepted { hint="Для следующего прыжка нужна опора или контакт с водой." }
        else if simulation.inWater { hint="В воде: потяни в сторону берега и отпусти, чтобы выбраться." }
        else { hint="Попробуй короткий прыжок на ящик или длинный — к опоре в воде." }
        aiming=false;aim = .zero
        deliverFeedback()
    }
    func cancelAim() { aiming=false;aim = .zero;movementInput.clear();applyMovement() }
    func tapJump() { guard !suspended else { return };_ = simulation.jump(Vec(0,7.2));deliverFeedback() }
    func showAbility() { guard !suspended else { return };cancelAim();abilityInfo=true }
    func selectForm(_ selection:ElementForm) {
        form=selection;UserDefaults.standard.set(form.rawValue,forKey:"elementalcube.form")
        reset();forms=false
    }
    func reset() {
        simulation=Simulation(form:form);simulation.gravity=Float(gravity);simulation.jumpScale=Float(power);simulation.waterEnabled=water;simulation.wind=Float(wind)
        visualPreview=false;cancelAim();hint="Новая попытка. \(form.ability) действует автоматически.";refresh()
    }
    func tick() {
        guard !suspended && !visualPreview else { return }
        simulation.step();deliverFeedback();publishTime+=Simulation.timestep
        if publishTime > 0.06 { publishTime=0;refresh() }
    }
    func refresh() {
        shards=simulation.collected.count;energy=simulation.energy;wetness=simulation.wetness;grounded=simulation.cube.grounded
        inWater=simulation.inWater;won=simulation.won;jumps=simulation.jumps
        health=simulation.health;dead=simulation.dead;passiveWorking=simulation.passiveWorking;deepRelic=simulation.deepRelic
    }
}
