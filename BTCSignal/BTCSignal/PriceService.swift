import Foundation

// MARK: - CoinGecko API Service

class PriceService: ObservableObject {
    @Published var prices: [PricePoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.coingecko.com/api/v3"

    /// Fetch 30 days of daily BTC prices
    func fetchPrices() async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        let urlString = "\(baseURL)/coins/bitcoin/market_chart?vs_currency=usd&days=30&interval=daily"

        guard let url = URL(string: urlString) else {
            await MainActor.run { errorMessage = "Invalid URL"; isLoading = false }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { errorMessage = "API error. Try again later."; isLoading = false }
                return
            }

            let decoded = try JSONDecoder().decode(CoinGeckoPrice.self, from: data)
            let points = decoded.prices.map { PricePoint(
                date: Date(timeIntervalSince1970: $0[0] / 1000),
                price: $0[1]
            )}

            await MainActor.run {
                self.prices = points
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
