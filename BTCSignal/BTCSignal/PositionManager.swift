import Foundation

// MARK: - Position Tracking

struct Position: Codable, Identifiable {
    let id: UUID
    var entryPrice: Double       // Price when position was opened
    var amountBTC: Double        // How much BTC
    var amountUSD: Double        // How much USD invested
    var entryDate: Date
    var type: PositionType
    var notes: String

    var currentValue: Double {
        amountBTC * (PriceCache.lastPrice ?? entryPrice)
    }

    var pnl: Double {
        currentValue - amountUSD
    }

    var pnlPercent: Double {
        guard amountUSD > 0 else { return 0 }
        return (pnl / amountUSD) * 100
    }

    var currentPrice: Double {
        PriceCache.lastPrice ?? entryPrice
    }

    var isInProfit: Bool { pnl >= 0 }
}

enum PositionType: String, Codable, CaseIterable {
    case long = "Long"
    case short = "Short"

    var emoji: String {
        switch self {
        case .long: return "📈"
        case .short: return "📉"
        }
    }
}

// MARK: - Price Cache (shared across app)

class PriceCache {
    static var lastPrice: Double?
}

// MARK: - Position Manager

class PositionManager: ObservableObject {
    @Published var positions: [Position] = []

    private let saveKey = "btc_positions"

    init() {
        load()
    }

    // MARK: - CRUD

    func addPosition(entryPrice: Double, amountBTC: Double, type: PositionType, notes: String = "") {
        let position = Position(
            id: UUID(),
            entryPrice: entryPrice,
            amountBTC: amountBTC,
            amountUSD: amountBTC * entryPrice,
            entryDate: Date(),
            type: type,
            notes: notes
        )
        positions.append(position)
        save()
    }

    func removePosition(at offsets: IndexSet) {
        positions.remove(atOffsets: offsets)
        save()
    }

    func removePosition(id: UUID) {
        positions.removeAll { $0.id == id }
        save()
    }

    // MARK: - Portfolio Summary

    var totalInvested: Double {
        positions.reduce(0) { $0 + $1.amountUSD }
    }

    var totalCurrentValue: Double {
        positions.reduce(0) { $0 + $1.currentValue }
    }

    var totalPnL: Double {
        totalCurrentValue - totalInvested
    }

    var totalPnLPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalPnL / totalInvested) * 100
    }

    var totalBTC: Double {
        positions.reduce(0) { $0 + $1.amountBTC }
    }

    // MARK: - Position-Based Signals

    func positionSignals(marketSignal: TradingSignal?) -> [PositionSignal] {
        guard let market = marketSignal else { return [] }

        return positions.map { pos in
            let currentPrice = pos.currentPrice
            let entryDiff = ((currentPrice - pos.entryPrice) / pos.entryPrice) * 100

            var recommendations: [String] = []
            var urgency: Urgency = .low

            // Profit/Loss analysis
            if pos.type == .long {
                if entryDiff > 15 {
                    recommendations.append("Up \(String(format: "%.1f", entryDiff))% from entry — consider taking partial profit (25-50%)")
                    urgency = .high
                } else if entryDiff > 8 {
                    recommendations.append("Up \(String(format: "%.1f", entryDiff))% — move stop-loss to breakeven")
                    urgency = .medium
                } else if entryDiff > 3 {
                    recommendations.append("Up \(String(format: "%.1f", entryDiff))% — position healthy, hold")
                } else if entryDiff < -10 {
                    recommendations.append("Down \(String(format: "%.1f", abs(entryDiff)))% — consider cutting loss or averaging down")
                    urgency = .critical
                } else if entryDiff < -5 {
                    recommendations.append("Down \(String(format: "%.1f", abs(entryDiff)))% — set stop-loss at -10%")
                    urgency = .high
                } else if entryDiff < -2 {
                    recommendations.append("Down \(String(format: "%.1f", abs(entryDiff)))% — minor drawdown, monitor closely")
                    urgency = .medium
                }
            }

            // Market signal overlay
            if market.signal == .sell || market.signal == .strongSell {
                if pos.type == .long && entryDiff > 0 {
                    recommendations.append("⚠️ Market signal is SELL while you're in profit — strongly consider closing")
                    urgency = .critical
                } else if pos.type == .long && entryDiff < 0 {
                    recommendations.append("⚠️ Market SELL signal + position underwater — evaluate stop-loss")
                    urgency = .critical
                }
            } else if market.signal == .buy || market.signal == .strongBuy {
                if entryDiff < -5 {
                    recommendations.append("Market BUY signal while position is down — potential averaging opportunity")
                }
            }

            // RSI-based
            if market.indicators.rsi > 70 && entryDiff > 5 {
                recommendations.append("RSI overbought + in profit — high-probability exit zone")
                urgency = .high
            } else if market.indicators.rsi < 30 && entryDiff < -5 {
                recommendations.append("RSI oversold + position down — reversal may be near, consider holding")
            }

            // Bollinger
            // Price near upper band + in profit = take profit signal
            // Price near lower band + down = potential bounce

            return PositionSignal(
                position: pos,
                entryDifference: entryDiff,
                recommendations: recommendations,
                urgency: urgency
            )
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Position].self, from: data) {
            positions = decoded
        }
    }
}

// MARK: - Position Signal

struct PositionSignal: Identifiable {
    let id = UUID()
    let position: Position
    let entryDifference: Double  // % from entry
    let recommendations: [String]
    let urgency: Urgency
}

enum Urgency: String {
    case low = "Monitor"
    case medium = "Watch"
    case high = "Act"
    case critical = "Urgent"

    var emoji: String {
        switch self {
        case .low: return "👁"
        case .medium: return "⚡"
        case .high: return "🔥"
        case .critical: return "🚨"
        }
    }

    var color: String {
        switch self {
        case .low: return "btcSubtext"
        case .medium: return "btcYellow"
        case .high: return "btcOrange"
        case .critical: return "btcRed"
        }
    }
}
