import SwiftUI
import MetalKit
import ElementalCore

struct CharacterPreviewState {
    var form:ElementForm,secondary:ElementForm?,seed:UInt64,stage:Int
    var time:Float,reactionAge:Float,wetness:Float,health:Float,burning:Float,reduced:Bool
}

/// UI and gameplay share the actual mesh, materials, coat shader and face.
/// Only the small portrait is rendered; this never advances a game simulation.
private final class PortraitGPU {
    static let shared:PortraitGPU? = {
        do { return try PortraitGPU() }
        catch {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") { fputs("Portrait GPU: \(error)\n",stderr) }
            return nil
        }
    }()
    let device:MTLDevice,queue:MTLCommandQueue
    let scene:MTLRenderPipelineState,coat:MTLRenderPipelineState,fiber:MTLRenderPipelineState,depth:MTLDepthStencilState
    init() throws {
        guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { throw NSError(domain:"Portrait Metal",code:1) }
        self.device=device;self.queue=queue
        #if SWIFT_PACKAGE
        let bundle=Bundle.module
        #else
        let bundle=Bundle.main
        #endif
        guard let url=bundle.url(forResource:"Shaders",withExtension:"metal.txt") else { throw NSError(domain:"Portrait shaders",code:2) }
        let library=try device.makeLibrary(source:String(contentsOf:url),options:nil)
        func pipeline(_ vertex:String,_ fragment:String,_ coverage:Bool=false)throws->MTLRenderPipelineState {
            let p=MTLRenderPipelineDescriptor();p.vertexFunction=library.makeFunction(name:vertex);p.fragmentFunction=library.makeFunction(name:fragment)
            p.colorAttachments[0].pixelFormat = .bgra8Unorm;p.depthAttachmentPixelFormat = .depth32Float;p.rasterSampleCount=4
            p.colorAttachments[0].isBlendingEnabled = !coverage;p.isAlphaToCoverageEnabled=coverage
            p.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;p.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            p.colorAttachments[0].sourceAlphaBlendFactor = .one;p.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor:p)
        }
        scene=try pipeline("scene_vertex","scene_fragment");coat=try pipeline("coat_vertex","coat_fragment",true);fiber=try pipeline("scene_vertex","scene_fragment",true)
        let d=MTLDepthStencilDescriptor();d.depthCompareFunction = .lessEqual;d.isDepthWriteEnabled=true;depth=device.makeDepthStencilState(descriptor:d)!
    }
}
private final class CharacterPreviewRenderer:NSObject,MTKViewDelegate {
    let gpu:PortraitGPU
    var state:CharacterPreviewState
    private var bodyBuffer:MTLBuffer?,bodyCount=0,identity="",fur:FurPhysics?
    private let inFlight=DispatchSemaphore(value:2)
    init(view:MTKView?=nil,state:CharacterPreviewState,gpu:PortraitGPU) {
        self.gpu=gpu;self.state=state;super.init()
        guard let view=view else { return }
        view.device=gpu.device;view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float;view.sampleCount=4
        view.clearColor=MTLClearColor(red:0,green:0,blue:0,alpha:0)
        view.isPaused=true;view.enableSetNeedsDisplay=true
        #if os(macOS)
        view.wantsLayer=true;view.layer?.isOpaque=false
        #else
        view.isOpaque=false;view.backgroundColor = .clear;view.isUserInteractionEnabled=false
        #endif
        view.delegate=self
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) { view.draw() }
    func draw(in view:MTKView) {
        guard let drawable=view.currentDrawable,let pass=view.currentRenderPassDescriptor,
              let cb=encode(pass:pass,size:view.drawableSize,logicalWidth:view.bounds.width) else { return }
        cb.present(drawable);cb.commit()
    }
    private func encode(pass:MTLRenderPassDescriptor,size:CGSize,logicalWidth:CGFloat)->MTLCommandBuffer? {
        let s=state,key=s.form.rawValue+String(s.seed)+String(s.stage)+(s.secondary?.rawValue ?? "")
        if key != identity {
            let mesh=Geometry.character(form:s.form,secondary:s.secondary,seed:s.seed)
            bodyBuffer=gpu.device.makeBuffer(bytes:mesh.vertices,length:mesh.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared);bodyCount=mesh.vertices.count
            fur=FurPhysics(form:s.form);identity=key
        }
        guard let body=bodyBuffer,let cb=gpu.queue.makeCommandBuffer(),let e=cb.makeRenderCommandEncoder(descriptor:pass) else { return nil }
        inFlight.wait();cb.addCompletedHandler { [inFlight] _ in inFlight.signal() }
        let t=s.reduced ? 0 : s.time,reaction=s.reactionAge>=0 && s.reactionAge<1.2
        let hover:Float=s.form == .air ? 0.05+sin(t*2.2)*0.035 : 0
        let hop:Float=reaction && !s.reduced ? max(0,sin(min(1,s.reactionAge/0.65)*Float.pi))*0.09 : 0
        let angle:Float=s.form == .stone ? sin(t)*0.008 : sin(t*1.1)*0.025
        let amount:Float=s.form == .stone ? 0.003 : (s.form == .water ? 0.027 : 0.013),breath=sin(t*2.4)*amount
        let stretch=SIMD3<Float>(1-breath,1+breath,1),lift=hover+hop*(s.form == .stone ? 0.2 : 1)
        let model=translation(V3(-0.12,lift-0.10,0))*rotationZ(angle)*rotationY(0.12)*scale(stretch)
        let height:Float=2.0,width=height*Float(size.width/max(1,size.height))
        let sx=2/max(1.5,width),sy=2/height
        let projection=simd_float4x4(columns:(SIMD4(sx,0,0.0075,0),SIMD4(0,sy,-0.007,0),SIMD4(sx*0.30,-sy*0.28,-0.025,0),SIMD4(0,0,0.5,1)))
        var u=Uniforms(projection:projection,model:model,animation:SIMD4(t,s.wetness,0,0),camera:SIMD4(0,width,height,1),support:SIMD4(0,0,0,0),world:SIMD4(0,0,Float(s.stage),0))
        e.setRenderPipelineState(gpu.scene);e.setDepthStencilState(gpu.depth)
        func draw(_ buffer:MTLBuffer,_ count:Int,_ transform:simd_float4x4,_ material:Float=0,_ plush:Bool=false) {
            u.model=transform;u.world.y=material;u.camera.w=plush ? 2 : 1
            e.setVertexBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setFragmentBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setVertexBuffer(buffer,offset:0,index:0);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:count)
        }
        func mesh(_ m:Mesh,_ transform:simd_float4x4=model) {
            guard !m.vertices.isEmpty,let b=gpu.device.makeBuffer(bytes:m.vertices,length:m.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared) else { return }
            draw(b,m.vertices.count,transform)
        }
        // The shadow lies on the ground plane (XZ), never across the lower
        // rear face. A camera-facing oval sliced the body into a false puddle.
        var shadow=Mesh()
        for i in 0..<32 {
            let a=Float(i)*2*Float.pi/32,b=Float(i+1)*2*Float.pi/32
            let center=V3(-0.12,-0.62,0)
            shadow.triangle(center,center+V3(cos(a)*0.56,0,sin(a)*0.40),center+V3(cos(b)*0.56,0,sin(b)*0.40),tint(0x254c46,s.form == .air ? 0.08 : 0.14),V3(0,1,0))
        }
        mesh(shadow,matrix_identity_float4x4)
        draw(body,bodyCount,model,s.form == .water ? 1 : (s.form == .fire ? 2 : (s.form == .air ? 3 : (s.form == .stone ? 4 : 0))),s.form.hasFur)
        mesh(Geometry.elementDetail(form:s.form,time:t))
        if s.form.hasFur {
            e.setRenderPipelineState(gpu.coat)
            for layer in 1...10 {
                var coat=SIMD4<Float>(Float(layer)/11,sin(t)*0.5,0,0);e.setVertexBytes(&coat,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                draw(body,bodyCount,model)
            }
            if logicalWidth>75,let fur=fur {
                for _ in 0..<2 { fur.step(dt:1/120,center:V3(0,lift,0),angle:angle,stretch:stretch,wind:sin(t)*0.5,water:{ _ in s.wetness>0.5 },solid:{ _ in false }) }
                e.setRenderPipelineState(gpu.fiber);mesh(Geometry.fur(fur,form:s.form),translation(V3(-0.12,-0.10,0)))
            }
            e.setRenderPipelineState(gpu.scene)
        }
        if s.form == .fire || s.burning>0 { mesh(Geometry.flames(time:t,active:true,wind:sin(t)*0.6)) }
        let phase=s.time.truncatingRemainder(dividingBy:4.8),blink:Float=phase<4.54 ? 1 : max(0.08,abs(phase-4.67)/0.13)
        mesh(Geometry.face(blink:blink,mood:reaction ? .delighted : (s.health<30 ? .sleepy : (s.burning>0 && s.form != .fire ? .displeased : .curious)),look:sin(s.time*0.73)*0.018,wet:s.wetness,form:s.form))
        if s.stage>0 {
            var gems=Mesh();for i in 0..<s.stage { gems.diamond(V3(-0.26+Float(i)*0.26,0.37,0.57),size:0.035,color:tint(0xe6d996)) };mesh(gems)
        }
        if reaction {
            var sparks=Mesh()
            for i in 0..<2 { sparks.diamond(V3(Float(i)*1.25-0.64,0.4+s.reactionAge*0.15,0.55),size:0.045,color:tint(0xefbd54,max(0,1-s.reactionAge/1.2))) };mesh(sparks)
        }
        e.endEncoding();return cb
    }
    #if os(macOS)
    private var rasterColor:MTLTexture?,rasterDepth:MTLTexture?,rasterResolve:MTLTexture?
    func rasterize(size:CGSize,scale:CGFloat)->CGImage? {
        let width=max(1,min(1024,Int(ceil(size.width*scale)))),height=max(1,min(1024,Int(ceil(size.height*scale))))
        if rasterResolve?.width != width || rasterResolve?.height != height {
            func texture(_ format:MTLPixelFormat,_ samples:Int,_ shared:Bool=false)->MTLTexture? {
                let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
                d.sampleCount=samples;d.textureType=samples>1 ? .type2DMultisample : .type2D
                d.storageMode=shared ? .shared : .private;d.usage = .renderTarget
                return gpu.device.makeTexture(descriptor:d)
            }
            rasterColor=texture(.bgra8Unorm,4);rasterDepth=texture(.depth32Float,4);rasterResolve=texture(.bgra8Unorm,1,true)
        }
        guard let color=rasterColor,let depth=rasterDepth,let resolve=rasterResolve else { return nil }
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=color;pass.colorAttachments[0].resolveTexture=resolve
        pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .multisampleResolve
        pass.colorAttachments[0].clearColor=MTLClearColor(red:0,green:0,blue:0,alpha:0)
        pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare;pass.depthAttachment.clearDepth=1
        guard let cb=encode(pass:pass,size:CGSize(width:width,height:height),logicalWidth:size.width) else { return nil }
        cb.commit();cb.waitUntilCompleted();guard cb.status == .completed else { return nil }
        var pixels=[UInt8](repeating:0,count:width*height*4)
        resolve.getBytes(&pixels,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)
        guard let data=CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),provider:data,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
    #endif
}
#if os(macOS)
// AppKit sheets can omit an embedded CAMetalLayer when compositing SwiftUI.
// Render the same mesh offscreen, then let SwiftUI compose its alpha image.
// Small portraits update on MonsterPortrait's clock; gameplay is never stepped.
private final class PortraitRasterizer:ObservableObject {
    private var renderer:CharacterPreviewRenderer?
    func image(_ state:CharacterPreviewState,size:CGSize)->NSImage? {
        guard size.width>0,size.height>0,let gpu=PortraitGPU.shared else { return nil }
        if renderer == nil { renderer=CharacterPreviewRenderer(state:state,gpu:gpu) }
        renderer?.state=state
        guard let cg=renderer?.rasterize(size:size,scale:NSScreen.main?.backingScaleFactor ?? 2) else { return nil }
        return NSImage(cgImage:cg,size:size)
    }
}
struct CharacterPreview:View {
    var state:CharacterPreviewState
    @StateObject private var raster=PortraitRasterizer()
    var body:some View {
        GeometryReader { bounds in
            if let image=raster.image(state,size:bounds.size) { Image(nsImage:image).resizable().interpolation(.high).scaledToFit() }
        }
    }
}
#else
struct CharacterPreview:UIViewRepresentable {
    var state:CharacterPreviewState
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeUIView(context:Context)->MTKView {
        let view=MTKView();if let gpu=PortraitGPU.shared { context.coordinator.renderer=CharacterPreviewRenderer(view:view,state:state,gpu:gpu) };return view
    }
    func updateUIView(_ view:MTKView,context:Context) { context.coordinator.renderer?.state=state;view.draw() }
    final class Coordinator { fileprivate var renderer:CharacterPreviewRenderer? }
}
#endif
