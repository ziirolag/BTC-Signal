import Foundation

// MARK: - Trade Mode

enum TradeMode: String, CaseIterable, Identifiable {
    case dayTrade = "Day Trade"
    case short    = "Short"
    case long     = "Long"

    var id: String { rawValue }

    var timeframes: [BinanceInterval] {
        switch self {
        case .dayTrade: return [.m15, .m5]
        case .short:    return [.h1, .m15]
        case .long:     return [.h4, .h1, .d1]
        }
    }

    var primaryInterval: BinanceInterval {
        switch self {
        case .dayTrade: return .m15
        case .short:    return .h1
        case .long:     return .h4
        }
    }

    var candleLimit: Int {
        switch self {
        case .dayTrade: return 100   // ~25 hours of 15m candles
        case .short:    return 72    // 3 days of 1h candles
        case .long:     return 90    // 15 days of 4h candles
        }
    }

    var icon: String {
        switch self {
        case .dayTrade: return "bolt.fill"
        case .short:    return "arrow.left.arrow.right"
        case .long:     return "arrow.up.forward.circle"
        }
    }

    var description: String {
        switch self {
        case .dayTrade: return "15m candles · Scalp / intraday"
        case .short:    return "1h candles · Hours to 1-2 days"
        case .long:     return "4h candles · Days to weeks"
        }
    }

    var holdTime: String {
        switch self {
        case .dayTrade: return "Minutes to hours"
        case .short:    return "Hours to 1-2 days"
        case .long:     return "Days to weeks"
        }
    }
}

// MARK: - Binance Intervals

enum BinanceInterval: String, CaseIterable {
    case m1  = "1m"
    case m5  = "5m"
    case m15 = "15m"
    case h1  = "1h"
    case h4  = "4h"
    case d1  = "1d"

    var displayName: String {
        switch self {
        case .m1:  return "1m"
        case .m5:  return "5m"
        case .m15: return "15m"
        case .h1:  return "1h"
        case .h4:  return "4h"
        case .d1:  return "1D"
        }
    }

    var seconds: Int {
        switch self {
        case .m1:  return 60
        case .m5:  return 300
        case .m15: return 900
        case .h1:  return 3600
        case .h4:  return 14400
        case .d1:  return 86400
        }
    }
}

// MARK: - Candle (with volume)

struct Candle: Identifiable {
    let id = UUID()
    let openTime: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double       // BTC volume
    let quoteVolume: Double  // USD volume
    let trades: Int          // number of trades
}

// MARK: - Price Point (legacy compat)

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

// MARK: - Order Book

struct OrderBook {
    let bids: [(price: Double, qty: Double)]  // sorted high to low
    let asks: [(price: Double, qty: Double)]  // sorted low to high
    let timestamp: Date

    var spread: Double {
        guard let bestAsk = asks.first?.price, let bestBid = bids.first?.price else { return 0 }
        return bestAsk - bestBid
    }

    var spreadPercent: Double {
        guard let mid = midPrice, mid > 0 else { return 0 }
        return (spread / mid) * 100
    }

    var midPrice: Double? {
        guard let bestAsk = asks.first?.price, let bestBid = bids.first?.price else { return nil }
        return (bestAsk + bestBid) / 2
    }

    /// Total bid vs ask volume within a % range from mid
    func imbalance(rangePercent: Double = 0.5) -> Double {
        guard let mid = midPrice else { return 0 }
        let range = mid * (rangePercent / 100)
        let bidVol = bids.filter { abs($0.price - mid) <= range }.reduce(0) { $0 + $1.qty }
        let askVol = asks.filter { abs($0.price - mid) <= range }.reduce(0) { $0 + $1.qty }
        let total = bidVol + askVol
        guard total > 0 else { return 0 }
        return (bidVol - askVol) / total  // -1 (all asks) to +1 (all bids)
    }

    /// Largest bid/ask walls (top 5 levels)
    var bidWalls: [(price: Double, qty: Double)] {
        Array(bids.sorted { $0.qty > $1.qty }.prefix(5))
    }

    var askWalls: [(price: Double, qty: Double)] {
        Array(asks.sorted { $0.qty > $1.qty }.prefix(5))
    }
}

// MARK: - Volume Analysis

struct VolumeAnalysis {
    let currentVolume: Double
    let avgVolume: Double         // 20-period average
    let volumeRatio: Double       // current / avg (>1.5 = high)
    let obv: Double               // On-Balance Volume
    let obvTrend: TrendDirection  // OBV direction
    let vwap: Double              // Volume Weighted Average Price
    let isVolumeSpike: Bool       // volume > 2x average
}

// MARK: - Entry/Exit Signal

struct EntryExitSignal {
    let direction: SignalType
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit1: Double
    let takeProfit2: Double
    let riskRewardRatio: Double   // TP distance / SL distance
    let positionSizePct: Double   // suggested % of portfolio
    let reasoning: [String]
    let urgency: Urgency

    var stopLossPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return ((stopLoss - entryPrice) / entryPrice) * 100
    }

    var takeProfit1Percent: Double {
        guard entryPrice > 0 else { return 0 }
        return ((takeProfit1 - entryPrice) / entryPrice) * 100
    }

    var takeProfit2Percent: Double {
        guard entryPrice > 0 else { return 0 }
        return ((takeProfit2 - entryPrice) / entryPrice) * 100
    }
}

// MARK: - Signal Types

enum SignalType: String, Equatable {
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

// MARK: - Trading Signal (expanded)

struct TradingSignal: Equatable {
    let signal: SignalType
    let confidence: Double
    let reasons: [String]
    let indicators: IndicatorValues
    let volumeAnalysis: VolumeAnalysis?
    let orderBookImbalance: Double?   // -1 to +1
    let entryExit: EntryExitSignal?
    let tradeMode: TradeMode
    let generatedAt: Date

    static func == (lhs: TradingSignal, rhs: TradingSignal) -> Bool {
        lhs.signal == rhs.signal && lhs.generatedAt == rhs.generatedAt
    }
}

// MARK: - Indicator Values (expanded)

struct IndicatorValues: Equatable {
    let sma7: Double
    let sma25: Double
    let rsi: Double
    let macdLine: Double
    let signalLine: Double
    let currentPrice: Double
    let priceChange24h: Double
    let atr: Double              // Average True Range (for SL/TP calc)
    let adx: Double              // Trend strength
    let stochasticK: Double
    let stochasticD: Double
    let bbUpper: Double
    let bbLower: Double
    let bbMiddle: Double
}

// MARK: - CoinGecko (legacy)

struct CoinGeckoPrice: Decodable {
    let prices: [[Double]]
}
