import XCTest

final class SkillTreeTests:XCTestCase {
    private func reveal(_ element:XCUIElement,_ app:XCUIApplication) {
        for _ in 0..<5 {
            // SwiftUI reports a clipped card hittable even when its centre is
            // below the sheet. Reveal the whole card before tapping its centre.
            if element.exists && element.isHittable && element.frame.maxY<app.frame.maxY-35 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app:XCUIApplication,_ title:String) {
        let a=XCTAttachment(screenshot:app.screenshot());a.name=title;a.lifetime = .keepAlways;add(a)
    }
    func testFireMasteryExplainsRealNumbersLearnsOnceAndUpdatesTheSimulation() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication();app.launchArguments=["--preview-skills","--preview-fire","--ui-testing"];app.launch()
        let mastery=app.buttons["skill.mastery"];XCTAssertTrue(mastery.waitForExistence(timeout:20))
        capture(app,"Illustrated fire tree")
        reveal(mastery,app);mastery.tap()
        XCTAssertTrue(app.staticTexts["85%"].waitForExistence(timeout:5))
        capture(app,"Hot core real before and after")
        let learn=app.buttons["skill.learn"];XCTAssertTrue(learn.isEnabled);learn.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Изучено: Жаркое ядро")).firstMatch.waitForExistence(timeout:2))
        XCTAssertTrue((mastery.value as? String ?? "").contains("Изучено"))
        mastery.tap()
        XCTAssertTrue(app.staticTexts["skill.known.status"].waitForExistence(timeout:4))
        XCTAssertFalse(app.buttons["skill.learn"].exists)
        capture(app,"Learned hot core unmistakable seal")
        app.buttons["skill.detail.close"].tap()
        app.buttons["inventory.close"].tap()
        let world=app.otherElements["game.world"];XCTAssertTrue(world.waitForExistence(timeout:8))
        XCTAssertTrue((world.value as? String ?? "").contains("fireCost=0.85"))
    }
    func testLockedFinisherShowsItsPrerequisiteAndCannotSpendPoints() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication();app.launchArguments=["--preview-skills","--preview-water","--ui-testing"];app.launch()
        let finisher=app.buttons["skill.resilience"];XCTAssertTrue(finisher.waitForExistence(timeout:20));reveal(finisher,app)
        capture(app,"Water elemental progression")
        finisher.tap()
        let learn=app.buttons["skill.learn"];XCTAssertTrue(learn.waitForExistence(timeout:5));XCTAssertFalse(learn.isEnabled)
        XCTAssertTrue(app.staticTexts["Живая вода"].exists)
        capture(app,"Living water locked with requirements")
        app.buttons["skill.detail.close"].tap();XCTAssertTrue(app.buttons["inventory.close"].isHittable)
        app.buttons["inventory.close"].tap();XCTAssertTrue(app.otherElements["game.world"].exists)
    }
}
