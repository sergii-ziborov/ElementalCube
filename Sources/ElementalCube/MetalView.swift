import SwiftUI
import MetalKit

#if os(macOS)
final class InteractiveMetalView: MTKView {
    var session:GameSession!

    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self);session.pointerBegan(convert(event.locationInWindow,from:nil))
    }
    override func mouseDragged(with event:NSEvent) {
        let p=convert(event.locationInWindow,from:nil)
        session.pointerMoved(p)
    }
    override func mouseUp(with event:NSEvent) { session.pointerEnded(convert(event.locationInWindow,from:nil)) }
    override func keyDown(with event:NSEvent) {
        switch event.keyCode {
        case 49: if !event.isARepeat { session.tapJump() }
        case 3: if !event.isARepeat { session.showAbility() }
        case 15: if !event.isARepeat { session.reset() }
        case 123,0: session.setMovement(source:"key:\(event.keyCode)",direction:-1,pressed:true)
        case 124,2: session.setMovement(source:"key:\(event.keyCode)",direction:1,pressed:true)
        case 53: session.cancelAim();session.paused.toggle()
        default: super.keyDown(with:event)
        }
    }
    override func keyUp(with event:NSEvent) {
        if [123,124,0,2].contains(Int(event.keyCode)) {
            session.setMovement(source:"key:\(event.keyCode)",direction:0,pressed:false)
        } else { super.keyUp(with:event) }
    }
    override func viewWillMove(toWindow newWindow:NSWindow?) { if newWindow == nil { session?.cancelAim() };super.viewWillMove(toWindow:newWindow) }
}
struct MetalView:NSViewRepresentable {
    var session:GameSession
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeNSView(context:Context)->InteractiveMetalView {
        let v=InteractiveMetalView();v.session=session
        do { context.coordinator.renderer=try Renderer(view:v,session:session) } catch { context.coordinator.error=error.localizedDescription;print(error) }
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }
    func updateNSView(_ view:InteractiveMetalView,context:Context) {}
    final class Coordinator { var renderer:Renderer?;var error:String? }
}
#else
final class InteractiveMetalView:MTKView {
    var session:GameSession!;var activeTouch:UITouch?
    private lazy var cubeAccessibility=UIAccessibilityElement(accessibilityContainer:self)
    private lazy var worldAccessibility=UIAccessibilityElement(accessibilityContainer:self)
    func updateAccessibility() {
        isAccessibilityElement=false
        let body=session.simulation.cube!,viewport=session.viewport,p=viewport.project(body.position,depth:1.1)
        let width=max(44,CGFloat(max(1.4,session.simulation.cubeWidth)/viewport.size.x*viewport.screen.x)),height=max(44,CGFloat(max(1.4,session.simulation.cubeHeight)/viewport.size.y*viewport.screen.y))
        cubeAccessibility.accessibilityIdentifier="game.cube";cubeAccessibility.accessibilityLabel="Куб: "+session.form.name
        cubeAccessibility.accessibilityFrameInContainerSpace=CGRect(x:CGFloat(p.x)-width/2,y:CGFloat(p.y)-height/2,width:width,height:height)
        worldAccessibility.accessibilityIdentifier="game.world";worldAccessibility.accessibilityLabel="Игровой мир"
        worldAccessibility.accessibilityFrameInContainerSpace=bounds
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            worldAccessibility.accessibilityValue=String(format:"x=%.3f;y=%.3f;jumps=%d;aiming=%d;cold=%.2f;charm=%@;pets=%d;map=%@;coins=%d;form=%@",body.position.x,body.position.y,session.simulation.jumps,session.aiming ? 1 : 0,session.simulation.waterField.conductivity,session.inventory.selected.equippedCharm?.rawValue ?? "none",session.affection,session.adventure.map.rawValue,session.adventure.coins,session.form.rawValue)
        }
        accessibilityElements=[cubeAccessibility,worldAccessibility]
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) { guard activeTouch == nil,let t=touches.first else { return };activeTouch=t;session.pointerBegan(t.location(in:self)) }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) { guard let t=activeTouch,touches.contains(t) else { return };let p=t.location(in:self);session.pointerMoved(p) }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) { guard let t=activeTouch,touches.contains(t) else { return };session.pointerEnded(t.location(in:self));activeTouch=nil }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) { activeTouch=nil;session.cancelAim() }
}
struct MetalView:UIViewRepresentable {
    var session:GameSession
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeUIView(context:Context)->InteractiveMetalView {
        let v=InteractiveMetalView();v.session=session;v.isMultipleTouchEnabled=true
        do { context.coordinator.renderer=try Renderer(view:v,session:session) } catch { print(error) }
        return v
    }
    func updateUIView(_ view:InteractiveMetalView,context:Context) {}
    final class Coordinator { var renderer:Renderer? }
}
#endif
