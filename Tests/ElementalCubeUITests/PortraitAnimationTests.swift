import XCTest
import UIKit

final class PortraitAnimationTests:XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication()
    }
    private func pixels(_ element:XCUIElement)->[UInt8] {
        let image=UIImage(data:element.screenshot().pngRepresentation)!.cgImage!
        var bytes=[UInt8](repeating:0,count:image.width*image.height*4)
        bytes.withUnsafeMutableBytes { data in
            let context=CGContext(data:data.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        }
        return bytes
    }
    private func assertMoves(_ portrait:XCUIElement,file:StaticString=#filePath,line:UInt=#line) {
        let first=pixels(portrait)
        Thread.sleep(forTimeInterval:0.55)
        let second=pixels(portrait)
        XCTAssertEqual(first.count,second.count,file:file,line:line)
        let changed=zip(first,second).reduce(0) { $0+(abs(Int($1.0)-Int($1.1))>4 ? 1 : 0) }
        XCTAssertGreaterThan(changed,24,"Compare decoded pixels, excluding PNG metadata",file:file,line:line)
    }
    func testEveryElementHasLivePortraitPixelsAndReactsToTouch() {
        app.launchArguments=["--preview-portraits","--ui-testing"];app.launch()
        for form in ["ice","water","air","stone","fire"] {
            let portrait=app.buttons["portrait."+form]
            XCTAssertTrue(portrait.waitForExistence(timeout:10))
            if !portrait.isHittable { app.swipeUp() }
            assertMoves(portrait)
        }
        app.swipeDown()
        let ice=app.buttons["portrait.ice"]
        ice.tap();XCTAssertEqual(ice.value as? String,"reactions=1")
    }
    func testInventoryPortraitKeepsMovingWhileGameplayIsPaused() {
        app.launchArguments=["--ui-testing"];app.launch()
        XCTAssertTrue(app.buttons["inventory.open"].waitForExistence(timeout:15))
        app.buttons["inventory.open"].tap()
        let portrait=app.buttons["portrait.inventory"]
        XCTAssertTrue(portrait.waitForExistence(timeout:5));assertMoves(portrait)
        portrait.tap();XCTAssertEqual(portrait.value as? String,"reactions=1")
        app.buttons["inventory.close"].tap()
        XCTAssertTrue(app.otherElements["game.cube"].exists)
    }
}
