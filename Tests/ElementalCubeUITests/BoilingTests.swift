import XCTest

final class BoilingTests:XCTestCase {
    func testFireBoilsActualWaterWithoutSpendingPassiveMana() {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication();app.launchArguments=["--preview-fire","--ui-testing"];app.launch()
        let world=app.otherElements["game.world"]
        XCTAssertTrue(world.waitForExistence(timeout:25))
        let raw=world.value as? String ?? ""
        func value(_ key:String)->String { raw.split(separator:";").first { $0.hasPrefix(key+"=") }.map { String($0.dropFirst(key.count+1)) } ?? "" }
        XCTAssertEqual(value("form"),"fire")
        XCTAssertGreaterThan(Float(value("boiling")) ?? 0,0)
        XCTAssertGreaterThan(Int(value("bubbles")) ?? 0,0)
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format:"label == %@","МАНА: 100 из 100")).firstMatch.exists)
        let image=XCTAttachment(screenshot:app.screenshot());image.name="Native local boiling";image.lifetime = .keepAlways;add(image)
    }
}
