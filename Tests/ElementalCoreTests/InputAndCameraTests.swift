import XCTest
@testable import ElementalCore

final class InputAndCameraTests: XCTestCase {
    func testReleasingOneButtonResumesTheOtherHeldButton() {
        var input=MovementInput()
        input.press(source:"left",direction:-1);input.press(source:"right",direction:1)
        XCTAssertEqual(input.value,1)
        input.release(source:"right");XCTAssertEqual(input.value,-1)
        input.release(source:"left");XCTAssertEqual(input.value,0)
    }
    func testRepeatsDoNotReverseTheMostRecentPress() {
        var input=MovementInput()
        input.press(source:"left",direction:-1);input.press(source:"right",direction:1)
        for _ in 0..<30 { input.press(source:"left",direction:-1) }
        XCTAssertEqual(input.value,1)
        input.release(source:"right");XCTAssertEqual(input.value,-1)
    }
    func testEquivalentKeysRemainHeldIndependently() {
        var input=MovementInput()
        input.press(source:"A",direction:-1);input.press(source:"arrow-left",direction:-1)
        input.release(source:"A");XCTAssertEqual(input.value,-1)
        input.release(source:"unrelated");XCTAssertEqual(input.value,-1)
        input.clear();XCTAssertEqual(input.value,0)
        input.release(source:"arrow-left");XCTAssertEqual(input.value,0)
    }
    func testInvalidInputCannotPoisonMovement() {
        var input=MovementInput()
        input.press(source:"left",direction:-1);input.press(source:"invalid",direction:.nan)
        XCTAssertEqual(input.value,-1)
    }
    func testCameraShowsSpaceAheadWhenMovingInEitherDirection() {
        func target(_ movement:Float)->Float {
            CameraFraming.target(cubeX:12,velocityX:0,movement:movement,facing:1,aimVelocityX:nil,worldWidth:10)
        }
        XCTAssertLessThan(target(-1),12);XCTAssertGreaterThan(target(1),12)
        XCTAssertEqual(12-target(-1),target(1)-12,accuracy:0.001)
    }
    func testAimedLeftJumpOverridesRightFacingCamera() {
        let left=CameraFraming.target(cubeX:12,velocityX:2,movement:1,facing:1,aimVelocityX:-8,worldWidth:10)
        let vertical=CameraFraming.target(cubeX:12,velocityX:0,movement:0,facing:1,aimVelocityX:0,worldWidth:10)
        XCTAssertLessThan(left,12);XCTAssertEqual(vertical,12,accuracy:0.001)
    }
    func testCameraKeepsWorldEdgesVisibleAndCentersOversizedViewport() {
        let nearLeft=CameraFraming.target(cubeX:-1,velocityX:-5,movement:-1,facing:-1,aimVelocityX:nil,worldWidth:10)
        let nearRight=CameraFraming.target(cubeX:24,velocityX:5,movement:1,facing:1,aimVelocityX:nil,worldWidth:10)
        XCTAssertGreaterThanOrEqual(nearLeft-5,-2.7);XCTAssertLessThanOrEqual(nearRight+5,25)
        let wide=CameraFraming.target(cubeX:24,velocityX:5,movement:1,facing:1,aimVelocityX:nil,worldWidth:40)
        XCTAssertEqual(wide,11.15,accuracy:0.001)
    }
}
