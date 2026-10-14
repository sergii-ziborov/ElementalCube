import SwiftUI
import ElementalCore

final class GameSession: ObservableObject {
    private let settingsStore: PlaygroundSettingsStore
    private let feedback = HapticFeedback()
    private var movementInput = MovementInput()
    var simulation = Simulation()
    @Published var shards = 0
    @Published var energy:Float = 100
    @Published var wetness:Float = 0
    @Published var grounded = true
    @Published var inWater = false
    @Published var won = false
    @Published var iceTime:Float = 0
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
    @Published var direction:Float = 1
    @Published var moving:Float = 0
    var dragging = false
    private var publishTime:Float = 0
    private var visualPreview = false
    init() {
        settingsStore = PlaygroundSettingsStore()
        let args=ProcessInfo.processInfo.arguments
        visualPreview=args.contains("--preview-water") || args.contains("--preview-wet") || args.contains("--preview-ice")
        let stored = visualPreview ? PlaygroundSettings() : settingsStore.load()
        gravity=stored.gravity;power=stored.power;zoom=stored.zoom;water=stored.water
        inverted=stored.inverted;debug=stored.debug;haptics=stored.haptics
        simulation.gravity=Float(gravity);simulation.jumpScale=Float(power);simulation.waterEnabled=water
        // Local visual QA scenes; normal launches always start at the beginning of the map.
        if args.contains("--preview-water") || args.contains("--preview-wet") {
            simulation.placeCube(Vec(10,-1.2))
            for _ in 0..<240 { simulation.step() }
            if args.contains("--preview-wet") { simulation.placeCube(Vec(6,0.7));for _ in 0..<30 { simulation.step() } }
        } else if args.contains("--preview-ice") {
            simulation.placeCube(Vec(6,0.7));for _ in 0..<90 { simulation.step() }
            _=simulation.frost();simulation.placeCube(Vec(9,0.7));for _ in 0..<90 { simulation.step() }
        }
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
        inverted=stored.inverted;debug=stored.debug;haptics=stored.haptics
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
            guard !paused && !settings else { return }
            movementInput.press(source:source,direction:direction)
        } else { movementInput.release(source:source) }
        applyMovement()
    }
    private func applyMovement() {
        moving=movementInput.value;simulation.movement=moving
        if moving != 0 { direction=moving }
    }
    func beginAim() { guard !paused && !settings else { return }; aiming=true }
    func releaseAim() {
        guard aiming else { return }; let v=aimImpulse
        let accepted=simulation.jump(v)
        if !accepted && simulation.inWater && simulation.energy<6 { hint="Для толчка нужно 6 энергии — она восстановится за пару секунд." }
        else if !accepted { hint="Для следующего прыжка нужна опора или контакт с водой." }
        else if simulation.inWater { hint="В воде: потяни в сторону берега и отпусти, чтобы выбраться." }
        else { hint="Попробуй короткий прыжок на ящик или длинный — к опоре в воде." }
        aiming=false;aim = .zero
        deliverFeedback()
    }
    func cancelAim() { aiming=false;aim = .zero;movementInput.clear();applyMovement() }
    func tapJump() { guard !paused && !settings else { return };_ = simulation.jump(Vec(0,7.2));deliverFeedback() }
    func frost() {
        guard !paused && !settings else { return }
        if simulation.frost() { hint="Ледяной наст готов. У тебя 25 секунд, чтобы перейти воду." }
        else if simulation.iceTime > 0 { hint="Наст уже создан — он растает сам." }
        else if simulation.energy < 30 { hint="Нужно 30 энергии. Она постепенно восстанавливается." }
        else { hint="Подойди к воде: дыхание действует только вблизи берега." }
        refresh()
        deliverFeedback()
    }
    func reset() {
        simulation=Simulation();simulation.gravity=Float(gravity);simulation.jumpScale=Float(power);simulation.waterEnabled=water
        cancelAim();hint="Новая попытка. Все изменения карты сброшены.";refresh()
    }
    func tick() {
        guard !paused && !settings && !visualPreview else { return }
        simulation.step();deliverFeedback();publishTime+=Simulation.timestep
        if publishTime > 0.06 { publishTime=0;refresh() }
    }
    func refresh() {
        shards=simulation.collected.count;energy=simulation.energy;wetness=simulation.wetness;grounded=simulation.cube.grounded
        inWater=simulation.inWater;won=simulation.won;iceTime=simulation.iceTime;jumps=simulation.jumps
    }
}
