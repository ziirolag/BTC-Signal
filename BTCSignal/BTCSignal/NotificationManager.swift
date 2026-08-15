import Foundation
import UserNotifications

// MARK: - iOS Notification Manager

class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    static let shared = NotificationManager()

    init() {
        checkAuthorization()
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Alert Notifications

    func sendSignalAlert(signal: String, price: Double, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "BTC Signal: \(signal)"
        content.body = "BTC at $\(formatPrice(price)) — \(reason)"
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "btc-signal-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func sendPositionAlert(position: Position, pnlPercent: Double, reason: String) {
        let content = UNMutableNotificationContent()

        if pnlPercent > 10 {
            content.title = "🚀 Position Up +\(String(format: "%.1f", pnlPercent))%"
        } else if pnlPercent > 5 {
            content.title = "📈 Position Up +\(String(format: "%.1f", pnlPercent))%"
        } else if pnlPercent < -10 {
            content.title = "⚠️ Position Down \(String(format: "%.1f", pnlPercent))%"
        } else if pnlPercent < -5 {
            content.title = "📉 Position Down \(String(format: "%.1f", pnlPercent))%"
        } else {
            content.title = "BTC Position Update"
        }

        let btcAmount = String(format: "%.6f", position.amountBTC)
        content.body = "\(btcAmount) BTC @ $\(formatPrice(position.entryPrice)) — \(reason)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "btc-position-\(position.id.uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func sendPriceAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "btc-price-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Recurring Check

    func scheduleRecurringCheck() {
        // Schedule a background check every 4 hours
        let content = UNMutableNotificationContent()
        content.title = "BTC Signal Check"
        content.body = "Tap to open and check your positions"
        content.sound = .default

        // 4 hours = 14400 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 14400, repeats: true)
        let request = UNNotificationRequest(identifier: "btc-recurring-check", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.0f", price)
    }
}
