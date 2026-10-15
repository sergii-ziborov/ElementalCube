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
    func testSubmergedMasonryReleasesTheActualContactedBrick() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication();app.launchArguments=["--ui-testing","--preview-stone","--preview-wall-intact"];app.launch()
        XCTAssertTrue(world.waitForExistence(timeout:25));XCTAssertEqual(value("masonry"),"9");XCTAssertEqual(value("debris"),"0")
        capture("Submerged bonded masonry before impact")
        app.terminate();app.launchArguments=["--ui-testing","--preview-stone","--preview-wall"];app.launch()
        XCTAssertTrue(world.waitForExistence(timeout:25));XCTAssertEqual(value("map"),"grotto")
        XCTAssertEqual(value("masonry"),"8");XCTAssertEqual(value("debris"),"1")
        capture("Submerged masonry with real hole and released brick")
    }
    func testIceCanSwipeJumpAwayFromItsFrozenContactBesideTheBridge() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication();app.launchArguments=["--ui-testing","--preview-ice","--preview-live","--test-calm"];app.launch()
        XCTAssertTrue(world.waitForExistence(timeout:25));XCTAssertEqual(value("form"),"ice")
        let start=Int(value("jumps")) ?? 0
        world.coordinate(withNormalizedOffset:CGVector(dx:0.80,dy:0.74)).press(forDuration:0.05,thenDragTo:world.coordinate(withNormalizedOffset:CGVector(dx:0.80,dy:0.43)))
        let jumped=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (Int(self.value("jumps")) ?? 0)>start },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[jumped],timeout:3),.completed)
        capture("Ice leaves the wet interface with a free swipe")
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
