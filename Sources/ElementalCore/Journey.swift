import Foundation

public enum SpeedMedal:Int,Codable,CaseIterable,Comparable {
    case none=0,bronze,silver,gold
    public static func <(a:Self,b:Self)->Bool { a.rawValue<b.rawValue }
    public var name:String { switch self { case .none:return "Без медали";case .bronze:return "Бронзовый маршрут";case .silver:return "Серебряный маршрут";case .gold:return "Золотой маршрут" } }
    public var reward:Int { [0,5,12,20][rawValue] }
}
public struct RouteTimes:Equatable {
    public let gold,silver,bronze:Double
    public init(_ gold:Double,_ silver:Double,_ bronze:Double) { self.gold=gold;self.silver=silver;self.bronze=bronze }
    public func medal(seconds:Double)->SpeedMedal {
        guard seconds.isFinite,seconds>=1 else { return .none }
        return seconds<=gold ? .gold : (seconds<=silver ? .silver : (seconds<=bronze ? .bronze : .none))
    }
}
public struct RunOutcome:Equatable {
    public let attemptID:UUID,map:WorldMap,seconds:Double?,standardPhysics:Bool,crystals:Int,coins:Int
    public init(attemptID:UUID,map:WorldMap,seconds:Double?,standardPhysics:Bool,crystals:Int,coins:Int) {
        self.attemptID=attemptID;self.map=map;self.seconds=seconds;self.standardPhysics=standardPhysics;self.crystals=crystals;self.coins=coins
    }
    public var isValid:Bool { (seconds.map { $0.isFinite && $0>=0 && $0<604800 } ?? true) && (0...map.definition.shards.count).contains(crystals) && (0...map.definition.coins.count).contains(coins) }
}
public struct FinishReceipt:Codable,Equatable,Identifiable {
    public var id:UUID { attemptID }
    public let attemptID:UUID,map:WorldMap,seconds:Double?,standardPhysics:Bool,medal:SpeedMedal,newBest:Bool
    public let crystals:Int,crystalTotal:Int,coins:Int,coinTotal:Int,aetherAward:Int,clearGold:Int,speedGold:Int
    public var goldAward:Int { clearGold+speedGold }
}
public struct RouteRecord:Codable,Equatable {
    public var bestTime:Double?,medal:SpeedMedal = .none,clearGoldClaimed=false
}
struct JourneyLedger:Codable,Equatable {
    var gold=0,claimedCoins:Set<String>=[],records:[String:RouteRecord]=[:],receipts:[FinishReceipt]=[]
    var isValid:Bool { gold>=0 && records.values.allSatisfy { $0.bestTime.map { $0.isFinite && $0>=1 && $0<604800 } ?? true } && receipts.count<=64 && Set(receipts.map(\.attemptID)).count==receipts.count }
}

public enum CampaignRoute {
    public static func next(_ map:WorldMap)->[WorldMap] {
        switch map {
        case .shore:return [.glacier,.forge]
        case .glacier:return [.meadow]
        case .forge:return [.grotto]
        case .meadow,.grotto:return [.windridge]
        case .windridge:return [.sanctuary]
        case .sanctuary:return []
        }
    }
    public static func available(_ map:WorldMap,completed:Set<WorldMap>)->Bool {
        map == .shore || completed.contains(map) || completed.contains { next($0).contains(map) }
    }
    public static func previous(_ map:WorldMap)->[WorldMap] { WorldMap.allCases.filter { next($0).contains(map) } }
}
