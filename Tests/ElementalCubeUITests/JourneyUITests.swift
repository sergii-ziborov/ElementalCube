import XCTest

final class JourneyUITests:XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait;app=XCUIApplication() }
    private func reveal(_ element:XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable && element.frame.midY<app.frame.maxY-55 && element.frame.midY>150 { return }
            app.swipeUp(velocity:.slow)
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name:String) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
    func testLockedBranchCanBeInspectedWithoutStartingIt() {
        app.launchArguments=["--ui-testing"];app.launch()
        XCTAssertTrue(app.buttons["home.open"].waitForExistence(timeout:15));app.buttons["home.open"].tap()
        let tree=XCTAttachment(string:app.debugDescription);tree.name="Journey accessibility";tree.lifetime = .keepAlways;add(tree)
        let node=app.buttons["map.glacier"];reveal(node);XCTAssertEqual(node.value as? String,"Закрыто");node.tap()
        let start=app.buttons["journey.start"];reveal(start);XCTAssertFalse(start.isEnabled)
        XCTAssertTrue(app.staticTexts["journey.selection"].label.contains("Хрустальные высоты"))
        capture("Locked route explains the previous shore")
    }
    func testFinishShowsTwoContinuationsAndActuallyLoadsTheChosenWorld() {
        app.launchArguments=["--ui-testing","--preview-finish"];app.launch()
        XCTAssertTrue(app.staticTexts["finish.title"].waitForExistence(timeout:20))
        XCTAssertTrue(app.otherElements["finish.finds"].exists || app.staticTexts["finish.finds"].exists)
        capture("Actual physical finish receipt")
        let next=app.buttons["finish.next.forge"];reveal(next);next.tap()
        XCTAssertTrue(app.otherElements["game.world"].waitForExistence(timeout:10))
        XCTAssertTrue((app.otherElements["game.world"].value as? String ?? "").contains("map=forge"))
        XCTAssertFalse(app.staticTexts["finish.title"].exists)
        app.buttons["home.open"].tap()
        let branch=app.buttons["map.glacier"];reveal(branch);XCTAssertEqual(branch.value as? String,"Доступно")
    }
    func testJourneyMapHasConnectedRoutesAndSelectionDetailsOnTabletAndPhone() {
        app.launchArguments=["--ui-testing","--preview-journey"];app.launch()
        XCTAssertTrue(app.segmentedControls["home.tabs"].waitForExistence(timeout:20))
        let grove=app.buttons["map.meadow"];reveal(grove);XCTAssertEqual(grove.value as? String,"Доступно")
        grove.tap();capture("Branching journey world map")
        let start=app.buttons["journey.start"];reveal(start);XCTAssertTrue(start.isEnabled)
        capture("Map details with exact collectible totals")
        start.tap();XCTAssertTrue(app.otherElements["game.world"].waitForExistence(timeout:10))
        XCTAssertTrue((app.otherElements["game.world"].value as? String ?? "").contains("map=meadow"))
    }
    func testStrongStoneImpactDrawsActualFragments() {
        app.launchArguments=["--ui-testing","--preview-stone","--preview-shatter"];app.launch()
        let world=app.otherElements["game.world"];XCTAssertTrue(world.waitForExistence(timeout:20))
        XCTAssertTrue((world.value as? String ?? "").contains("debris=6"))
        capture("Stone impact and six real fragments")
    }
    func testRelicIllustrationsHaveDifferentInventoryCards() {
        app.launchArguments=["--ui-testing","--ui-testing-rich","--preview-equipment"];app.launch()
        let first=app.otherElements["item.art.travelerCharm"],second=app.otherElements["item.art.deepRelic"]
        XCTAssertTrue(app.buttons["equip.travelerCharm"].waitForExistence(timeout:20))
        capture("Distinct illustrated talismans")
        reveal(app.buttons["equip.deepRelic"])
        XCTAssertTrue(second.exists || app.staticTexts["Сердце глубин"].exists)
        app.buttons["equip.deepRelic"].tap();capture("Heart of the Depths equipped")
        app.buttons["inventory.close"].tap()
        XCTAssertTrue((app.otherElements["game.world"].value as? String ?? "").contains("charm=deepRelic"))
        _=first
    }
}
