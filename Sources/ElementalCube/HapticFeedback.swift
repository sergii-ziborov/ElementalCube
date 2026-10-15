import Foundation
import ElementalCore
#if os(iOS)
import UIKit
#endif

final class HapticFeedback {
    #if os(iOS)
    private let soft = UIImpactFeedbackGenerator(style:.soft)
    private let rigid = UIImpactFeedbackGenerator(style:.rigid)
    private let notification = UINotificationFeedbackGenerator()
    #endif
    func play(_ events: [SimulationFeedback], enabled: Bool) {
        #if os(iOS)
        guard enabled, !events.isEmpty else { return }
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.play(events,enabled:enabled) }; return
        }
        for event in events {
            switch event {
            case .jumped: soft.impactOccurred(intensity:0.45)
            case let .landed(impact,surface):
                if surface == .grass || surface == .wood { soft.impactOccurred(intensity:CGFloat(impact)) }
                else { rigid.impactOccurred(intensity:CGFloat(impact)) }
            case let .enteredWater(strength): soft.impactOccurred(intensity:CGFloat(max(0.25,strength)))
            case .collectedCoin: soft.impactOccurred(intensity:0.4)
            case .collectedRelic: notification.notificationOccurred(.success)
            case .collectedCrystal: soft.impactOccurred(intensity:0.65)
            case .frozeWater: rigid.impactOccurred(intensity:0.5)
            case .hurt: rigid.impactOccurred(intensity:0.8)
            case .died: notification.notificationOccurred(.error)
            case .finished: notification.notificationOccurred(.success)
            }
        }
        #endif
    }
}
