import MetalKit
import simd
import ElementalCore

struct Uniforms { var projection:simd_float4x4;var model:simd_float4x4;var animation:SIMD4<Float>;var camera:SIMD4<Float>;var support:SIMD4<Float>;var world:SIMD4<Float> }
final class Renderer: NSObject, MTKViewDelegate {
    let device:MTLDevice,queue:MTLCommandQueue
    let scenePipeline:MTLRenderPipelineState,backgroundPipeline:MTLRenderPipelineState
    let coatPipeline:MTLRenderPipelineState,fiberPipeline:MTLRenderPipelineState
    let depthWrite:MTLDepthStencilState,depthRead:MTLDepthStencilState
    let session:GameSession
    var terrain:MTLBuffer,cube:MTLBuffer,crate:MTLBuffer
    var terrainCount:Int,cubeCount:Int,crateCount:Int
    var cameraX:Float=7.3,cameraY:Float=1.6,worldWidth:Float=22,worldHeight:Float=13.5
    var renderedForm:ElementForm = .ice
    var renderedAppearance=""
    var materialTime:Float = -1
    var terrainCenter=Vec(7.3,1.6),terrainSize=Vec(22,13.5)
    var dynamicBuffers:[[MTLBuffer]] = [[],[],[]]
    let inFlight=DispatchSemaphore(value:3)
    var lastTime=ProcessInfo.processInfo.systemUptime,accumulator:Double=0
    private var pendingInputCancellation=false
    var frame=0
    init(view:MTKView,session:GameSession) throws {
        guard let d=MTLCreateSystemDefaultDevice(),let q=d.makeCommandQueue() else { throw NSError(domain:"Metal недоступен",code:1) }
        self.device=d;self.queue=q;self.session=session
        view.device=d;view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
        view.sampleCount=4;view.preferredFramesPerSecond=60;view.clearColor=MTLClearColor(red:0.6,green:0.8,blue:0.8,alpha:1)
        #if SWIFT_PACKAGE
        let shaderBundle=Bundle.module
        #else
        let shaderBundle=Bundle.main
        #endif
        let library:MTLLibrary
        if let url=shaderBundle.url(forResource:"Shaders",withExtension:"metal.txt") {
            library=try d.makeLibrary(source:String(contentsOf:url),options:nil)
        } else if let compiled=d.makeDefaultLibrary() { library=compiled }
        else { throw NSError(domain:"Не удалось загрузить шейдеры",code:2) }
        func pipeline(_ vertex:String,_ fragment:String,depth:Bool,coverage:Bool=false)->MTLRenderPipelineState {
            let p=MTLRenderPipelineDescriptor();p.vertexFunction=library.makeFunction(name:vertex);p.fragmentFunction=library.makeFunction(name:fragment)
            p.colorAttachments[0].pixelFormat=view.colorPixelFormat;p.depthAttachmentPixelFormat = .depth32Float;p.rasterSampleCount=4
            p.colorAttachments[0].isBlendingEnabled = !coverage;p.isAlphaToCoverageEnabled=coverage
            p.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;p.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            p.colorAttachments[0].sourceAlphaBlendFactor = .one;p.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try! d.makeRenderPipelineState(descriptor:p)
        }
        scenePipeline=pipeline("scene_vertex","scene_fragment",depth:true);backgroundPipeline=pipeline("background_vertex","background_fragment",depth:false)
        coatPipeline=pipeline("coat_vertex","coat_fragment",depth:true,coverage:true)
        fiberPipeline=pipeline("scene_vertex","scene_fragment",depth:true,coverage:true)
        let dw=MTLDepthStencilDescriptor();dw.depthCompareFunction = .lessEqual;dw.isDepthWriteEnabled=true;depthWrite=d.makeDepthStencilState(descriptor:dw)!
        dw.isDepthWriteEnabled=false;depthRead=d.makeDepthStencilState(descriptor:dw)!
        let t=Geometry.terrain(definition:session.simulation.definition),c=Geometry.cube(),box=Geometry.crate()
        func buffer(_ m:Mesh)->MTLBuffer { d.makeBuffer(bytes:m.vertices,length:m.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared)! }
        terrain=buffer(t);terrainCount=t.vertices.count;cube=buffer(c);cubeCount=c.vertices.count;crate=buffer(box);crateCount=box.vertices.count
        cameraX=session.simulation.cube.position.x;cameraY=session.simulation.cube.position.y+1.4
        super.init();view.delegate=self
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {
        // SwiftUI can resize the Metal view while evaluating its own layout.
        // Cancel at the next frame rather than publishing inside that update.
        pendingInputCancellation=true;updateViewport(size)
    }
    private func updateViewport(_ size:CGSize) {
        let shortLandscape=size.width>size.height && Float(size.width/size.height)>1.9
        worldHeight=(shortLandscape ? 8.8 : 11.8)/Float(session.zoom);worldWidth=Float(size.width/max(1,size.height))*worldHeight
        let minWidth:Float=8.3/Float(session.zoom)
        if worldWidth<minWidth { worldWidth=minWidth;worldHeight=worldWidth*Float(size.height/max(1,size.width)) }
    }
    func projection()->simd_float4x4 {
        let sx=2/worldWidth,sy=2/worldHeight
        let shake=sin(session.simulation.time*85)*session.simulation.impact*0.035
        return simd_float4x4(columns:(SIMD4(sx,0,0,0),SIMD4(0,sy,0,0),SIMD4(sx*0.30,sy*0.34,-0.025,0),SIMD4(-cameraX*sx,(-cameraY+shake)*sy,0.5,1)))
    }
    func draw(in view:MTKView) {
        if pendingInputCancellation { pendingInputCancellation=false;session.cancelAim() }
        updateViewport(view.drawableSize)
        let now=ProcessInfo.processInfo.systemUptime,dt=min(0.06,now-lastTime);lastTime=now
        if session.suspended { accumulator=0 } else {
            accumulator+=dt
            while accumulator>=Double(Simulation.timestep) { session.tick();accumulator-=Double(Simulation.timestep) }
        }
        let s=session.simulation,p=s.cube.position
        if !session.aiming {
            let target=CameraFraming.target(cubeX:p.x,velocityX:s.cube.velocity.x,movement:session.moving,facing:session.direction,aimVelocityX:nil,worldWidth:worldWidth,bounds:s.definition.bounds)
            if ProcessInfo.processInfo.arguments.contains("--preview-gesture") { cameraX=target }
            else { cameraX+=(target-cameraX)*Float(1-exp(-dt*3.4)) }
            let y=CameraFraming.verticalTarget(cubeY:p.y,velocityY:s.cube.velocity.y,aimVelocityY:nil,worldHeight:worldHeight,bounds:s.definition.bounds)
            if ProcessInfo.processInfo.arguments.contains("--preview-gesture") { cameraY=y }
            else { cameraY+=(y-cameraY)*Float(1-exp(-dt*3.4)) }
        }
        let shake=sin(s.time*85)*s.impact*0.035
        session.viewport=WorldViewport(center:Vec(cameraX,cameraY-shake),size:Vec(worldWidth,worldHeight),screen:Vec(Float(view.bounds.width),Float(view.bounds.height)))
        session.preparePreview()
        #if os(iOS)
        (view as? InteractiveMetalView)?.updateAccessibility()
        #endif
        guard let drawable=view.currentDrawable,let pass=view.currentRenderPassDescriptor,let cb=queue.makeCommandBuffer(),let e=cb.makeRenderCommandEncoder(descriptor:pass) else { return }
        inFlight.wait();cb.addCompletedHandler { [inFlight] _ in inFlight.signal() }
        var meshIndex=0
        let slot=frame%3
        let appearance=session.inventory.selected.id.uuidString+String(s.evolutionStage)
        if appearance != renderedAppearance {
            let mesh=Geometry.character(form:s.form,secondary:session.inventory.selected.secondaryForm,seed:session.inventory.selected.appearanceSeed)
            renderedAppearance=appearance
            cube=device.makeBuffer(bytes:mesh.vertices,length:mesh.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared)!;cubeCount=mesh.vertices.count;renderedForm=s.form
        }
        if s.time<materialTime || s.time-materialTime>0.25 || abs(cameraX-terrainCenter.x)>1 || abs(cameraY-terrainCenter.y)>1 || abs(worldWidth-terrainSize.x)>0.1 || abs(worldHeight-terrainSize.y)>0.1 {
            terrainCenter=Vec(cameraX,cameraY);terrainSize=Vec(worldWidth,worldHeight)
            let mesh=Geometry.terrain(patches:s.patches,visible:WorldBounds(cameraX-worldWidth/2-2,cameraY-worldHeight/2-2,cameraX+worldWidth/2+2,cameraY+worldHeight/2+2),definition:s.definition);terrain=device.makeBuffer(bytes:mesh.vertices,length:mesh.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared)!;terrainCount=mesh.vertices.count;materialTime=s.time
        }
        var floorHeight:Float=p.y-0.56,floorSlope:Float=0
        if s.surface != .ice && s.surface != .wood && p.y < 0.6 && p.y > -4.5 {
            if p.x>7 && p.x<9.4 { floorSlope = -1.625;floorHeight = -(p.x-7)*1.625 }
            else if p.x>14.6 && p.x<17 { floorSlope=1.625;floorHeight = -(17-p.x)*1.625 }
        }
        var u=Uniforms(projection:projection(),model:matrix_identity_float4x4,animation:SIMD4(s.time,s.wetness,s.squash,s.cube.velocity.x),camera:SIMD4(cameraX,worldWidth,worldHeight,0),support:SIMD4(s.cube.grounded ? 1 : 0,floorHeight,floorSlope,p.x),world:SIMD4(Float(WorldMap.allCases.firstIndex(of:s.definition.map) ?? 0),0,Float(s.evolutionStage),0))
        e.setRenderPipelineState(backgroundPipeline);e.setDepthStencilState(depthRead)
        e.setFragmentBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        e.setRenderPipelineState(scenePipeline);e.setDepthStencilState(depthWrite)
        func drawBuffer(_ buffer:MTLBuffer,_ count:Int,_ model:simd_float4x4=matrix_identity_float4x4,character:Bool=false,furSurface:Bool=false,material:Float=0) {
            u.model=model;u.camera.w=furSurface ? 2 : (character ? 1 : 0);u.world.y=material
            e.setVertexBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setFragmentBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setVertexBuffer(buffer,offset:0,index:0)
            e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:count)
        }
        func drawMesh(_ mesh:Mesh,_ model:simd_float4x4=matrix_identity_float4x4,character:Bool=false) {
            guard !mesh.vertices.isEmpty else { return }
            let length=mesh.vertices.count*MemoryLayout<Vertex>.stride
            if dynamicBuffers[slot].count<=meshIndex { dynamicBuffers[slot].append(device.makeBuffer(length:max(length,4096),options:.storageModeShared)!) }
            if dynamicBuffers[slot][meshIndex].length<length { dynamicBuffers[slot][meshIndex]=device.makeBuffer(length:length,options:.storageModeShared)! }
            let b=dynamicBuffers[slot][meshIndex];meshIndex+=1
            mesh.vertices.withUnsafeBytes { bytes in b.contents().copyMemory(from:bytes.baseAddress!,byteCount:length) }
            drawBuffer(b,mesh.vertices.count,model,character:character)
        }
        drawBuffer(terrain,terrainCount)
        var details=Mesh()
        let support=s.supportHeight(at:p.x),shadeAlpha=max(0.03,0.22-max(0,p.y-support-0.56)*0.035)
        if !s.inWater && p.y-support>0.3 && p.y-support<5 { details.ellipse(center:V3(p.x,support+0.11,0.86),rx:0.67,ry:0.07,color:tint(0x254c46,shadeAlpha)) }
        if s.crateExists && s.crate.position.y>0 && (s.crate.position.x<7 || s.crate.position.x>17) {
            details.ellipse(center:V3(s.crate.position.x,0.12,0.82),rx:0.78,ry:0.09,color:tint(0x25443c,0.21))
        }
        if s.landingAge<0.45 {
            let r=0.3+s.landingAge*1.3
            details.ellipse(center:V3(p.x,p.y-0.55,0.9),rx:r,ry:0.035,color:tint(0xf9efc4,(1-s.landingAge/0.45)*s.impact*0.5))
        }
        for trail in s.trails {
            let at=V3(trail.position.x,trail.position.y,1.35)
            switch trail.form {
            case .ice:
                details.ellipse(center:at,rx:0.24,ry:0.022,color:tint(0xc9f8ff,min(0.7,trail.life*0.3)))
                details.line(at+V3(-0.16,0.01,0),at+V3(0.13,0.02,0),width:0.009,color:tint(0xf2ffff,min(0.6,trail.life*0.25)))
            case .fire:break
            case .air:
                details.line(at+V3(-0.18,0.17,0),at+V3(0.13,0.21,0),width:0.012,color:tint(0xcaf6e3,trail.life*0.13))
            case .water:
                details.ellipse(center:at,rx:0.13,ry:0.018,color:tint(0x8cdce8,trail.life*0.16))
            case .stone:break
            }
        }
        for i in s.shards.indices where !s.collected.contains(i) {
            let pos=s.shards[i];details.diamond(V3(pos.x,pos.y+sin(s.time*2+Float(i))*0.12,0.6),size:0.30,color:tint(0x7be6ed))
            details.ellipse(center:V3(pos.x,pos.y-0.38,0.65),rx:0.13,ry:0.018,color:tint(0xdcffdd,0.4))
        }
        for particle in s.particles {
            let color:[C4]=[tint(0xe4deba),tint(0xb8f5ee),tint(0xc2f9ff),tint(0xfaf0b4),tint(0xffab4d),tint(0xdfece5,0.55),tint(0xf3a8be)]
            let alpha=min(1,particle.life*2),at=V3(particle.position.x,particle.position.y,particle.kind==1 || particle.kind==6 ? 1.5 : 0.9)
            if particle.kind==7 {
                let radius:Float=0.025+max(0,2-particle.life)*0.012
                for j in 0..<16 {
                    let a=Float(j)*2*Float.pi/16,b=Float(j+1)*2*Float.pi/16
                    details.line(at+V3(cos(a)*radius,sin(a)*radius,0),at+V3(cos(b)*radius,sin(b)*radius,0),width:0.006,color:tint(0xd7faf8,alpha*0.65))
                }
            } else if particle.kind==5 {
                for j in 0..<3 { details.ellipse(center:at+V3(Float(j-1)*0.035,Float(j%2)*0.025,0),rx:0.055+max(0,1-particle.life)*0.04,ry:0.045,color:tint(0xe0f2e9,alpha*0.13)) }
            } else if particle.kind==6 {
                let c=color[6]*SIMD4(1,1,1,alpha)
                details.ellipse(center:at+V3(-0.025,0.015,0),rx:0.032,ry:0.03,color:c,segments:8)
                details.ellipse(center:at+V3(0.025,0.015,0),rx:0.032,ry:0.03,color:c,segments:8)
                details.triangle(at+V3(-0.052,0.015,0),at+V3(0.052,0.015,0),at+V3(0,-0.055,0),c,V3(0,0,1))
            } else {
                details.ellipse(center:at,rx:particle.kind==1 ? 0.022 : 0.035,ry:particle.kind==1 ? min(0.07,0.028+abs(particle.velocity.y)*0.004) : 0.035,color:color[max(0,min(color.count-1,particle.kind))]*SIMD4(1,1,1,alpha),segments:6)
            }
        }
        if !s.deepRelic {
            details.diamond(V3(12,-3.35,0.85),size:0.22,color:tint(0xebc77d))
        }
        for patch in s.patches where patch.fuel<0.99 || patch.frost>0.05 {
            guard patch.x<7 || patch.x>17 else { continue }
            details.box(center:V3(patch.x,patch.y+0.1,0.35),size:V3(0.5,0.035,1.2),color:mix(tint(0x34332e,1-patch.fuel),tint(0xd6f6ff,patch.frost),patch.frost))
        }
        for mark in s.frostMarks where mark.cold>0.08 {
            details.ellipse(center:V3(mark.position.x,mark.position.y,0.85),rx:0.18,ry:0.045,color:tint(0xdcf8ff,mark.cold*0.8),segments:8)
        }
        if s.form == .air && s.passiveWorking {
            for i in 0..<3 {
                let phase=(s.time*0.8+Float(i)*0.3).truncatingRemainder(dividingBy:1)
                details.line(V3(p.x-0.4-phase*0.5,p.y-0.45-Float(i)*0.08,0.8),V3(p.x+0.45-phase*0.5,p.y-0.45-Float(i)*0.08,0.8),width:0.012,color:tint(0xd8ffeb,(1-phase)*0.6))
            }
        }
        drawMesh(details)
        for patch in s.patches where patch.burning>0 && patch.fuel>0 {
            drawMesh(Geometry.flames(time:s.time+patch.x,active:true,wind:s.windVelocity,body:false),translation(V3(patch.x,patch.y+0.15,0.8))*scale(SIMD3(repeating:0.25)))
        }
        if s.crateBurning>0 && s.crateExists {
            drawMesh(Geometry.flames(time:s.time,active:true,wind:s.windVelocity,body:false),translation(V3(s.crate.position.x,s.crate.position.y+0.7,0.7))*scale(SIMD3(repeating:0.4)))
        }
        drawMesh(Geometry.bridgeFixtures())
        for section in s.bridge {
            var wood=Geometry.bridgeSection(width:section.width)
            for i in wood.vertices.indices { wood.vertices[i].color=mix(tint(0x302d29),wood.vertices[i].color,section.fuel) }
            let model=translation(V3(section.state.position.x,section.state.position.y,0.55))*rotationZ(section.state.angle)
            drawMesh(wood,model)
            if section.burning>0 { drawMesh(Geometry.flames(time:s.time,active:true,wind:s.windVelocity,body:false),model*translation(V3(0,0.22,0))*scale(SIMD3(repeating:0.3))) }
        }
        if let first=s.bridge.first,let last=s.bridge.last {
            var ropes=Mesh()
            let left=FluidBody(id:0,center:first.state.position,angle:first.state.angle,width:first.width,height:first.height).world(Vec(-first.width/2,0))
            let right=FluidBody(id:0,center:last.state.position,angle:last.state.angle,width:last.width,height:last.height).world(Vec(last.width/2,0))
            for (a,b) in [(s.bridgeAnchors[0],left),(s.bridgeAnchors[1],right)] {
                let distance=hypot(b.x-a.x,b.y-a.y),length=hypot(Float(3.4),Float(0.195))+0.12
                let sag=sqrt(max(0,3*distance*(length-distance)/8))
                for z:Float in [-0.12,1.20] {
                    for i in 0..<16 {
                        func point(_ t:Float)->V3 { V3(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t-4*sag*t*(1-t),z) }
                        ropes.line(point(Float(i)/16),point(Float(i+1)/16),width:0.045,color:tint(0x6b6550))
                    }
                }
            }
            drawMesh(ropes)
        }
        for source in s.fireSources {
            var ring=Mesh()
            for i in 0..<6 {
                let a=Float(i)*2*Float.pi/6
                ring.box(center:V3(source.position.x+cos(a)*0.4,source.position.y-0.20,0.55+sin(a)*0.3),size:V3(0.18,0.17,0.18),color:tint(0x74766b))
            }
            ring.line(V3(source.position.x-0.25,source.position.y-0.15,0.42),V3(source.position.x+0.25,source.position.y-0.15,0.72),width:0.12,color:tint(0x75513d));drawMesh(ring)
            drawMesh(Geometry.flames(time:s.time,active:true,body:false),translation(V3(source.position.x,source.position.y-0.12,0.55))*scale(SIMD3(repeating:0.55)))
        }
        if s.crateExists {
            var box=Geometry.crate()
            for i in box.vertices.indices { box.vertices[i].color=mix(box.vertices[i].color*SIMD4(0.3+s.crateFuel*0.7,0.3+s.crateFuel*0.7,0.3+s.crateFuel*0.7,1),tint(0xc4edff),s.crateFrost*0.8) }
            drawMesh(box,translation(V3(s.crate.position.x,s.crate.position.y,0.55))*rotationZ(s.crate.angle))
        } else {
            var ash=Mesh();ash.box(center:V3(s.crate.position.x,s.crate.position.y-0.5,0.65),size:V3(0.9,0.12,0.7),color:tint(0x383936));drawMesh(ash)
        }
        let model=translation(V3(p.x,p.y,0.55))*rotationZ(s.bodyAngle)*rotationY(0.12)*scale(s.bodyStretch)
        drawBuffer(cube,cubeCount,model,character:true,furSurface:s.form.hasFur,material:s.form == .water ? 1 : (s.form == .fire ? 2 : (s.form == .air ? 3 : (s.form == .stone ? 4 : 0))))
        drawMesh(Geometry.elementDetail(form:s.form,time:s.time),model,character:true)
        if s.form.hasFur {
            e.setRenderPipelineState(coatPipeline)
            for layer in 1...10 {
                var coat=SIMD4<Float>(Float(layer)/11,s.windVelocity,0,0)
                e.setVertexBytes(&coat,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                drawBuffer(cube,cubeCount,model,character:true)
            }
            e.setRenderPipelineState(fiberPipeline)
            drawMesh(Geometry.fur(s.fur,form:s.form))
            e.setRenderPipelineState(scenePipeline)
        }
        if s.evolutionStage>0 || s.hybridStyle != nil {
            var gems=Mesh()
            for i in 0..<max(1,s.evolutionStage) { gems.diamond(V3(-0.26+Float(i)*0.26,0.37,1.13),size:0.035,color:tint(s.hybridStyle == .magma ? 0xffa359 : 0xe6d996)) }
            drawMesh(gems,model,character:true)
        }
        if let style=s.hybridStyle,style == .steam || style == .geyser || style == .mist {
            var mist=Mesh()
            for i in 0..<4 {
                let phase=(s.time*0.6+Float(i)*0.25).truncatingRemainder(dividingBy:1)
                mist.ellipse(center:V3(p.x-0.4+Float(i)*0.22,p.y+0.48+phase*0.65,0.85),rx:0.08+phase*0.1,ry:0.06+phase*0.08,color:tint(0xe5fcfa,(1-phase)*0.2),segments:10)
            }
            drawMesh(mist)
        }
        if let charm=session.inventory.selected.equippedCharm {
            var ornament=Mesh();ornament.diamond(V3(0,-0.34,1.14),size:0.075,color:charm == .deepRelic ? tint(0xebc77d) : tint(0xb3c6b2));drawMesh(ornament,model,character:true)
        }
        if (s.form == .fire || s.burning>0) && !s.dead { drawMesh(Geometry.flames(time:s.time,active:s.passiveWorking || s.burning>0,wind:s.windVelocity),model) }
        let blinkPhase=s.time.truncatingRemainder(dividingBy:4.7)
        let mood:Mood=session.aiming ? .focused : (s.won ? .delighted : s.mood)
        let gaze=session.aiming ? session.aimImpulse.x*0.004 : s.cube.velocity.x*0.006
        drawMesh(Geometry.face(blink:blinkPhase>4.5 ? 0.12 : 1,mood:mood,look:gaze,wet:s.wetness,form:s.form),model,character:true)
        if s.form.hasFur && s.wetness>0.15 {
            var drips=Mesh()
            for i in 0..<5 {
                let phase=(s.time*0.9+Float(i)*0.21).truncatingRemainder(dividingBy:1)
                let x=p.x-0.43+Float(i)*0.21
                drips.ellipse(center:V3(x,p.y-0.5-phase*0.65,1.45),rx:0.012,ry:0.032,color:tint(0xb8eff9,(1-phase)*s.wetness*0.8),segments:9)
            }
            drawMesh(drips)
        }
        if session.aiming && s.canLaunch && hypot(session.aimImpulse.x,session.aimImpulse.y)>0.05 {
            var trajectory=Mesh();let v=session.launchVelocity
            for i in 1...42 {
                let t=Float(i)*0.045
                let point=V3(p.x+v.x*t,p.y+v.y*t-0.5*s.gravity*t*t,1.3)
                if s.intersectsSolid(at:Vec(point.x,point.y)) {
                    trajectory.line(point+V3(-0.07,-0.07,0),point+V3(0.07,0.07,0),width:0.022,color:tint(0xf8edc4))
                    trajectory.line(point+V3(-0.07,0.07,0),point+V3(0.07,-0.07,0),width:0.022,color:tint(0xf8edc4))
                    break
                }
                let radius:Float=0.045+Float(i)*0.0007,alpha=1-Float(i)/50
                trajectory.ellipse(center:point,rx:radius*1.35,ry:radius*1.35,color:tint(0x214b4f,alpha*0.8),segments:10)
                trajectory.ellipse(center:point+V3(0,0,0.01),rx:radius*0.7,ry:radius*0.7,color:tint(0xc8ffff,alpha),segments:10)
            }
            drawMesh(trajectory)
        }
        // Water composites after the cube. The submerged fur and eyes acquire its tint.
        e.setDepthStencilState(depthRead)
        if s.waterEnabled { drawMesh(Geometry.liquid(s.waterField,bodies:s.fluidBodies)) }
        if s.waterEnabled { drawMesh(Geometry.frozenWater(s.waterField)) }
        if session.debug {
            var debugMesh=Mesh()
            func outline(_ pos:Vec,_ w:Float,_ h:Float) { let x=pos.x,y=pos.y
                for (a,b) in [(V3(x-w/2,y-h/2,2.5),V3(x+w/2,y-h/2,2.5)),(V3(x+w/2,y-h/2,2.5),V3(x+w/2,y+h/2,2.5)),(V3(x+w/2,y+h/2,2.5),V3(x-w/2,y+h/2,2.5)),(V3(x-w/2,y+h/2,2.5),V3(x-w/2,y-h/2,2.5))] { debugMesh.line(a,b,width:0.02,color:tint(0xf0e095)) }
            }
            for platform in s.platforms { outline(Vec(platform.x,platform.y),platform.width,platform.height) }
            outline(s.cube.position,1.12,1.12);if s.crateExists { outline(s.crate.position,1.25,1.25) }
            debugMesh.line(V3(p.x,p.y,2.5),V3(p.x+s.cube.velocity.x*0.18,p.y+s.cube.velocity.y*0.18,2.5),width:0.035,color:tint(0xf08087))
            drawMesh(debugMesh)
        }
        e.endEncoding();cb.present(drawable);cb.commit();frame+=1
    }
}
func translation(_ p:V3)->simd_float4x4 { var m=matrix_identity_float4x4;m.columns.3=SIMD4(p,1);return m }
func scale(_ p:V3)->simd_float4x4 { simd_float4x4(diagonal:SIMD4(p,1)) }
func rotationZ(_ a:Float)->simd_float4x4 { simd_float4x4(columns:(SIMD4(cos(a),sin(a),0,0),SIMD4(-sin(a),cos(a),0,0),SIMD4(0,0,1,0),SIMD4(0,0,0,1))) }
func rotationY(_ a:Float)->simd_float4x4 { simd_float4x4(columns:(SIMD4(cos(a),0,-sin(a),0),SIMD4(0,1,0,0),SIMD4(sin(a),0,cos(a),0),SIMD4(0,0,0,1))) }
