import Foundation

// MARK: - Technical Analysis Engine

class SignalEngine {

    /// Generate a trading signal from historical price data
    func analyze(prices: [PricePoint]) -> TradingSignal? {
        guard prices.count >= 26 else { return nil }

        let closes = prices.map { $0.price }
        let sma7  = calculateSMA(closes: closes, period: 7)
        let sma25 = calculateSMA(closes: closes, period: 25)
        let rsi   = calculateRSI(closes: closes, period: 14)
        let (macdLine, signalLine) = calculateMACD(closes: closes)

        let currentPrice = closes.last!
        let previousPrice = closes[closes.count - 2]
        let priceChange24h = ((currentPrice - previousPrice) / previousPrice) * 100

        let indicators = IndicatorValues(
            sma7: sma7,
            sma25: sma25,
            rsi: rsi,
            macdLine: macdLine,
            signalLine: signalLine,
            currentPrice: currentPrice,
            priceChange24h: priceChange24h
        )

        // Score each indicator
        var buyScore = 0
        var sellScore = 0
        var reasons: [String] = []

        // 1. SMA Crossover
        if sma7 > sma25 {
            buyScore += 2
            reasons.append("SMA7 above SMA25 (bullish)")
        } else {
            sellScore += 2
            reasons.append("SMA7 below SMA25 (bearish)")
        }

        // 2. RSI
        if rsi < 30 {
            buyScore += 2
            reasons.append("RSI \(Int(rsi)) — oversold territory")
        } else if rsi < 40 {
            buyScore += 1
            reasons.append("RSI \(Int(rsi)) — approaching oversold")
        } else if rsi > 70 {
            sellScore += 2
            reasons.append("RSI \(Int(rsi)) — overbought territory")
        } else if rsi > 60 {
            sellScore += 1
            reasons.append("RSI \(Int(rsi)) — approaching overbought")
        } else {
            reasons.append("RSI \(Int(rsi)) — neutral zone")
        }

        // 3. MACD
        if macdLine > signalLine {
            buyScore += 2
            reasons.append("MACD above signal line (bullish)")
        } else {
            sellScore += 2
            reasons.append("MACD below signal line (bearish)")
        }

        // 4. Price momentum (last 3 candles direction)
        let recentPrices = Array(closes.suffix(4))
        let momentum = recentPrices.last! - recentPrices.first!
        if momentum > 0 {
            buyScore += 1
            reasons.append("Positive short-term momentum")
        } else {
            sellScore += 1
            reasons.append("Negative short-term momentum")
        }

        // Determine signal
        let totalScore = buyScore + sellScore
        let netScore = Double(buyScore - sellScore)
        let confidence = (abs(netScore) / Double(totalScore)) * 100

        let signal: SignalType
        if netScore >= 5 {
            signal = .strongBuy
        } else if netScore >= 2 {
            signal = .buy
        } else if netScore <= -5 {
            signal = .strongSell
        } else if netScore <= -2 {
            signal = .sell
        } else {
            signal = .hold
        }

        return TradingSignal(
            signal: signal,
            confidence: min(confidence, 95),
            reasons: reasons,
            indicators: indicators,
            generatedAt: Date()
        )
    }

    // MARK: - Indicators

    private func calculateSMA(closes: [Double], period: Int) -> Double {
        let slice = Array(closes.suffix(period))
        return slice.reduce(0, +) / Double(slice.count)
    }

    private func calculateRSI(closes: [Double], period: Int) -> Double {
        let slice = Array(closes.suffix(period + 1))
        var gains = 0.0
        var losses = 0.0

        for i in 1..<slice.count {
            let change = slice[i] - slice[i - 1]
            if change > 0 {
                gains += change
            } else {
                losses += abs(change)
            }
        }

        let avgGain = gains / Double(period)
        let avgLoss = losses / Double(period)

        guard avgLoss > 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }

    private func calculateEMA(closes: [Double], period: Int) -> [Double] {
        let multiplier = 2.0 / Double(period + 1)
        var ema: [Double] = []

        // First EMA = SMA
        let firstSMA = Array(closes.prefix(period)).reduce(0, +) / Double(period)
        ema.append(firstSMA)

        for i in period..<closes.count {
            let value = (closes[i] - ema.last!) * multiplier + ema.last!
            ema.append(value)
        }
        return ema
    }

    private func calculateMACD(closes: [Double]) -> (Double, Double) {
        let ema12 = calculateEMA(closes: closes, period: 12)
        let ema26 = calculateEMA(closes: closes, period: 26)

        // Align lengths
        let offset = ema12.count - ema26.count
        let aligned12 = Array(ema12.suffix(ema26.count))

        let macdLine = zip(aligned12, ema26).map { $0.0 - $0.1 }
        let signalLine = calculateEMA(closes: macdLine, period: 9)

        return (macdLine.last ?? 0, signalLine.last ?? 0)
    }
}
