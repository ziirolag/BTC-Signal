# BTC Signal 🟢🔴

A simple iOS app that generates Bitcoin buy/sell signals using technical analysis.

## Features

- **Real-time BTC price** from CoinGecko (free, no API key needed)
- **30-day price chart** with gradient fill
- **Trading signals**: Strong Buy / Buy / Hold / Sell / Strong Sell
- **Confidence score** for each signal
- **Technical indicators**:
  - SMA 7/25 crossover
  - RSI (14-period)
  - MACD with signal line
  - Short-term momentum

## How It Works

The app fetches 30 days of daily Bitcoin prices and runs them through a multi-indicator scoring engine:

| Indicator | Bullish | Bearish |
|-----------|---------|---------|
| SMA 7 vs SMA 25 | SMA7 > SMA25 | SMA7 < SMA25 |
| RSI (14) | < 30 (oversold) | > 70 (overbought) |
| MACD | Above signal line | Below signal line |
| Momentum | Positive | Negative |

Each indicator contributes to a buy/sell score. The final signal is determined by the net score, and confidence is calculated from the score margin.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- No API keys needed

## Getting Started

1. Open `BTCSignal.xcodeproj` in Xcode
2. Select your iPhone or Simulator
3. Hit Run (⌘R)

## Sync to Your Mac

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/BTC-Signal.git
cd BTC-Signal

# Open in Xcode
open BTCSignal/BTCSignal.xcodeproj
```

## ⚠️ Disclaimer

This app is for **educational purposes only**. It is NOT financial advice. Always do your own research before making any investment decisions. Past performance does not guarantee future results.

## License

MIT
