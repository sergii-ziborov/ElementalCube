// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ElementalCube", platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.executable(name: "ElementalCube", targets: ["ElementalCube"]), .library(name: "ElementalCore", targets: ["ElementalCore"])],
    targets: [
        .target(name: "Box2D", path: "Vendor/Box2D", exclude: ["src/CMakeLists.txt", "src/box2d.natvis"], sources: ["src"], publicHeadersPath: "include", cSettings: [.headerSearchPath("src")]),
        .target(name: "CPhysics", dependencies: ["Box2D"], path: "Sources/CPhysics", publicHeadersPath: "include"),
        .target(name: "ElementalCore", dependencies: ["CPhysics"]),
        .executableTarget(name: "ElementalCube", dependencies: ["ElementalCore"], resources: [.copy("Shaders.metal.txt"),.copy("SkillArt")]),
        .testTarget(name: "ElementalCoreTests", dependencies: ["ElementalCore"])
    ], cLanguageStandard: .c17
)
