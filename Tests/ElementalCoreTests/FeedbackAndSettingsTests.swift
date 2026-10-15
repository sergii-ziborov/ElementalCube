import XCTest
@testable import ElementalCore

final class FeedbackAndSettingsTests: XCTestCase {
    private func advance(_ simulation: Simulation, _ seconds: Float) {
        for _ in 0..<Int(seconds/Simulation.timestep) { simulation.step() }
    }
    func testRejectedAirJumpDoesNotProduceAnotherJumpFeedback() {
        let s=Simulation();advance(s,1);_=s.takeFeedback()
        XCTAssertTrue(s.jump(Vec(0,8),buffered:false))
        XCTAssertEqual(s.takeFeedback(),[.jumped])
        XCTAssertFalse(s.jump(Vec(0,8),buffered:false))
        XCTAssertTrue(s.takeFeedback().isEmpty)
    }
    func testLandingFeedbackIsDeliveredOnceAndUsesTheContactSurface() {
        for (x,surface) in [(Float(2),Surface.grass),(Float(12),Surface.wood)] {
            let s=Simulation(form:.stone);s.placeCube(Vec(x,5));advance(s,2)
            let landings=s.takeFeedback().compactMap { event -> Float? in
                if case let .landed(impact,actual)=event { XCTAssertEqual(actual,surface);return impact }
                return nil
            }
            XCTAssertEqual(landings.count,1);XCTAssertGreaterThan(landings.first ?? 0,0.4)
            advance(s,2)
            XCTAssertFalse(s.takeFeedback().contains { if case .landed = $0 { return true };return false })
        }
    }
    func testCollectibleAndFreezeFeedbackDoNotRepeatOnRefresh() {
        let s=Simulation();s.placeCube(s.shards[0]);s.step()
        XCTAssertEqual(s.takeFeedback().filter { $0 == .collectedCrystal },[.collectedCrystal])
        s.placeCube(s.shards[0]);s.step()
        XCTAssertFalse(s.takeFeedback().contains(.collectedCrystal))
        s.placeCube(Vec(10,-1));s.equipPassive(true);advance(s,3)
        XCTAssertEqual(s.takeFeedback().filter { $0 == .frozeWater },[.frozeWater])
        advance(s,0.3);XCTAssertFalse(s.takeFeedback().contains(.frozeWater))
    }
    private func withDefaults(_ block:(UserDefaults)->Void) {
        let suite="ElementalCubeTests.\(UUID().uuidString)"
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        block(defaults)
    }
    func testSettingsSurviveCreatingAnotherStore() {
        withDefaults { defaults in
            var settings=PlaygroundSettings();settings.gravity=22;settings.power=0.8;settings.zoom=1.4
            settings.water=false;settings.inverted=false;settings.debug=true;settings.haptics=false
            PlaygroundSettingsStore(defaults:defaults).save(settings)
            XCTAssertEqual(PlaygroundSettingsStore(defaults:defaults).load(),settings)
        }
    }
    func testCorruptOrOlderSettingsFallBackToUsableDefaults() {
        withDefaults { defaults in
            for data in [Data("invalid json".utf8),Data("{\"gravity\":18}".utf8)] {
                defaults.set(data,forKey:"elementalcube.settings.v1")
                XCTAssertEqual(PlaygroundSettingsStore(defaults:defaults).load(),PlaygroundSettings())
            }
        }
    }
    func testInvalidSettingsCannotApplyUnsafePhysicsValues() {
        withDefaults { defaults in
            var settings=PlaygroundSettings();settings.gravity = .infinity;settings.power = -100;settings.zoom = 10
            PlaygroundSettingsStore(defaults:defaults).save(settings)
            let loaded=PlaygroundSettingsStore(defaults:defaults).load()
            XCTAssertEqual(loaded.gravity,18);XCTAssertEqual(loaded.power,0.7);XCTAssertEqual(loaded.zoom,1.6)
        }
    }
}
