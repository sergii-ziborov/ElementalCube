import SwiftUI
import ElementalCore

struct SkillPalette {
    let accent:Color
    let background=Color(red:0.055,green:0.14,blue:0.17)
    let paper=Color(red:0.93,green:0.96,blue:0.89)
    init(_ form:ElementForm) {
        switch form {
        case .ice:accent=Color(red:0.53,green:0.87,blue:1)
        case .water:accent=Color(red:0.38,green:0.80,blue:0.97)
        case .air:accent=Color(red:0.52,green:0.93,blue:0.79)
        case .stone:accent=Color(red:0.90,green:0.77,blue:0.51)
        case .fire:accent=Color(red:1,green:0.69,blue:0.39)
        }
    }
}

private enum SkillArtLibrary {
    #if os(macOS)
    static let images:[String:NSImage]=load()
    static func load()->[String:NSImage] {
        names.reduce(into:[:]) { result,name in if let url=bundle.url(forResource:name,withExtension:"png",subdirectory:"SkillArt"),let image=NSImage(contentsOf:url) { result[name]=image } }
    }
    #else
    static let images:[String:UIImage]=load()
    static func load()->[String:UIImage] {
        names.reduce(into:[:]) { result,name in if let url=bundle.url(forResource:name,withExtension:"png",subdirectory:"SkillArt"),let image=UIImage(contentsOfFile:url.path) { result[name]=image } }
    }
    #endif
    static let names=["fire","ice","water","air","stone","aim","momentum","double","control","affinity"]+["fire","ice","water","air","stone"].flatMap { [$0+"-mastery",$0+"-resilience"] }
    static var bundle:Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}

/// Painted emblems with different silhouettes for a passive, elemental core,
/// affinity and signature. No SF Symbol stands in for the ability artwork.
struct SkillArtwork:View {
    var monster:MonsterRecord
    var kind:SkillNode.Kind
    var size:CGFloat=84
    private var palette:SkillPalette { SkillPalette(monster.form) }
    private var asset:String {
        switch kind {
        case .jump:return "aim"
        case .momentum:return "momentum"
        case .doubleJump:return "double"
        case .control:return "control"
        case .passive:return monster.form.rawValue
        case .affinity:return "affinity"
        case .mastery:return (monster.hybridStyle == .magma ? "fire" : (monster.hybridStyle == .crystal ? "ice" : monster.form.rawValue))+"-mastery"
        case .resilience:
            switch monster.signature {
            case .quickDry:return "ice-resilience"
            case .healingWater,.healingMist:return "water-resilience"
            case .softLanding:return "air-resilience"
            case .titanRoll:return "stone-resilience"
            case .boilingHeart:return "fire-resilience"
            case .coldCrystal:return "ice-mastery"
            case .spring:return "momentum"
            case .windGuard:return "air-mastery"
            }
        }
    }
    var body:some View {
        ZStack {
            RadialGradient(colors:[palette.accent.opacity(0.18),.clear],center:.center,startRadius:2,endRadius:size*0.56)
            art.frame(width:size,height:size).shadow(color:palette.accent.opacity(0.22),radius:size*0.08)
            if monster.isHybrid && !SkillCatalog.movement.contains(kind) {
                Circle().fill(SkillPalette(monster.secondaryForm ?? monster.form).accent).frame(width:size*0.105,height:size*0.105).overlay(Circle().stroke(.white.opacity(0.8),lineWidth:1)).offset(x:size*0.33,y:size*0.26)
            }
        }.frame(width:size,height:size).accessibilityHidden(true)
    }
    @ViewBuilder private var art:some View {
        if let image=SkillArtLibrary.images[asset] {
            #if os(macOS)
            Image(nsImage:image).resizable().interpolation(.high).scaledToFit()
            #else
            Image(uiImage:image).resizable().interpolation(.high).scaledToFit()
            #endif
        } else {
            // A visible loading fallback during local asset preparation.
            gem.fill(palette.accent.opacity(0.4))
        }
    }
    private var gem:Path {
        Path { p in p.move(to:CGPoint(x:size*0.5,y:size*0.06));for q in [CGPoint(x:size*0.86,y:size*0.29),CGPoint(x:size*0.78,y:size*0.7),CGPoint(x:size*0.5,y:size*0.94),CGPoint(x:size*0.20,y:size*0.7),CGPoint(x:size*0.12,y:size*0.29)] { p.addLine(to:q) };p.closeSubpath() }
    }
}
