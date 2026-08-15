import Foundation

// MARK: - Price Service (Binance-powered, multi-timeframe)

class PriceService: ObservableObject {
    @Published var candles: [Candle] = []
    @Published var orderBook: OrderBook?
    @Published var ticker: Ticker24h?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let binance = BinanceService.shared

    // Legacy compat — converts candles to PricePoints
    var prices: [PricePoint] {
        candles.map { PricePoint(date: $0.openTime, price: $0.close) }
    }

    var currentPrice: Double {
        ticker?.lastPrice ?? candles.last?.close ?? 0
    }

    var priceChange24h: Double {
        ticker?.priceChangePercent ?? 0
    }

    // MARK: - Fetch All Data for a Trade Mode

    func fetchData(mode: TradeMode) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            // Fetch klines + order book + ticker in parallel
            async let klinesTask = binance.fetchKlines(
                interval: mode.primaryInterval,
                limit: mode.candleLimit
            )
            async let orderBookTask = binance.fetchOrderBook(limit: 50)
            async let tickerTask = binance.fetch24hTicker()

            let (klines, book, tick) = try await (klinesTask, orderBookTask, tickerTask)

            await MainActor.run {
                self.candles = klines
                self.orderBook = book
                self.ticker = tick
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Refresh Order Book Only (lightweight)

    func refreshOrderBook() async {
        do {
            let book = try await binance.fetchOrderBook(limit: 50)
            await MainActor.run { self.orderBook = book }
        } catch {
            // Silently fail — order book is supplementary
        }
    }

    // MARK: - Legacy Fetch (backward compat)

    func fetchPrices() async {
        await fetchData(mode: .long)
    }
}
