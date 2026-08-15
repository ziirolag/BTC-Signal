import SwiftUI

// MARK: - Positions View

struct PositionsView: View {
    @ObservedObject var positionManager: PositionManager
    @ObservedObject var notificationManager: NotificationManager
    let marketSignal: TradingSignal?
    @State private var showAddPosition = false
    @State private var showNotificationPrompt = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Positions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if !positionManager.positions.isEmpty {
                        Text("\(positionManager.positions.count) active")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.btcSubtext)
                    }
                }
                Spacer()

                HStack(spacing: 10) {
                    // Notification toggle
                    Button(action: {
                        if notificationManager.isAuthorized {
                            notificationManager.cancelAll()
                        } else {
                            notificationManager.requestPermission()
                        }
                    }) {
                        Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash")
                            .font(.system(size: 14))
                            .foregroundColor(notificationManager.isAuthorized ? .btcGreen : .btcSubtext)
                    }

                    // Add position
                    Button(action: { showAddPosition = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Enter")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.btcOrange))
                    }
                }
            }

            if positionManager.positions.isEmpty {
                emptyState
            } else {
                // Portfolio summary
                portfolioSummary

                // Position cards
                ForEach(positionManager.positionSignals(marketSignal: marketSignal)) { posSignal in
                    PositionCardView(posSignal: posSignal, positionManager: positionManager, notificationManager: notificationManager)
                }
            }
        }
        .sheet(isPresented: $showAddPosition) {
            AddPositionView(positionManager: positionManager, currentPrice: marketSignal?.indicators.currentPrice)
        }
    }

    // MARK: - Portfolio Summary

    private var portfolioSummary: some View {
        HStack(spacing: 0) {
            summaryBox(
                label: "Invested",
                value: "$\(formatUSD(positionManager.totalInvested))"
            )
            divider
            summaryBox(
                label: "Value",
                value: "$\(formatUSD(positionManager.totalCurrentValue))"
            )
            divider
            summaryBox(
                label: "P&L",
                value: "\(positionManager.totalPnL >= 0 ? "+" : "")\(String(format: "%.1f", positionManager.totalPnLPercent))%",
                color: positionManager.totalPnL >= 0 ? .btcGreen : .btcRed
            )
            divider
            summaryBox(
                label: "BTC",
                value: String(format: "%.5f", positionManager.totalBTC)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.btcCard)
        )
    }

    private func summaryBox(label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.btcSubtext)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.btcDivider)
            .frame(width: 1, height: 30)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.btcSubtext.opacity(0.5))
            Text("No positions yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text("Tap \"Enter\" to track a position and get personalized buy/sell signals based on your entry price.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.btcSubtext)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.btcCard)
        )
    }
}

// MARK: - Position Card

struct PositionCardView: View {
    let posSignal: PositionSignal
    @ObservedObject var positionManager: PositionManager
    @ObservedObject var notificationManager: NotificationManager
    @State private var showDeleteConfirm = false

    private var position: Position { posSignal.position }

    var body: some View {
        VStack(spacing: 0) {
            // Main info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(position.type.emoji)
                            .font(.system(size: 14))
                        Text(position.type.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(position.type == .long ? .btcGreen : .btcRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill((position.type == .long ? Color.btcGreen : Color.btcRed).opacity(0.12))
                            )
                        Text(posSignal.urgency.emoji)
                            .font(.system(size: 12))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.6f", position.amountBTC))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("BTC")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.btcSubtext)
                    }

                    Text("Entry: $\(formatPrice(position.entryPrice))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.btcSubtext)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // P&L
                    Text("\(position.pnl >= 0 ? "+" : "")$\(formatUSD(abs(position.pnl)))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(position.isInProfit ? .btcGreen : .btcRed)

                    Text("\(posSignal.entryDifference >= 0 ? "+" : "")\(String(format: "%.2f", posSignal.entryDifference))%")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(position.isInProfit ? .btcGreen : .btcRed)

                    Text("$\(formatPrice(position.currentPrice))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.btcSubtext)
                }
            }
            .padding(14)

            // Recommendations
            if !posSignal.recommendations.isEmpty {
                Divider().background(Color.btcDivider)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(posSignal.recommendations.enumerated()), id: \.offset) { _, rec in
                        HStack(alignment: .top, spacing: 6) {
                            Text(posSignal.urgency.emoji)
                                .font(.system(size: 10))
                                .padding(.top, 2)
                            Text(rec)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(12)
            }

            // Footer
            HStack {
                Text(position.entryDate.formatted(.dateTime.month().day().hour().minute()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.btcSubtext.opacity(0.5))
                Spacer()
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.btcRed.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.btcCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(urgencyColor.opacity(0.15), lineWidth: 1)
        )
        .alert("Close Position?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                positionManager.removePosition(id: position.id)
            }
        } message: {
            Text("This will remove the position from tracking. This doesn't affect any actual holdings.")
        }
    }

    private var urgencyColor: Color {
        switch posSignal.urgency {
        case .low: return .btcSubtext
        case .medium: return .btcYellow
        case .high: return .btcOrange
        case .critical: return .btcRed
        }
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.0f", price)
    }

    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Add Position View

struct AddPositionView: View {
    @ObservedObject var positionManager: PositionManager
    let currentPrice: Double?
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var entryPriceText = ""
    @State private var selectedType: PositionType = .long
    @State private var notes = ""
    @State private var useCurrentPrice = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btcDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Position type
                        HStack(spacing: 12) {
                            ForEach(PositionType.allCases, id: \.self) { type in
                                Button(action: { selectedType = type }) {
                                    HStack(spacing: 6) {
                                        Text(type.emoji)
                                        Text(type.rawValue)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(selectedType == type ? .white : .btcSubtext)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedType == type ?
                                                (type == .long ? Color.btcGreen.opacity(0.15) : Color.btcRed.opacity(0.15)) :
                                                Color.white.opacity(0.03))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                selectedType == type ?
                                                    (type == .long ? Color.btcGreen.opacity(0.4) : Color.btcRed.opacity(0.4)) :
                                                    Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }

                        // Amount
                        inputField(
                            label: "Amount (BTC)",
                            text: $amountText,
                            placeholder: "0.001",
                            icon: "bitcoinsign.circle"
                        )

                        // Entry price
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Entry Price (USD)", systemImage: "dollarsign.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.btcSubtext)
                                Spacer()
                                if currentPrice != nil {
                                    Button(action: {
                                        useCurrentPrice.toggle()
                                        if useCurrentPrice, let price = currentPrice {
                                            entryPriceText = String(format: "%.0f", price)
                                        }
                                    }) {
                                        Text("Use current")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.btcOrange)
                                    }
                                }
                            }

                            TextField("$63,000", text: $entryPriceText)
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .onAppear {
                                    if useCurrentPrice, let price = currentPrice {
                                        entryPriceText = String(format: "%.0f", price)
                                    }
                                }
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes (optional)", systemImage: "note.text")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.btcSubtext)

                            TextField("Why are you entering?", text: $notes, axis: .vertical)
                                .lineLimit(3)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }

                        // Preview
                        if let btc = Double(amountText), btc > 0, let price = Double(entryPriceText), price > 0 {
                            let usd = btc * price
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Total investment")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.btcSubtext)
                                    Spacer()
                                    Text("$\(formatUSD(usd))")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.btcOrange.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.btcOrange.opacity(0.15), lineWidth: 1)
                            )
                        }

                        // Save button
                        Button(action: savePosition) {
                            Text("Track Position")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().fill(canSave ? Color.btcOrange : Color.gray.opacity(0.3))
                                )
                        }
                        .disabled(!canSave)
                    }
                    .padding(16)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("New Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.btcSubtext)
                }
            }
        }
    }

    private var canSave: Bool {
        guard let btc = Double(amountText), btc > 0,
              let price = Double(entryPriceText), price > 0 else { return false }
        return true
    }

    private func savePosition() {
        guard let btc = Double(amountText), let price = Double(entryPriceText) else { return }
        positionManager.addPosition(entryPrice: price, amountBTC: btc, type: selectedType, notes: notes)
        dismiss()
    }

    private func inputField(label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.btcSubtext)

            TextField(placeholder, text: text)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .keyboardType(.decimalPad)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}
