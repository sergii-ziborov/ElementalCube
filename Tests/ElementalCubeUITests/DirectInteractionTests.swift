import XCTest

final class DirectInteractionTests:XCTestCase {
    var app:XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false;XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication();app.launchArguments=["--ui-testing"];app.launch()
        XCTAssertTrue(app.otherElements["game.cube"].waitForExistence(timeout:15))
        sleep(2)
    }
    private var cube:XCUIElement { app.otherElements["game.cube"] }
    private var world:XCUIElement { app.otherElements["game.world"] }
    private func value(_ key:String)->String {
        let raw=world.value as? String ?? ""
        return raw.split(separator:";").first { $0.hasPrefix(key+"=") }.map { String($0.dropFirst(key.count+1)) } ?? ""
    }
    private func coordinate(_ offset:CGVector)->XCUICoordinate { cube.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).withOffset(offset) }
    func testMapTapMovesAndReversesWithoutJump() {
        let start=Double(value("x"))!
        coordinate(CGVector(dx:115,dy:-20)).tap()
        let forward=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (Double(self.value("x")) ?? start)>start+0.6 },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[forward],timeout:8),.completed);XCTAssertEqual(value("jumps"),"0")
        let right=Double(value("x"))!
        coordinate(CGVector(dx:-115,dy:-20)).tap()
        let reverse=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (Double(self.value("x")) ?? right)<right-0.6 },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[reverse],timeout:8),.completed);XCTAssertEqual(value("jumps"),"0")
    }
    func testSingleShortTapIsOneOrdinaryUpwardJump() {
        let startX=Double(value("x"))!
        cube.tap()
        XCTAssertEqual(value("jumps"),"1")
        XCTAssertLessThan(abs(Double(value("x"))!-startX),0.4)
        sleep(2);XCTAssertEqual(value("jumps"),"1")
    }
    func testDragCubeJumpsInTheDraggedDirectionAndRotates() {
        app.buttons["inventory.open"].tap()
        let directed=app.buttons["skill.jump"]
        XCTAssertTrue(directed.waitForExistence(timeout:5))
        if !directed.isHittable { app.swipeUp() };directed.tap()
        app.buttons["skill.learn"].tap()
        app.buttons["inventory.close"].tap()
        let start=Double(value("x"))!
        coordinate(.zero).press(forDuration:0.1,thenDragTo:coordinate(CGVector(dx:75,dy:-125)))
        XCTAssertEqual(value("jumps"),"1")
        sleep(1);XCTAssertGreaterThan(Double(value("x"))!,start+0.5)
        XCUIDevice.shared.orientation = .landscapeLeft;sleep(1)
        XCTAssertEqual(value("aiming"),"0")
        XCTAssertTrue(cube.exists)
        let image=XCTAttachment(screenshot:app.screenshot());image.name="iPhone landscape direct controls";image.lifetime = .keepAlways;add(image)
    }
    func testDirectedDragIsLockedUntilLearnedButTapStillJumps() {
        coordinate(.zero).press(forDuration:0.1,thenDragTo:coordinate(CGVector(dx:75,dy:-125)))
        XCTAssertEqual(value("jumps"),"0")
        cube.tap();XCTAssertEqual(value("jumps"),"1")
    }
    func testPersonalTreeAndEquipmentChangeTheSelectedMonster() {
        app.buttons["inventory.open"].tap()
        XCTAssertTrue(app.buttons["skill.mastery"].waitForExistence(timeout:5))
        app.swipeUp()
        app.buttons["skill.mastery"].tap()
        let learn=app.buttons["skill.learn"]
        if !learn.isHittable { app.swipeUp() }
        XCTAssertTrue(learn.waitForExistence(timeout:3));learn.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout:3))
        app.swipeDown()
        app.segmentedControls.buttons["Снаряжение"].tap()
        let equip=app.buttons["equip.travelerCharm"]
        if !equip.isHittable { app.swipeUp() };equip.tap()
        let image=XCTAttachment(screenshot:app.screenshot());image.name="iPhone monster inventory";image.lifetime = .keepAlways;add(image)
        app.buttons["inventory.close"].tap()
        XCTAssertEqual(value("cold"),"1.25");XCTAssertEqual(value("charm"),"travelerCharm")
    }
}
