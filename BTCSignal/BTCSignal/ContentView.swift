import SwiftUI

struct ContentView: View {
    @StateObject private var priceService = PriceService()
    @State private var signal: TradingSignal?
    @State private var showDetails = false
    @State private var showInfo = false

    private let engine = SignalEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection

                        if priceService.isLoading {
                            loadingView
                        } else if let error = priceService.errorMessage {
                            errorView(error)
                        } else {
                            signalCard
                            priceChart
                            indicatorsSection
                            reasonsSection
                            disclaimerView
                        }
                    }
                    .padding()
                }
            }
            .preferredColorScheme(.dark)
            .task { await refresh() }
            .refreshable { await refresh() }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showInfo) {
                InfoView()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BTC Signal")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Bitcoin Trading Signals")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Button(action: { Task { await refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .rotationEffect(.degrees(priceService.isLoading ? 360 : 0))
                        .animation(priceService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: priceService.isLoading)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Signal Card

    private var signalCard: some View {
        VStack(spacing: 16) {
            if let signal = signal {
                // Big signal display
                VStack(spacing: 8) {
                    Text(signal.signal.emoji)
                        .font(.system(size: 48))
                    Text(signal.signal.rawValue)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(signalColor(signal.signal))

                    // Confidence bar
                    VStack(spacing: 4) {
                        Text("Confidence: \(Int(signal.confidence))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(signalColor(signal.signal))
                                    .frame(width: geo.size.width * (signal.confidence / 100), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.vertical, 20)

                // Price info
                HStack {
                    VStack(alignment: .leading) {
                        Text("BTC Price")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("$\(formatPrice(signal.indicators.currentPrice))")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("24h Change")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(signal.indicators.priceChange24h >= 0 ? "+" : "")\(String(format: "%.2f", signal.indicators.priceChange24h))%")
                            .font(.title2.bold())
                            .foregroundColor(signal.indicators.priceChange24h >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal)

                Text("Updated \(signal.generatedAt.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Price Chart (simplified)

    private var priceChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("30-Day Price")
                .font(.headline)
                .foregroundColor(.white)

            GeometryReader { geo in
                let prices = priceService.prices.map { $0.price }
                guard let minP = prices.min(), let maxP = prices.max(), prices.count > 1 else {
                    Text("No data").foregroundColor(.gray)
                    return
                }

                let range = maxP - minP
                let stepX = geo.size.width / CGFloat(prices.count - 1)

                ZStack {
                    // Grid lines
                    ForEach(0..<5) { i in
                        let y = geo.size.height * CGFloat(i) / 4
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }

                    // Price line
                    Path { p in
                        for (i, price) in prices.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height - CGFloat((price - minP) / range) * geo.size.height
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                    // Fill under line
                    Path { p in
                        for (i, price) in prices.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height - CGFloat((price - minP) / range) * geo.size.height
                            if i == 0 { p.move(to: CGPoint(x: x, y: geo.size.height)) }
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: CGFloat(prices.count - 1) * stepX, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(colors: [.orange.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                    )

                    // Current price dot
                    let lastX = CGFloat(prices.count - 1) * stepX
                    let lastY = geo.size.height - CGFloat((prices.last! - minP) / range) * geo.size.height
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                        .position(x: lastX, y: lastY)
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Indicators

    private var indicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Indicators")
                .font(.headline)
                .foregroundColor(.white)

            if let signal = signal {
                let ind = signal.indicators
                HStack(spacing: 12) {
                    indicatorBox("SMA 7", value: "$\(formatPrice(ind.sma7))", bullish: ind.sma7 > ind.sma25)
                    indicatorBox("SMA 25", value: "$\(formatPrice(ind.sma25))", bullish: ind.sma25 < ind.sma7)
                }
                HStack(spacing: 12) {
                    indicatorBox("RSI (14)", value: String(format: "%.1f", ind.rsi),
                                 bullish: ind.rsi < 50, isRSI: true)
                    indicatorBox("MACD", value: ind.macdLine > ind.signalLine ? "Bullish" : "Bearish",
                                 bullish: ind.macdLine > ind.signalLine)
                }
            }
        }
    }

    private func indicatorBox(_ name: String, value: String, bullish: Bool, isRSI: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(.body, design: .rounded).bold())
                .foregroundColor(.white)
            Text(bullish ? "Bullish" : "Bearish")
                .font(.caption2.bold())
                .foregroundColor(bullish ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(bullish ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Reasons

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis")
                .font(.headline)
                .foregroundColor(.white)

            if let signal = signal {
                ForEach(signal.reasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                            .padding(.top, 6)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Helpers

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.orange)
                .scaleEffect(1.5)
            Text("Fetching Bitcoin data...")
                .foregroundColor(.gray)
        }
        .frame(height: 300)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await refresh() } }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .frame(height: 300)
    }

    private var disclaimerView: some View {
        Text("⚠️ Not financial advice. Signals are based on technical indicators only. Always do your own research.")
            .font(.caption2)
            .foregroundColor(.gray.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.bottom, 40)
    }

    private func refresh() async {
        await priceService.fetchPrices()
        if !priceService.prices.isEmpty {
            signal = engine.analyze(prices: priceService.prices)
        }
    }

    private func signalColor(_ signal: SignalType) -> Color {
        switch signal {
        case .strongBuy, .buy: return .green
        case .hold: return .yellow
        case .sell, .strongSell: return .red
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        }
        return String(format: "%.2f", price)
    }
}

#Preview {
    ContentView()
}
