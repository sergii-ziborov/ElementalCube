import XCTest

final class MetamorphosisTests:XCTestCase {
    private func reveal(_ element:XCUIElement,_ app:XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.frame.midY<app.frame.maxY-110 && element.frame.midY>app.frame.minY+110 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }
    private func capture(_ app:XCUIApplication,_ name:String) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
    private func world(_ app:XCUIApplication,_ key:String)->String {
        (app.otherElements["game.world"].value as? String ?? "").split(separator:";").first { $0.hasPrefix(key+"=") }.map { String($0.dropFirst(key.count+1)) } ?? ""
    }
    func testPreparationCanCancelThenCommitPinnedIceToSteamWithARealLossReport() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication();app.launchArguments=["--preview-metamorphosis","--ui-testing"];app.launch()
        let start=app.buttons["merge.begin"];XCTAssertTrue(start.waitForExistence(timeout:20));reveal(start,app);start.tap()
        let confirm=app.buttons["merge.confirm"];XCTAssertTrue(confirm.waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["merge.result.form"].label.contains("Парик"));capture(app,"Known Steam form and lost cold")
        app.buttons["merge.keep"].tap();XCTAssertTrue(app.segmentedControls["home.tabs"].waitForExistence(timeout:5))
        reveal(start,app);start.tap();XCTAssertTrue(confirm.waitForExistence(timeout:5))
        let cold=app.buttons["merge.pin.receiver.0"];reveal(cold,app);XCTAssertFalse(cold.isEnabled)
        let jump=app.buttons["merge.pin.receiver.3"];reveal(jump,app);XCTAssertTrue(jump.isEnabled);jump.tap()
        XCTAssertEqual(jump.value as? String,"Закреплён");capture(app,"Conditioned genetic probabilities")
        XCTAssertTrue(confirm.isEnabled);confirm.tap()
        let close=app.buttons["merge.result.close"];XCTAssertTrue(close.waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Парик"].exists);XCTAssertTrue(app.staticTexts["Потеряно"].exists);capture(app,"Stored metamorphosis outcome")
        close.tap()
        let play=app.buttons["home.play"];reveal(play,app);play.tap()
        XCTAssertTrue(app.otherElements["game.world"].waitForExistence(timeout:10))
        XCTAssertEqual(world(app,"morph"),"steam");XCTAssertEqual(world(app,"freeze"),"0");XCTAssertEqual(world(app,"heatImmune"),"1");XCTAssertEqual(world(app,"generation"),"1")
        app.buttons["home.open"].tap();app.segmentedControls.buttons["Кубики"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","Огонёк","Сменить")).firstMatch.exists)
    }
    func testPersonalPassportEditsFourReserveImprintsWithoutChangingTheTree() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication();app.launchArguments=["--preview-metamorphosis","--ui-testing"];app.launch()
        XCTAssertTrue(app.segmentedControls["home.tabs"].waitForExistence(timeout:20));app.segmentedControls.buttons["Путь"].tap()
        app.buttons["home.inventory"].tap()
        let open=app.buttons["passport.open"];XCTAssertTrue(open.waitForExistence(timeout:5));reveal(open,app);open.tap()
        let mastery=app.buttons["passport.mastery"];XCTAssertTrue(mastery.waitForExistence(timeout:5));mastery.tap()
        let control=app.buttons["passport.control"];reveal(control,app);control.tap()
        XCTAssertEqual(control.value as? String,"В паспорте");capture(app,"Four chosen reserve imprints")
        app.buttons["passport.save"].tap();XCTAssertTrue(open.waitForExistence(timeout:5));reveal(open,app);open.tap()
        XCTAssertTrue(mastery.waitForExistence(timeout:5));XCTAssertEqual(mastery.value as? String,"Вне паспорта")
        reveal(control,app);XCTAssertEqual(control.value as? String,"В паспорте")
        app.buttons["passport.save"].tap();app.buttons["inventory.close"].tap()
        XCTAssertTrue(app.segmentedControls["home.tabs"].exists)
    }
}
