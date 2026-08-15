import Foundation

// MARK: - Binance Public API (no key required)

class BinanceService {

    static let shared = BinanceService()
    private let base = "https://api.binance.us/api/v3"

    // MARK: - Klines (Candles)

    /// Fetch klines from Binance. Returns candles with OHLCV data.
    func fetchKlines(symbol: String = "BTCUSDT", interval: BinanceInterval, limit: Int = 100) async throws -> [Candle] {
        let urlStr = "\(base)/klines?symbol=\(symbol)&interval=\(interval.rawValue)&limit=\(limit)"
        guard let url = URL(string: urlStr) else { throw BinanceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BinanceError.httpError
        }

        // Binance klines format: [[openTime, open, high, low, close, volume, closeTime, quoteVolume, trades, ...]]
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw BinanceError.decodeError
        }

        return raw.compactMap { row -> Candle? in
            guard row.count >= 8,
                  let openTime = row[0] as? Double,
                  let open = Double("\(row[1])"),
                  let high = Double("\(row[2])"),
                  let low = Double("\(row[3])"),
                  let close = Double("\(row[4])"),
                  let volume = Double("\(row[5])"),
                  let quoteVol = Double("\(row[7])"),
                  let trades = row[8] as? Int
            else { return nil }

            return Candle(
                openTime: Date(timeIntervalSince1970: openTime / 1000),
                open: open, high: high, low: low, close: close,
                volume: volume, quoteVolume: quoteVol, trades: trades
            )
        }
    }

    // MARK: - Order Book Depth

    func fetchOrderBook(symbol: String = "BTCUSDT", limit: Int = 50) async throws -> OrderBook {
        let urlStr = "\(base)/depth?symbol=\(symbol)&limit=\(limit)"
        guard let url = URL(string: urlStr) else { throw BinanceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BinanceError.httpError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawBids = json["bids"] as? [[String]],
              let rawAsks = json["asks"] as? [[String]]
        else { throw BinanceError.decodeError }

        let bids: [(price: Double, qty: Double)] = rawBids.compactMap { level in
            guard level.count >= 2, let p = Double(level[0]), let q = Double(level[1]) else { return nil }
            return (p, q)
        }.sorted { $0.price > $1.price }  // high to low

        let asks: [(price: Double, qty: Double)] = rawAsks.compactMap { level in
            guard level.count >= 2, let p = Double(level[0]), let q = Double(level[1]) else { return nil }
            return (p, q)
        }.sorted { $0.price < $1.price }  // low to high

        return OrderBook(bids: bids, asks: asks, timestamp: Date())
    }

    // MARK: - 24h Ticker

    func fetch24hTicker(symbol: String = "BTCUSDT") async throws -> Ticker24h {
        let urlStr = "\(base)/ticker/24hr?symbol=\(symbol)"
        guard let url = URL(string: urlStr) else { throw BinanceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BinanceError.httpError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lastPriceStr = json["lastPrice"] as? String,
              let lastPrice = Double(lastPriceStr),
              let highStr = json["highPrice"] as? String,
              let highPrice = Double(highStr),
              let lowStr = json["lowPrice"] as? String,
              let lowPrice = Double(lowStr),
              let volStr = json["volume"] as? String,
              let volume = Double(volStr),
              let quoteVolStr = json["quoteVolume"] as? String,
              let quoteVolume = Double(quoteVolStr),
              let changeStr = json["priceChangePercent"] as? String,
              let changePct = Double(changeStr)
        else { throw BinanceError.decodeError }

        return Ticker24h(
            lastPrice: lastPrice,
            highPrice: highPrice,
            lowPrice: lowPrice,
            volume: volume,
            quoteVolume: quoteVolume,
            priceChangePercent: changePct
        )
    }
}

// MARK: - Supporting Types

struct Ticker24h {
    let lastPrice: Double
    let highPrice: Double
    let lowPrice: Double
    let volume: Double         // BTC
    let quoteVolume: Double    // USD
    let priceChangePercent: Double
}

enum BinanceError: Error {
    case invalidURL
    case httpError
    case decodeError
}
