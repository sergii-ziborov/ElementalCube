import XCTest

final class HomeFlowTests:XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication()
    }
    private func reveal(_ element:XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity:.fast)
        }
        XCTAssertTrue(element.exists);XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name:String) {
        let image=XCTAttachment(screenshot:app.screenshot());image.name=name;image.lifetime = .keepAlways;add(image)
    }
    private func worldValue(_ key:String)->String {
        let raw=app.otherElements["game.world"].value as? String ?? ""
        return raw.split(separator:";").first { $0.hasPrefix(key+"=") }.map { String($0.dropFirst(key.count+1)) } ?? ""
    }
    func testFirstChoiceStartsWithWaterAndReturningHomeDoesNotGiveAFreeSwitch() {
        app.launchArguments=["--ui-testing","--onboarding"];app.launch()
        capture("Native starter choice")
        let water=app.buttons["starter.water"]
        XCTAssertTrue(water.waitForExistence(timeout:15));reveal(water);water.tap()
        let begin=app.buttons["starter.begin"];reveal(begin);begin.tap()
        XCTAssertTrue(app.otherElements["game.cube"].waitForExistence(timeout:15))
        XCTAssertEqual(worldValue("form"),"water")
        app.buttons["home.open"].tap()
        XCTAssertTrue(app.segmentedControls["home.tabs"].waitForExistence(timeout:8))
        app.segmentedControls.buttons["Кубики"].tap()
        let recruit=app.buttons.matching(NSPredicate(format:"label CONTAINS %@", "Новый друг · 4")).firstMatch
        reveal(recruit);recruit.tap()
        let confirm=app.buttons["collection.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout:5));reveal(confirm);XCTAssertFalse(confirm.isEnabled)
    }
    func testEvolutionRecruitAndMergeProduceAnActualNewOwnedMonster() {
        app.launchArguments=["--ui-testing","--ui-testing-rich"];app.launch()
        XCTAssertTrue(app.buttons["home.open"].waitForExistence(timeout:15));app.buttons["home.open"].tap()
        capture("Native journey")
        app.segmentedControls.buttons["Эволюция"].tap()
        let evolve=app.buttons["evolution.confirm"];reveal(evolve);XCTAssertTrue(evolve.isEnabled);evolve.tap()
        XCTAssertTrue(app.staticTexts["Росток"].waitForExistence(timeout:5));capture("Native evolution")
        app.swipeDown(velocity:.fast);app.segmentedControls.buttons["Кубики"].tap()
        let recruit=app.buttons.matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@", "Капля","Новый друг")).firstMatch
        reveal(recruit);recruit.tap()
        let confirm=app.buttons["collection.confirm"];reveal(confirm);confirm.tap()
        XCTAssertTrue(app.segmentedControls["home.tabs"].waitForExistence(timeout:6))
        app.swipeDown(velocity:.fast);app.segmentedControls.buttons["Эволюция"].tap()
        let merge=app.buttons["merge.begin"];reveal(merge);merge.tap()
        let choices=app.buttons.matching(NSPredicate(format:"label == %@", "Объединить · 4 эфира"))
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout:4));choices.allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(app.buttons["merge.result.close"].waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["Снежок"].exists)
        let image=XCTAttachment(screenshot:app.screenshot());image.name="Native hybrid birth";image.lifetime = .keepAlways;add(image)
        app.buttons["merge.result.close"].tap()
        let play=app.buttons["home.play"];reveal(play);play.tap()
        XCTAssertTrue(app.otherElements["game.cube"].waitForExistence(timeout:10));XCTAssertEqual(worldValue("form"),"ice")
    }
    func testEveryMapOpensItsOwnPhysicalWorld() {
        app.launchArguments=["--ui-testing"];app.launch()
        for map in ["glacier","forge","shore"] {
            XCTAssertTrue(app.buttons["home.open"].waitForExistence(timeout:15));app.buttons["home.open"].tap()
            let entry=app.buttons["map."+map];reveal(entry);entry.tap()
            XCTAssertTrue(app.otherElements["game.cube"].waitForExistence(timeout:10))
            XCTAssertEqual(worldValue("map"),map)
        }
    }

}
