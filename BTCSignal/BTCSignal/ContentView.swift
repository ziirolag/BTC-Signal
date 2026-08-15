import SwiftUI

// MARK: - Color Palette

extension Color {
    static let btcOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let btcDark = Color(red: 0.06, green: 0.06, blue: 0.1)
    static let btcCard = Color(red: 0.1, green: 0.1, blue: 0.14)
    static let btcGreen = Color(red: 0.18, green: 0.82, blue: 0.45)
    static let btcRed = Color(red: 1.0, green: 0.32, blue: 0.32)
    static let btcYellow = Color(red: 1.0, green: 0.82, blue: 0.2)
    static let btcSubtext = Color(red: 0.55, green: 0.55, blue: 0.62)
    static let btcDivider = Color(red: 0.18, green: 0.18, blue: 0.24)
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var priceService = PriceService()
    @StateObject private var positionManager = PositionManager()
    @StateObject private var notificationManager = NotificationManager()
    @State private var signal: TradingSignal?
    @State private var showInfo = false
    @State private var animateSignal = false
    @State private var selectedTab = 0

    private let engine = SignalEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btcDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        tabButton("Signal", icon: "chart.line.uptrend.xyaxis", tag: 0)
                        tabButton("Positions", icon: "briefcase.fill", tag: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                signalTab
                            } else {
                                positionsTab
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                    .refreshable { await refresh() }
                }
            }
            .preferredColorScheme(.dark)
            .task {
                await refresh()
                notificationManager.requestPermission()
            }
            .sheet(isPresented: $showInfo) { InfoView() }
            .onChange(of: signal) { newSignal in
                checkAndNotify(signal: newSignal)
            }
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { selectedTab = tag } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selectedTab == tag ? .white : .btcSubtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedTab == tag ? Color.btcOrange.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selectedTab == tag ? Color.btcOrange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Signal Tab

    private var signalTab: some View {
        VStack(spacing: 16) {
            headerView

            if priceService.isLoading {
                loadingView
            } else if let error = priceService.errorMessage {
                errorCard(error)
            } else if let signal = signal {
                signalHeroCard(signal)
                priceRow(signal)
                chartView
                indicatorGrid(signal)
                analysisCard(signal)
                disclaimerCard
            } else {
                noSignalView
            }
        }
    }

    // MARK: - Positions Tab

    private var positionsTab: some View {
        VStack(spacing: 16) {
            // Quick stats at top
            if let signal = signal {
                miniSignalBar(signal)
            }

            PositionsView(
                positionManager: positionManager,
                notificationManager: notificationManager,
                marketSignal: signal
            )
        }
    }

    // MARK: - Mini Signal Bar (on positions tab)

    private func miniSignalBar(_ signal: TradingSignal) -> some View {
        HStack(spacing: 10) {
            Text(signalEmoji(signal.signal))
                .font(.system(size: 18))
            Text(signal.signal.rawValue)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(signalColor(signal.signal))
            Spacer()
            Text("$\(formatPriceFull(signal.indicators.currentPrice))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("\(signal.indicators.priceChange24h >= 0 ? "+" : "")\(String(format: "%.2f", signal.indicators.priceChange24h))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(signal.indicators.priceChange24h >= 0 ? .btcGreen : .btcRed)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BTC Signal")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Technical Analysis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.btcSubtext)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.btcSubtext)
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        Task { await refresh() }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.btcOrange)
                        .rotationEffect(.degrees(priceService.isLoading ? 360 : 0))
                        .animation(.easeInOut(duration: 0.8), value: priceService.isLoading)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Signal Hero Card

    private func signalHeroCard(_ signal: TradingSignal) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(signalGlow(signal.signal))
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                        .opacity(animateSignal ? 0.6 : 0.3)
                        .animation(.easeInOut(duration: 1.5), value: animateSignal)

                    Circle()
                        .fill(signalGlow(signal.signal))
                        .frame(width: 56, height: 56)
                        .opacity(0.15)

                    Text(signalEmoji(signal.signal))
                        .font(.system(size: 32))
                }
                .onAppear { animateSignal = true }

                Text(signal.signal.rawValue)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(signalColor(signal.signal))
                    .tracking(2)

                HStack(spacing: 6) {
                    Text("\(Int(signal.confidence))%")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(signalColor(signal.signal))
                    Text("confidence")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.btcSubtext)
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [signalColor(signal.signal).opacity(0.6), signalColor(signal.signal)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (signal.confidence / 100))
                }
            }
            .frame(height: 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.btcCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(signalColor(signal.signal).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Price Row

    private func priceRow(_ signal: TradingSignal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bitcoin")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.btcSubtext)
                Text("$\(formatPriceFull(signal.indicators.currentPrice))")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("24h")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.btcSubtext)
                HStack(spacing: 4) {
                    Image(systemName: signal.indicators.priceChange24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(signal.indicators.priceChange24h >= 0 ? "+" : "")\(String(format: "%.2f", signal.indicators.priceChange24h))%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }
                .foregroundColor(signal.indicators.priceChange24h >= 0 ? .btcGreen : .btcRed)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    // MARK: - Chart

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("30-Day Price")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("USD")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.btcSubtext)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }

            let prices = priceService.prices.map { $0.price }
            if prices.count > 1, let minP = prices.min(), let maxP = prices.max() {
                chartContent(prices: prices, minP: minP, range: maxP - minP)
            } else {
                Text("No chart data")
                    .foregroundColor(.btcSubtext)
                    .frame(height: 160)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    private func chartContent(prices: [Double], minP: Double, range: Double) -> some View {
        GeometryReader { geo in
            let padding: CGFloat = 4
            let chartWidth = geo.size.width - padding * 2
            let chartHeight = geo.size.height - padding * 2
            let stepX = chartWidth / CGFloat(prices.count - 1)
            let safeRange = range > 0 ? range : 1

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let y = padding + chartHeight * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: padding, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width - padding, y: y))
                    }
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                }

                Path { p in
                    for (i, price) in prices.enumerated() {
                        let x = padding + CGFloat(i) * stepX
                        let y = padding + chartHeight - CGFloat((price - minP) / safeRange) * chartHeight
                        if i == 0 { p.move(to: CGPoint(x: x, y: geo.size.height)) }
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: padding + CGFloat(prices.count - 1) * stepX, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.btcOrange.opacity(0.2), Color.btcOrange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { p in
                    for (i, price) in prices.enumerated() {
                        let x = padding + CGFloat(i) * stepX
                        let y = padding + chartHeight - CGFloat((price - minP) / safeRange) * chartHeight
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.btcOrange.opacity(0.7), Color.btcOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                let lastX = padding + CGFloat(prices.count - 1) * stepX
                let lastY = padding + chartHeight - CGFloat((prices.last! - minP) / safeRange) * chartHeight

                Circle()
                    .fill(Color.btcOrange.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .position(x: lastX, y: lastY)

                Circle()
                    .fill(Color.btcOrange)
                    .frame(width: 7, height: 7)
                    .position(x: lastX, y: lastY)

                Text(formatChartPrice(minP))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.btcSubtext.opacity(0.6))
                    .position(x: geo.size.width / 2, y: geo.size.height - 6)

                Text(formatChartPrice(minP + range))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.btcSubtext.opacity(0.6))
                    .position(x: geo.size.width / 2, y: 8)
            }
        }
        .frame(height: 160)
    }

    // MARK: - Indicator Grid

    private func indicatorGrid(_ signal: TradingSignal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Indicators")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                indicatorTile(name: "SMA 7", value: formatChartPrice(signal.indicators.sma7), trend: signal.indicators.sma7 > signal.indicators.sma25 ? .up : .down)
                indicatorTile(name: "SMA 25", value: formatChartPrice(signal.indicators.sma25), trend: signal.indicators.sma25 < signal.indicators.sma7 ? .up : .down)
                indicatorTile(name: "RSI (14)", value: String(format: "%.1f", signal.indicators.rsi), trend: signal.indicators.rsi < 50 ? .up : .down, subtitle: rsiLabel(signal.indicators.rsi))
                indicatorTile(name: "MACD", value: signal.indicators.macdLine > signal.indicators.signalLine ? "Bullish" : "Bearish", trend: signal.indicators.macdLine > signal.indicators.signalLine ? .up : .down)
            }
        }
    }

    private func indicatorTile(name: String, value: String, trend: TrendDirection, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.btcSubtext)
                Spacer()
                Image(systemName: trend == .up ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(trend == .up ? .btcGreen : .btcRed)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(trend == .up ? .btcGreen : .btcRed)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.btcCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5)
        )
    }

    // MARK: - Analysis Card

    private func analysisCard(_ signal: TradingSignal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Analysis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(signal.reasons.count) factors")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.btcSubtext)
            }
            ForEach(Array(signal.reasons.enumerated()), id: \.offset) { index, reason in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.btcOrange)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.btcOrange.opacity(0.12)))
                    Text(reason)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(3)
                }
                if index < signal.reasons.count - 1 {
                    Divider().background(Color.btcDivider).padding(.leading, 30)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.btcOrange)
                .scaleEffect(1.3)
            Text("Fetching market data...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.btcSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.btcRed)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.btcSubtext)
                .multilineTextAlignment(.center)
            Button(action: { Task { await refresh() } }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.btcOrange))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    private var noSignalView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.btcSubtext)
            Text("Not enough data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("Need at least 26 days of price history.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.btcSubtext)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    private var disclaimerCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.btcYellow.opacity(0.7))
            Text("Not financial advice. Based on technical indicators only. Do your own research.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.btcSubtext.opacity(0.6))
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.btcYellow.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.btcYellow.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Notification Logic

    private func checkAndNotify(signal: TradingSignal?) {
        guard let signal = signal, notificationManager.isAuthorized else { return }

        PriceCache.lastPrice = signal.indicators.currentPrice

        // Alert on non-HOLD signals
        if signal.signal != .hold {
            notificationManager.sendSignalAlert(
                signal: signal.signal.rawValue,
                price: signal.indicators.currentPrice,
                reason: signal.reasons.first ?? "Multiple indicators aligned"
            )
        }

        // Alert on position-specific signals
        let posSignals = positionManager.positionSignals(marketSignal: signal)
        for posSignal in posSignals {
            if posSignal.urgency == .critical || posSignal.urgency == .high {
                notificationManager.sendPositionAlert(
                    position: posSignal.position,
                    pnlPercent: posSignal.entryDifference,
                    reason: posSignal.recommendations.first ?? "Position needs attention"
                )
            }
        }
    }

    // MARK: - Helpers

    private func refresh() async {
        await priceService.fetchPrices()
        if !priceService.prices.isEmpty {
            signal = engine.analyze(prices: priceService.prices)
            PriceCache.lastPrice = priceService.prices.last?.price
        }
    }

    private func signalColor(_ type: SignalType) -> Color {
        switch type {
        case .strongBuy, .buy: return .btcGreen
        case .hold: return .btcYellow
        case .sell, .strongSell: return .btcRed
        }
    }

    private func signalGlow(_ type: SignalType) -> Color {
        switch type {
        case .strongBuy, .buy: return .btcGreen
        case .hold: return .btcYellow
        case .sell, .strongSell: return .btcRed
        }
    }

    private func signalEmoji(_ type: SignalType) -> String {
        switch type {
        case .strongBuy: return "🚀"
        case .buy: return "📈"
        case .hold: return "⏸"
        case .sell: return "📉"
        case .strongSell: return "⚠️"
        }
    }

    private func rsiLabel(_ rsi: Double) -> String {
        if rsi < 30 { return "Oversold" }
        if rsi < 40 { return "Near oversold" }
        if rsi > 70 { return "Overbought" }
        if rsi > 60 { return "Near overbought" }
        return "Neutral"
    }

    private func formatPriceFull(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.0f", price)
    }

    private func formatChartPrice(_ price: Double) -> String {
        if price >= 10000 { return "$\(Int(price / 1000))k" }
        if price >= 1000 { return "$\(String(format: "%.1f", price / 1000))k" }
        return "$\(String(format: "%.0f", price))"
    }
}

// MARK: - Supporting Types

enum TrendDirection {
    case up, down
}

#Preview {
    ContentView()
}
