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
                            Text("Everything is transparent. Here's exactly how signals are generated.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Sections
                        faqSection(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Where Does the Data Come From?",
                            content: """
                            We use the **CoinGecko API** — a free, public cryptocurrency data API that requires no API key.

                            **What we fetch:**
                            • 30 days of daily Bitcoin closing prices
                            • Quoted in USD
                            • Pulled in real-time each time you open or refresh the app

                            CoinGecko aggregates prices across hundreds of exchanges to give a fair market average. We don't use any single exchange's price, which reduces noise from flash crashes or manipulation on smaller platforms.

                            **Endpoint:** `api.coingecko.com/api/v3/coins/bitcoin/market_chart`
                            """
                        )

                        faqSection(
                            icon: "clock",
                            title: "What Date Range Is Used?",
                            content: """
                            The app analyzes the **last 30 days** of daily price data.

                            Why 30 days?
                            • Long enough to identify medium-term trends
                            • Short enough to stay responsive to recent moves
                            • Provides enough data points (30+) for all indicators to stabilize

                            Each data point is one daily closing price. We need at least 26 data points to run all indicators — the 30-day window gives us comfortable margin.
                            """
                        )

                        faqSection(
                            icon: "function",
                            title: "What Indicators Are Used?",
                            content: """
                            The app runs **4 technical indicators**, each contributing to a buy/sell score:

                            **1. SMA Crossover (7 / 25 day)**
                            SMA = Simple Moving Average. We calculate the average price over the last 7 days and the last 25 days.
                            • When the short-term average (7) crosses above the long-term average (25) → bullish (uptrend starting)
                            • When it crosses below → bearish (downtrend starting)
                            This is one of the most widely-used trend indicators in trading.

                            **2. RSI — Relative Strength Index (14 day)**
                            RSI measures how fast prices have been rising or falling, on a scale of 0–100.
                            • Below 30 = "oversold" — price may have dropped too far, too fast (potential bounce)
                            • Above 70 = "overbought" — price may have risen too far, too fast (potential pullback)
                            • 30–70 = neutral zone
                            RSI was developed by J. Welles Wilder Jr. in 1978 and remains a standard tool.

                            **3. MACD (12/26/9)**
                            MACD = Moving Average Convergence Divergence. It compares a fast EMA (12-day) to a slow EMA (26-day), then smooths the difference with a 9-day "signal line."
                            • MACD line above signal line → bullish momentum
                            • MACD line below signal line → bearish momentum
                            EMA (Exponential Moving Average) gives more weight to recent prices, making it more responsive than SMA.

                            **4. Price Momentum (4-day)**
                            We simply check if the price is higher or lower than 4 days ago.
                            • Rising = positive short-term momentum
                            • Falling = negative short-term momentum
                            """
                        )

                        faqSection(
                            icon: "brain",
                            title: "How Is the Signal Determined?",
                            content: """
                            Each indicator casts a "vote" for buy or sell:

                            | Indicator | Bullish Points | Bearish Points |
                            |-----------|---------------|----------------|
                            | SMA Crossover | +2 | +2 |
                            | RSI | +1 to +2 | +1 to +2 |
                            | MACD | +2 | +2 |
                            | Momentum | +1 | +1 |

                            The total possible score ranges from -7 (maximum bearish) to +7 (maximum bullish).

                            **Signal thresholds:**
                            • **Strong Buy** → net score ≥ +5
                            • **Buy** → net score ≥ +2
                            • **Hold** → score between -2 and +2
                            • **Sell** → net score ≤ -2
                            • **Strong Sell** → net score ≤ -5

                            **Confidence** is calculated as: |net score| / total possible score × 100, capped at 95%. A higher confidence means more indicators agree with each other.

                            For RSI specifically, the scoring is graduated:
                            • RSI < 30 → +2 buy points (strongly oversold)
                            • RSI 30-40 → +1 buy point (mildly oversold)
                            • RSI > 70 → +2 sell points (strongly overbought)
                            • RSI 60-70 → +1 sell point (mildly overbought)
                            """
                        )

                        faqSection(
                            icon: "exclamationmark.triangle",
                            title: "What Are the Limitations?",
                            content: """
                            **This is not financial advice.** Here's what you should know:

                            • **Technical analysis only** — The app uses price patterns, not fundamentals. It doesn't consider news, regulations, adoption, or macroeconomics.

                            • **No volume data** — We don't analyze trading volume, which is a key confirmatory signal in professional trading.

                            • **No backtesting shown** — While these indicators are well-established, we don't show historical accuracy rates for this specific combination.

                            • **Lagging indicators** — Moving averages and MACD are "lagging" — they confirm trends that have already started, not predict the future.

                            • **30-day window** — We only look at 30 days. A longer dataset might tell a different story.

                            • **Not a crystal ball** — Markets are driven by human behavior, news, and events that no algorithm can predict. Use this as one data point among many.

                            **Bottom line:** This app is a learning tool and a quick reference, not a trading bot. Always do your own research.
                            """
                        )

                        faqSection(
                            icon: "arrow.clockwise",
                            title: "How Often Should I Check?",
                            content: """
                            The data updates every time you pull to refresh or reopen the app.

                            Since we use **daily** price data, checking more than once a day won't change the signal (unless you're seeing a live price update). The indicators are calculated from daily closes.

                            **Recommended usage:**
                            • Check once or twice a day
                            • Pull down to refresh for the latest data
                            • Don't obsess over minute-to-minute changes — daily signals are meant to capture broader trends
                            """
                        )

                        faqSection(
                            icon: "text.book.closed",
                            title: "Glossary",
                            content: """
                            **SMA** — Simple Moving Average. The sum of prices over N days, divided by N. Smooths out daily noise.

                            **EMA** — Exponential Moving Average. Like SMA but gives more weight to recent prices. Reacts faster to changes.

                            **RSI** — Relative Strength Index. A momentum oscillator (0–100) measuring speed and magnitude of price changes.

                            **MACD** — Moving Average Convergence Divergence. Shows the relationship between two EMAs. Used to spot trend changes.

                            **Signal Line** — A smoothed version of the MACD line. When MACD crosses it, it suggests a trend shift.

                            **Oversold** — When an asset has fallen significantly and may be due for a bounce.

                            **Overbought** — When an asset has risen significantly and may be due for a pullback.

                            **Momentum** — The rate of acceleration of price change. Positive momentum = prices trending up.

                            **Bullish** — Expecting prices to rise.

                            **Bearish** — Expecting prices to fall.
                            """
                        )

                        // Footer
                        VStack(spacing: 8) {
                            Divider().background(Color.gray.opacity(0.3))
                            Text("Built with SwiftUI • Data from CoinGecko")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Version 1.0")
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
