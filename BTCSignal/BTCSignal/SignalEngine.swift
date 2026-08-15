import Foundation

// MARK: - Technical Analysis Engine v2

class SignalEngine {

    var minimumDataPoints: Int { 26 }

    func analyze(prices: [PricePoint]) -> TradingSignal? {
        guard prices.count >= minimumDataPoints else { return nil }

        let closes = prices.map { $0.price }
        let currentPrice = closes.last!
        let previousPrice = closes[closes.count - 2]
        let priceChange24h = ((currentPrice - previousPrice) / previousPrice) * 100

        // === INDICATOR CALCULATIONS ===

        let sma7  = calcSMA(closes, 7)
        let sma25 = calcSMA(closes, 25)
        let ema12 = calcEMA(closes, 12)
        let ema26 = calcEMA(closes, 26)
        let rsi = calcRSI(closes, 14)
        let (macdLine, signalLine, histogram) = calcMACD(closes)
        let (stochK, stochD) = calcStochastic(closes, kPeriod: 14, dPeriod: 3)
        let (bbUpper, bbMiddle, bbLower) = calcBollingerBands(closes, period: 20, stdDev: 2.0)
        let atr = calcATR(closes, period: 14)
        let adx = calcADX(closes, period: 14)
        let vwap = calcVWAP(closes)
        let (support, resistance) = findSupportResistance(closes)

        let indicators = IndicatorValues(
            sma7: sma7,
            sma25: sma25,
            rsi: rsi,
            macdLine: macdLine,
            signalLine: signalLine,
            currentPrice: currentPrice,
            priceChange24h: priceChange24h
        )

        // === SCORING ENGINE ===

        var buyScore: Double = 0
        var sellScore: Double = 0
        var reasons: [String] = []
        var confluenceCount = 0  // how many independent systems agree

        // -----------------------------------------------
        // 1. TREND (SMA Crossover + EMA confirmation)
        // -----------------------------------------------
        let smaSignal = sma7 > sma25
        let emaSignal = (ema12.last ?? 0) > (ema26.last ?? 0)
        if smaSignal && emaSignal {
            buyScore += 3
            confluenceCount += 1
            reasons.append("Both SMA and EMA confirm uptrend — strong trend alignment")
        } else if !smaSignal && !emaSignal {
            sellScore += 3
            confluenceCount += 1
            reasons.append("Both SMA and EMA confirm downtrend — strong bearish alignment")
        } else if smaSignal {
            buyScore += 1
            reasons.append("SMA bullish but EMA lagging — weak uptrend")
        } else {
            sellScore += 1
            reasons.append("SMA bearish but EMA lagging — weak downtrend")
        }

        // Price position relative to MAs
        let priceVsSMA25 = ((currentPrice - sma25) / sma25) * 100
        if priceVsSMA25 > 3 && priceVsSMA25 < 10 {
            buyScore += 1
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% above SMA25 — healthy uptrend")
        } else if priceVsSMA25 > 10 {
            sellScore += 1.5
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% above SMA25 — stretched, may revert")
        } else if priceVsSMA25 < -3 && priceVsSMA25 > -10 {
            sellScore += 1
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% below SMA25 — bearish")
        } else if priceVsSMA25 < -10 {
            buyScore += 1.5
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% below SMA25 — oversold, potential bounce")
        }

        // -----------------------------------------------
        // 2. MOMENTUM (RSI + Stochastic)
        // -----------------------------------------------
        let rsiBuy = rsi < 30
        let rsiSell = rsi > 70
        let stochBuy = stochK < 20 && stochK > stochD  // oversold + turning up
        let stochSell = stochK > 80 && stochK < stochD  // overbought + turning down

        if rsiBuy && stochBuy {
            buyScore += 3
            confluenceCount += 1
            reasons.append("RSI \(Int(rsi)) + Stochastic both oversold — high-probability reversal zone")
        } else if rsiSell && stochSell {
            sellScore += 3
            confluenceCount += 1
            reasons.append("RSI \(Int(rsi)) + Stochastic both overbought — high-probability pullback zone")
        } else if rsiBuy {
            buyScore += 2
            reasons.append("RSI \(Int(rsi)) — oversold, waiting for Stochastic confirmation")
        } else if rsiSell {
            sellScore += 2
            reasons.append("RSI \(Int(rsi)) — overbought, waiting for Stochastic confirmation")
        } else if rsi < 45 {
            buyScore += 0.5
            reasons.append("RSI \(Int(rsi)) — leaning slightly bullish")
        } else if rsi > 55 {
            sellScore += 0.5
            reasons.append("RSI \(Int(rsi)) — leaning slightly bearish")
        } else {
            reasons.append("RSI \(Int(rsi)) — neutral, no edge")
        }

        // Stochastic crossover
        if stochK > stochD && stochK < 30 {
            buyScore += 1
            reasons.append("Stochastic bullish crossover in oversold zone")
        } else if stochK < stochD && stochK > 70 {
            sellScore += 1
            reasons.append("Stochastic bearish crossover in overbought zone")
        }

        // -----------------------------------------------
        // 3. MACD (Line + Signal + Histogram momentum)
        // -----------------------------------------------
        if !macdLine.isNaN && !signalLine.isNaN && !histogram.isNaN {
            let macdBullish = macdLine > signalLine
            let histogramGrowing = histogram > 0

            if macdBullish && histogramGrowing {
                buyScore += 2.5
                confluenceCount += 1
                reasons.append("MACD bullish with growing histogram — accelerating momentum")
            } else if !macdBullish && !histogramGrowing {
                sellScore += 2.5
                confluenceCount += 1
                reasons.append("MACD bearish with declining histogram — momentum fading")
            } else if macdBullish {
                buyScore += 1.5
                reasons.append("MACD above signal but histogram flat — momentum slowing")
            } else {
                sellScore += 1.5
                reasons.append("MACD below signal but histogram flat — selling pressure easing")
            }

            // MACD zero-line cross (strong signal)
            if macdLine > 0 && signalLine > 0 {
                buyScore += 1
                reasons.append("MACD above zero line — trend is bullish on larger timeframe")
            } else if macdLine < 0 && signalLine < 0 {
                sellScore += 1
                reasons.append("MACD below zero line — trend is bearish on larger timeframe")
            }
        }

        // -----------------------------------------------
        // 4. BOLLINGER BANDS (Volatility + Mean Reversion)
        // -----------------------------------------------
        let bbPosition = (currentPrice - bbLower) / (bbUpper - bbLower)  // 0 = at lower, 1 = at upper
        let bbWidth = (bbUpper - bbLower) / bbMiddle * 100  // bandwidth as %

        if bbPosition < 0.05 {
            buyScore += 2.5
            confluenceCount += 1
            reasons.append("Price at lower Bollinger Band — extreme oversold, bounce likely")
        } else if bbPosition < 0.2 {
            buyScore += 1.5
            reasons.append("Price near lower Bollinger Band — approaching support")
        } else if bbPosition > 0.95 {
            sellScore += 2.5
            confluenceCount += 1
            reasons.append("Price at upper Bollinger Band — extreme overbought, pullback likely")
        } else if bbPosition > 0.8 {
            sellScore += 1.5
            reasons.append("Price near upper Bollinger Band — approaching resistance")
        }

        // Bollinger Squeeze (low volatility → big move coming)
        if bbWidth < 3 {
            reasons.append("Bollinger squeeze detected — volatility expansion imminent (direction unclear)")
        }

        // -----------------------------------------------
        // 5. TREND STRENGTH (ADX filter)
        // -----------------------------------------------
        // ADX tells us if the market is trending or choppy
        // High ADX (>25) = trending, signals are reliable
        // Low ADX (<20) = choppy, signals are noise
        let trendStrength: Double
        if adx > 30 {
            trendStrength = 1.3  // boost signals
            reasons.append("ADX \(Int(adx)) — strong trend, signals amplified")
        } else if adx > 25 {
            trendStrength = 1.1
            reasons.append("ADX \(Int(adx)) — moderate trend")
        } else if adx > 20 {
            trendStrength = 0.9  // dampen signals
            reasons.append("ADX \(Int(adx)) — weak trend, signals dampened")
        } else {
            trendStrength = 0.6  // heavily dampen
            reasons.append("ADX \(Int(adx)) — choppy/ranging market, signals unreliable")
        }

        buyScore *= trendStrength
        sellScore *= trendStrength

        // -----------------------------------------------
        // 6. SUPPORT / RESISTANCE proximity
        // -----------------------------------------------
        let distToSupport = ((currentPrice - support) / currentPrice) * 100
        let distToResistance = ((resistance - currentPrice) / currentPrice) * 100

        if distToSupport < 2 && distToSupport >= 0 {
            buyScore += 1.5
            reasons.append("Price \(String(format: "%.1f", distToSupport))% above support at \(formatUSD(support)) — bounce zone")
        } else if distToResistance < 2 && distToResistance >= 0 {
            sellScore += 1.5
            reasons.append("Price \(String(format: "%.1f", distToResistance))% below resistance at \(formatUSD(resistance)) — rejection zone")
        }

        // -----------------------------------------------
        // 7. MOMENTUM (multi-period)
        // -----------------------------------------------
        let mom5 = momentum(closes, 5)
        let mom10 = momentum(closes, 10)

        if mom5 > 0 && mom10 > 0 {
            buyScore += 1.5
            confluenceCount += 1
            reasons.append("Both 5-day and 10-day momentum positive — sustained buying")
        } else if mom5 < 0 && mom10 < 0 {
            sellScore += 1.5
            confluenceCount += 1
            reasons.append("Both 5-day and 10-day momentum negative — sustained selling")
        } else if mom5 > 0 && mom10 < 0 {
            reasons.append("Short-term bounce but longer-term still bearish — caution")
        } else {
            reasons.append("Short-term weakness but longer-term still bullish — noise")
        }

        // ===============================================
        // FINAL SIGNAL DETERMINATION
        // ===============================================

        let totalScore = buyScore + sellScore
        let netScore = buyScore - sellScore
        let rawConfidence = totalScore > 0 ? (abs(netScore) / totalScore) * 100 : 50

        // Confluence bonus: more independent systems agreeing = higher confidence
        let confluenceBonus = Double(confluenceCount) * 5.0
        let confidence = min(rawConfidence + confluenceBonus, 95)

        // Signal thresholds — higher bar for action (reduce false signals)
        let signal: SignalType
        if netScore >= 6 && confluenceCount >= 3 {
            signal = .strongBuy
        } else if netScore >= 3 && confluenceCount >= 2 {
            signal = .buy
        } else if netScore <= -6 && confluenceCount >= 3 {
            signal = .strongSell
        } else if netScore <= -3 && confluenceCount >= 2 {
            signal = .sell
        } else {
            signal = .hold
        }

        return TradingSignal(
            signal: signal,
            confidence: confidence,
            reasons: reasons,
            indicators: indicators,
            generatedAt: Date()
        )
    }

    // MARK: - Core Indicators

    private func calcSMA(_ closes: [Double], _ period: Int) -> Double {
        guard period > 0, closes.count >= period else { return closes.last ?? 0 }
        return Array(closes.suffix(period)).reduce(0, +) / Double(period)
    }

    private func calcEMA(_ closes: [Double], _ period: Int) -> [Double] {
        guard closes.count >= period, period > 0 else { return [] }
        let k = 2.0 / Double(period + 1)
        var ema = [Array(closes.prefix(period)).reduce(0, +) / Double(period)]
        for i in period..<closes.count {
            ema.append(closes[i] * k + ema.last! * (1 - k))
        }
        return ema
    }

    private func calcRSI(_ closes: [Double], _ period: Int) -> Double {
        guard period > 0, closes.count > period else { return 50 }
        let slice = Array(closes.suffix(period + 1))
        var gains = 0.0, losses = 0.0
        for i in 1..<slice.count {
            let d = slice[i] - slice[i - 1]
            if d > 0 { gains += d } else { losses += abs(d) }
        }
        let avgG = gains / Double(period)
        let avgL = losses / Double(period)
        guard avgL > 0 else { return 100 }
        return 100 - (100 / (1 + avgG / avgL))
    }

    private func calcMACD(_ closes: [Double]) -> (Double, Double, Double) {
        let ema12 = calcEMA(closes, 12)
        let ema26 = calcEMA(closes, 26)
        guard !ema12.isEmpty, !ema26.isEmpty else { return (.nan, .nan, .nan) }

        let count = min(ema12.count, ema26.count)
        let macdLine = zip(Array(ema12.suffix(count)), Array(ema26.suffix(count))).map { $0.0 - $0.1 }
        guard macdLine.count >= 9 else { return (macdLine.last ?? 0, .nan, .nan) }

        let signalArr = calcEMA(macdLine, 9)
        let signal = signalArr.last ?? .nan
        let histogram = (macdLine.last ?? 0) - signal
        return (macdLine.last ?? 0, signal, histogram)
    }

    private func calcStochastic(_ closes: [Double], kPeriod: Int, dPeriod: Int) -> (Double, Double) {
        guard closes.count >= kPeriod else { return (50, 50) }
        let slice = Array(closes.suffix(kPeriod))
        let high = slice.max()!
        let low = slice.min()!
        let k = high != low ? ((closes.last! - low) / (high - low)) * 100 : 50

        // %D = SMA of %K (simplified: use current K for single-point D)
        // In practice with daily data, D ≈ K smoothed
        let d = k  // simplified — in full implementation you'd track K history
        return (k, d)
    }

    private func calcBollingerBands(_ closes: [Double], period: Int, stdDev: Double) -> (Double, Double, Double) {
        guard closes.count >= period else {
            let p = closes.last ?? 0
            return (p, p, p)
        }
        let slice = Array(closes.suffix(period))
        let sma = slice.reduce(0, +) / Double(period)
        let variance = slice.map { ($0 - sma) * ($0 - sma) }.reduce(0, +) / Double(period)
        let sd = sqrt(variance)
        return (sma + stdDev * sd, sma, sma - stdDev * sd)
    }

    private func calcATR(_ closes: [Double], period: Int) -> Double {
        guard closes.count > period else { return 0 }
        var trueRanges: [Double] = []
        for i in 1..<closes.count {
            let high = max(closes[i], closes[i - 1])
            let low = min(closes[i], closes[i - 1])
            trueRanges.append(high - low)
        }
        return Array(trueRanges.suffix(period)).reduce(0, +) / Double(period)
    }

    private func calcADX(_ closes: [Double], period: Int) -> Double {
        // Simplified ADX: measures trend strength using directional movement
        guard closes.count > period + 1 else { return 25 }
        var plusDM: [Double] = []
        var minusDM: [Double] = []

        for i in 1..<closes.count {
            let up = closes[i] - closes[i - 1]
            let down = closes[i - 1] - closes[i]
            plusDM.append(up > down && up > 0 ? up : 0)
            minusDM.append(down > up && down > 0 ? down : 0)
        }

        let avgPlus = Array(plusDM.suffix(period)).reduce(0, +) / Double(period)
        let avgMinus = Array(minusDM.suffix(period)).reduce(0, +) / Double(period)
        let atr = calcATR(closes, period: period)
        guard atr > 0 else { return 25 }

        let diPlus = (avgPlus / atr) * 100
        let diMinus = (avgMinus / atr) * 100
        let diSum = diPlus + diMinus
        guard diSum > 0 else { return 25 }
        let dx = abs(diPlus - diMinus) / diSum * 100
        return dx
    }

    private func calcVWAP(_ closes: [Double]) -> Double {
        // Simplified VWAP proxy: volume-weighted average (using price as proxy for volume)
        // Real VWAP needs volume data, this is a trend-weighted average instead
        let period = min(20, closes.count)
        let slice = Array(closes.suffix(period))
        var weightedSum = 0.0
        var weightTotal = 0.0
        for (i, price) in slice.enumerated() {
            let weight = Double(i + 1)  // more recent = heavier weight
            weightedSum += price * weight
            weightTotal += weight
        }
        return weightedSum / weightTotal
    }

    private func findSupportResistance(_ closes: [Double]) -> (Double, Double) {
        // Find recent swing lows (support) and swing highs (resistance)
        let lookback = min(20, closes.count)
        let slice = Array(closes.suffix(lookback))
        let recentLow = slice.min()!
        let recentHigh = slice.max()!

        // Adjust: support is slightly below recent low, resistance slightly above recent high
        let atr = calcATR(closes, period: 14)
        let support = recentLow - atr * 0.2
        let resistance = recentHigh + atr * 0.2
        return (support, resistance)
    }

    private func momentum(_ closes: [Double], _ period: Int) -> Double {
        guard closes.count > period else { return 0 }
        return closes.last! - closes[closes.count - period - 1]
    }

    private func formatUSD(_ value: Double) -> String {
        if value >= 1000 { return "$\(Int(value))" }
        return "$\(String(format: "%.2f", value))"
    }
}
