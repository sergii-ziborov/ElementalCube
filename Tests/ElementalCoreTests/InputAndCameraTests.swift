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
        let nearLeft=CameraFraming.target(cubeX:WorldLayout.bounds.minX+1,velocityX:-5,movement:-1,facing:-1,aimVelocityX:nil,worldWidth:10)
        let nearRight=CameraFraming.target(cubeX:WorldLayout.bounds.maxX-1,velocityX:5,movement:1,facing:1,aimVelocityX:nil,worldWidth:10)
        XCTAssertGreaterThanOrEqual(nearLeft-5,WorldLayout.bounds.minX);XCTAssertLessThanOrEqual(nearRight+5,WorldLayout.bounds.maxX)
        let wide=CameraFraming.target(cubeX:WorldLayout.bounds.maxX-1,velocityX:5,movement:1,facing:1,aimVelocityX:nil,worldWidth:130)
        XCTAssertEqual(wide,WorldLayout.bounds.center.x,accuracy:0.001)
    }
    func testVerticalCameraKeepsCubeClearOfPhoneHUDAtBothWorldExtremes() {
        for (y,velocity):(Float,Float) in [(22.56,0),(-22.34,0),(22.56,-12),(-22.34,-12)] {
            let height:Float=18,center=CameraFraming.verticalTarget(cubeY:y,velocityY:velocity,aimVelocityY:nil,worldHeight:height)
            let screenFraction=0.5-(y+0.34-center)/height
            XCTAssertGreaterThan(screenFraction,0.4);XCTAssertLessThan(screenFraction,0.8)
        }
    }

}
