import Foundation

// MARK: - Data Models

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

enum SignalType: String {
    case strongBuy  = "STRONG BUY"
    case buy        = "BUY"
    case hold       = "HOLD"
    case sell       = "SELL"
    case strongSell = "STRONG SELL"

    var emoji: String {
        switch self {
        case .strongBuy:  return "🟢🟢"
        case .buy:        return "🟢"
        case .hold:       return "🟡"
        case .sell:       return "🔴"
        case .strongSell: return "🔴🔴"
        }
    }

    var color: String {
        switch self {
        case .strongBuy, .buy: return "green"
        case .hold:            return "yellow"
        case .sell, .strongSell: return "red"
        }
    }
}

struct TradingSignal {
    let signal: SignalType
    let confidence: Double      // 0-100
    let reasons: [String]
    let indicators: IndicatorValues
    let generatedAt: Date
}

struct IndicatorValues {
    let sma7: Double
    let sma25: Double
    let rsi: Double
    let macdLine: Double
    let signalLine: Double
    let currentPrice: Double
    let priceChange24h: Double
}

struct CoinGeckoPrice: Decodable {
    let prices: [[Double]]
}
