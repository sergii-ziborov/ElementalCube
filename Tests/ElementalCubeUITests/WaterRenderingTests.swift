import XCTest

final class WaterRenderingTests:XCTestCase {
    private var app:XCUIApplication!
    private var world:XCUIElement { app.otherElements["game.world"] }
    private func value(_ key:String)->String {
        (world.value as? String ?? "").split(separator:";").first { $0.hasPrefix(key+"=") }.map { String($0.dropFirst(key.count+1)) } ?? ""
    }
    private func launch(_ args:[String]) {
        app?.terminate();app=XCUIApplication();app.launchArguments=args+["--ui-testing"];app.launch()
        XCTAssertTrue(world.waitForExistence(timeout:25));XCTAssertEqual(value("form"),"water")
    }
    private func capture(_ name:String) {
        let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
    }
    func testWaterSurfaceAtBankAndDuringImpact() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        launch(["--preview-water","--preview-bank"])
        XCTAssertGreaterThan(Float(value("x")) ?? 0,15)
        capture("Water cube and bank meniscus")
        launch(["--preview-water","--preview-splash"])
        capture("Conserved impact water and detached spray")
    }
    func testWaterSwimsOutOfTheBasinInTheActualApp() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        launch(["--preview-water","--preview-bank","--preview-live"])
        // A map tap, through the same touch path used on an iPhone, chooses
        // the right bank. No debug teleport after the scene starts running.
        world.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.56)).tap()
        let escaped=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (Float(self.value("x")) ?? 0)>17 },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[escaped],timeout:10),.completed)
        XCTAssertEqual(value("form"),"water");capture("Water returned to the bank")
    }
}
