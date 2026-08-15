import Foundation

// MARK: - Technical Analysis Engine

class SignalEngine {

    /// Minimum data points needed for all indicators
    var minimumDataPoints: Int { 20 }

    /// Generate a trading signal from historical price data
    func analyze(prices: [PricePoint]) -> TradingSignal? {
        guard prices.count >= minimumDataPoints else { return nil }

        let closes = prices.map { $0.price }
        let currentPrice = closes.last!
        let previousPrice = closes[closes.count - 2]
        let priceChange24h = ((currentPrice - previousPrice) / previousPrice) * 100

        // SMA — always works if we have enough points
        let sma7  = calculateSMA(closes: closes, period: min(7, closes.count))
        let sma25 = calculateSMA(closes: closes, period: min(25, closes.count))

        // RSI — works with any data length
        let rsiPeriod = min(14, closes.count - 1)
        let rsi = calculateRSI(closes: closes, period: rsiPeriod)

        // MACD — use shorter periods if data is limited
        let (macdLine, signalLine) = calculateMACD(closes: closes)

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
            reasons.append("Short-term average (\(formatUSD(sma7))) above long-term (\(formatUSD(sma25))) — uptrend")
        } else {
            sellScore += 2
            reasons.append("Short-term average (\(formatUSD(sma7))) below long-term (\(formatUSD(sma25))) — downtrend")
        }

        // 2. RSI
        if rsi < 30 {
            buyScore += 2
            reasons.append("RSI at \(Int(rsi)) — deeply oversold, potential bounce")
        } else if rsi < 40 {
            buyScore += 1
            reasons.append("RSI at \(Int(rsi)) — approaching oversold territory")
        } else if rsi > 70 {
            sellScore += 2
            reasons.append("RSI at \(Int(rsi)) — overbought, may pull back")
        } else if rsi > 60 {
            sellScore += 1
            reasons.append("RSI at \(Int(rsi)) — approaching overbought")
        } else {
            reasons.append("RSI at \(Int(rsi)) — neutral zone, no strong signal")
        }

        // 3. MACD (only if we have valid values)
        if !macdLine.isNaN && !signalLine.isNaN {
            if macdLine > signalLine {
                buyScore += 2
                reasons.append("MACD bullish crossover — momentum shifting up")
            } else {
                sellScore += 2
                reasons.append("MACD bearish crossover — momentum shifting down")
            }
        } else {
            reasons.append("MACD — insufficient data for reliable reading")
        }

        // 4. Price momentum (last 5 candles)
        let lookback = min(5, closes.count - 1)
        let recentPrices = Array(closes.suffix(lookback + 1))
        let momentum = recentPrices.last! - recentPrices.first!
        let momentumPct = (momentum / recentPrices.first!) * 100
        if momentum > 0 {
            buyScore += 1
            reasons.append("Short-term momentum +\(String(format: "%.1f", momentumPct))% — rising")
        } else {
            sellScore += 1
            reasons.append("Short-term momentum \(String(format: "%.1f", momentumPct))% — falling")
        }

        // 5. Price vs SMA25 (mean reversion signal)
        let priceVsSMA = ((currentPrice - sma25) / sma25) * 100
        if priceVsSMA < -5 {
            buyScore += 1
            reasons.append("Price \(String(format: "%.1f", abs(priceVsSMA)))% below average — potential value")
        } else if priceVsSMA > 5 {
            sellScore += 1
            reasons.append("Price \(String(format: "%.1f", priceVsSMA))% above average — extended")
        }

        // Determine signal
        let totalScore = buyScore + sellScore
        let netScore = Double(buyScore - sellScore)
        let confidence = totalScore > 0 ? (abs(netScore) / Double(totalScore)) * 100 : 50

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
        guard period > 0, closes.count >= period else { return closes.last ?? 0 }
        let slice = Array(closes.suffix(period))
        return slice.reduce(0, +) / Double(slice.count)
    }

    private func calculateRSI(closes: [Double], period: Int) -> Double {
        guard period > 0, closes.count > period else { return 50 }
        let slice = Array(closes.suffix(period + 1))
        var gains = 0.0
        var losses = 0.0

        for i in 1..<slice.count {
            let change = slice[i] - slice[i - 1]
            if change > 0 { gains += change }
            else { losses += abs(change) }
        }

        let avgGain = gains / Double(period)
        let avgLoss = losses / Double(period)

        guard avgLoss > 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }

    private func calculateEMA(closes: [Double], period: Int) -> [Double] {
        guard closes.count >= period, period > 0 else { return [] }
        let multiplier = 2.0 / Double(period + 1)
        var ema: [Double] = []

        // First EMA = SMA of first `period` values
        let firstSMA = Array(closes.prefix(period)).reduce(0, +) / Double(period)
        ema.append(firstSMA)

        for i in period..<closes.count {
            let value = (closes[i] - ema.last!) * multiplier + ema.last!
            ema.append(value)
        }
        return ema
    }

    private func calculateMACD(closes: [Double]) -> (Double, Double) {
        // Adaptive: use shorter periods if data is limited
        let fastPeriod = min(12, closes.count / 3)
        let slowPeriod = min(26, closes.count / 2)
        let signalPeriod = min(9, max(3, closes.count / 4))

        guard fastPeriod > 0, slowPeriod > 0, closes.count >= slowPeriod else {
            return (.nan, .nan)
        }

        let emaFast = calculateEMA(closes: closes, period: fastPeriod)
        let emaSlow = calculateEMA(closes: closes, period: slowPeriod)

        guard !emaFast.isEmpty, !emaSlow.isEmpty else { return (.nan, .nan) }

        // Align to shorter
        let count = min(emaFast.count, emaSlow.count)
        let alignedFast = Array(emaFast.suffix(count))
        let alignedSlow = Array(emaSlow.suffix(count))

        let macdLine = zip(alignedFast, alignedSlow).map { $0.0 - $0.1 }
        guard macdLine.count >= signalPeriod else { return (macdLine.last ?? 0, .nan) }

        let signalArr = calculateEMA(closes: macdLine, period: signalPeriod)
        return (macdLine.last ?? 0, signalArr.last ?? .nan)
    }

    private func formatUSD(_ value: Double) -> String {
        if value >= 1000 { return "$\(Int(value))" }
        return "$\(String(format: "%.2f", value))"
    }
}
