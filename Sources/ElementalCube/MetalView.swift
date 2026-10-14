import SwiftUI
import MetalKit

#if os(macOS)
final class InteractiveMetalView: MTKView {
    var session:GameSession!
    var origin=CGPoint.zero
    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self);origin=convert(event.locationInWindow,from:nil);session.beginAim()
    }
    override func mouseDragged(with event:NSEvent) {
        let p=convert(event.locationInWindow,from:nil)
        session.updateAim(CGSize(width:p.x-origin.x,height:p.y-origin.y))
    }
    override func mouseUp(with event:NSEvent) { session.releaseAim() }
    override func keyDown(with event:NSEvent) {
        switch event.keyCode {
        case 49: if !event.isARepeat { session.tapJump() }
        case 3: if !event.isARepeat { session.frost() }
        case 15: if !event.isARepeat { session.reset() }
        case 123,0: session.move(-1)
        case 124,2: session.move(1)
        case 53: session.cancelAim();session.paused.toggle()
        default: super.keyDown(with:event)
        }
    }
    override func keyUp(with event:NSEvent) {
        if [123,124,0,2].contains(Int(event.keyCode)) { session.move(0) } else { super.keyUp(with:event) }
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
    var session:GameSession!;var origin=CGPoint.zero;var activeTouch:UITouch?
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) { guard activeTouch == nil,let t=touches.first else { return };activeTouch=t;origin=t.location(in:self);session.beginAim() }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) { guard let t=activeTouch,touches.contains(t) else { return };let p=t.location(in:self);session.updateAim(CGSize(width:p.x-origin.x,height:p.y-origin.y)) }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) { guard let t=activeTouch,touches.contains(t) else { return };activeTouch=nil;session.releaseAim() }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) { activeTouch=nil;session.cancelAim() }
}
struct MetalView:UIViewRepresentable {
    var session:GameSession
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeUIView(context:Context)->InteractiveMetalView {
        let v=InteractiveMetalView();v.session=session;v.isMultipleTouchEnabled=false
        do { context.coordinator.renderer=try Renderer(view:v,session:session) } catch { print(error) }
        return v
    }
    func updateUIView(_ view:InteractiveMetalView,context:Context) {}
    final class Coordinator { var renderer:Renderer? }
}
#endif
