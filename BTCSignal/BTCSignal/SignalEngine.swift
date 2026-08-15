import Foundation

// MARK: - Signal Engine v2 — Multi-Timeframe, Volume, Order Book, Entry/Exit

class SignalEngine {

    var minimumDataPoints: Int { 26 }

    // MARK: - Main Analysis

    func analyze(candles: [Candle], orderBook: OrderBook?, mode: TradeMode) -> TradingSignal? {
        guard candles.count >= minimumDataPoints else { return nil }

        let closes = candles.map { $0.close }
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }
        let volumes = candles.map { $0.volume }
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
        let atr = calcATR(highs: highs, lows: lows, closes: closes, period: 14)
        let adx = calcADX(highs: highs, lows: lows, closes: closes, period: 14)

        let indicators = IndicatorValues(
            sma7: sma7, sma25: sma25, rsi: rsi,
            macdLine: macdLine, signalLine: signalLine,
            currentPrice: currentPrice, priceChange24h: priceChange24h,
            atr: atr, adx: adx,
            stochasticK: stochK, stochasticD: stochD,
            bbUpper: bbUpper, bbLower: bbLower, bbMiddle: bbMiddle
        )

        // === VOLUME ANALYSIS ===

        let volumeAnalysis = analyzeVolume(candles: candles, closes: closes, volumes: volumes)

        // === ORDER BOOK ===

        let orderBookImbalance = orderBook?.imbalance(rangePercent: 0.5)

        // === SCORING ENGINE ===

        var buyScore: Double = 0
        var sellScore: Double = 0
        var reasons: [String] = []
        var confluenceCount = 0

        // 1. TREND (SMA + EMA)
        let smaSignal = sma7 > sma25
        let emaSignal = (ema12.last ?? 0) > (ema26.last ?? 0)
        if smaSignal && emaSignal {
            buyScore += 3; confluenceCount += 1
            reasons.append("SMA + EMA confirm uptrend")
        } else if !smaSignal && !emaSignal {
            sellScore += 3; confluenceCount += 1
            reasons.append("SMA + EMA confirm downtrend")
        } else if smaSignal {
            buyScore += 1; reasons.append("SMA bullish, EMA lagging — weak uptrend")
        } else {
            sellScore += 1; reasons.append("SMA bearish, EMA lagging — weak downtrend")
        }

        // Price vs SMA25
        let priceVsSMA25 = ((currentPrice - sma25) / sma25) * 100
        if priceVsSMA25 > 3 && priceVsSMA25 < 10 {
            buyScore += 1
            reasons.append("Price +\(String(format: "%.1f", priceVsSMA25))% above SMA25")
        } else if priceVsSMA25 > 10 {
            sellScore += 1.5
            reasons.append("Price +\(String(format: "%.1f", priceVsSMA25))% above SMA25 — stretched")
        } else if priceVsSMA25 < -3 && priceVsSMA25 > -10 {
            sellScore += 1
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% below SMA25")
        } else if priceVsSMA25 < -10 {
            buyScore += 1.5
            reasons.append("Price \(String(format: "%.1f", priceVsSMA25))% below SMA25 — oversold bounce zone")
        }

        // 2. MOMENTUM (RSI + Stochastic)
        if rsi < 30 && stochK < 20 && stochK > stochD {
            buyScore += 3; confluenceCount += 1
            reasons.append("RSI \(Int(rsi)) + Stochastic both oversold — reversal zone")
        } else if rsi > 70 && stochK > 80 && stochK < stochD {
            sellScore += 3; confluenceCount += 1
            reasons.append("RSI \(Int(rsi)) + Stochastic both overbought — pullback zone")
        } else if rsi < 30 {
            buyScore += 2; reasons.append("RSI \(Int(rsi)) — oversold")
        } else if rsi > 70 {
            sellScore += 2; reasons.append("RSI \(Int(rsi)) — overbought")
        } else if rsi < 45 {
            buyScore += 0.5; reasons.append("RSI \(Int(rsi)) — leaning bullish")
        } else if rsi > 55 {
            sellScore += 0.5; reasons.append("RSI \(Int(rsi)) — leaning bearish")
        } else {
            reasons.append("RSI \(Int(rsi)) — neutral")
        }

        if stochK > stochD && stochK < 30 {
            buyScore += 1; reasons.append("Stochastic bullish crossover in oversold zone")
        } else if stochK < stochD && stochK > 70 {
            sellScore += 1; reasons.append("Stochastic bearish crossover in overbought zone")
        }

        // 3. MACD
        if !macdLine.isNaN && !signalLine.isNaN && !histogram.isNaN {
            if macdLine > signalLine && histogram > 0 {
                buyScore += 2.5; confluenceCount += 1
                reasons.append("MACD bullish with growing histogram")
            } else if macdLine < signalLine && histogram < 0 {
                sellScore += 2.5; confluenceCount += 1
                reasons.append("MACD bearish with declining histogram")
            } else if macdLine > signalLine {
                buyScore += 1.5; reasons.append("MACD above signal — momentum slowing")
            } else {
                sellScore += 1.5; reasons.append("MACD below signal — selling pressure easing")
            }
        }

        // 4. BOLLINGER BANDS
        let bbRange = bbUpper - bbLower
        let bbPosition = bbRange > 0 ? (currentPrice - bbLower) / bbRange : 0.5
        if bbPosition < 0.05 {
            buyScore += 2.5; confluenceCount += 1
            reasons.append("Price at lower Bollinger Band — extreme oversold")
        } else if bbPosition < 0.2 {
            buyScore += 1.5; reasons.append("Price near lower Bollinger Band")
        } else if bbPosition > 0.95 {
            sellScore += 2.5; confluenceCount += 1
            reasons.append("Price at upper Bollinger Band — extreme overbought")
        } else if bbPosition > 0.8 {
            sellScore += 1.5; reasons.append("Price near upper Bollinger Band")
        }

        // 5. ADX (trend strength)
        let trendStrength: Double
        if adx > 30 {
            trendStrength = 1.3; reasons.append("ADX \(Int(adx)) — strong trend, signals amplified")
        } else if adx > 25 {
            trendStrength = 1.1; reasons.append("ADX \(Int(adx)) — moderate trend")
        } else if adx > 20 {
            trendStrength = 0.9; reasons.append("ADX \(Int(adx)) — weak trend, signals dampened")
        } else {
            trendStrength = 0.6; reasons.append("ADX \(Int(adx)) — choppy market, signals unreliable")
        }
        buyScore *= trendStrength
        sellScore *= trendStrength

        // 6. VOLUME CONFIRMATION
        if let vol = volumeAnalysis {
            if vol.isVolumeSpike {
                if buyScore > sellScore {
                    buyScore += 2; confluenceCount += 1
                    reasons.append("Volume spike (×\(String(format: "%.1f", vol.volumeRatio))) confirms buying pressure")
                } else if sellScore > buyScore {
                    sellScore += 2; confluenceCount += 1
                    reasons.append("Volume spike (×\(String(format: "%.1f", vol.volumeRatio))) confirms selling pressure")
                }
            }

            if vol.obvTrend == .up && buyScore > sellScore {
                buyScore += 1; reasons.append("OBV trending up — accumulation")
            } else if vol.obvTrend == .down && sellScore > buyScore {
                sellScore += 1; reasons.append("OBV trending down — distribution")
            }

            // VWAP position
            if currentPrice > vol.vwap && buyScore > sellScore {
                buyScore += 0.5; reasons.append("Price above VWAP \(formatUSD(vol.vwap)) — bullish")
            } else if currentPrice < vol.vwap && sellScore > buyScore {
                sellScore += 0.5; reasons.append("Price below VWAP \(formatUSD(vol.vwap)) — bearish")
            }
        }

        // 7. ORDER BOOK IMBALANCE
        if let imbalance = orderBookImbalance {
            if imbalance > 0.3 {
                buyScore += 1.5; confluenceCount += 1
                reasons.append("Order book: strong bid support (imbalance +\(String(format: "%.0f", imbalance * 100))%)")
            } else if imbalance < -0.3 {
                sellScore += 1.5; confluenceCount += 1
                reasons.append("Order book: heavy ask pressure (imbalance \(String(format: "%.0f", imbalance * 100))%)")
            } else if imbalance > 0.15 {
                buyScore += 0.5
                reasons.append("Order book: moderate bid support")
            } else if imbalance < -0.15 {
                sellScore += 0.5
                reasons.append("Order book: moderate ask pressure")
            }
        }

        // 8. SUPPORT/RESISTANCE
        let (support, resistance) = findSupportResistance(highs: highs, lows: lows, closes: closes, atr: atr)
        let distToSupport = ((currentPrice - support) / currentPrice) * 100
        let distToResistance = ((resistance - currentPrice) / currentPrice) * 100
        if distToSupport < 2 && distToSupport >= 0 {
            buyScore += 1.5
            reasons.append("Price \(String(format: "%.1f", distToSupport))% above support \(formatUSD(support))")
        } else if distToResistance < 2 && distToResistance >= 0 {
            sellScore += 1.5
            reasons.append("Price \(String(format: "%.1f", distToResistance))% below resistance \(formatUSD(resistance))")
        }

        // 9. MOMENTUM (multi-period)
        let mom5 = momentum(closes, min(5, closes.count - 1))
        let mom10 = momentum(closes, min(10, closes.count - 1))
        if mom5 > 0 && mom10 > 0 {
            buyScore += 1.5; confluenceCount += 1
            reasons.append("Short + medium momentum positive")
        } else if mom5 < 0 && mom10 < 0 {
            sellScore += 1.5; confluenceCount += 1
            reasons.append("Short + medium momentum negative")
        }

        // === FINAL SIGNAL ===

        let totalScore = buyScore + sellScore
        let netScore = buyScore - sellScore
        let rawConfidence = totalScore > 0 ? (abs(netScore) / totalScore) * 100 : 50
        let confluenceBonus = Double(confluenceCount) * 5.0
        let confidence = min(rawConfidence + confluenceBonus, 95)

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

        // === ENTRY/EXIT ===

        let entryExit = calculateEntryExit(
            signal: signal, currentPrice: currentPrice,
            atr: atr, support: support, resistance: resistance,
            bbUpper: bbUpper, bbLower: bbLower,
            mode: mode, netScore: netScore
        )

        return TradingSignal(
            signal: signal, confidence: confidence,
            reasons: reasons, indicators: indicators,
            volumeAnalysis: volumeAnalysis,
            orderBookImbalance: orderBookImbalance,
            entryExit: entryExit,
            tradeMode: mode,
            generatedAt: Date()
        )
    }

    // MARK: - Volume Analysis

    private func analyzeVolume(candles: [Candle], closes: [Double], volumes: [Double]) -> VolumeAnalysis {
        let currentVol = volumes.last ?? 0
        let period = min(20, volumes.count)
        let recentVols = Array(volumes.suffix(period))
        let avgVol = recentVols.reduce(0, +) / Double(period)
        let volRatio = avgVol > 0 ? currentVol / avgVol : 1.0

        // OBV
        var obv: Double = 0
        for i in 1..<closes.count {
            if closes[i] > closes[i - 1] {
                obv += volumes[i]
            } else if closes[i] < closes[i - 1] {
                obv -= volumes[i]
            }
        }

        // OBV trend (compare last 5 periods)
        let obvLookback = min(5, closes.count - 1)
        var obvRunning: Double = 0
        var obvValues: [Double] = []
        for i in 1..<closes.count {
            if closes[i] > closes[i - 1] {
                obvRunning += volumes[i]
            } else if closes[i] < closes[i - 1] {
                obvRunning -= volumes[i]
            }
            obvValues.append(obvRunning)
        }
        let obvRecent = Array(obvValues.suffix(obvLookback))
        let obvTrend: TrendDirection = (obvRecent.last ?? 0) > (obvRecent.first ?? 0) ? .up : .down

        // VWAP
        var volPriceSum: Double = 0
        var volSum: Double = 0
        for i in 0..<closes.count {
            volPriceSum += closes[i] * volumes[i]
            volSum += volumes[i]
        }
        let vwap = volSum > 0 ? volPriceSum / volSum : closes.last ?? 0

        return VolumeAnalysis(
            currentVolume: currentVol, avgVolume: avgVol,
            volumeRatio: volRatio, obv: obv, obvTrend: obvTrend,
            vwap: vwap, isVolumeSpike: volRatio > 2.0
        )
    }

    // MARK: - Entry/Exit Calculation

    private func calculateEntryExit(
        signal: SignalType, currentPrice: Double, atr: Double,
        support: Double, resistance: Double,
        bbUpper: Double, bbLower: Double,
        mode: TradeMode, netScore: Double
    ) -> EntryExitSignal {

        let slMultiplier: Double  // ATR multiplier for stop loss
        let tpMultiplier: Double  // ATR multiplier for take profit
        let positionPct: Double

        switch mode {
        case .dayTrade:
            slMultiplier = 1.0; tpMultiplier = 1.5; positionPct = 15
        case .short:
            slMultiplier = 1.5; tpMultiplier = 2.5; positionPct = 20
        case .long:
            slMultiplier = 2.0; tpMultiplier = 3.5; positionPct = 25
        }

        let entry: Double
        let sl: Double
        let tp1: Double
        let tp2: Double
        var reasons: [String] = []

        switch signal {
        case .strongBuy, .buy:
            entry = currentPrice
            sl = currentPrice - (atr * slMultiplier)
            tp1 = currentPrice + (atr * tpMultiplier)
            tp2 = currentPrice + (atr * tpMultiplier * 2)
            reasons.append("Entry at current price \(formatUSD(currentPrice))")
            reasons.append("Stop loss at \(formatUSD(sl)) (\(String(format: "%.1f", ((sl - currentPrice) / currentPrice) * 100))%)")
            reasons.append("TP1: \(formatUSD(tp1)) — TP2: \(formatUSD(tp2))")

            // Adjust SL to just below support if close
            if support > sl && support < currentPrice {
                sl = support * 0.998
                reasons.append("SL adjusted to just below support \(formatUSD(support))")
            }

        case .sell, .strongSell:
            entry = currentPrice
            sl = currentPrice + (atr * slMultiplier)
            tp1 = currentPrice - (atr * tpMultiplier)
            tp2 = currentPrice - (atr * tpMultiplier * 2)
            reasons.append("Short entry at current price \(formatUSD(currentPrice))")
            reasons.append("Stop loss at \(formatUSD(sl)) (\(String(format: "%.1f", ((sl - currentPrice) / currentPrice) * 100))%)")
            reasons.append("TP1: \(formatUSD(tp1)) — TP2: \(formatUSD(tp2))")

            if resistance < sl && resistance > currentPrice {
                sl = resistance * 1.002
                reasons.append("SL adjusted to just above resistance \(formatUSD(resistance))")
            }

        case .hold:
            entry = currentPrice
            sl = currentPrice - (atr * slMultiplier)
            tp1 = currentPrice + (atr * tpMultiplier)
            tp2 = currentPrice + (atr * tpMultiplier * 2)
            reasons.append("No clear entry — hold and wait for confirmation")
        }

        let slDist = abs(entry - sl)
        let tpDist = abs(tp1 - entry)
        let rr = slDist > 0 ? tpDist / slDist : 0

        let urgency: Urgency
        if signal == .strongBuy || signal == .strongSell {
            urgency = .high
        } else if signal == .buy || signal == .sell {
            urgency = .medium
        } else {
            urgency = .low
        }

        return EntryExitSignal(
            direction: signal, entryPrice: entry,
            stopLoss: sl, takeProfit1: tp1, takeProfit2: tp2,
            riskRewardRatio: rr, positionSizePct: positionPct,
            reasoning: reasons, urgency: urgency
        )
    }

    // MARK: - Core Indicators

    private func calcSMA(_ data: [Double], _ period: Int) -> Double {
        guard period > 0, data.count >= period else { return data.last ?? 0 }
        return Array(data.suffix(period)).reduce(0, +) / Double(period)
    }

    private func calcEMA(_ data: [Double], _ period: Int) -> [Double] {
        guard data.count >= period, period > 0 else { return [] }
        let k = 2.0 / Double(period + 1)
        var ema = [Array(data.prefix(period)).reduce(0, +) / Double(period)]
        for i in period..<data.count {
            ema.append(data[i] * k + ema.last! * (1 - k))
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
        return (k, k)
    }

    private func calcBollingerBands(_ closes: [Double], period: Int, stdDev: Double) -> (Double, Double, Double) {
        guard closes.count >= period else {
            let p = closes.last ?? 0; return (p, p, p)
        }
        let slice = Array(closes.suffix(period))
        let sma = slice.reduce(0, +) / Double(period)
        let variance = slice.map { ($0 - sma) * ($0 - sma) }.reduce(0, +) / Double(period)
        let sd = sqrt(variance)
        return (sma + stdDev * sd, sma, sma - stdDev * sd)
    }

    private func calcATR(highs: [Double], lows: [Double], closes: [Double], period: Int) -> Double {
        guard highs.count > period, lows.count > period, closes.count > period else { return 0 }
        var trueRanges: [Double] = []
        for i in 1..<closes.count {
            let tr = max(
                highs[i] - lows[i],
                max(abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1]))
            )
            trueRanges.append(tr)
        }
        return Array(trueRanges.suffix(period)).reduce(0, +) / Double(period)
    }

    private func calcADX(highs: [Double], lows: [Double], closes: [Double], period: Int) -> Double {
        guard highs.count > period + 1 else { return 25 }
        var plusDM: [Double] = []
        var minusDM: [Double] = []
        var trueRanges: [Double] = []

        for i in 1..<closes.count {
            let up = highs[i] - highs[i - 1]
            let down = lows[i - 1] - lows[i]
            plusDM.append(up > down && up > 0 ? up : 0)
            minusDM.append(down > up && down > 0 ? down : 0)
            let tr = max(highs[i] - lows[i], max(abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1])))
            trueRanges.append(tr)
        }

        let avgPlus = Array(plusDM.suffix(period)).reduce(0, +) / Double(period)
        let avgMinus = Array(minusDM.suffix(period)).reduce(0, +) / Double(period)
        let avgTR = Array(trueRanges.suffix(period)).reduce(0, +) / Double(period)
        guard avgTR > 0 else { return 25 }

        let diPlus = (avgPlus / avgTR) * 100
        let diMinus = (avgMinus / avgTR) * 100
        let diSum = diPlus + diMinus
        guard diSum > 0 else { return 25 }
        return abs(diPlus - diMinus) / diSum * 100
    }

    private func findSupportResistance(highs: [Double], lows: [Double], closes: [Double], atr: Double) -> (Double, Double) {
        let lookback = min(20, closes.count)
        let recentHigh = Array(highs.suffix(lookback)).max()!
        let recentLow = Array(lows.suffix(lookback)).min()!
        return (recentLow - atr * 0.2, recentHigh + atr * 0.2)
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
