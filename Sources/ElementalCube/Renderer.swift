import MetalKit
import simd
import ElementalCore

struct Uniforms { var projection:simd_float4x4;var model:simd_float4x4;var animation:SIMD4<Float>;var camera:SIMD4<Float>;var support:SIMD4<Float> }
final class Renderer: NSObject, MTKViewDelegate {
    let device:MTLDevice,queue:MTLCommandQueue
    let scenePipeline:MTLRenderPipelineState,backgroundPipeline:MTLRenderPipelineState
    let depthWrite:MTLDepthStencilState,depthRead:MTLDepthStencilState
    let session:GameSession
    var terrain:MTLBuffer,cube:MTLBuffer,crate:MTLBuffer
    var terrainCount:Int,cubeCount:Int,crateCount:Int
    var cameraX:Float=7.3,worldWidth:Float=22,worldHeight:Float=13.5
    var lastTime=ProcessInfo.processInfo.systemUptime,accumulator:Double=0
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
        func pipeline(_ vertex:String,_ fragment:String,depth:Bool)->MTLRenderPipelineState {
            let p=MTLRenderPipelineDescriptor();p.vertexFunction=library.makeFunction(name:vertex);p.fragmentFunction=library.makeFunction(name:fragment)
            p.colorAttachments[0].pixelFormat=view.colorPixelFormat;p.depthAttachmentPixelFormat = .depth32Float;p.rasterSampleCount=4
            p.colorAttachments[0].isBlendingEnabled=true
            p.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;p.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            p.colorAttachments[0].sourceAlphaBlendFactor = .one;p.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try! d.makeRenderPipelineState(descriptor:p)
        }
        scenePipeline=pipeline("scene_vertex","scene_fragment",depth:true);backgroundPipeline=pipeline("background_vertex","background_fragment",depth:false)
        let dw=MTLDepthStencilDescriptor();dw.depthCompareFunction = .lessEqual;dw.isDepthWriteEnabled=true;depthWrite=d.makeDepthStencilState(descriptor:dw)!
        dw.isDepthWriteEnabled=false;depthRead=d.makeDepthStencilState(descriptor:dw)!
        let t=Geometry.terrain(),c=Geometry.cube(),box=Geometry.crate()
        func buffer(_ m:Mesh)->MTLBuffer { d.makeBuffer(bytes:m.vertices,length:m.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared)! }
        terrain=buffer(t);terrainCount=t.vertices.count;cube=buffer(c);cubeCount=c.vertices.count;crate=buffer(box);crateCount=box.vertices.count
        super.init();view.delegate=self
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {
        session.cancelAim();updateViewport(size)
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
        return simd_float4x4(columns:(SIMD4(sx,0,0,0),SIMD4(0,sy,0,0),SIMD4(sx*0.30,sy*0.34,-0.025,0),SIMD4(-cameraX*sx,(-1.6+shake)*sy,0.5,1)))
    }
    func draw(in view:MTKView) {
        updateViewport(view.drawableSize)
        let now=ProcessInfo.processInfo.systemUptime,dt=min(0.06,now-lastTime);lastTime=now
        if session.paused || session.settings { accumulator=0 } else {
            accumulator+=dt
            while accumulator>=Double(Simulation.timestep) { session.tick();accumulator-=Double(Simulation.timestep) }
        }
        let s=session.simulation,p=s.cube.position
        let half=worldWidth/2,minX = -2.7+half,maxX=25-half
        let lookAhead:Float=worldWidth<12 ? 1.4 : 3
        let target=max(minX,min(max(minX,maxX),p.x+lookAhead))
        cameraX+=(target-cameraX)*Float(1-exp(-dt*3.4))
        guard let drawable=view.currentDrawable,let pass=view.currentRenderPassDescriptor,let cb=queue.makeCommandBuffer(),let e=cb.makeRenderCommandEncoder(descriptor:pass) else { return }
        var floorHeight:Float=0,floorSlope:Float=0
        if s.surface == .ice { floorHeight=s.waterLevel+0.45 }
        else if s.surface == .wood { floorHeight=s.crate.position.y+0.625 }
        else if p.x>7 && p.x<9.4 { floorSlope = -0.75;floorHeight = -(p.x-7)*0.75 }
        else if p.x>14.6 && p.x<17 { floorSlope=0.75;floorHeight = -(17-p.x)*0.75 }
        else if s.surface == .stone { floorHeight = -0.1 }
        var u=Uniforms(projection:projection(),model:matrix_identity_float4x4,animation:SIMD4(s.time,s.wetness,s.squash,s.cube.velocity.x),camera:SIMD4(cameraX,worldWidth,worldHeight,0),support:SIMD4(s.cube.grounded ? 1 : 0,floorHeight,floorSlope,p.x))
        e.setRenderPipelineState(backgroundPipeline);e.setDepthStencilState(depthRead)
        e.setFragmentBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        e.setRenderPipelineState(scenePipeline);e.setDepthStencilState(depthWrite)
        func drawBuffer(_ buffer:MTLBuffer,_ count:Int,_ model:simd_float4x4=matrix_identity_float4x4,character:Bool=false) {
            u.model=model;u.camera.w=character ? 1 : 0
            e.setVertexBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setFragmentBytes(&u,length:MemoryLayout<Uniforms>.stride,index:1);e.setVertexBuffer(buffer,offset:0,index:0)
            e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:count)
        }
        func drawMesh(_ mesh:Mesh,_ model:simd_float4x4=matrix_identity_float4x4,character:Bool=false) {
            guard !mesh.vertices.isEmpty else { return }
            let b=device.makeBuffer(bytes:mesh.vertices,length:mesh.vertices.count*MemoryLayout<Vertex>.stride,options:.storageModeShared)!
            drawBuffer(b,mesh.vertices.count,model,character:character)
        }
        drawBuffer(terrain,terrainCount)
        var details=Mesh()
        let shadeAlpha=max(0.05,0.22-(p.y-0.56)*0.035)
        if p.y > -0.2 { details.ellipse(center:V3(p.x,0.11,0.86),rx:0.67,ry:0.07,color:tint(0x254c46,shadeAlpha)) }
        if s.crate.position.y>0 && (s.crate.position.x<7 || s.crate.position.x>17) {
            details.ellipse(center:V3(s.crate.position.x,0.12,0.82),rx:0.78,ry:0.09,color:tint(0x25443c,0.21))
        }
        if s.landingAge<0.45 {
            let r=0.3+s.landingAge*1.3
            details.ellipse(center:V3(p.x,p.y-0.55,0.9),rx:r,ry:0.035,color:tint(0xf9efc4,(1-s.landingAge/0.45)*s.impact*0.5))
        }
        for i in s.shards.indices where !s.collected.contains(i) {
            let pos=s.shards[i];details.diamond(V3(pos.x,pos.y+sin(s.time*2+Float(i))*0.12,0.6),size:0.30,color:tint(0x7be6ed))
            details.ellipse(center:V3(pos.x,pos.y-0.38,0.65),rx:0.13,ry:0.018,color:tint(0xdcffdd,0.4))
        }
        for particle in s.particles {
            let color:[C4]=[tint(0xe4deba),tint(0xb8f5ee),tint(0xc2f9ff),tint(0xfaf0b4)]
            details.ellipse(center:V3(particle.position.x,particle.position.y,0.9),rx:0.035,ry:0.035,color:color[particle.kind]*SIMD4(1,1,1,min(1,particle.life*2)),segments:6)
        }
        drawMesh(details)
        drawBuffer(crate,crateCount,translation(V3(s.crate.position.x,s.crate.position.y,0.4))*rotationZ(s.crate.angle)*rotationY(0.06))
        let compression=s.squash+(session.aiming && s.cube.grounded ? 0.12 : 0)
        let breathing=sin(s.time*2.7)*0.012
        let wiggle=s.shakeTime>0 ? sin(s.time*43)*0.11 : 0
        let lean=max(-0.10,min(0.10,-s.cube.velocity.x*0.012))
        let bodyScale=V3(1+compression*0.5+breathing,1-compression-breathing,1)
        let model=translation(V3(p.x,p.y,0.55))*rotationZ(s.cube.angle+lean+wiggle)*rotationY(0.12)*scale(bodyScale)
        drawBuffer(cube,cubeCount,model,character:true)
        let blinkPhase=s.time.truncatingRemainder(dividingBy:4.7)
        let mood:Mood=session.aiming ? .focused : (s.won ? .delighted : s.mood)
        let gaze=session.aiming ? session.aimImpulse.x*0.004 : s.cube.velocity.x*0.006
        drawMesh(Geometry.face(blink:blinkPhase>4.5 ? 0.12 : 1,mood:mood,look:gaze,wet:s.wetness),model,character:true)
        if s.wetness>0.15 {
            var drips=Mesh()
            for i in 0..<5 {
                let phase=(s.time*0.9+Float(i)*0.21).truncatingRemainder(dividingBy:1)
                let x=p.x-0.43+Float(i)*0.21
                drips.ellipse(center:V3(x,p.y-0.5-phase*0.65,1.45),rx:0.012,ry:0.032,color:tint(0xb8eff9,(1-phase)*s.wetness*0.8),segments:9)
            }
            drawMesh(drips)
        }
        if session.aiming && s.canLaunch {
            var trajectory=Mesh();let v=session.launchVelocity
            for i in 1...28 {
                let t=Float(i)*0.055
                let point=V3(p.x+v.x*t,p.y+v.y*t-0.5*s.gravity*t*t,1.3)
                if s.intersectsSolid(at:Vec(point.x,point.y)) {
                    trajectory.line(point+V3(-0.07,-0.07,0),point+V3(0.07,0.07,0),width:0.022,color:tint(0xf8edc4))
                    trajectory.line(point+V3(-0.07,0.07,0),point+V3(0.07,-0.07,0),width:0.022,color:tint(0xf8edc4))
                    break
                }
                trajectory.ellipse(center:point,rx:0.035+Float(i)*0.001,ry:0.035+Float(i)*0.001,color:tint(0xf9ffe0,1-Float(i)/35),segments:8)
            }
            drawMesh(trajectory)
        }
        // Water composites after the cube. The submerged fur and eyes acquire its tint.
        e.setDepthStencilState(depthRead)
        if s.waterEnabled {
            var water=Mesh()
            for i in 0..<80 {
                let x=7+Float(i)*0.125,x2=x+0.125,y=s.waterLevel+s.wave[i],y2=s.waterLevel+s.wave[i+1]
                let a=V3(x,-4,1.7),b=V3(x2,-4,1.7),c=V3(x2,y2,1.7),d=V3(x,y,1.7)
                let deep=tint(0x177e82,0.72),top=tint(0x67c8c3,0.46)
                let normal=SIMD4<Float>(0,0,1,0)
                for (p,col) in [(a,deep),(b,deep),(c,top),(a,deep),(c,top),(d,top)] { water.vertices.append(Vertex(position:SIMD4(p,1),normal:normal,color:col)) }
                water.line(V3(x,y,1.72),V3(x2,y2,1.72),width:0.022,color:tint(0xd1fff0,0.8))
                if i%6<4 { water.line(V3(x,y+0.03,1.74),V3(x2,y2+0.03,1.74),width:0.008,color:tint(0xf2ffe5,0.55)) }
            }
            for i in 0..<12 {
                let x=7.3+Float(i)*0.8,y = -0.9-Float(i%4)*0.48+sin(s.time*0.8+Float(i))*0.04
                water.line(V3(x,y,1.73),V3(x+0.28,y,1.73),width:0.012,color:tint(0xc0ede0,0.2))
            }
            drawMesh(water)
        }
        if s.iceTime > 0 {
            var ice=Mesh()
            let melt=max(0,min(1,(4-s.iceTime)/4)),alpha=1-melt*0.3
            for segment in s.iceSegments where segment.y-segment.x>0.18 {
                let start=segment.x,end=segment.y,top=s.waterLevel+0.45
                ice.box(center:V3((start+end)/2,s.waterLevel+0.225,0.05),size:V3(end-start,0.45,1.8),color:tint(0x7ccfe4,0.96*alpha))
                ice.line(V3(start,top,0.96),V3(end,top,0.96),width:0.038,color:tint(0xe7fbff,alpha))
                let count=max(1,Int((end-start)/0.55))
                for i in 0..<count {
                    let x=start+Float(i)*0.55,w=min(0.55,end-x)
                    ice.triangle(V3(x,top,0.97),V3(x+w,top-0.06,0.97),V3(x+w*0.4,top-0.32,0.97),tint(i%2==0 ? 0xb8f3ff : 0x59b6dd,0.5*alpha),V3(0,0,1))
                    ice.line(V3(x+0.12,top-0.02,0.98),V3(x+0.3,top-0.21,0.98),width:0.015,color:tint(0xf1ffff,0.8*alpha))
                    ice.line(V3(x+0.3,top-0.21,0.98),V3(x+0.45,top-0.34,0.98),width:0.009,color:tint(0xe5fdff,0.7*alpha))
                    if melt>0.1 { ice.line(V3(x,top-0.29,0.99),V3(x+0.38,top-0.10,0.99),width:0.012,color:tint(0x2489b4,melt)) }
                }
            }
            drawMesh(ice)
        }
        if session.debug {
            var debugMesh=Mesh()
            func outline(_ pos:Vec,_ w:Float,_ h:Float) { let x=pos.x,y=pos.y
                for (a,b) in [(V3(x-w/2,y-h/2,2.5),V3(x+w/2,y-h/2,2.5)),(V3(x+w/2,y-h/2,2.5),V3(x+w/2,y+h/2,2.5)),(V3(x+w/2,y+h/2,2.5),V3(x-w/2,y+h/2,2.5)),(V3(x-w/2,y+h/2,2.5),V3(x-w/2,y-h/2,2.5))] { debugMesh.line(a,b,width:0.02,color:tint(0xf0e095)) }
            }
            for platform in s.platforms { outline(Vec(platform.x,platform.y),platform.width,platform.height) }
            outline(s.cube.position,1.12,1.12);outline(s.crate.position,1.25,1.25)
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
