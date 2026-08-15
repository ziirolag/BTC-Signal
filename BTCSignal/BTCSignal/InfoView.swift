import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("How BTC Signal Works")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("Multi-timeframe trading signals powered by Binance data.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Trade Modes
                        faqSection(
                            icon: "slider.horizontal.3",
                            title: "Trade Modes",
                            content: """
                            **Three modes** for different trading styles:

                            ⚡ **Day Trade** — 15-minute candles
                            • For scalping and intraday trades
                            • Hold time: minutes to hours
                            • 100 candles (~25 hours of data)

                            ↔️ **Short** — 1-hour candles
                            • For swing trades over hours to 1-2 days
                            • 72 candles (3 days of data)

                            📈 **Long** — 4-hour candles
                            • For position trades over days to weeks
                            • 90 candles (15 days of data)

                            Each mode recalculates all indicators on its timeframe. Switch modes to see how signals change across timeframes.
                            """
                        )

                        faqSection(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Data Source: Binance",
                            content: """
                            All data comes from the **Binance public API** — free, no API key required.

                            **What we fetch:**
                            • OHLCV candles (Open, High, Low, Close, Volume)
                            • Order book depth (top 50 bid/ask levels)
                            • 24h ticker (price, volume, change %)

                            Binance is the world's largest crypto exchange by volume. Using their order book gives us real market depth, not just aggregated prices.

                            **Endpoints used:**
                            • `/api/v3/klines` — candle data
                            • `/api/v3/depth` — order book
                            • `/api/v3/ticker/24hr` — 24h stats
                            """
                        )

                        faqSection(
                            icon: "function",
                            title: "Indicators Used",
                            content: """
                            **Trend:**
                            • SMA crossover (7/25) — short vs medium-term trend
                            • EMA (12/26) — exponential MA, more responsive
                            • ADX — trend strength (strong trend vs choppy)

                            **Momentum:**
                            • RSI (14) — overbought/oversold (0-100)
                            • Stochastic (14) — K/D crossover for reversals
                            • MACD (12/26/9) — momentum + signal line

                            **Volatility:**
                            • Bollinger Bands (20, 2σ) — mean reversion zones
                            • ATR (14) — average true range for SL/TP sizing

                            **Volume (NEW):**
                            • OBV — On-Balance Volume (accumulation/distribution)
                            • VWAP — Volume Weighted Average Price
                            • Volume ratio — current vs 20-period average
                            • Volume spikes — >2x average = significant

                            **Order Book (NEW):**
                            • Bid/ask imbalance — which side has more pressure
                            • Spread — market efficiency indicator
                            • Wall detection — large orders at key levels
                            """
                        )

                        faqSection(
                            icon: "target",
                            title: "Entry / Exit Signals",
                            content: """
                            Each signal includes specific trade levels:

                            **Entry** — recommended entry price (usually current price)

                            **Stop Loss** — exit if price moves against you
                            • Sized using ATR (volatility-adjusted)
                            • Adjusted to support/resistance levels when possible

                            **Take Profit 1 & 2** — two targets
                            • TP1: conservative (1.5-2.5× ATR from entry)
                            • TP2: aggressive (3-5× ATR from entry)

                            **Risk:Reward Ratio** — TP distance ÷ SL distance
                            • ≥ 2:1 = excellent trade setup
                            • ≥ 1.5:1 = acceptable
                            • < 1.5:1 = poor risk/reward, skip or reduce size

                            **Position Size** — suggested % of portfolio based on mode:
                            • Day Trade: 15% (smaller, more trades)
                            • Short: 20%
                            • Long: 25% (larger, fewer trades)
                            """
                        )

                        faqSection(
                            icon: "brain",
                            title: "Signal Scoring",
                            content: """
                            Each indicator votes for buy or sell with weighted points:

                            • SMA+EMA agreement: ±3 points
                            • RSI + Stochastic agreement: ±3 points
                            • MACD + histogram: ±2.5 points
                            • Bollinger Band position: ±2.5 points
                            • Volume spike confirmation: ±2 points
                            • Order book imbalance: ±1.5 points
                            • Support/resistance proximity: ±1.5 points
                            • Momentum (multi-period): ±1.5 points

                            **Trend strength (ADX) acts as a multiplier:**
                            • ADX > 30: ×1.3 (strong trend, amplified)
                            • ADX 25-30: ×1.1
                            • ADX 20-25: ×0.9 (weak trend, dampened)
                            • ADX < 20: ×0.6 (choppy, heavily dampened)

                            **Confluence bonus:** Each independent system that agrees adds +5% confidence.

                            **Signal thresholds:**
                            • Strong Buy: net score ≥ +6 AND 3+ systems agree
                            • Buy: net score ≥ +3 AND 2+ systems agree
                            • Hold: everything else
                            • Sell / Strong Sell: mirror of buy thresholds
                            """
                        )

                        faqSection(
                            icon: "exclamationmark.triangle",
                            title: "Limitations",
                            content: """
                            **This is not financial advice.**

                            • Technical analysis only — no fundamentals, news, or macro
                            • Binance data only — prices may differ on other exchanges
                            • No backtesting shown — indicators are well-established but accuracy varies
                            • Lagging indicators — confirm trends, don't predict
                            • No leverage/futures — spot analysis only
                            • Order book can be spoofed — walls may be fake

                            **Bottom line:** Use this as one input among many. Always manage risk.
                            """
                        )

                        // Footer
                        VStack(spacing: 8) {
                            Divider().background(Color.gray.opacity(0.3))
                            Text("Built with SwiftUI • Data from Binance")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Version 2.0")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("FAQ & Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - FAQ Card

    private func faqSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 28)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(LocalizedStringKey(content))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    InfoView()
}
